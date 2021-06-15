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
--------------------------------------------------------------------------------
--
-- Purpose: Test bench for fft_r2_wide.vhd using file data
--
-- Usage:
--   This tb uses the same Matlab stimuli and expected results as
--   tb_fft_r2_pipe.vhd.
--
--   For the fft_r2_wide wb_factor > 1 and < nof_points, because it implements
--   a combination of fft_r2_pipe and fft_r2_par.
--   The fft_r2_wide does support use_reorder.
--   The fft_r2_wide does support use_separate.
--   The fft_r2_wide does support input flow control with invalid gaps in the
--   input.
--   The fft_r2_wide only supports nof_chan=0, because the concept of channels
--   is void when wb_factor > 0.
--
--   For more description see tb_fft_r2_pipe.vhd.
--
--   > run -all
--   > testbench is selftesting.
--   > observe the *_scope signals as radix decimal, format analogue format
--     signals in the Wave window
--
library ieee, common_pkg_lib, r2sdf_fft_lib, casper_ram_lib, casper_mm_lib, casper_sim_tools_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.ALL;
use common_pkg_lib.common_lfsr_sequences_pkg.ALL;
use common_pkg_lib.tb_common_pkg.all;
use casper_mm_lib.tb_common_mem_pkg.ALL;
use r2sdf_fft_lib.rTwoSDFPkg.all;
use work.fft_gnrcs_intrfcs_pkg.all;
-- use work.fft_pkg.all;
use work.tb_fft_pkg.all;

