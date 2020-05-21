-------------------------------------------------------------------------------
--
-- Copyright 2020
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--     http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-------------------------------------------------------------------------------
--
-- Author:
--   D. van der Schuur  May 2012  Original with manual file IO using an editor.
--   E. Kooistra        Feb 2017  Added purpose and description
--                                Added external control by p_mm_stimuli and
--                                p_sim_stimuli
-- Purpose: Testbench for MM and simulation control via file io
-- Description:
--   This testbench verifies mm_file and mm_file_pkg.
--   1) p_mm_stimuli
--     The p_mm_stimuli uses mmf_mm_bus_wr() and mmf_mm_bus_rd() to access a MM
--     slave register instance of common_reg_r_w_dc via mm_file using a MM slave
--     .ctrl and .stat file. The p_mm_stimuli verifies the W/R accesses.
--   2) p_sim_stimuli
--     The p_sim_stimuli waits for get_now and then it uses mmf_sim_get_now() to
--     read the simulator status via mmf_poll_sim_ctrl_file() using a sim.ctrl
--     and sim.stat file. The p_sim_stimuli does not verify read rd_now value,
--     but it does print it.
-- Usage:
--   > as 5
--   > run -all
--   The tb is self stopping and self checking. 
--   For example observe mm_mosi, mm_miso, rd_now and out_reg_arr in wave window.

LIBRARY IEEE, common_pkg_lib, casper_ram_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE common_pkg_lib.common_str_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;
USE work.mm_file_pkg.ALL;

ENTITY tb_mm_file IS
  GENERIC (
    g_tb_index           : NATURAL := 0;
    g_mm_nof_accesses    : NATURAL := 100;
    g_mm_timeout         : TIME := 0 ns;--100 ns;   -- default 0 ns for full speed MM, use > 0 to define number of mm_clk without MM access after which the MM file IO is paused
    g_mm_pause           : TIME := 1000 ns;  -- defines the time for which MM file IO is paused to reduce the file IO rate when the MM slave is idle
    g_timeout_gap        : INTEGER := -1;--4;    -- no gap when < 0, else force MM access gap after g_timeout_gap wr or rd strobes
    g_cross_clock_domain : BOOLEAN := FALSE --TRUE
  );
END tb_mm_file;

