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
-- Modified for CASPER by:
-- @author: Talon Myburgh
-- @company: Mydon Solutions
--------------------------------------------------------------------------------

-- Purpose: Test bench for fft_r2_bf_par
-- Features:
--
-- Usage:
-- > as 10
-- > run -all
-- Testbench is selftesting. 

library IEEE, common_pkg_lib, dp_pkg_lib, casper_diagnostics_lib, r2sdf_fft_lib, casper_ram_lib, casper_mm_lib, common_components_lib;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;
use common_pkg_lib.common_pkg.ALL;
use casper_ram_lib.common_ram_pkg.ALL;
use common_pkg_lib.common_lfsr_sequences_pkg.ALL;
use common_pkg_lib.tb_common_pkg.ALL;  
use casper_mm_lib.tb_common_mem_pkg.ALL; 
use dp_pkg_lib.dp_stream_pkg.ALL;
use casper_diagnostics_lib.diag_pkg.ALL;  
use r2sdf_fft_lib.twiddlesPkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all; 

entity tb_fft_r2_bf_par is
  generic( 
    g_twiddle_width : natural := 18;
    g_stage       : natural := 4;
    g_element     : natural := 2
  );
end tb_fft_r2_bf_par;

architecture tb of tb_fft_r2_bf_par is

  constant c_pipeline              : t_fft_pipeline := c_fft_pipeline;  -- defined in astron_r2sdf_fft_lib.rTwoSDFPkg
  
  constant c_clk_period            : time    := 10 ns;
  constant c_nof_points            : natural := 1024;   -- Number of points should be a power of 2
  constant c_conjugate             : boolean := FALSE;  
                                   
  constant c_in_dat_w              : natural := 16; 
  constant c_weight_w              : natural := 16;
  constant c_prod_w                : natural := c_in_dat_w+c_weight_w;
  constant c_bit_growth            : natural := 1;
  constant c_round_w               : natural := c_weight_w-c_bit_growth;   -- the weights are normalized
   
  -- BG derived constants
  constant c_nof_streams           : natural := 2;
  constant c_bg_mem_size           : natural := 1024;
  constant c_bg_addr_w             : natural := ceil_log2(c_bg_mem_size);
  constant c_nof_samples_in_packet : natural := c_nof_points;
  constant c_gap                   : natural := 0;    -- Gapsize is set to 0 in order to generate a continuous stream of packets. 
  constant c_nof_accum_per_sync    : natural := 10;
  constant c_bsn_init              : natural := 32; 
  constant c_bg_prefix             : string := "data/ramp";

  signal tb_end           : std_logic := '0';
  signal rst              : std_logic;
  signal clk              : std_logic := '1'; 

  signal ram_bg_data_mosi : t_mem_mosi; 
  signal reg_bg_ctrl_mosi : t_mem_mosi;  
  signal in_sosi_arr      : t_dp_sosi_arr(c_nof_streams-1 downto 0);
  signal in_siso_arr      : t_dp_siso_arr(c_nof_streams-1 downto 0);  
  signal x_out_re         : std_logic_vector(c_in_dat_w-1 downto 0);
  signal x_out_im         : std_logic_vector(c_in_dat_w-1 downto 0);
  signal y_out_re         : std_logic_vector(c_in_dat_w-1 downto 0);
  signal y_out_im         : std_logic_vector(c_in_dat_w-1 downto 0);
  signal out_val          : std_logic;
  signal ovflw            : std_logic;
  
  signal ref_x_out_re_dly : std_logic_vector(c_in_dat_w-1 downto 0);
  signal ref_x_out_im_dly : std_logic_vector(c_in_dat_w-1 downto 0);
  signal ref_x_out_re     : std_logic_vector(c_in_dat_w-1 downto 0);
  signal ref_x_out_im     : std_logic_vector(c_in_dat_w-1 downto 0);

  signal ref_y_out_re_dly : std_logic_vector(c_in_dat_w-1 downto 0);
  signal ref_y_out_im_dly : std_logic_vector(c_in_dat_w-1 downto 0);
  signal ref_y_out_re     : std_logic_vector(c_in_dat_w-1 downto 0);
  signal ref_y_out_im     : std_logic_vector(c_in_dat_w-1 downto 0);
  signal ref_y_prod_re    : std_logic_vector(2*c_in_dat_w-1 downto 0);  
  signal ref_y_prod_im    : std_logic_vector(2*c_in_dat_w-1 downto 0);  
  
	signal weight_re   			: signed(g_twiddle_width-1 downto 0);
	signal weight_im   			: signed(g_twiddle_width-1 downto 0);
  