entity tb_fft_r2_wide is
  generic(
    -- DUT generics
    --g_fft : t_fft := ( true, false,  true, 0, 4, 0, 128, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- two real inputs A and B
    g_fft : t_fft := ( true, false,  true, 0, 4, 0,  32, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- two real inputs A and B
    --g_fft : t_fft := ( true, false, false, 0, 4, 0,  32, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- complex input reordered
    --g_fft : t_fft := (false, false, false, 0, 4, 0,  32, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- complex input flipped
    --  type t_rtwo_fft is record
    --    use_reorder    : boolean;  -- = false for bit-reversed output, true for normal output
    --    use_fft_shift  : boolean;  -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
    --    use_separate   : boolean;  -- = false for complex input, true for two real inputs
    --    nof_chan       : natural;  -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan         
    --    wb_factor      : natural;  -- = default 1, wideband factor
    --    twiddle_offset : natural;  -- = default 0, twiddle offset for PFT sections in a wideband FFT
    --    nof_points     : natural;  -- = 1024, N point FFT
    --    in_dat_w       : natural;  -- = 8, number of input bits
    --    out_dat_w      : natural;  -- = 13, number of output bits, bit growth: in_dat_w + natural((ceil_log2(nof_points))/2 + 2)  
    --    out_gain_w     : natural;  -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
    --    stage_dat_w    : natural;  -- = 18, data width used between the stages(= DSP multiplier-width)
    --    guard_w        : natural;  -- = 2,  Guard used to avoid overflow in FFT stage. 
    --    guard_enable   : boolean;  -- = true when input needs guarding, false when input requires no guarding but scaling must be skipped at the last stage(s) (used in wb fft)
    --    stat_data_w    : positive; -- = 56 (= 18b+18b)+log2(781250)
    --    stat_data_sz   : positive; -- = 2 (complex re and im)
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
    -- * 64 points = 64 channels
    --g_data_file_c           : string := "data/run_pfft_complex_m_phasor_chirp_8b_64points_16b.dat";
    --g_data_file_c_nof_lines : natural := 12800;
    --g_data_file_c           : string := "data/run_pfft_complex_m_phasor_8b_64points_16b.dat";
    --g_data_file_c_nof_lines : natural := 320;
    --g_data_file_c           : string := "data/run_pfft_complex_m_noise_8b_64points_16b.dat";
    --g_data_file_c_nof_lines : natural := 640;

    -- * 32 points = 32 channels
    g_data_file_c           : string := "data/run_pfft_complex_m_phasor_chirp_8b_32points_16b.dat";
    g_data_file_c_nof_lines : natural := 6400;
    --g_data_file_c           : string := "data/run_pfft_complex_m_phasor_8b_32points_16b.dat";
    --g_data_file_c_nof_lines : natural := 160;
    --g_data_file_c           : string := "data/run_pfft_complex_m_noise_8b_32points_16b.dat";
    --g_data_file_c_nof_lines : natural := 320;
    
    g_data_file_nof_lines   : natural := 6400;    -- actual number of lines with input data to simulate from the data files, must be <= g_data_file_*_nof_lines
    g_enable_in_val_gaps    : boolean := TRUE   -- when false then in_val flow control active continuously, else with random inactive gaps
  );
end entity tb_fft_r2_wide;

architecture tb of tb_fft_r2_wide is

  constant c_clk_period            : time := 10 ns;
  constant c_sclk_period           : time := c_clk_period / g_fft.wb_factor;
  
  constant c_in_complex            : boolean := not g_fft.use_separate;
  constant c_fft_r2_check          : boolean := fft_r2_parameter_asserts(g_fft);
  
  constant c_nof_channels          : natural := 1;  -- fixed g_fft.nof_chan=0, because the concept of channels is void when wb_factor > 1
  constant c_nof_data_per_block    : natural := g_fft.nof_points * c_nof_channels;
  constant c_nof_valid_per_block   : natural := c_nof_data_per_block / g_fft.wb_factor;

  constant c_rnd_factor            : natural := sel_a_b(g_enable_in_val_gaps, 3, 1);
  constant c_dut_block_latency     : natural := 4;
  constant c_dut_clk_latency       : natural := c_nof_valid_per_block * c_dut_block_latency * c_rnd_factor + 50;  -- worst case

  -- input/output data width
  constant c_in_dat_w              : natural := g_fft.in_dat_w;   
  constant c_out_dat_w             : natural := g_fft.out_dat_w;

  -- Data file access (Header + WG data + PFFT data)
  constant c_nof_lines_header        : natural := 2;
  constant c_nof_lines_a_wg_dat      : natural := g_data_file_a_nof_lines;                    -- Real input A via in_re, one value per line
  constant c_nof_lines_a_wg_header   : natural := c_nof_lines_header;
  constant c_nof_lines_a_pfft_dat    : natural := g_data_file_a_nof_lines/c_nof_complex;      -- Half spectrum, two values per line (re, im)
  constant c_nof_lines_a_pfft_header : natural := c_nof_lines_header + c_nof_lines_a_wg_dat;
  constant c_nof_lines_b_wg_dat      : natural := g_data_file_b_nof_lines;                    -- Real input B via in_im, one value per line
  constant c_nof_lines_b_wg_header   : natural := c_nof_lines_header;
  constant c_nof_lines_b_pfft_dat    : natural := g_data_file_b_nof_lines/c_nof_complex;      -- Half spectrum, two values per line (re, im)
  constant c_nof_lines_b_pfft_header : natural := c_nof_lines_header + c_nof_lines_b_wg_dat;
  constant c_nof_lines_c_wg_dat      : natural := g_data_file_c_nof_lines;                    -- Complex input, two values per line (re, im)
  constant c_nof_lines_c_wg_header   : natural := c_nof_lines_header;
  constant c_nof_lines_c_pfft_dat    : natural := g_data_file_c_nof_lines;                    -- Full spectrum, two values per line (re, im)
  constant c_nof_lines_c_pfft_header : natural := c_nof_lines_header + c_nof_lines_c_wg_dat;

  -- signal definitions
  signal tb_end                 : std_logic := '0';
  signal tb_end_almost          : std_logic := '0';
  signal clk                    : std_logic := '0';
  signal sclk                   : std_logic := '0';
  signal rst                    : std_logic := '0';
  signal random                 : std_logic_vector(15 DOWNTO 0) := (OTHERS=>'0');  -- use different lengths to have different random sequences

  signal input_data_a_arr       : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- one value per line (A via re input)
  signal input_data_b_arr       : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- one value per line (B via im input)
  signal input_data_c_arr       : t_integer_arr(0 to g_data_file_nof_lines*c_nof_complex-1) := (OTHERS=>0);  -- two values per line (re, im)

  signal output_data_a_re_arr   : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, re
  signal output_data_a_im_arr   : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, im
  signal output_data_b_re_arr   : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, re
  signal output_data_b_im_arr   : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, im
  signal output_data_c_re_arr   : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- full spectrum, re
  signal output_data_c_im_arr   : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- full spectrum, im  
  
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
  signal in_re_arr              : t_fft_slv_arr_in(g_fft.wb_factor-1 downto 0);
  signal in_im_arr              : t_fft_slv_arr_in(g_fft.wb_factor-1 downto 0);
  signal in_re_data             : std_logic_vector(g_fft.wb_factor*c_in_dat_w-1 DOWNTO 0);
  signal in_im_data             : std_logic_vector(g_fft.wb_factor*c_in_dat_w-1 DOWNTO 0);
  signal in_val                 : std_logic:= '0';
  signal in_val_cnt             : natural := 0;
  signal in_gap                 : std_logic := '0';

  -- Input in sclk domain  
  signal in_re_scope            : integer;
  signal in_im_scope            : integer;
  signal in_val_scope           : std_logic:= '0';

  -- Output
  signal out_re_arr             : t_fft_slv_arr_out(g_fft.wb_factor-1 downto 0);
  signal out_im_arr             : t_fft_slv_arr_out(g_fft.wb_factor-1 downto 0);
  signal out_re_data            : std_logic_vector(g_fft.wb_factor*c_out_dat_w-1 DOWNTO 0);
  signal out_im_data            : std_logic_vector(g_fft.wb_factor*c_out_dat_w-1 DOWNTO 0);
  signal out_val                : std_logic:= '0';  -- for parallel output
  signal out_val_cnt            : natural := 0;
  
  -- Output in sclk domain  
  signal out_re_scope           : integer := 0;
  signal out_im_scope           : integer := 0;
  signal out_val_a              : std_logic:= '0';  -- for real A
  signal out_val_b              : std_logic:= '0';  -- for real B
  signal out_val_c              : std_logic:= '0';  -- for complex(A,B)
  signal out_channel            : natural := 0;
  signal out_cnt                : natural := 0;
  signal out_bin_cnt            : natural := 0;
  signal out_bin                : natural;
  
  -- Output data for complex input data
  signal out_re_c_scope         : integer := 0;
  signal exp_re_c_scope         : integer := 0;
  signal out_im_c_scope         : integer := 0;
  signal exp_im_c_scope         : integer := 0;
  signal diff_re_c_scope        : integer := 0;
  signal diff_im_c_scope        : integer := 0;
  
  -- register control signals to account for sclk register in output scope signals
  signal reg_out_val_a          : std_logic;
  signal reg_out_val_b          : std_logic;
  signal reg_out_val_c          : std_logic;
  signal reg_out_channel        : natural := 0;
  signal reg_out_cnt            : natural := 0;
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

  sclk <= (not sclk) or tb_end after c_sclk_period/2;
  clk <= (not clk) or tb_end after c_clk_period/2;
  rst <= '1', '0' after c_clk_period*7;
  random <= func_common_random(random) WHEN rising_edge(clk);
  in_gap <= random(random'HIGH) WHEN g_enable_in_val_gaps=TRUE ELSE '0';

  ---------------------------------------------------------------
  -- DATA INPUT
  ---------------------------------------------------------------
  p_input_stimuli : process
  begin
    -- read input data from file
    if c_in_complex then
      proc_common_read_integer_file(g_data_file_c, c_nof_lines_c_wg_header, g_data_file_nof_lines, c_nof_complex, input_data_c_arr);
    else
      proc_common_read_integer_file(g_data_file_a, c_nof_lines_a_wg_header, g_data_file_nof_lines, 1, input_data_a_arr);
      proc_common_read_integer_file(g_data_file_b, c_nof_lines_b_wg_header, g_data_file_nof_lines, 1, input_data_b_arr);
    end if;
    wait for 1 ns;
    in_re_arr <= (others=>(others=>'0'));
    in_im_arr <= (others=>(others=>'0'));
    in_val <= '0';
    proc_common_wait_until_low(clk, rst);         -- Wait until reset has finished
    proc_common_wait_some_cycles(clk, 10);        -- Wait an additional amount of cycles

    -- apply stimuli
    for J in 0 to g_data_file_nof_lines/g_fft.wb_factor-1 loop  -- serial
      for I in 0 to g_fft.wb_factor-1 loop  -- parallel
        if c_in_complex then
          in_re_arr(I) <= to_fft_in_svec(input_data_c_arr(2*(J*g_fft.wb_factor+I)));
          in_im_arr(I) <= to_fft_in_svec(input_data_c_arr(2*(J*g_fft.wb_factor+I)+1));
        else
          in_re_arr(I) <= to_fft_in_svec(input_data_a_arr(J*g_fft.wb_factor+I));
          in_im_arr(I) <= to_fft_in_svec(input_data_b_arr(J*g_fft.wb_factor+I));
        end if;
      end loop;
      in_val <= '1';
      proc_common_wait_some_cycles(clk, 1);
      if in_gap='1' then
        in_val <= '0';
        proc_common_wait_some_cycles(clk, 1);
      end if;
    end loop;

    -- Wait until done
    in_val <= '0';
    proc_common_wait_some_cycles(clk, c_dut_clk_latency);  -- wait for DUT latency
    tb_end_almost <= '1';
    proc_common_wait_some_cycles(clk, 100);
    tb_end <= '1';
    wait;
  end process;

  ---------------------------------------------------------------
  -- DUT = Device Under Test
  ---------------------------------------------------------------
  u_dut : entity work.fft_r2_wide
  generic map(
    g_fft          => g_fft
  )
  port map(
    clk        => clk,
    clken        => '1',
    rst        => rst,
    shiftreg   => (0=>'0', 1=>'0', others=>'1'),
    in_re_arr  => in_re_arr,
    in_im_arr  => in_im_arr,
    in_val     => in_val,
    out_re_arr => out_re_arr,
    out_im_arr => out_im_arr,
    ovflw => open,
    out_val    => out_val
  );
  
  -- Data valid count
  in_val_cnt  <= in_val_cnt+1  when rising_edge(clk) and in_val='1'  else in_val_cnt;
  out_val_cnt <= out_val_cnt+1 when rising_edge(clk) and out_val='1' else out_val_cnt;

  -- Block count t_blk time axis
  t_blk <= in_val_cnt / (g_fft.nof_points /g_fft.wb_factor);                       

  -- Verify nof valid counts
  p_verify_out_val_cnt : process
  begin
    -- Wait until tb_end_almost
    proc_common_wait_until_high(clk, tb_end_almost);
    assert in_val_cnt > 0 report "Test did not run, no valid input data"  severity error;
    if g_fft.wb_factor=g_fft.nof_points then
      -- Parallel FFT 
      assert out_val_cnt = in_val_cnt report "Unexpected number of valid output data" severity error;
    else
      -- Wideband FFT 
      -- The PFFT has a memory of 1 block, independent of use_reorder and use_separate, but without the
      -- reorder buffer it outputs 1 sample more, because that is immediately available in a new block.
      -- Ensure g_data_file_nof_lines is multiple of g_fft.nof_points.
      if g_fft.use_reorder=true then
        assert out_val_cnt = in_val_cnt-c_nof_valid_per_block                report "Unexpected number of valid output data" severity error;
      else
        assert out_val_cnt = in_val_cnt-c_nof_valid_per_block+c_nof_channels report "Unexpected number of valid output data" severity error;
      end if;
    end if;
    wait;
  end process;
  
  ---------------------------------------------------------------
  -- DATA OUTPUT CONTROL IN SCLK DOMAIN
  ---------------------------------------------------------------
  out_cnt <= out_cnt + 1 when rising_edge(sclk) and out_val_c='1' else out_cnt;
    
  proc_fft_out_control(g_fft.wb_factor, g_fft.nof_points, c_nof_channels, g_fft.use_reorder, g_fft.use_fft_shift, g_fft.use_separate,
                       out_cnt, out_val_c, out_val_a, out_val_b, out_channel, out_bin, out_bin_cnt);
  
  -- clk diff to avoid combinatorial glitches when selecting the data with out_val_a,b,c
  reg_out_val_a   <= out_val_a   when rising_edge(sclk);
  reg_out_val_b   <= out_val_b   when rising_edge(sclk);
  reg_out_val_c   <= out_val_c   when rising_edge(sclk);
  reg_out_channel <= out_channel when rising_edge(sclk);
  reg_out_cnt     <= out_cnt     when rising_edge(sclk);
  reg_out_bin_cnt <= out_bin_cnt when rising_edge(sclk);
  reg_out_bin     <= out_bin     when rising_edge(sclk);
  
  out_re_a_scope <= out_re_scope when rising_edge(sclk) and out_val_a='1';
  out_im_a_scope <= out_im_scope when rising_edge(sclk) and out_val_a='1';
  out_re_b_scope <= out_re_scope when rising_edge(sclk) and out_val_b='1';
  out_im_b_scope <= out_im_scope when rising_edge(sclk) and out_val_b='1';
  out_re_c_scope <= out_re_scope when rising_edge(sclk) and out_val_c='1';
  out_im_c_scope <= out_im_scope when rising_edge(sclk) and out_val_c='1';

  exp_re_a_scope <= expected_data_a_re_arr(out_bin_cnt) when rising_edge(sclk) and out_val_a='1';
  exp_im_a_scope <= expected_data_a_im_arr(out_bin_cnt) when rising_edge(sclk) and out_val_a='1';
  exp_re_b_scope <= expected_data_b_re_arr(out_bin_cnt) when rising_edge(sclk) and out_val_b='1';
  exp_im_b_scope <= expected_data_b_im_arr(out_bin_cnt) when rising_edge(sclk) and out_val_b='1';  
  exp_re_c_scope <= expected_data_c_re_arr(out_bin_cnt) when rising_edge(sclk) and out_val_c='1';
  exp_im_c_scope <= expected_data_c_im_arr(out_bin_cnt) when rising_edge(sclk) and out_val_c='1';

  diff_re_a_scope <= exp_re_a_scope - out_re_a_scope;
  diff_im_a_scope <= exp_im_a_scope - out_im_a_scope;
  diff_re_b_scope <= exp_re_b_scope - out_re_b_scope;
  diff_im_b_scope <= exp_im_b_scope - out_im_b_scope;
  diff_re_c_scope <= exp_re_c_scope - out_re_c_scope;
  diff_im_c_scope <= exp_im_c_scope - out_im_c_scope;

  ---------------------------------------------------------------
  -- VERIFY OUTPUT DATA
  ---------------------------------------------------------------
  -- p_verify_output
  gen_verify_two_real : if not c_in_complex generate
    assert diff_re_a_scope >= -g_diff_margin and diff_re_a_scope <= g_diff_margin report "Output data A real error" severity error;
    assert diff_im_a_scope >= -g_diff_margin and diff_im_a_scope <= g_diff_margin report "Output data A imag error" severity error;
    assert diff_re_b_scope >= -g_diff_margin and diff_re_b_scope <= g_diff_margin report "Output data B real error" severity error;
    assert diff_im_b_scope >= -g_diff_margin and diff_im_b_scope <= g_diff_margin report "Output data B imag error" severity error;
  end generate;
  gen_verify_complex : if c_in_complex generate
    assert diff_re_c_scope >= -g_diff_margin and diff_re_c_scope <= g_diff_margin report "Output data C real error" severity error;
    assert diff_im_c_scope >= -g_diff_margin and diff_im_c_scope <= g_diff_margin report "Output data C imag error" severity error;
  end generate;

  ---------------------------------------------------------------
  -- READ EXPECTED OUTPUT DATA FROM FILE
  ---------------------------------------------------------------
  p_expected_output : process
  begin
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
  
  ---------------------------------------------------------------
  -- INPUT AND OUTPUT DATA SCOPES
  ---------------------------------------------------------------
  p_data : process(in_re_arr, in_im_arr, out_re_arr, out_im_arr)
  begin
    for P in 0 to g_fft.wb_factor-1 loop
      in_re_data( (P+1)*c_in_dat_w-1 downto P*c_in_dat_w) <= in_re_arr( P)(c_in_dat_w-1 downto 0);
      in_im_data( (P+1)*c_in_dat_w-1 downto P*c_in_dat_w) <= in_im_arr( P)(c_in_dat_w-1 downto 0);
      
      out_re_data((P+1)*c_out_dat_w-1 downto P*c_out_dat_w) <= out_re_arr(P)(c_out_dat_w-1 downto 0);
      out_im_data((P+1)*c_out_dat_w-1 downto P*c_out_dat_w) <= out_im_arr(P)(c_out_dat_w-1 downto 0);
    end loop;
  end process;

  u_in_re_scope : entity casper_sim_tools_lib.common_wideband_data_scope
  generic map (
    g_sim                 => TRUE,
    g_wideband_factor     => g_fft.wb_factor,  -- Wideband rate factor = 4 for dp_clk processing frequency is 200 MHz frequency and SCLK sample frequency Fs is 800 MHz
    g_wideband_big_endian => FALSE,            -- When true in_data[3:0] = sample[t0,t1,t2,t3], else when false : in_data[3:0] = sample[t3,t2,t1,t0]
    g_dat_w               => c_in_dat_w        -- Actual width of the data samples
  )
  port map (
    -- Sample clock
    SCLK      => sclk,  -- sample clk, use only for simulation purposes

    -- Streaming input data
    in_data   => in_re_data,
    in_val    => in_val,

    -- Scope output samples
    out_dat   => OPEN,
    out_int   => in_re_scope,
    out_val   => in_val_scope
  );

  u_in_im_scope : entity casper_sim_tools_lib.common_wideband_data_scope
  generic map (
    g_sim                 => TRUE,
    g_wideband_factor     => g_fft.wb_factor,  -- Wideband rate factor = 4 for dp_clk processing frequency is 200 MHz frequency and SCLK sample frequency Fs is 800 MHz
    g_wideband_big_endian => FALSE,            -- When true in_data[3:0] = sample[t0,t1,t2,t3], else when false : in_data[3:0] = sample[t3,t2,t1,t0]
    g_dat_w               => c_in_dat_w        -- Actual width of the data samples
  )
  port map (
    -- Sample clock
    SCLK      => sclk,  -- sample clk, use only for simulation purposes

    -- Streaming input data
    in_data   => in_im_data,
    in_val    => in_val,

    -- Scope output samples
    out_dat   => OPEN,
    out_int   => in_im_scope,
    out_val   => open
  );

  u_out_re_scope : entity casper_sim_tools_lib.common_wideband_data_scope
  generic map (
    g_sim                 => TRUE,
    g_wideband_factor     => g_fft.wb_factor,  -- Wideband rate factor = 4 for dp_clk processing frequency is 200 MHz frequency and SCLK sample frequency Fs is 800 MHz
    g_wideband_big_endian => FALSE,            -- When true in_data[3:0] = sample[t0,t1,t2,t3], else when false : in_data[3:0] = sample[t3,t2,t1,t0]
    g_dat_w               => c_out_dat_w       -- Actual width of the data samples
  )
  port map (
    -- Sample clock
    SCLK      => sclk,  -- sample clk, use only for simulation purposes

    -- Streaming input data
    in_data   => out_re_data,
    in_val    => out_val,

    -- Scope output samples
    out_dat   => OPEN,
    out_int   => out_re_scope,
    out_val   => out_val_c
  );

  u_out_im_scope : entity casper_sim_tools_lib.common_wideband_data_scope
  generic map (
    g_sim                 => TRUE,
    g_wideband_factor     => g_fft.wb_factor,  -- Wideband rate factor = 4 for dp_clk processing frequency is 200 MHz frequency and SCLK sample frequency Fs is 800 MHz
    g_wideband_big_endian => FALSE,            -- When true in_data[3:0] = sample[t0,t1,t2,t3], else when false : in_data[3:0] = sample[t3,t2,t1,t0]
    g_dat_w               => c_out_dat_w       -- Actual width of the data samples
  )
  port map (
    -- Sample clock
    SCLK      => sclk,  -- sample clk, use only for simulation purposes

    -- Streaming input data
    in_data   => out_im_data,
    in_val    => out_val,

    -- Scope output samples
    out_dat   => OPEN,
    out_int   => out_im_scope,
    out_val   => open
  );
  
end tb;