ARCHITECTURE tb OF tb_mm_file IS

  CONSTANT c_mm_clk_period            : TIME := c_mmf_mm_clk_period;  -- = 100 ps;
  CONSTANT c_mm_nof_dat               : NATURAL := smallest(c_mem_reg_init_w/c_32, g_mm_nof_accesses);
  CONSTANT c_mm_rd_latency            : NATURAL := 2;
  
  CONSTANT c_cross_nof_mm_clk         : NATURAL := sel_a_b(g_cross_clock_domain, 100, 0);  -- > 2*24 see common_reg_cross_domain, factor 2 for W/R
  
  -- Determine node mm_file prefix based on --unb --gn (similar as done in mmf_unb_file_prefix())
  CONSTANT c_unb_nr                   : NATURAL := 3;  --unb
  CONSTANT c_pn_nr                    : NATURAL := 1;  --gn = 0:7
  CONSTANT c_node_type                : STRING(1 TO 2):= sel_a_b(c_pn_nr<4, "FN", "BN");
  CONSTANT c_node_nr                  : NATURAL := sel_a_b(c_node_type="BN", c_pn_nr-4, c_pn_nr);

  -- Use local mmfiles/ subdirectory in mm project build directory
  CONSTANT c_sim_file_pathname        : STRING := mmf_slave_prefix("TB", g_tb_index) & "sim";
  CONSTANT c_reg_r_w_dc_file_pathname : STRING := mmf_slave_prefix("TB", g_tb_index, "UNB", c_unb_nr, c_node_type, c_node_nr) & "REG_R_W_DC";

  --TYPE t_c_mem IS RECORD
  --  latency   : NATURAL;    -- read latency
  --  adr_w     : NATURAL;
  --  dat_w     : NATURAL;
  --  nof_dat   : NATURAL;    -- optional, nof dat words <= 2**adr_w
  --  init_sl   : STD_LOGIC;  -- optional, init all dat words to std_logic '0', '1' or 'X'
  --  --init_file : STRING;     -- "UNUSED", unconstrained length can not be in record
  --END RECORD;
  CONSTANT c_mem_reg            : t_c_mem := (c_mm_rd_latency, ceil_log2(c_mm_nof_dat), c_32, c_mm_nof_dat, '0');

  SIGNAL tb_state           : STRING(1 TO 5) := "Init ";
  SIGNAL tb_end             : STD_LOGIC := '0';
  SIGNAL mm_clk             : STD_LOGIC := '0';
  SIGNAL mm_rst             : STD_LOGIC;

  SIGNAL get_now            : STD_LOGIC := '0';
  SIGNAL rd_now             : STRING(1 TO 16);  -- sufficient to fit TIME NOW in ns as a string
  
  SIGNAL mm_mosi            : t_mem_mosi;
  SIGNAL mm_miso            : t_mem_miso;
  SIGNAL file_wr_data       : STD_LOGIC_VECTOR(c_32-1 DOWNTO 0);
  SIGNAL file_rd_data       : STD_LOGIC_VECTOR(c_32-1 DOWNTO 0);

  SIGNAL reg_wr_arr         : STD_LOGIC_VECTOR(     c_mem_reg.nof_dat-1 DOWNTO 0);
  SIGNAL reg_rd_arr         : STD_LOGIC_VECTOR(     c_mem_reg.nof_dat-1 DOWNTO 0);
  SIGNAL in_new             : STD_LOGIC := '1';
  SIGNAL in_reg             : STD_LOGIC_VECTOR(c_32*c_mem_reg.nof_dat-1 DOWNTO 0);
  SIGNAL out_reg            : STD_LOGIC_VECTOR(c_32*c_mem_reg.nof_dat-1 DOWNTO 0);
  SIGNAL out_new            : STD_LOGIC;    -- Pulses '1' when new data has been written.

  SIGNAL out_reg_arr        : t_slv_32_arr(c_mem_reg.nof_dat-1 DOWNTO 0);
  
