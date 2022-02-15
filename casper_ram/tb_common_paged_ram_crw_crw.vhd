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

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;

-- Purpose: Test bench for common_paged_ram_crw_crw
--
-- Features:
-- . Use c_gap_sz = 0 to try writing and reading multiple page without idle
--   cycles
-- . Most applications use c_nof_pages = 2, but use > 2 is supported too.
--
-- Usage:
-- > as 10
-- > run -all
  

ENTITY tb_common_paged_ram_crw_crw IS
END tb_common_paged_ram_crw_crw;

ARCHITECTURE tb OF tb_common_paged_ram_crw_crw IS

  CONSTANT clk_period        : TIME := 10 ns;
  
  CONSTANT c_data_w          : NATURAL := 8;
  CONSTANT c_nof_pages       : NATURAL := 2;  -- >= 2
  CONSTANT c_page_sz         : NATURAL := 8;
  CONSTANT c_start_page_a    : NATURAL := 0;
  CONSTANT c_start_page_b    : NATURAL := 1;
  CONSTANT c_gap_sz          : NATURAL := 0;  -- >= 0
  CONSTANT c_rl              : NATURAL := 1;
    
  SIGNAL rst               : STD_LOGIC;
  SIGNAL clk               : STD_LOGIC := '1';
  SIGNAL tb_end            : STD_LOGIC := '0';
  
  -- DUT
  SIGNAL next_page         : STD_LOGIC;
  
  SIGNAL next_page_a       : STD_LOGIC;
  SIGNAL adr_a             : STD_LOGIC_VECTOR(ceil_log2(c_page_sz)-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL wr_en_a           : STD_LOGIC;
  SIGNAL wr_dat_a          : STD_LOGIC_VECTOR(c_data_w-1 DOWNTO 0) := (OTHERS=>'0');
  
  SIGNAL next_page_b       : STD_LOGIC;
  SIGNAL adr_b             : STD_LOGIC_VECTOR(ceil_log2(c_page_sz)-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL rd_en_b           : STD_LOGIC := '0';
  
  SIGNAL mux_rd_dat_b      : STD_LOGIC_VECTOR(c_data_w-1 DOWNTO 0);
  SIGNAL mux_rd_val_b      : STD_LOGIC;
  
  SIGNAL adr_rd_dat_b      : STD_LOGIC_VECTOR(c_data_w-1 DOWNTO 0);
  SIGNAL adr_rd_val_b      : STD_LOGIC;
  
  SIGNAL ofs_rd_dat_b      : STD_LOGIC_VECTOR(c_data_w-1 DOWNTO 0);
  SIGNAL ofs_rd_val_b      : STD_LOGIC;
  
  -- Verify
  SIGNAL verify_en         : STD_LOGIC;
  SIGNAL ready             : STD_LOGIC := '1';
  
  SIGNAL prev_mux_rd_dat_b : STD_LOGIC_VECTOR(c_data_w-1 DOWNTO 0);
  SIGNAL prev_adr_rd_dat_b : STD_LOGIC_VECTOR(c_data_w-1 DOWNTO 0);
  SIGNAL prev_ofs_rd_dat_b : STD_LOGIC_VECTOR(c_data_w-1 DOWNTO 0);
  
BEGIN

  clk <= NOT clk AND NOT tb_end AFTER clk_period/2;
  rst <= '1', '0' AFTER clk_period*7;
  
  verify_en <= '0', '1' AFTER clk_period*(15+(c_nof_pages-1)*c_page_sz);
  
  -- Apply stimuli via port 'a', do write 'a' and read 'b', and derive the 'b' stimuli from the 'a' stimuli with 1 clock cycle latency
  next_page_a <= next_page;
  next_page_b <= next_page WHEN rising_edge(clk);
  
  wr_dat_a <= INCR_UVEC(wr_dat_a, 1) WHEN rising_edge(clk) AND wr_en_a='1';
  adr_a    <= INCR_UVEC(   adr_a, 1) WHEN rising_edge(clk) AND wr_en_a='1';
  adr_b    <=              adr_a     WHEN rising_edge(clk);
  rd_en_b  <=            wr_en_a     WHEN rising_edge(clk);
  
  p_stimuli : PROCESS
  BEGIN
    next_page <= '0';
    wr_en_a   <= '0';
    proc_common_wait_until_low(clk, rst);
    proc_common_wait_some_cycles(clk, 3);
    
    -- Access the pages several times
    FOR I IN 0 TO c_nof_pages*3 LOOP
      wr_en_a <= '1';
      proc_common_wait_some_cycles(clk, c_page_sz-1);
      next_page <= '1';
      proc_common_wait_some_cycles(clk, 1);
      next_page <= '0';
      wr_en_a <= '0';
      proc_common_wait_some_cycles(clk, c_gap_sz);  -- optinal gap between the pages
    END LOOP;
    
    wr_en_a <= '0';
    proc_common_wait_some_cycles(clk, c_page_sz);
    tb_end <= '1';
    WAIT;
  END PROCESS;
  
  u_dut_mux : ENTITY work.common_paged_ram_crw_crw
  GENERIC MAP (
    g_str           => "use_mux",
    g_data_w        => c_data_w,
    g_nof_pages     => c_nof_pages,
    g_page_sz       => c_page_sz,
    g_start_page_a  => c_start_page_a,
    g_start_page_b  => c_start_page_b
  )
  PORT MAP (
    rst_a       => rst,
    rst_b       => rst,
    clk_a       => clk,
    clk_b       => clk,
    clken_a     => '1',
    clken_b     => '1',
    next_page_a => next_page_a,
    adr_a       => adr_a,
    wr_en_a     => wr_en_a,
    wr_dat_a    => wr_dat_a,
    rd_en_a     => '0',
    rd_dat_a    => OPEN,
    rd_val_a    => OPEN,
    next_page_b => next_page_b,
    adr_b       => adr_b,
    wr_en_b     => '0',
    wr_dat_b    => (OTHERS=>'0'),
    rd_en_b     => rd_en_b,
    rd_dat_b    => mux_rd_dat_b,
    rd_val_b    => mux_rd_val_b
  );
  
  u_dut_adr : ENTITY work.common_paged_ram_crw_crw
  GENERIC MAP (
    g_str           => "use_adr",
    g_data_w        => c_data_w,
    g_nof_pages     => c_nof_pages,
    g_page_sz       => c_page_sz,
    g_start_page_a  => c_start_page_a,
    g_start_page_b  => c_start_page_b
  )
  PORT MAP (
    rst_a       => rst,
    rst_b       => rst,
    clk_a       => clk,
    clk_b       => clk,
    clken_a     => '1',
    clken_b     => '1',
    next_page_a => next_page_a,
    adr_a       => adr_a,
    wr_en_a     => wr_en_a,
    wr_dat_a    => wr_dat_a,
    rd_en_a     => '0',
    rd_dat_a    => OPEN,
    rd_val_a    => OPEN,
    next_page_b => next_page_b,
    adr_b       => adr_b,
    wr_en_b     => '0',
    wr_dat_b    => (OTHERS=>'0'),
    rd_en_b     => rd_en_b,
    rd_dat_b    => adr_rd_dat_b,
    rd_val_b    => adr_rd_val_b
  );
  
  u_dut_ofs : ENTITY work.common_paged_ram_crw_crw
  GENERIC MAP (
    g_str           => "use_ofs",
    g_data_w        => c_data_w,
    g_nof_pages     => c_nof_pages,
    g_page_sz       => c_page_sz,
    g_start_page_a  => c_start_page_a,
    g_start_page_b  => c_start_page_b
  )
  PORT MAP (
    rst_a       => rst,
    rst_b       => rst,
    clk_a       => clk,
    clk_b       => clk,
    clken_a     => '1',
    clken_b     => '1',
    next_page_a => next_page_a,
    adr_a       => adr_a,
    wr_en_a     => wr_en_a,
    wr_dat_a    => wr_dat_a,
    rd_en_a     => '0',
    rd_dat_a    => OPEN,
    rd_val_a    => OPEN,
    next_page_b => next_page_b,
    adr_b       => adr_b,
    wr_en_b     => '0',
    wr_dat_b    => (OTHERS=>'0'),
    rd_en_b     => rd_en_b,
    rd_dat_b    => ofs_rd_dat_b,
    rd_val_b    => ofs_rd_val_b
  );

  -- Verify that the read data is incrementing data
  proc_common_verify_data(c_rl, clk, verify_en, ready, mux_rd_val_b, mux_rd_dat_b, prev_mux_rd_dat_b);
  proc_common_verify_data(c_rl, clk, verify_en, ready, adr_rd_val_b, adr_rd_dat_b, prev_adr_rd_dat_b);
  proc_common_verify_data(c_rl, clk, verify_en, ready, ofs_rd_val_b, ofs_rd_dat_b, prev_ofs_rd_dat_b);
     
  -- Verify that the read data is the same for all three DUT variants
  p_verify_equal : PROCESS(clk)  
  BEGIN
    IF rising_edge(clk) THEN
      IF UNSIGNED(mux_rd_dat_b) /= UNSIGNED(adr_rd_dat_b) OR UNSIGNED(mux_rd_dat_b) /= UNSIGNED(ofs_rd_dat_b) THEN
        REPORT "DUT : read data differs between two implementations" SEVERITY ERROR;
      END IF;
      IF mux_rd_val_b /= adr_rd_val_b OR mux_rd_val_b /= ofs_rd_val_b THEN
        REPORT "DUT : read valid differs between two implementations" SEVERITY ERROR;
      END IF;
    END IF;
  END PROCESS;
  
END tb;