begin

  clk <= (not clk) or tb_end after c_clk_period/2;
  rst <= '1', '0' after c_clk_period*3;

  p_control_input_stream : process
  begin   
    tb_end <= '0';
    reg_bg_ctrl_mosi <= c_mem_mosi_rst;  
    
    -- Wait until reset is done
    proc_common_wait_until_high(clk, rst);
    proc_common_wait_some_cycles(clk, 10);
   
    -- Set and enable the waveform generators. All generators are controlled by the same registers
    proc_mem_mm_bus_wr(1, c_nof_samples_in_packet,   clk, reg_bg_ctrl_mosi);  -- Set the number of samples per block
    proc_mem_mm_bus_wr(2, c_nof_accum_per_sync,      clk, reg_bg_ctrl_mosi);  -- Set the number of blocks per sync
    proc_mem_mm_bus_wr(3, c_gap,                     clk, reg_bg_ctrl_mosi);  -- Set the gapsize
    proc_mem_mm_bus_wr(4, 0,                         clk, reg_bg_ctrl_mosi);  -- Set the start address of the memory
    proc_mem_mm_bus_wr(5, c_nof_samples_in_packet-1, clk, reg_bg_ctrl_mosi);  -- Set the end address of the memory
    proc_mem_mm_bus_wr(6, c_bsn_init,                clk, reg_bg_ctrl_mosi);  -- Set the BSNInit low  value
    proc_mem_mm_bus_wr(7, 0,                         clk, reg_bg_ctrl_mosi);  -- Set the BSNInit high value
    proc_mem_mm_bus_wr(0, 1,                         clk, reg_bg_ctrl_mosi);  -- Enable the BG
    
    -- Run time
    proc_common_wait_some_cycles(clk, c_nof_points);
    proc_mem_mm_bus_wr(0, 0, clk, reg_bg_ctrl_mosi);      -- Disable the BG
    
    -- The end
    proc_common_wait_some_cycles(clk, c_nof_points + 20);
    tb_end <= '1';
    wait;    
  end process;
  
  u_block_generator : entity casper_diagnostics_lib.mms_diag_block_gen 
  generic map(    
    g_nof_streams        => c_nof_streams,
    g_buf_dat_w          => c_nof_complex*c_in_dat_w, 
    g_buf_addr_w         => c_bg_addr_w,              -- Waveform buffer size 2**g_buf_addr_w nof samples
    g_file_name_prefix   => c_bg_prefix
  )
  port map(
   -- Clocks and reset
    mm_rst           => rst, 
    mm_clk           => clk, 
    dp_rst           => rst, 
    dp_clk           => clk,
    en_sync          => '1',
    ram_bg_data_mosi => ram_bg_data_mosi, 
    ram_bg_data_miso => open, 
    reg_bg_ctrl_mosi => reg_bg_ctrl_mosi, 
    reg_bg_ctrl_miso => open, 
    out_siso_arr     => in_siso_arr,
    out_sosi_arr     => in_sosi_arr
  );
  in_siso_arr(0) <= c_dp_siso_rdy;
  in_siso_arr(1) <= c_dp_siso_rdy;

  -- device under test
  u_dut : entity work.fft_r2_bf_par
  generic map (
    g_stage       => g_stage,
             
    g_element     => g_element,
    g_twiddle_width => g_twiddle_width   
  )
  port map (
    clk      => clk, 
    rst      => rst, 
    x_in_re  => in_sosi_arr(0).re(c_in_dat_w-1 downto 0),
    x_in_im  => in_sosi_arr(0).im(c_in_dat_w-1 downto 0),
    y_in_re  => in_sosi_arr(1).re(c_in_dat_w-1 downto 0),
    y_in_im  => in_sosi_arr(1).im(c_in_dat_w-1 downto 0),
    in_val   => in_sosi_arr(0).valid,
    scale    => '1',
    x_out_re => x_out_re,
    x_out_im => x_out_im,
    y_out_re => y_out_re,
    y_out_im => y_out_im,
    ovflw    => ovflw,
    out_val  => out_val
  );
 
  -- verification 
	weight_re <= gen_twiddle_factor(0,g_element,g_stage-1,1,g_twiddle_width,false,true);
	weight_im <= gen_twiddle_factor(0,g_element,g_stage-1,1,g_twiddle_width,false,false);
  
  p_verify : process  
    variable v_ref_y_out_re_dif : std_logic_vector(c_in_dat_w-1 downto 0);
    variable v_ref_y_out_im_dif : std_logic_vector(c_in_dat_w-1 downto 0);  
    variable v_ref_y_prod_re    : std_logic_vector(2*c_in_dat_w-1 downto 0);  
    variable v_ref_y_prod_im    : std_logic_vector(2*c_in_dat_w-1 downto 0);  
  begin                              
    wait until (rising_edge(clk) and in_sosi_arr(0).valid = '1');
    ref_x_out_re       <= ADD_SVEC(in_sosi_arr(0).re(c_in_dat_w-1 downto 0), in_sosi_arr(1).re(c_in_dat_w-1 downto 0), ref_x_out_re'length);
    ref_x_out_im       <= ADD_SVEC(in_sosi_arr(0).im(c_in_dat_w-1 downto 0), in_sosi_arr(1).im(c_in_dat_w-1 downto 0), ref_x_out_im'length);
    
    v_ref_y_out_re_dif := SUB_SVEC(in_sosi_arr(0).re(c_in_dat_w-1 downto 0), in_sosi_arr(1).re(c_in_dat_w-1 downto 0), ref_x_out_re'length);
    v_ref_y_out_im_dif := SUB_SVEC(in_sosi_arr(0).im(c_in_dat_w-1 downto 0), in_sosi_arr(1).im(c_in_dat_w-1 downto 0), ref_x_out_im'length);
    
    v_ref_y_prod_re    := func_complex_multiply(v_ref_y_out_re_dif, v_ref_y_out_im_dif, std_logic_vector(weight_re), std_logic_vector(weight_im), c_conjugate, "RE", ref_y_prod_re'length);
    v_ref_y_prod_im    := func_complex_multiply(v_ref_y_out_re_dif, v_ref_y_out_im_dif, std_logic_vector(weight_re), std_logic_vector(weight_im), c_conjugate, "IM", ref_y_prod_im'length);
   
    ref_y_out_re       <= truncate_and_resize_svec(v_ref_y_prod_re, c_round_w, ref_y_out_re'length);
    ref_y_out_im       <= truncate_and_resize_svec(v_ref_y_prod_im, c_round_w, ref_y_out_im'length);
                           
  end process; 
  
  u_verify_pipeline_x_re : entity common_components_lib.common_pipeline
  generic map (
    g_pipeline  => (c_pipeline.bf_lat + c_pipeline.mul_lat),
    g_in_dat_w  => ref_x_out_re'length,
    g_out_dat_w => ref_x_out_re'length
  )
  port map (
    clk     => clk,
    in_dat  => ref_x_out_re,
    out_dat => ref_x_out_re_dly
  );
  
  u_verify_pipeline_x_im : entity common_components_lib.common_pipeline
  generic map (
    g_pipeline  => (c_pipeline.bf_lat + c_pipeline.mul_lat),
    g_in_dat_w  => ref_x_out_im'length,
    g_out_dat_w => ref_x_out_im'length
  )
  port map (
    clk     => clk,
    in_dat  => ref_x_out_im,
    out_dat => ref_x_out_im_dly
  );

  u_verify_pipeline_y_re : entity common_components_lib.common_pipeline
  generic map (
    g_pipeline  => (c_pipeline.bf_lat + c_pipeline.mul_lat),
    g_in_dat_w  => ref_y_out_re'length,
    g_out_dat_w => ref_y_out_re'length
  )
  port map (
    clk     => clk,
    in_dat  => ref_y_out_re,
    out_dat => ref_y_out_re_dly
  );
  
  u_verify_pipeline_y_im : entity common_components_lib.common_pipeline
  generic map (
    g_pipeline  => (c_pipeline.bf_lat + c_pipeline.mul_lat),
    g_in_dat_w  => ref_y_out_im'length,
    g_out_dat_w => ref_y_out_im'length
  )
  port map (
    clk     => clk,
    in_dat  => ref_y_out_im,
    out_dat => ref_y_out_im_dly
  );
  
  ------------------------------------------------------------------------  
  -- Simples process that does the final test.                     
  ------------------------------------------------------------------------ 
  p_tester : process(rst, clk)  
    variable I : integer;
  begin
    if rst='0' then
      if rising_edge(clk) and out_val = '1' then 
        assert ref_x_out_re_dly = x_out_re report "Error: wrong RTL result in X real path" severity error;
        assert ref_x_out_im_dly = x_out_im report "Error: wrong RTL result in X imag path" severity error;
        assert ref_y_out_re_dly = y_out_re report "Error: wrong RTL result in Y real path" severity error;
        assert ref_y_out_im_dly = y_out_im report "Error: wrong RTL result in Y imag path" severity error;
      end if;
    end if;
  end process p_tester;  

end tb;
