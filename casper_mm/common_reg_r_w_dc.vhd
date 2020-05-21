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

-- Purpose: Provide dual clock domain crossing to common_reg_r_w.vhd
-- Description:
-- . Write vector to out_reg
-- . Read vector from in_reg or readback from out_reg
--
--   31             24 23             16 15              8 7               0  wi
--  |-----------------|-----------------|-----------------|-----------------|
--  |                              data[31:0]                               |  0
--  |-----------------------------------------------------------------------|
--  |                              data[63:32]                              |  1
--  |-----------------------------------------------------------------------|
--
-- . g_readback
--   When g_readback is TRUE then the written data is read back from the st_clk
--   domain directly into the mm_clk domain, so without ST --> MM clock domain
--   crossing logic. This is allowed because the read back value is stable. 
--   For readback the out_reg needs to be connected to in_reg, independent of
--   the g_readback setting, because the readback value is read back from the
--   st_clk domain. In this way the readback value also reveals that the 
--   written value is indeed available in the st_clk domain (ie. this shows 
--   that the st_clk is active). If g_cross_clock_domain=FALSE, then g_readback
--   is don't care.
--   In fact g_readback could better be called g_st_readback. An alternative
--   g_mm_readback could define direct read back in the MM clock domain and
--   would allow leaving the in_reg not connected.

LIBRARY IEEE, common_pkg_lib, common_components_lib, casper_ram_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;

ENTITY common_reg_r_w_dc IS
  GENERIC (
    g_cross_clock_domain : BOOLEAN := TRUE;  -- use FALSE when mm_clk and st_clk are the same, else use TRUE to cross the clock domain
    g_in_new_latency     : NATURAL := 0;  -- >= 0
    g_readback           : BOOLEAN := FALSE;  -- must use FALSE for write/read or read only register when g_cross_clock_domain=TRUE
    --g_readback           : BOOLEAN := TRUE;   -- can use TRUE for write and readback register
    g_reg                : t_c_mem := c_mem_reg;
    g_init_reg           : STD_LOGIC_VECTOR(c_mem_reg_init_w-1 DOWNTO 0) := (OTHERS => '0')
  );
  PORT (
    -- Clocks and reset
    mm_rst      : IN  STD_LOGIC;   -- reset synchronous with mm_clk
    mm_clk      : IN  STD_LOGIC;   -- memory-mapped bus clock
    st_rst      : IN  STD_LOGIC;   -- reset synchronous with st_clk
    st_clk      : IN  STD_LOGIC;   -- other clock domain clock
    
    -- Memory Mapped Slave in mm_clk domain
    sla_in      : IN  t_mem_mosi;  -- actual ranges defined by g_reg
    sla_out     : OUT t_mem_miso;  -- actual ranges defined by g_reg
    
    -- MM registers in st_clk domain
    reg_wr_arr  : OUT STD_LOGIC_VECTOR(            g_reg.nof_dat-1 DOWNTO 0);
    reg_rd_arr  : OUT STD_LOGIC_VECTOR(            g_reg.nof_dat-1 DOWNTO 0);
    in_new      : IN  STD_LOGIC := '1';
    in_reg      : IN  STD_LOGIC_VECTOR(g_reg.dat_w*g_reg.nof_dat-1 DOWNTO 0);
    out_reg     : OUT STD_LOGIC_VECTOR(g_reg.dat_w*g_reg.nof_dat-1 DOWNTO 0);
    out_new     : OUT STD_LOGIC    -- Pulses '1' when new data has been written. 
  );
END common_reg_r_w_dc;


ARCHITECTURE str OF common_reg_r_w_dc IS

  -- Registers in mm_clk domain
  SIGNAL vector_wr_arr   : STD_LOGIC_VECTOR(            g_reg.nof_dat-1 DOWNTO 0);
  SIGNAL vector_rd_arr   : STD_LOGIC_VECTOR(            g_reg.nof_dat-1 DOWNTO 0);
  SIGNAL out_vector      : STD_LOGIC_VECTOR(g_reg.dat_w*g_reg.nof_dat-1 DOWNTO 0);
  SIGNAL in_vector       : STD_LOGIC_VECTOR(g_reg.dat_w*g_reg.nof_dat-1 DOWNTO 0);

  -- Initialize output to avoid Warning: (vsim-8684) No drivers exist on out port *, and its initial value is not used
  SIGNAL i_sla_out       : t_mem_miso := c_mem_miso_rst;
  
  SIGNAL reg_wr_arr_i    : STD_LOGIC_VECTOR(            g_reg.nof_dat-1 DOWNTO 0);  
  SIGNAL wr_pulse        : STD_LOGIC;
  SIGNAL toggle          : STD_LOGIC;
  SIGNAL out_new_i       : STD_LOGIC;  
  
