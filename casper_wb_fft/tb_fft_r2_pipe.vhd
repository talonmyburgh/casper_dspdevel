--------------------------------------------------------------------------------
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
---------------------------------------------------------------------------------
-- Adapted for use in the CASPER ecosystem by Talon Myburgh under Mydon Solutions
-- myburgh.talon@gmail.com
-- https://github.com/talonmyburgh | https://github.com/MydonSolutions
---------------------------------------------------------------------------------
-- Purpose: Test bench for fft_r2_pipe.vhd using file data
--
-- Usage:
--   The g_data_file with input and expected output data is created by the
--   Matlab script:
--
--     $RADIOHDL/applications/apertif/matlab/run_pfft.m
--
--   yields:
--
--   . g_data_file_*: run_pfft_m_<signal type>_8b_128points_16b.dat
--
--   First verified use_separate=true with a sinusoid for debugging, because
--   this yields an impulse in the spectrum. Then used impulse to verify the
--   dual of the sinusoid, because it yields sinusoids in the spectrum. Then
--   use chirp of sinusoid and chirp of impulse to increase the test coverage
--   of the FFT, while still having reconizable input and output results.
--   Finally use noise to even further increase the test coverage. In fact
--   for regression tests the noise stimuli are sufficient, but not suitable
--   for debugging.
--
--   The g_data_file_* contains input data and expected FFT output data
--   Two real input data files A and B used when g_fft.use_separate = true:
--     g_data_file_a           = real input data via A and expected output data for 1 stream, or zeros when UNUSED
--     g_data_file_b           = real input data via B and expected output data for 1 stream, or zeros when UNUSED
--     g_data_file_a_nof_lines = number of lines with input data that is available in the g_data_file_a
--     g_data_file_b_nof_lines = number of lines with input data that is available in the g_data_file_b

--   One complex input data file C used when g_fft.use_separate = false:
--     g_data_file_c           = complex input data and expected output data for 1 stream, or zeros when UNUSED
--     g_data_file_c_nof_lines = number of lines with input data that is available in the g_data_file_c
--   
--     g_data_file_nof_lines   = number of lines with input data to read and simulate,
--                               must be <= g_data_file_*_nof_lines and choose multiple of g_fft.nof_points
-- 
--   Then verify nof_chan>0.
--
--   Then verify g_enable_in_val_gaps=false to check the in_val flow control.
--
--   Then verify complex input using use_separate=false with a phasor. First
--   with use_reorder and then without.
--
--   For the fft_r2_pipe wb_factor=1 effectively, because the pipelined FFT
--   is serial for the entire g_fft.nof_points input time samples. More serial
--   then that is not possible.
--
--   Preserve the various tb options in the tb_tb multi-tb that will serve as
--   the regression test.
--   
--   The g_ppf parameters nof points, in_dat_w and out_dat_w must match the
--   settings in the data file.
--
--   The dat file that is created by Matlab first need to be copied manually
--   to these local directories.
--   The modelsim_copy_files key in the hdllib.cfg will copy these files to the
--   build directory from where they are loaded by Modelsim.
--
--   > run -all
--   > testbench is selftesting.
--   > observe the *_scope signals as radix decimal, format analogue format
--     signals in the Wave window
--
library ieee, common_pkg_lib, r2sdf_fft_lib, casper_ram_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.ALL;
use common_pkg_lib.common_lfsr_sequences_pkg.ALL;
use common_pkg_lib.tb_common_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;
use work.fft_gnrcs_intrfcs_pkg.all;
use work.tb_fft_pkg.all;

