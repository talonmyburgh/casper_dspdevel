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
-- Purpose:  Testbench for the st_sst unit. 
--           To be used in conjunction with python script: ../python/tc_mmf_st_sst.py
--
--
-- Usage in non-auto-mode (c_modelsim_start = 0 in python):
--   > as 5
--   > run -all
--   > Run python script in separate terminal: "python tc_mmf_st_xst.py --unb 0 --bn 0 --sim"
--   > Check the results of the python script. 
--   > Stop the simulation manually in Modelsim by pressing the stop-button.
--   > Evalute the WAVE window. 

LIBRARY IEEE, common_pkg_lib, casper_ram_lib, casper_mm_lib, casper_diagnostics_lib, dp_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE common_pkg_lib.common_str_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;
USE casper_mm_lib.tb_common_mem_pkg.ALL;
USE casper_mm_lib.mm_file_unb_pkg.ALL;
USE casper_mm_lib.mm_file_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL; 
USE casper_diagnostics_lib.diag_pkg.ALL; 

ENTITY tb_mmf_st_sst IS 
  GENERIC(
    g_nof_stat      : NATURAL := 8; -- nof accumulators
    g_xst_enable    : BOOLEAN := TRUE; 
    g_in_data_w     : NATURAL := 16;
    g_stat_data_w   : NATURAL := 56;  -- statistics accumulator width
    g_stat_data_sz  : NATURAL := 2;   -- statistics word width >= statistics accumulator width and fit in a power of 2 multiple 32b MM words
    g_nof_instances : NATURAL := 4;   -- The number of st_sst instances in parallel. 
    g_nof_frames    : NATURAL := 1
  );
END tb_mmf_st_sst;

ARCHITECTURE tb OF tb_mmf_st_sst IS
  
  CONSTANT c_sim                : BOOLEAN := TRUE;

  ----------------------------------------------------------------------------
  -- Clocks and resets
  ----------------------------------------------------------------------------   
  CONSTANT c_mm_clk_period      : TIME := 100 ps;
  CONSTANT c_dp_clk_period      : TIME := 2 ns;
  CONSTANT c_sclk_period        : TIME := 1250 ps;
  CONSTANT c_dp_pps_period      : NATURAL := 64;

  SIGNAL dp_pps                 : STD_LOGIC;

  SIGNAL mm_rst                 : STD_LOGIC := '1';
  SIGNAL mm_clk                 : STD_LOGIC := '0';

  SIGNAL dp_rst                 : STD_LOGIC;
  SIGNAL dp_clk                 : STD_LOGIC := '0';

  ----------------------------------------------------------------------------
  -- MM buses
  ----------------------------------------------------------------------------                                         
  SIGNAL reg_diag_bg_mosi       : t_mem_mosi;
  SIGNAL reg_diag_bg_miso       : t_mem_miso;
                              
  SIGNAL ram_diag_bg_mosi       : t_mem_mosi;
  SIGNAL ram_diag_bg_miso       : t_mem_miso;
                              
  SIGNAL ram_st_sst_mosi        : t_mem_mosi;
  SIGNAL ram_st_sst_miso        : t_mem_miso;
                               
  SIGNAL reg_st_sst_mosi        : t_mem_mosi;
  SIGNAL reg_st_sst_miso        : t_mem_miso;
  
  SIGNAL ram_st_sst_mosi_arr    : t_mem_mosi_arr(g_nof_instances-1 DOWNTO 0);
  SIGNAL ram_st_sst_miso_arr    : t_mem_miso_arr(g_nof_instances-1 DOWNTO 0);
                                
  SIGNAL reg_st_sst_mosi_arr    : t_mem_mosi_arr(g_nof_instances-1 DOWNTO 0);
  SIGNAL reg_st_sst_miso_arr    : t_mem_miso_arr(g_nof_instances-1 DOWNTO 0);

  -- Custom definitions of constants
  CONSTANT c_bg_block_len           : NATURAL  := g_nof_stat*g_nof_frames;
  CONSTANT c_complex_factor         : NATURAL  := sel_a_b(g_xst_enable, c_nof_complex, 1); 
  CONSTANT c_ram_addr_w             : NATURAL  := ceil_log2(g_stat_data_sz*g_nof_stat*c_complex_factor);
 
  -- Configuration of the block generator:
  CONSTANT c_bg_nof_output_streams  : POSITIVE := g_nof_instances;    
  CONSTANT c_bg_buf_dat_w           : POSITIVE := c_nof_complex*g_in_data_w;
  CONSTANT c_bg_buf_adr_w           : POSITIVE := ceil_log2(c_bg_block_len);
  CONSTANT c_bg_data_file_prefix    : STRING   := "UNUSED";
  CONSTANT c_bg_data_file_index_arr : t_nat_natural_arr := array_init(0, g_nof_instances, 1);
  
  -- Signal declarations to connect block generator to the DUT
  SIGNAL bg_siso_arr                : t_dp_siso_arr(c_bg_nof_output_streams-1 DOWNTO 0) := (OTHERS=>c_dp_siso_rdy);
  SIGNAL bg_sosi_arr                : t_dp_sosi_arr(c_bg_nof_output_streams-1 DOWNTO 0);
   