BEGIN

  ------------------------------------------------------------------------------
  -- MM register access in the mm_clk domain
  ------------------------------------------------------------------------------
  
  sla_out <= i_sla_out;
  
  u_reg : ENTITY work.common_reg_r_w
  GENERIC MAP (
    g_reg      => g_reg,
    g_init_reg => g_init_reg
  )
  PORT MAP (
    rst         => mm_rst,
    clk         => mm_clk,
    -- control side
    wr_en       => sla_in.wr,
    wr_adr      => sla_in.address(g_reg.adr_w-1 DOWNTO 0),
    wr_dat      => sla_in.wrdata(g_reg.dat_w-1 DOWNTO 0),
    rd_en       => sla_in.rd,
    rd_adr      => sla_in.address(g_reg.adr_w-1 DOWNTO 0),
    rd_dat      => i_sla_out.rddata(g_reg.dat_w-1 DOWNTO 0),
    rd_val      => i_sla_out.rdval,
    -- data side
    reg_wr_arr  => vector_wr_arr,
    reg_rd_arr  => vector_rd_arr,
    out_reg     => out_vector,
    in_reg      => in_vector
  );
  

  ------------------------------------------------------------------------------
  -- Transfer register value between mm_clk and st_clk domain.
  -- If the function of the register ensures that the value will not be used
  -- immediately when it was set, then the transfer between the clock domains
  -- can be done by wires only. Otherwise if the change in register value can
  -- have an immediate effect then the bit or word value needs to be transfered
  -- using:
  --
  -- . common_async            --> for single-bit level signal
  -- . common_spulse           --> for single-bit pulse signal
  -- . common_reg_cross_domain --> for a multi-bit (a word) signal
  --
  -- Typically always use a crossing component for the single bit signals (to
  -- be on the save side) and only use a crossing component for the word
  -- signals if it is necessary (to avoid using more logic than necessary).
  ------------------------------------------------------------------------------
  
  no_cross : IF g_cross_clock_domain = FALSE GENERATE
    in_vector   <= in_reg;
    out_reg     <= out_vector;
    reg_wr_arr  <= vector_wr_arr;
    reg_rd_arr  <= vector_rd_arr; 
    out_new     <= vector_wr_arr(0);
  END GENERATE;  -- no_cross

  gen_cross : IF g_cross_clock_domain = TRUE GENERATE
  
    gen_rdback : IF g_readback=TRUE GENERATE
      in_vector <= in_reg;
    END GENERATE;
    
    gen_rd : IF g_readback=FALSE GENERATE
      u_in_vector : ENTITY work.common_reg_cross_domain
      GENERIC MAP (
        g_in_new_latency => g_in_new_latency
      )
      PORT MAP (
        in_rst      => st_rst,
        in_clk      => st_clk,
        in_new      => in_new,
        in_dat      => in_reg,
        in_done     => OPEN,
        out_rst     => mm_rst,
        out_clk     => mm_clk,
        out_dat     => in_vector,
        out_new     => OPEN
      );
    END GENERATE;
  
    u_out_reg : ENTITY work.common_reg_cross_domain
    GENERIC MAP(
      g_out_dat_init => g_init_reg
    )
    PORT MAP (
      in_rst      => mm_rst,
      in_clk      => mm_clk,
      in_dat      => out_vector,
      in_done     => OPEN,
      out_rst     => st_rst,
      out_clk     => st_clk,
      out_dat     => out_reg,
      out_new     => out_new_i
    );

    u_toggle : ENTITY common_components_lib.common_switch
    GENERIC MAP (
      g_rst_level    => '0',
      g_priority_lo  => FALSE,
      g_or_high      => FALSE,
      g_and_low      => FALSE
    )
    PORT MAP (
      rst         => st_rst,
      clk         => st_clk,
      switch_high => wr_pulse,
      switch_low  => out_new_i,
      out_level   => toggle
    );
  
    wr_pulse   <= '0' WHEN vector_or(reg_wr_arr_i)='0' ELSE '1'; 
    out_new    <= out_new_i AND toggle;
    reg_wr_arr <= reg_wr_arr_i;
    
    gen_access_evt : FOR I IN 0 TO g_reg.nof_dat-1 GENERATE
      u_reg_wr_arr : ENTITY common_components_lib.common_spulse
      PORT MAP (
        in_rst    => mm_rst,
        in_clk    => mm_clk,
        in_pulse  => vector_wr_arr(I),
        in_busy   => OPEN,
        out_rst   => st_rst,
        out_clk   => st_clk,
        out_pulse => reg_wr_arr_i(I)
      );
    
      u_reg_rd_arr : ENTITY common_components_lib.common_spulse
      PORT MAP (
        in_rst    => mm_rst,
        in_clk    => mm_clk,
        in_pulse  => vector_rd_arr(I),
        in_busy   => OPEN,
        out_rst   => st_rst,
        out_clk   => st_clk,
        out_pulse => reg_rd_arr(I)
      );
    END GENERATE;
    
  END GENERATE;  -- gen_cross

END str;