BEGIN

  mm_clk <= NOT mm_clk OR tb_end AFTER c_mm_clk_period/2;
  mm_rst <= '1', '0' AFTER c_mm_clk_period*10;

  -- DUT mm access files 'c_reg_r_w_dc_file_pathname'.ctrl and 'c_reg_r_w_dc_file_pathname'.stat
  p_mm_stimuli : PROCESS
    VARIABLE v_addr : NATURAL;
  BEGIN
    proc_common_wait_until_low(mm_clk, mm_rst);
    proc_common_wait_some_cycles(mm_clk, 3);
    
    -- Write all nof_dat once
    tb_state <= "Write";
    FOR I IN 0 TO c_mm_nof_dat-1 LOOP
      IF I=g_timeout_gap THEN
        WAIT FOR 2*c_mmf_mm_timeout;
      END IF;
      file_wr_data <= TO_UVEC(I, c_32);
      mmf_mm_bus_wr(c_reg_r_w_dc_file_pathname, I, I, mm_clk);
    END LOOP;
    
    proc_common_wait_some_cycles(mm_clk, c_cross_nof_mm_clk);
    
    -- Read all nof_dat once
    tb_state <= "Read ";
    FOR I IN 0 TO c_mm_nof_dat-1 LOOP
      IF I=g_timeout_gap THEN
        WAIT FOR 2*c_mmf_mm_timeout;
      END IF;
      mmf_mm_bus_rd(c_reg_r_w_dc_file_pathname, c_mem_reg.latency, I, file_rd_data, mm_clk);
      ASSERT I=TO_UINT(file_rd_data) REPORT "Read data is wrong." SEVERITY ERROR;
    END LOOP;
    
    -- Write/Read
    tb_state <= "Both ";
    FOR I IN 0 TO g_mm_nof_accesses-1 LOOP
      IF I=g_timeout_gap THEN
        WAIT FOR 2*c_mmf_mm_timeout;
      END IF;
      file_wr_data <= TO_UVEC(I, c_32);
      v_addr := I MOD c_mm_nof_dat;
      mmf_mm_bus_wr(c_reg_r_w_dc_file_pathname, v_addr, I, mm_clk);
      proc_common_wait_some_cycles(mm_clk, c_cross_nof_mm_clk);
      mmf_mm_bus_rd(c_reg_r_w_dc_file_pathname, c_mem_reg.latency, v_addr, file_rd_data, mm_clk);
      ASSERT TO_UINT(file_wr_data)=TO_UINT(file_rd_data) REPORT "Write/read data is wrong." SEVERITY ERROR;
    END LOOP;
    
    proc_common_gen_pulse(mm_clk, get_now);
    tb_state <= "End  ";
    
    proc_common_wait_some_cycles(mm_clk, g_mm_nof_accesses);
    tb_end <= '1';
    WAIT;
  END PROCESS;
                            
  u_mm_file : ENTITY work.mm_file
  GENERIC MAP(
    g_file_prefix   => c_reg_r_w_dc_file_pathname,
    g_mm_rd_latency => c_mem_reg.latency,  -- the mm_file g_mm_rd_latency must be >= the MM slave read latency
    g_mm_timeout    => g_mm_timeout,
    g_mm_pause      => g_mm_pause
  )
  PORT MAP (
    mm_rst        => mm_rst,
    mm_clk        => mm_clk,

    mm_master_out => mm_mosi,
    mm_master_in  => mm_miso
  );

  -- Target MM reg
  u_reg_r_w_dc : ENTITY work.common_reg_r_w_dc
  GENERIC MAP (
    g_cross_clock_domain => g_cross_clock_domain,
    g_in_new_latency     => 0,
    g_readback           => FALSE,
    g_reg                => c_mem_reg
    --g_init_reg           => STD_LOGIC_VECTOR(c_mem_reg_init_w-1 DOWNTO 0) := (OTHERS => '0')
  )
  PORT MAP (
    -- Clocks and reset
    mm_rst      => mm_rst,
    mm_clk      => mm_clk,
    st_rst      => mm_rst,
    st_clk      => mm_clk,

    -- Memory Mapped Slave in mm_clk domain
    sla_in      => mm_mosi,
    sla_out     => mm_miso,

    -- MM registers in st_clk domain
    reg_wr_arr  => reg_wr_arr,
    reg_rd_arr  => reg_rd_arr,
    in_new      => in_new,
    in_reg      => in_reg,
    out_reg     => out_reg,
    out_new     => out_new
  );
  
  in_reg <= out_reg;
  
  p_wire : PROCESS(out_reg)
  BEGIN
    FOR I IN c_mem_reg.nof_dat-1 DOWNTO 0 LOOP
      out_reg_arr(I) <= out_reg((I+1)*c_32-1 DOWNTO I*c_32);
    END LOOP;
  END PROCESS;

  -- Also verify simulation status access
  mmf_poll_sim_ctrl_file(mm_clk, c_sim_file_pathname & ".ctrl", c_sim_file_pathname & ".stat");

  p_sim_stimuli : PROCESS
  BEGIN
    proc_common_wait_until_low(mm_clk, mm_rst);
    proc_common_wait_some_cycles(mm_clk, 10);
    
    proc_common_wait_until_hi_lo(mm_clk, get_now);
    mmf_sim_get_now(c_sim_file_pathname, rd_now, mm_clk);
    WAIT;
  END PROCESS;
  
END tb;