entity tb_fft_r2_pipe is
  GENERIC(
    -- DUT generics
    --g_fft : t_fft := ( true, false,  true, 0, 1, 0, 128, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- two real inputs A and B
    g_fft : t_fft := (  -- two real inputs A and B
        use_reorder=>  true, 
        use_fft_shift=>false,  
        use_separate=>true, 
        nof_chan=>0, 
        wb_factor=>1, 
        nof_points=>0,  
        in_dat_w=>8, 
        out_dat_w=>16, 
        out_gain_w=>0, 
        stage_dat_w=>c_dsp_mult_w, 
        twiddle_dat_w=>18, 
        max_addr_w=>9, 
        guard_w=>2, 
        guard_enable=>true, 
        stat_data_w=>56, 
        stat_data_sz=>2, 
        pipe_reo_in_place=>false
      );
                
    --g_fft : t_fft := ( true, false, false, false, 0, 1, 0,  64, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- complex input reordered
    --g_fft : t_fft := (false, false, false, false, 0, 1, 0,  64, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- complex input flipped
    --  type t_rtwo_fft is record
    --    use_reorder       : boolean;  -- = false for bit-reversed output, true for normal output
    --    use_fft_shift     : boolean;  -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
    --    use_separate      : boolean;  -- = false for complex input, true for two real inputs
    --    pipe_reo_in_place : boolean;  -- = false for double buffer reorder, true for single
    --    nof_chan          : natural;  -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan         
    --    wb_factor         : natural;  -- = default 1, wideband factor
    --    twiddle_offset    : natural;  -- = default 0, twiddle offset for PFT sections in a wideband FFT
    --    nof_points        : natural;  -- = 1024, N point FFT
    --    in_dat_w          : natural;  -- = 8, number of input bits
    --    out_dat_w         : natural;  -- = 13, number of output bits, bit growth: in_dat_w + natural((ceil_log2(nof_points))/2 + 2)  
    --    out_gain_w        : natural;  -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
    --    stage_dat_w       : natural;  -- = 18, data width used between the stages(= DSP multiplier-width)
    --    guard_w           : natural;  -- = 2,  Guard used to avoid overflow in FFT stage. 
    --    guard_enable      : boolean;  -- = true when input needs guarding, false when input requires no guarding but scaling must be skipped at the last stage(s) (used in wb fft)
    --    stat_data_w       : positive; -- = 56 (= 18b+18b)+log2(781250)
    --    stat_data_sz      : positive; -- = 2 (complex re and im)
    --  end record;
    --
    -- TB generics
    g_diff_margin           : integer := 2;  -- maximum difference between HDL output and expected output (> 0 to allow minor rounding differences)
    
    -- Two real input data files A and B used when g_fft.use_separate = true
    -- * 128 points = 64 subbands
    --g_data_file_a           : string := "data/run_pfft_m_sinusoid_chirp_8b_128points_16b.dat";
    --g_data_file_a_nof_lines : natural := 25600;
    --g_data_file_b           : string := "UNUSED";
    --g_data_file_b_nof_lines : natural := 0;
    
    -- * 32 points = 16 subbands
    g_data_file_a           : string := "data/run_pfft_m_sinusoid_chirp_8b_32points_16b.dat";
    g_data_file_a_nof_lines : natural := 6400;
    --g_data_file_a           : string := "data/run_pfft_m_sinusoid_8b_32points_16b.dat";
    --g_data_file_a_nof_lines : natural := 160;
    
    --g_data_file_b           : string := "data/run_pfft_m_impulse_chirp_8b_32points_16b.dat";
    --g_data_file_b_nof_lines : natural := 6400;
    g_data_file_b           : string := "UNUSED";
    g_data_file_b_nof_lines : natural := 0;

    -- One complex input data file C used when g_fft.use_separate = false
    --g_data_file_c           : string := "data/run_pfft_complex_m_phasor_chirp_8b_64points_16b.dat";
    --g_data_file_c_nof_lines : natural := 12800;
    g_data_file_c           : string := "data/run_pfft_complex_m_phasor_8b_64points_16b.dat";
    g_data_file_c_nof_lines : natural := 320;
    
    g_data_file_nof_lines   : natural := 6400;
    g_enable_in_val_gaps    : boolean := FALSE;   -- when false then in_val flow control active continuously, else with random inactive gaps
    g_twid_file_stem        : string := "UNUSED";

    g_use_variant : STRING := "4DSP";
    g_ovflw_behav : STRING := "WRAP";
    g_use_round   : STRING := "TRUNCATE"
  );
  PORT
  (
    o_rst       : out std_logic;
    o_clk       : out std_logic;
    o_tb_end    : out std_logic;
    o_test_msg  : out string(1 to 80);
    o_test_pass : out boolean
  );
end entity tb_fft_r2_pipe;

architecture tb of tb_fft_r2_pipe is

  constant c_clk_period            : time := 10 ns;

  constant c_in_complex            : boolean := not g_fft.use_separate;
  constant c_fft_r2_check          : boolean := fft_r2_parameter_asserts(g_fft);

  constant c_nof_channels          : natural := 2**g_fft.nof_chan;
  constant c_nof_data_per_block    : natural := g_fft.nof_points * c_nof_channels;
  constant c_nof_valid_per_block   : natural := c_nof_data_per_block;  -- wb_factor=1

  constant c_rnd_factor            : natural := sel_a_b(g_enable_in_val_gaps, 3, 1);
  constant c_dut_block_latency     : natural := 3;
  constant c_dut_clk_latency       : natural := c_nof_valid_per_block * c_dut_block_latency * c_rnd_factor;  -- worst case
  
  -- input/output data width
  constant c_in_dat_w              : natural := g_fft.in_dat_w;   
  constant c_out_dat_w             : natural := g_fft.out_dat_w;

  -- Data file access
  constant c_nof_lines_header        : natural := 2;
  constant c_nof_lines_a_wg_dat      : natural := g_data_file_a_nof_lines;                    -- Real input A via in_re, one value per line
  constant c_nof_lines_a_pfft_dat    : natural := g_data_file_a_nof_lines/c_nof_complex;      -- Half spectrum, two values per line (re, im)
  constant c_nof_lines_a_pfft_header : natural := c_nof_lines_header + c_nof_lines_a_wg_dat;
  constant c_nof_lines_b_wg_dat      : natural := g_data_file_b_nof_lines;                    -- Real input B via in_im, one value per line
  constant c_nof_lines_b_pfft_dat    : natural := g_data_file_b_nof_lines/c_nof_complex;      -- Half spectrum, two values per line (re, im)
  constant c_nof_lines_b_pfft_header : natural := c_nof_lines_header + c_nof_lines_b_wg_dat;
  constant c_nof_lines_c_wg_dat      : natural := g_data_file_c_nof_lines;                    -- Complex input, two values per line (re, im)
  constant c_nof_lines_c_pfft_dat    : natural := g_data_file_c_nof_lines;                    -- Full spectrum, two values per line (re, im)
  constant c_nof_lines_c_pfft_header : natural := c_nof_lines_header + c_nof_lines_c_wg_dat;

  -- signal definitions
  signal tb_end                 : std_logic := '0';
  signal tb_end_almost          : std_logic := '0';
  signal clk                    : std_logic := '0';
  signal rst                    : std_logic := '0';
  signal random                 : std_logic_vector(15 DOWNTO 0) := (OTHERS=>'0');  -- use different lengths to have different random sequences

  signal input_data_a_arr       : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- one value per line (A via re input)
  signal input_data_b_arr       : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- one value per line (B via im input)
  signal input_data_c_arr       : t_integer_arr(0 to g_data_file_nof_lines*c_nof_complex-1) := (OTHERS=>0);  -- two values per line (re, im)
  
  signal shiftreg               : std_logic_vector(ceil_log2(g_fft.nof_points)-1 Downto 0); 
  -- signal shiftreg               : std_logic_vector(ceil_log2(g_fft.nof_points)-1 Downto 0) := "1111100";
  --signal shiftreg               : std_logic_vector(ceil_log2(g_fft.nof_points)-1 Downto 0) := "111100";

  signal ovflw                  : std_logic_vector(ceil_log2(g_fft.nof_points)-1 Downto 0) := (others=>'0');

  signal expected_data_a_arr    : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- half spectrum, two values per line (re, im)
  signal expected_data_a_re_arr : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, re
  signal expected_data_a_im_arr : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, im
  signal expected_data_b_arr    : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- half spectrum, two values per line (re, im)
  signal expected_data_b_re_arr : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, re
  signal expected_data_b_im_arr : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, im
  signal expected_data_c_arr    : t_integer_arr(0 to g_data_file_nof_lines*c_nof_complex-1) := (OTHERS=>0);  -- full spectrum, two values per line (re, im)
  signal expected_data_c_re_arr : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- full spectrum, re
  signal expected_data_c_im_arr : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- full spectrum, im  

  signal t_blk                  : integer := 0;  -- block time counter

  -- Input
  signal in_dat_a               : std_logic_vector(c_in_dat_w-1 downto 0);
  signal in_dat_a_scope         : integer;
  signal in_dat_b               : std_logic_vector(c_in_dat_w-1 downto 0);
  signal in_dat_b_scope         : integer;
  signal in_channel             : natural;
  signal in_val                 : std_logic:= '0';
  signal dut_val                : std_logic:= '0';
  signal dat_val                : std_logic:= '0';
  signal in_sync                : std_logic:= '0';
  signal in_val_cnt             : natural := 0;
  signal in_val_cnt_test        : natural := 0;
  signal in_blk_val             : std_logic;
  signal in_blk_val_cnt         : natural := 0;
  signal in_gap                 : std_logic := '0';

  -- Output control
  signal out_val_cnt            : natural := 0;
  signal out_val                : std_logic:= '0';  -- for complex(A,B)
  signal out_val_a              : std_logic:= '0';  -- for real A
  signal out_val_b              : std_logic:= '0';  -- for real B
  signal out_sync               : std_logic:= '0';
  signal out_bin_cnt            : natural := 0;
  signal out_bin                : natural;
  signal out_channel            : natural;
  signal out_blk_val            : std_logic;
  signal out_blk_val_cnt        : natural := 0;
  
  -- Output data
  signal out_re                 : std_logic_vector(c_out_dat_w-1 downto 0);
  signal out_im                 : std_logic_vector(c_out_dat_w-1 downto 0);
  
  -- Output data for complex input data
  signal out_re_c_scope         : integer := 0;
  signal exp_re_c_scope         : integer := 0;
  signal out_im_c_scope         : integer := 0;
  signal exp_im_c_scope         : integer := 0;
  
  signal diff_re_c_scope        : integer := 0;
  signal diff_im_c_scope        : integer := 0;
  
  -- register control signals to account for clk register in output scope signals
  signal reg_out_val_a          : std_logic;
  signal reg_out_val_b          : std_logic;
  signal reg_out_val            : std_logic;
  signal reg_out_channel        : natural := 0;
  signal reg_out_bin_cnt        : natural := 0;
  signal reg_out_bin            : natural;
  
  -- Output data two real input data A and B
  signal out_re_a_scope         : integer := 0;
  signal exp_re_a_scope         : integer := 0;
  signal out_im_a_scope         : integer := 0;
  signal exp_im_a_scope         : integer := 0;
  
  signal out_re_b_scope         : integer := 0;
  signal exp_re_b_scope         : integer := 0;
  signal out_im_b_scope         : integer := 0;
  signal exp_im_b_scope         : integer := 0;
  
  signal diff_re_a_scope        : integer := 0;
  signal diff_im_a_scope        : integer := 0;
  signal diff_re_b_scope        : integer := 0;
  signal diff_im_b_scope        : integer := 0;
  
begin

  shiftreg(1 downto 0) <= "00";
  shiftreg(ceil_log2(g_fft.nof_points)-1 Downto 2) <= (others=>'1');

  clk <= (not clk) or tb_end after c_clk_period/2;
  rst <= '1', '0' after c_clk_period*7;
  random <= func_common_random(random) WHEN rising_edge(clk);
  in_gap <= random(random'HIGH) WHEN g_enable_in_val_gaps=TRUE ELSE '0';

  o_clk <= clk;
  o_rst <= rst;
  in_sync <= rst;
  dut_val <= in_val when in_sync ='0' else '0';
  dat_val <= out_val when out_sync = '0' else '0';
  o_tb_end <= tb_end;

  ---------------------------------------------------------------
  -- DATA INPUT
  ---------------------------------------------------------------
  p_input_stimuli : process
    variable vP : natural;
  begin
    -- read input data from file
    if c_in_complex then
      proc_common_read_integer_file(g_data_file_c, c_nof_lines_header, g_data_file_nof_lines, c_nof_complex, input_data_c_arr);
    else
      proc_common_read_integer_file(g_data_file_a, c_nof_lines_header, g_data_file_nof_lines, 1, input_data_a_arr);
      proc_common_read_integer_file(g_data_file_b, c_nof_lines_header, g_data_file_nof_lines, 1, input_data_b_arr);
    end if;
    wait for 1 ns;
    in_dat_a <= (others=>'0');
    in_dat_b <= (others=>'0');
    in_val <= '1';
    wait for 2*c_clk_period;
    in_val <= '0';
    proc_common_wait_until_low(clk, rst);         -- Wait until reset has finished
    proc_common_wait_some_cycles(clk, 10);        -- Wait an additional amount of cycles

    -- apply stimuli
    for I in 0 to g_data_file_nof_lines-1 loop  -- serial
      for K in 0 to c_nof_channels-1 loop  -- serial
        if c_in_complex then
          in_dat_a <= TO_SVEC(input_data_c_arr(2*I), c_in_dat_w);
          in_dat_b <= TO_SVEC(input_data_c_arr(2*I+1), c_in_dat_w);
        else
          in_dat_a <= TO_SVEC(input_data_a_arr(I), c_in_dat_w);
          in_dat_b <= TO_SVEC(input_data_b_arr(I), c_in_dat_w);
        end if;
        in_channel <= K;
        in_val <= '1';
        proc_common_wait_some_cycles(clk, 1);
        if in_gap='1' then
          in_val <= '0';
          proc_common_wait_some_cycles(clk, 1);
        end if;
      end loop;
    end loop;

    -- Wait until done
    in_val <= '0';
    proc_common_wait_some_cycles(clk, c_dut_clk_latency);  -- wait for at least latency of 2 FFT block
    tb_end_almost <= '1';
    proc_common_wait_some_cycles(clk, 100);
    tb_end <= '1';
    wait;
  end process;

  ---------------------------------------------------------------
  -- DUT = Device Under Test
  ---------------------------------------------------------------
  u_dut : entity work.fft_r2_pipe
  generic map (
    g_fft      => g_fft,
    g_use_variant => g_use_variant,
    g_ovflw_behav => g_ovflw_behav,
    g_round => stringround_to_enum_round(g_use_round),
    g_twid_file_stem => g_twid_file_stem
  )
  port map (
    clken    => std_logic'('1'),
    clk      => clk,
    in_sync  => in_sync,
    in_re    => in_dat_a,
    in_im    => in_dat_b,
    shiftreg => (0=>'0', 1=>'0', others=>'1'),
    in_val   => in_val,
    out_re   => out_re,
    out_im   => out_im,
    out_sync => out_sync,
    ovflw    => ovflw,
    out_val  => out_val
  );

  -- Separate output
  in_val_cnt  <= in_val_cnt+1  when rising_edge(clk) and in_val='1' and in_sync ='0' else in_val_cnt;
  out_val_cnt <= out_val_cnt+1 when rising_edge(clk) and out_val = '1' and out_sync ='0' else out_val_cnt;

  proc_fft_out_control(1, g_fft.nof_points, c_nof_channels, g_fft.use_reorder, g_fft.use_fft_shift, g_fft.use_separate,
                       out_val_cnt, dat_val, out_val_a, out_val_b, out_channel, out_bin, out_bin_cnt);
                       
  -- Block count t_blk for c_nof_channels>=1 channels per block
  in_blk_val  <= '1' when dut_val='1'  and (in_val_cnt  mod c_nof_channels)=0 else '0';
  out_blk_val <= '1' when dat_val='1' and (out_val_cnt mod c_nof_channels)=0 else '0';
  in_blk_val_cnt  <= in_val_cnt/c_nof_channels;
  out_blk_val_cnt <= out_val_cnt/c_nof_channels;

  t_blk <= t_blk+1 when rising_edge(clk) and in_blk_val='1' and in_blk_val_cnt > 0 and (in_blk_val_cnt MOD c_nof_valid_per_block = 0);

  ---------------------------------------------------------------
  -- VERIFY OUTPUT
  ---------------------------------------------------------------
  p_verify_out_val_cnt : process
  begin
    -- Wait until tb_end_almost
    proc_common_wait_until_high(clk, tb_end_almost);
    assert in_val_cnt > 0 report "Test did not run, no valid input data"  severity error;
    -- The PFFT has a memory of 1 block, independent of use_reorder and use_separate, but without the
    -- reorder buffer it outputs 1 sample more, because that is immediately available in a new block.
    -- Ensure g_data_file_nof_lines is multiple of g_fft.nof_points.
    if g_fft.use_reorder=true then
        if g_fft.pipe_reo_in_place=true then
            if g_fft.use_separate=true then
                in_val_cnt_test<=in_val_cnt-(2*g_fft.nof_points-2);
            else
              in_val_cnt_test<=in_val_cnt-(2*g_fft.nof_points-1); 
            end if;
        else
            in_val_cnt_test<=in_val_cnt-c_nof_valid_per_block;
        end if;
    else
        in_val_cnt_test<=in_val_cnt-c_nof_valid_per_block+c_nof_channels;
    end if;
    assert out_val_cnt = in_val_cnt_test report "Unexpected number of valid output data" severity error;
    wait;
  end process;
            
  p_expected_output : process
  begin
    -- read expected output data from file
    if c_in_complex then
      proc_common_read_integer_file(g_data_file_c, c_nof_lines_c_pfft_header, g_data_file_nof_lines, c_nof_complex, expected_data_c_arr);
      wait for 1 ns;
      for I in 0 to g_data_file_nof_lines-1 loop
        expected_data_c_re_arr(I) <= expected_data_c_arr(2*I);
        expected_data_c_im_arr(I) <= expected_data_c_arr(2*I+1);
      end loop;
    else
      proc_common_read_integer_file(g_data_file_a, c_nof_lines_a_pfft_header, g_data_file_nof_lines/c_nof_complex, c_nof_complex, expected_data_a_arr);
      proc_common_read_integer_file(g_data_file_b, c_nof_lines_b_pfft_header, g_data_file_nof_lines/c_nof_complex, c_nof_complex, expected_data_b_arr);
      wait for 1 ns;
      for I in 0 to g_data_file_nof_lines/c_nof_complex-1 loop
        expected_data_a_re_arr(I) <= expected_data_a_arr(2*I);
        expected_data_a_im_arr(I) <= expected_data_a_arr(2*I+1);
        expected_data_b_re_arr(I) <= expected_data_b_arr(2*I);
        expected_data_b_im_arr(I) <= expected_data_b_arr(2*I+1);
      end loop;
    end if;
    wait;
  end process;
  
  -- p_verify_output
  verify_data : process(rst,clk)
    VARIABLE v_test_pass : BOOLEAN := TRUE;
    VARIABLE v_test_msg : STRING( 1 to 80 );  
  begin
   if rising_edge(clk) and (rst='0') then
    if not c_in_complex then
      v_test_pass := diff_re_a_scope >= -g_diff_margin and diff_re_a_scope <= g_diff_margin;
      if not v_test_pass then
        v_test_msg := pad("Output data A real error, expected: " & integer'image(exp_re_a_scope) & "but got: " & integer'image(out_re_a_scope),o_test_msg'length,'.');
        report v_test_msg severity error;
      end if;
      v_test_pass := diff_im_a_scope >= -g_diff_margin and diff_im_a_scope <= g_diff_margin;
      if not v_test_pass then
        v_test_msg := pad("Output data A imag error, expected: " & integer'image(exp_im_a_scope) & "but got: " & integer'image(out_im_a_scope),o_test_msg'length,'.');
        report v_test_msg severity error;
      end if;
      v_test_pass := diff_re_b_scope >= -g_diff_margin and diff_re_b_scope <= g_diff_margin;
      if not v_test_pass then
        v_test_msg := pad("Output data B real error, expected: " & integer'image(exp_re_b_scope) & "but got: " & integer'image(out_re_b_scope),o_test_msg'length,'.');
        report v_test_msg severity error;
      end if;
      v_test_pass := diff_im_b_scope >= -g_diff_margin and diff_im_b_scope <= g_diff_margin;
      if not v_test_pass then
        v_test_msg := pad("Output data B imag error, expected: " & integer'image(exp_im_b_scope) & "but got: " & integer'image(out_im_b_scope),o_test_msg'length,'.');
        report v_test_msg severity error;
      end if;
    else
      v_test_pass := diff_re_c_scope >= -g_diff_margin and diff_re_c_scope <= g_diff_margin;
      if not v_test_pass then
        v_test_msg := pad("Output data C real error, expected: " & integer'image(exp_re_c_scope) & "but got: " & integer'image(out_re_c_scope),o_test_msg'length,'.');
        report v_test_msg severity error;
      end if;
      v_test_pass := diff_im_c_scope >= -g_diff_margin and diff_im_c_scope <= g_diff_margin;
      if not v_test_pass then
        v_test_msg := pad("Output data C imag error, expected: " & integer'image(exp_im_c_scope) & "but got: " & integer'image(out_im_c_scope),o_test_msg'length,'.');
        report v_test_msg severity error;
      end if;
    end if;
    end if;
    o_test_pass <= v_test_pass;
    o_test_msg <= v_test_msg;
  end process;

  ---------------------------------------------------------------
  -- DATA SCOPES
  ---------------------------------------------------------------
  in_dat_a_scope <= TO_SINT(in_dat_a);
  in_dat_b_scope <= TO_SINT(in_dat_b);

  -- clk diff to avoid combinatorial glitches when selecting the data with out_val_a,b, dat_val
  reg_out_val_a   <= out_val_a   when rising_edge(clk);
  reg_out_val_b   <= out_val_b   when rising_edge(clk);
  reg_out_val     <= dat_val     when rising_edge(clk);
  reg_out_channel <= out_channel when rising_edge(clk);
  reg_out_bin_cnt <= out_bin_cnt when rising_edge(clk);
  reg_out_bin     <= out_bin     when rising_edge(clk);

  -- clk diff to avoid combinatorial glitches
  out_re_a_scope <= TO_SINT(out_re) when rising_edge(clk) and out_val_a='1';
  out_im_a_scope <= TO_SINT(out_im) when rising_edge(clk) and out_val_a='1';
  out_re_b_scope <= TO_SINT(out_re) when rising_edge(clk) and out_val_b='1';
  out_im_b_scope <= TO_SINT(out_im) when rising_edge(clk) and out_val_b='1';
  out_re_c_scope <= TO_SINT(out_re) when rising_edge(clk) and dat_val='1';
  out_im_c_scope <= TO_SINT(out_im) when rising_edge(clk) and dat_val='1';

  exp_re_a_scope <= expected_data_a_re_arr(out_bin_cnt) when rising_edge(clk) and out_val_a='1';
  exp_im_a_scope <= expected_data_a_im_arr(out_bin_cnt) when rising_edge(clk) and out_val_a='1';
  exp_re_b_scope <= expected_data_b_re_arr(out_bin_cnt) when rising_edge(clk) and out_val_b='1';
  exp_im_b_scope <= expected_data_b_im_arr(out_bin_cnt) when rising_edge(clk) and out_val_b='1';  
  exp_re_c_scope <= expected_data_c_re_arr(out_bin_cnt) when rising_edge(clk) and dat_val='1';
  exp_im_c_scope <= expected_data_c_im_arr(out_bin_cnt) when rising_edge(clk) and dat_val='1';

  diff_re_a_scope <= exp_re_a_scope - out_re_a_scope;
  diff_im_a_scope <= exp_im_a_scope - out_im_a_scope;
  diff_re_b_scope <= exp_re_b_scope - out_re_b_scope;
  diff_im_b_scope <= exp_im_b_scope - out_im_b_scope;
  diff_re_c_scope <= exp_re_c_scope - out_re_c_scope;
  diff_im_c_scope <= exp_im_c_scope - out_im_c_scope;

end tb;
