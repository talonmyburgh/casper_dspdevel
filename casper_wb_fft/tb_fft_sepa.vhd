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

-- Purpose: Test bench for fft_sepa
-- Features:
--
-- Usage:
-- > as 10
-- > run -all    
-- > Testbench is selftesting. 
-- First frame contains always some errors. 

library IEEE, common_pkg_lib, dp_pkg_lib, casper_diagnostics_lib, casper_ram_lib, casper_mm_lib;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;
use common_pkg_lib.common_pkg.ALL;
use casper_ram_lib.common_ram_pkg.ALL;
use common_pkg_lib.tb_common_pkg.ALL;
use casper_mm_lib.tb_common_mem_pkg.ALL; 
use dp_pkg_lib.dp_stream_pkg.ALL;
use casper_diagnostics_lib.diag_pkg.ALL;   

entity tb_fft_sepa is
end tb_fft_sepa;

architecture tb of tb_fft_sepa is

  constant c_clk_period : time := 10 ns;

  constant c_nof_points   : natural := 8;
  constant c_nof_points_b : natural := 1024;
  constant c_in_dat_w     : natural := 16;   
  constant c_bg_addr_w    : natural := ceil_log2(c_nof_points_b);
  
  type t_input_buf_arr is array (integer range <>) of std_logic_vector(c_in_dat_w-1 downto 0); 

  -- BG derived constants
  constant c_nof_samples_in_packet     : natural := c_nof_points;
  constant c_gap                       : natural := 8;
  constant c_bst_skip_nof_sync         : natural := 3;
  constant c_nof_accum_per_sync        : natural := 10;
  constant c_bsn_init                  : natural := 32; 
  constant c_bg_prefix                 : string := "to_separate";
  
  signal tb_end    : std_logic := '0';
  signal rst       : std_logic;
  signal clk       : std_logic := '1'; 

  signal ram_bg_data_mosi : t_mem_mosi; 
  signal reg_bg_ctrl_mosi : t_mem_mosi;  
  signal in_sosi_arr      : t_dp_sosi_arr(0 downto 0);
  signal in_siso_arr      : t_dp_siso_arr(0 downto 0);  
  signal out_sosi         : t_dp_sosi;
  signal in_dat           : std_logic_vector(2*c_in_dat_w-1 downto 0); 
  signal out_dat          : std_logic_vector(2*c_in_dat_w-1 downto 0); 
  signal out_dat_re       : std_logic_vector(c_in_dat_w-1 downto 0); 
  signal out_dat_im       : std_logic_vector(c_in_dat_w-1 downto 0); 
  signal out_val          : std_logic; 
                          
  signal buf_input_re     : t_input_buf_arr(c_nof_points-1 downto 0);
  signal buf_input_im     : t_input_buf_arr(c_nof_points-1 downto 0);  
  signal buf_output_a_re  : t_input_buf_arr(c_nof_points/2-1 downto 0);
  signal buf_output_a_im  : t_input_buf_arr(c_nof_points/2-1 downto 0);  
  signal buf_output_b_re  : t_input_buf_arr(c_nof_points/2-1 downto 0);
  signal buf_output_b_im  : t_input_buf_arr(c_nof_points/2-1 downto 0);  
  signal buf_output_re    : t_input_buf_arr(c_nof_points-1 downto 0);
  signal buf_output_im    : t_input_buf_arr(c_nof_points-1 downto 0);  

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
    proc_common_wait_some_cycles(clk, 300);
    
    proc_mem_mm_bus_wr(0, 0, clk, reg_bg_ctrl_mosi);  -- Disable the BG
    
    -- The end
    proc_common_wait_some_cycles(clk, c_nof_points + 20);
    tb_end <= '1';
    wait;    
  end process;

  u_block_generator : entity casper_diagnostics_lib.mms_diag_block_gen 
  generic map(    
    g_nof_streams        => 1,
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

  -- device under test
  u_dut : entity work.fft_sepa
  port map (
    clken    => std_logic'('1'),
    clk      => clk,
    rst      => rst,
    in_dat   => in_dat, 
    in_val   => in_sosi_arr(0).valid,
    out_dat  => out_dat,
    out_val  => out_val
  );                          
  
  in_dat <= in_sosi_arr(0).im(c_in_dat_w-1 downto 0) & in_sosi_arr(0).re(c_in_dat_w-1 downto 0);
  out_dat_re <= out_dat(c_in_dat_w-1 downto 0);           
  out_dat_im <= out_dat(2*c_in_dat_w-1 downto c_in_dat_w);
  out_sosi.re(c_in_dat_w-1 downto 0) <= out_dat(c_in_dat_w-1 downto 0);
  out_sosi.im(c_in_dat_w-1 downto 0) <= out_dat(2*c_in_dat_w-1 downto c_in_dat_w);
  
  -- verification
  p_verify : process  
    variable I : integer;  
    variable v_buf_output_a_re : t_input_buf_arr(c_nof_points/2-1 downto 0);
    variable v_buf_output_a_im : t_input_buf_arr(c_nof_points/2-1 downto 0);  
    variable v_buf_output_b_re : t_input_buf_arr(c_nof_points/2-1 downto 0);
    variable v_buf_output_b_im : t_input_buf_arr(c_nof_points/2-1 downto 0);  

  begin                              
    I := 0;
    wait until in_sosi_arr(0).sync = '1';
    while I < c_nof_points loop
      wait until (rising_edge(clk) and in_sosi_arr(0).valid = '1');
      buf_input_re(I) <= in_sosi_arr(0).re(c_in_dat_w-1 downto 0);
      buf_input_im(I) <= in_sosi_arr(0).im(c_in_dat_w-1 downto 0);       
      I := I + 1;
    end loop;  
    proc_common_wait_some_cycles(clk, 1);
    for J in 0 to c_nof_points/2-1 loop
      v_buf_output_a_re(J) := ADD_SVEC(buf_input_re(2*J+1), buf_input_re(2*J), c_in_dat_w+1)(c_in_dat_w downto 1);
      v_buf_output_a_im(J) := SUB_SVEC(buf_input_im(2*J), buf_input_im(2*J+1), c_in_dat_w+1)(c_in_dat_w downto 1); 
      v_buf_output_b_re(J) := ADD_SVEC(buf_input_im(2*J+1), buf_input_im(2*J), c_in_dat_w+1)(c_in_dat_w downto 1);
      v_buf_output_b_im(J) := SUB_SVEC(buf_input_re(2*J+1), buf_input_re(2*J), c_in_dat_w+1)(c_in_dat_w downto 1);
      buf_output_re(2*J)   <= v_buf_output_a_re(J);
      buf_output_im(2*J)   <= v_buf_output_a_im(J);
      buf_output_re(2*J+1) <= v_buf_output_b_re(J);
      buf_output_im(2*J+1) <= v_buf_output_b_im(J);
    end loop;
    wait;
  end process; 
  
  ------------------------------------------------------------------------  
  -- Simples process that does the final test.                     
  ------------------------------------------------------------------------ 
  p_tester : process(rst, clk)  
    variable I : integer;
  begin
    if rst='0' then
      if rising_edge(clk) and out_val = '1' then 
        assert buf_output_re(I) = out_dat_re report "Error: wrong RTL result in real path" severity ERROR;
        assert buf_output_im(I) = out_dat_im report "Error: wrong RTL result in imag path" severity ERROR;
        if(I = c_nof_points - 1 ) then 
          I := 0;
        else
          I := I + 1;
        end if; 
      end if;
    else 
      I := 0;
    end if;
  end process p_tester;  

end tb;