BEGIN

  ----------------------------------------------------------------------------
  -- Clock and reset generation
  ----------------------------------------------------------------------------
  mm_clk <= NOT mm_clk AFTER c_mm_clk_period/2;
  mm_rst <= '1', '0' AFTER c_mm_clk_period*5;

  dp_clk <= NOT dp_clk AFTER c_dp_clk_period/2;
  dp_rst <= '1', '0' AFTER c_dp_clk_period*5;

  ------------------------------------------------------------------------------
  -- External PPS
  ------------------------------------------------------------------------------  
  proc_common_gen_pulse(1, c_dp_pps_period, '1', dp_clk, dp_pps);

   ----------------------------------------------------------------------------
  -- Procedure that polls a sim control file that can be used to e.g. get
  -- the simulation time in ns
  ----------------------------------------------------------------------------
  mmf_poll_sim_ctrl_file(c_mmf_unb_file_path & "sim.ctrl", c_mmf_unb_file_path & "sim.stat");
 
  ----------------------------------------------------------------------------
  -- MM buses  
  ----------------------------------------------------------------------------
  u_mm_file_reg_diag_bg          : mm_file GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "REG_DIAG_BG")
                                           PORT MAP(mm_rst, mm_clk, reg_diag_bg_mosi, reg_diag_bg_miso);

  u_mm_file_ram_diag_bg          : mm_file GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "RAM_DIAG_BG")
                                           PORT MAP(mm_rst, mm_clk, ram_diag_bg_mosi, ram_diag_bg_miso);

  u_mm_file_ram_st_sst           : mm_file GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "RAM_ST_SST")
                                           PORT MAP(mm_rst, mm_clk, ram_st_sst_mosi, ram_st_sst_miso);

  u_mm_file_reg_st_sst           : mm_file GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "REG_ST_SST")
                                           PORT MAP(mm_rst, mm_clk, reg_st_sst_mosi, reg_st_sst_miso);

  ----------------------------------------------------------------------------
  -- Source: block generator
  ---------------------------------------------------------------------------- 
  u_bg : ENTITY casper_diagnostics_lib.mms_diag_block_gen
  GENERIC MAP(
    g_nof_streams        => c_bg_nof_output_streams,
    g_buf_dat_w          => c_bg_buf_dat_w,
    g_buf_addr_w         => c_bg_buf_adr_w,            
    g_file_index_arr     => c_bg_data_file_index_arr,
    g_file_name_prefix   => c_bg_data_file_prefix
  )
  PORT MAP(
    -- System
    mm_rst               => mm_rst,
    mm_clk               => mm_clk,
    dp_rst               => dp_rst,
    dp_clk               => dp_clk,
    en_sync              => dp_pps,
    -- MM interface      
    reg_bg_ctrl_mosi     => reg_diag_bg_mosi,
    reg_bg_ctrl_miso     => reg_diag_bg_miso,
    ram_bg_data_mosi     => ram_diag_bg_mosi,
    ram_bg_data_miso     => ram_diag_bg_miso,
    -- ST interface      
    out_siso_arr         => bg_siso_arr,
    out_sosi_arr         => bg_sosi_arr
  );
  
  -- Combine the internal array of mm interfaces for the beamlet statistics to one array that is connected to the port of bf
  u_mem_mux_ram_sst : ENTITY casper_mm_lib.common_mem_mux
  GENERIC MAP (    
    g_nof_mosi    => g_nof_instances,
    g_mult_addr_w => c_ram_addr_w 
  )
  PORT MAP (
    mosi     => ram_st_sst_mosi,
    miso     => ram_st_sst_miso,
    mosi_arr => ram_st_sst_mosi_arr,
    miso_arr => ram_st_sst_miso_arr
  );  

  u_mem_mux_reg_sst : ENTITY casper_mm_lib.common_mem_mux
  GENERIC MAP (    
    g_nof_mosi    => g_nof_instances,
    g_mult_addr_w => 1
  )
  PORT MAP (
    mosi     => reg_st_sst_mosi,
    miso     => reg_st_sst_miso,
    mosi_arr => reg_st_sst_mosi_arr,
    miso_arr => reg_st_sst_miso_arr
  );  

  ----------------------------------------------------------------------------
  -- DUT: Device Under Test
  ---------------------------------------------------------------------------- 
  gen_duts : FOR I IN 0 TO g_nof_instances-1 GENERATE
    u_dut : ENTITY work.st_sst
    GENERIC MAP(
      g_nof_stat       => g_nof_stat,      
      g_xst_enable     => g_xst_enable,    
      g_in_data_w      => g_in_data_w,     
      g_stat_data_w    => g_stat_data_w,   
      g_stat_data_sz   => g_stat_data_sz  
    )
    PORT MAP(
      mm_rst           =>  mm_rst,
      mm_clk           =>  mm_clk,
      dp_rst           =>  dp_rst,
      dp_clk           =>  dp_clk,
      
      -- Streaming
      in_complex       => bg_sosi_arr(I), 
      
      -- Memory Mapped
      ram_st_sst_mosi  => ram_st_sst_mosi_arr(I),
      ram_st_sst_miso  => ram_st_sst_miso_arr(I),
      reg_st_sst_mosi  => reg_st_sst_mosi_arr(I),  
      reg_st_sst_miso  => reg_st_sst_miso_arr(I)
    );
  END GENERATE;

END tb;
