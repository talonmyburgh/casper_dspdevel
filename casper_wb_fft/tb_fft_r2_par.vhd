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
-- Purpose: Test bench for fft_r2_par.vhd using file data
--
-- Usage:
--   This tb uses the same Matlab stimuli and expected results as
--   tb_fft_r2_pipe.vhd.
--
--   For the fft_r2_par nof_chan=0, because with parallel input the time
--   multiplexed channels can be applied completely outside the FFT. I.e first
--   input block with g_fft.nof_points time samples in parallel for channel 0,
--   then idem for the next channel etc.
--   For the fft_r2_par wb_factor wb_factor=nof_points effectively, because
--   the parallel FFT is parallel for the entire g_fft.nof_points input time
--   samples. More parallel then that is not possible.
--   The fft_r2_par does support use_reorder.
--   The fft_r2_par does support use_separate.
--   The fft_r2_par does support input flow control with invalid gaps in the
--   input.
--
--   For more description see tb_fft_r2_pipe.vhd.
--
--   > run -all
--   > testbench is selftesting.
--   > observe the *_scope signals as radix decimal, format analogue format
--     signals in the Wave window
--
-- Remark:
-- . The verification replays the captured parallel data to be able to display
--   it using the scope signals in the Wave window and to be able to reuse the
--   serial proc_fft_out_control() procedure for determining the exepected
--   order of the output data.
-- . In retrospect the verification could have been done without the replay by
--   using wb_factor=nof_points.
-- . Use separate dut_clk and tb_clk (both directly related to clk), to be
--   able to disable the dut_clk during verification to significantly speed
--   up the simulation.
library ieee, common_pkg_lib, r2sdf_fft_lib, casper_ram_lib, casper_mm_lib;
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
use work.tb_fft_pkg.all;

entity tb_fft_r2_par is
  generic(
    -- DUT generics
    --g_fft : t_fft := ( true, false,  true, 0, 1, 128, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- two real inputs A and B
    g_fft : t_fft := ( true, false,  true, 0, 1, 32, 8, 16, 0, c_dsp_mult_w,18,9, 2, true, 56, 2);         -- two real inputs A and B
    --g_fft : t_fft := ( true, false, false, 0, 1,  64, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- complex input reordered
    --g_fft : t_fft := (false, false, false, 0, 1,  64, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- complex input flipped
    --  type t_rtwo_fft is record
    --    use_reorder    : boolean;  -- = false for bit-reversed output, true for normal output
    --    use_fft_shift  : boolean;  -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
    --    use_separate   : boolean;  -- = false for complex input, true for two real inputs
    --    nof_chan       : natural;  -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan         
    --    wb_factor      : natural;  -- = default 1, wideband factor
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
    --g_data_file_a           : string := "data/run_pfft_m_sinusoid_chirp_8b_128points_16b.dat";
    --g_data_file_a_nof_lines : natural := 25600;
    --g_data_file_b           : string := "data/run_pfft_m_impulse_chirp_8b_128points_16b.dat";
    --g_data_file_b_nof_lines : natural := 25600;

    g_data_file_a           : string := "run_pfft_m_sinusoid_8b_32points_16b.dat";
    g_data_file_a_nof_lines : natural := 160;
    g_data_file_b           : string := "UNUSED";
    g_data_file_b_nof_lines : natural := 0;
    
    -- One complex input data file C used when g_fft.use_separate = false
    --g_data_file_c           : string := "run_pfft_complex_m_phasor_chirp_8b_64points_16b.dat";
    --g_data_file_c_nof_lines : natural := 12800;
    g_data_file_c           : string := "run_pfft_complex_m_phasor_8b_64points_16b.dat";
    g_data_file_c_nof_lines : natural := 320;
    
    g_data_file_nof_lines   : natural := 160;
    g_enable_in_val_gaps    : boolean := FALSE;   -- when false then in_val flow control active continuously, else with random inactive gaps
    g_twid_file_stem        : string := "UNUSED";
    g_use_variant           : string := "4DSP";
    g_ovflw_behav           : string := "WRAP";
    g_use_round             : string := "TRUNCATE"
    );
  PORT
  (
    o_rst       : out std_logic;
    o_clk       : out std_logic;
    o_tb_end    : out std_logic;
    o_test_msg  : out string(1 to 80);
    o_test_pass : out boolean
  );
end entity tb_fft_r2_par;

architecture tb of tb_fft_r2_par is

  constant c_clk_period            : time := 10 ns;

  constant c_in_complex            : boolean := not g_fft.use_separate;
  constant c_fft_r2_check          : boolean := fft_r2_parameter_asserts(g_fft);

  constant c_nof_channels          : natural := 1;  -- fixed g_fft.nof_chan=0, because the concept of channels is void for the parallel FFT

  constant c_rnd_factor            : natural := sel_a_b(g_enable_in_val_gaps, 3, 1);
  constant c_dut_block_latency     : natural := 3;
  constant c_dut_clk_latency       : natural := g_fft.nof_points * c_dut_block_latency * c_rnd_factor;  -- worst case
                                                -- need to account for g_fft.nof_points, because tb verifies on serialized output
  
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

  constant c_gap_factor            : natural := sel_a_b(g_enable_in_val_gaps, 3, 1);
  
  -- signal definitions
  signal tb_end                 : std_logic := '0';
  signal tb_end_dut             : std_logic := '0';
  signal clk                    : std_logic := '0';
  signal dut_clk                : std_logic := '0';
  signal tb_clk                 : std_logic := '0';
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
  signal in_dat_a               : std_logic_vector(c_in_dat_w-1 downto 0);
  signal in_dat_a_scope         : integer;
  signal in_dat_b               : std_logic_vector(c_in_dat_w-1 downto 0);
  signal in_dat_b_scope         : integer;
  signal in_val_ab              : std_logic:= '0';
  signal in_re_arr              : t_fft_slv_arr_stg(g_fft.nof_points-1 downto 0);
  signal in_im_arr              : t_fft_slv_arr_stg(g_fft.nof_points-1 downto 0);
  signal in_val                 : std_logic:= '0';
  signal in_val_cnt             : natural := 0;
  signal in_gap                 : std_logic := '0';

  -- Output control

  signal out_re_arr             : t_fft_slv_arr_stg(g_fft.nof_points-1 downto 0);
  signal out_im_arr             : t_fft_slv_arr_stg(g_fft.nof_points-1 downto 0);
  signal out_val                : std_logic:= '0';  -- for parallel output
  signal out_val_cnt            : natural := 0;
  signal out_channel            : natural := 0;     -- not used for parallel FFT, set at default 0
  signal out_val_a              : std_logic:= '0';  -- for real A
  signal out_val_b              : std_logic:= '0';  -- for real B
  signal out_val_c              : std_logic:= '0';  -- for complex(A,B)
  signal out_cnt                : natural := 0;
  signal out_bin_cnt            : natural := 0;
  signal out_bin                : natural;
  
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
  signal reg_out_val_a          : std_logic := '0';
  signal reg_out_val_b          : std_logic := '0';
  signal reg_out_val_c          : std_logic := '0';
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

  clk <= (not clk) or tb_end after c_clk_period/2;
  dut_clk <= clk or tb_end_dut;
  tb_clk <= clk and tb_end_dut;
  rst <= '1', '0' after c_clk_period*7;
  random <= func_common_random(random) WHEN rising_edge(dut_clk);
  in_gap <= random(random'HIGH) WHEN g_enable_in_val_gaps=TRUE ELSE '0';

  o_clk <= clk;
  o_rst <= rst;
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
    in_re_arr <= (others=>(others=>'0'));
    in_im_arr <= (others=>(others=>'0'));
    in_val <= '0';
    proc_common_wait_until_low(dut_clk, rst);         -- Wait until reset has finished
    proc_common_wait_some_cycles(dut_clk, 10);        -- Wait an additional amount of cycles

    -- apply stimuli
    for B in 0 to g_data_file_nof_lines/g_fft.nof_points-1 loop  -- serial
      for I in 0 to g_fft.nof_points-1 loop  -- parallel
        if c_in_complex then
          in_re_arr(I) <= to_fft_stg_svec(input_data_c_arr(2*(B*g_fft.nof_points+I)));
          in_im_arr(I) <= to_fft_stg_svec(input_data_c_arr(2*(B*g_fft.nof_points+I)+1));
        else
          in_re_arr(I) <= to_fft_stg_svec(input_data_a_arr(B*g_fft.nof_points+I));
          in_im_arr(I) <= to_fft_stg_svec(input_data_b_arr(B*g_fft.nof_points+I));
        end if;
      end loop;
      in_val <= '1';
      proc_common_wait_some_cycles(dut_clk, 1);
      if in_gap='1' then
        in_val <= '0';
        proc_common_wait_some_cycles(dut_clk, 1);
      end if;
    end loop;

    -- Wait until done
    in_val <= '0';
    proc_common_wait_some_cycles(dut_clk, c_dut_clk_latency);  -- wait for DUT latency
    tb_end_dut <= '1';
    wait;
  end process;

  ---------------------------------------------------------------
  -- DUT = Device Under Test
  ---------------------------------------------------------------
  u_dut : entity work.fft_r2_par
  generic map(
    g_fft      => g_fft,
    g_use_variant => g_use_variant,
    g_ovflw_behav => g_ovflw_behav,
    g_use_round => g_use_round
  )
  port map(
    clk        => dut_clk,
    rst        => rst,
    in_re_arr  => in_re_arr,
    in_im_arr  => in_im_arr,
    shiftreg   => (0=>'0', 1=>'0', others=>'1'),
    in_val     => in_val,
    out_re_arr => out_re_arr,
    out_im_arr => out_im_arr,
    ovflw      => open,
    out_val    => out_val
  );
  
  -- Block count
  in_val_cnt  <= in_val_cnt+1  when rising_edge(dut_clk) and in_val='1'  else in_val_cnt;
  out_val_cnt <= out_val_cnt+1 when rising_edge(dut_clk) and out_val='1' else out_val_cnt;

  -- Block count t_blk
  t_blk <= in_val_cnt;

  -- Capture the output
  p_capture_output : process(dut_clk)
  begin
    if rising_edge(dut_clk) then
      if out_val='1' then
        if c_in_complex then
          for I in 0 to g_fft.nof_points-1 loop
            output_data_c_re_arr(out_val_cnt*g_fft.nof_points + I) <= TO_SINT(out_re_arr(I));
            output_data_c_im_arr(out_val_cnt*g_fft.nof_points + I) <= TO_SINT(out_im_arr(I));
          end loop;
        else
          for I in 0 to g_fft.nof_points/c_nof_complex-1 loop
            output_data_a_re_arr(out_val_cnt*g_fft.nof_points/c_nof_complex + I) <= TO_SINT(out_re_arr(2*I));
            output_data_a_im_arr(out_val_cnt*g_fft.nof_points/c_nof_complex + I) <= TO_SINT(out_im_arr(2*I));
            output_data_b_re_arr(out_val_cnt*g_fft.nof_points/c_nof_complex + I) <= TO_SINT(out_re_arr(2*I+1));
            output_data_b_im_arr(out_val_cnt*g_fft.nof_points/c_nof_complex + I) <= TO_SINT(out_im_arr(2*I+1));
          end loop;
        end if;
      end if;
    end if;
  end process;
                       
  ---------------------------------------------------------------
  -- REPLAY INPUT AND CAPTURED OUTPUT SERIALLY
  ---------------------------------------------------------------
  p_pipe_input : process
  begin
    in_val_ab <= '0';
    -- Wait until tb_end_dut
    proc_common_wait_until_high(tb_clk, tb_end_dut);
    
    -- Show the input serially
    for B in 0 to g_data_file_nof_lines/g_fft.nof_points-1 loop  -- serial
      for I in 0 to g_fft.nof_points-1 loop  -- serial
        if c_in_complex then
          in_dat_a <= TO_SVEC(input_data_c_arr(2*(B*g_fft.nof_points+I)), c_in_dat_w);
          in_dat_b <= TO_SVEC(input_data_c_arr(2*(B*g_fft.nof_points+I)+1), c_in_dat_w);
        else
          in_dat_a <= TO_SVEC(input_data_a_arr(B*g_fft.nof_points+I), c_in_dat_w);
          in_dat_b <= TO_SVEC(input_data_b_arr(B*g_fft.nof_points+I), c_in_dat_w);
        end if;
        in_val_ab <= '1';
        proc_common_wait_some_cycles(tb_clk, 1);
      end loop;
    end loop;   
    in_val_ab <= '0';
    wait;
  end process;

  p_pipe_output : process
  begin
    out_val_c <= '0';
    -- Wait until tb_end_dut
    proc_common_wait_until_high(tb_clk, tb_end_dut);

    -- Show the output serially
    for B in 0 to g_data_file_nof_lines/g_fft.nof_points-1 loop  -- serial
      for I in 0 to g_fft.nof_points-1 loop  -- serial
        if c_in_complex then
          out_re <= TO_SVEC(output_data_c_re_arr(B*g_fft.nof_points+I), c_out_dat_w);
          out_im <= TO_SVEC(output_data_c_im_arr(B*g_fft.nof_points+I), c_out_dat_w);
        else
          if I mod c_nof_complex = 0 then  -- must use I here, cannot use out_cnt because then for the first two out_val_c mod will yield 0
            out_re <= TO_SVEC(output_data_a_re_arr((B*g_fft.nof_points+I)/c_nof_complex), c_out_dat_w);
            out_im <= TO_SVEC(output_data_a_im_arr((B*g_fft.nof_points+I)/c_nof_complex), c_out_dat_w);
          else
            out_re <= TO_SVEC(output_data_b_re_arr((B*g_fft.nof_points+I)/c_nof_complex), c_out_dat_w);
            out_im <= TO_SVEC(output_data_b_im_arr((B*g_fft.nof_points+I)/c_nof_complex), c_out_dat_w);
          end if;
        end if;
        out_val_c <= '1';
        proc_common_wait_some_cycles(tb_clk, 1);
        --out_cnt <= out_cnt + 1;  -- can increment out_cnt here inside this process after rising_edge(tb_clk) or in separate concurrent process statement
      end loop;
    end loop;   
    out_val_c <= '0';
    
    proc_common_wait_some_cycles(tb_clk, 100);
    tb_end <= '1';
    wait;
  end process;
  
  out_cnt <= out_cnt + 1 when rising_edge(tb_clk) and out_val_c='1' else out_cnt;
    
  proc_fft_out_control(1, g_fft.nof_points, c_nof_channels, g_fft.use_reorder, g_fft.use_fft_shift, g_fft.use_separate,
                       out_cnt, out_val_c, out_val_a, out_val_b, out_channel, out_bin, out_bin_cnt);

  ---------------------------------------------------------------
  -- VERIFY OUTPUT
  ---------------------------------------------------------------
  p_verify_out_val_cnt : process
  begin
    -- Wait until tb_end_dut
    proc_common_wait_until_high(tb_clk, tb_end_dut);
    assert in_val_cnt > 0           report "Test did not run, no valid input data"  severity failure;
    assert out_val_cnt = in_val_cnt report "Unexpected number of valid output data" severity failure;
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
  
  verify_data : process(rst,clk,out_val_a,out_val_b,out_val_c)
    VARIABLE v_test_pass : BOOLEAN := TRUE;
    VARIABLE v_test_msg : STRING( 1 to 80 ) := (others => '.');  
  begin
   if rising_edge(clk) then
    if rst = '0' then
      if not c_in_complex then
        if (out_val_a ='1') and (out_val_b = '1') then
          v_test_pass := diff_re_a_scope >= -g_diff_margin and diff_re_a_scope <= g_diff_margin;
          if not v_test_pass then
            v_test_msg := pad("Output data A real error, expected: " & integer'image(exp_re_a_scope) & "but got: " & integer'image(out_re_a_scope),o_test_msg'length,'.');
            report v_test_msg severity failure;
          end if;
          v_test_pass := diff_im_a_scope >= -g_diff_margin and diff_im_a_scope <= g_diff_margin;
          if not v_test_pass then
            v_test_msg := pad("Output data A imag error, expected: " & integer'image(exp_im_a_scope) & "but got: " & integer'image(out_im_a_scope),o_test_msg'length,'.');
            report v_test_msg severity failure;
          end if;
          v_test_pass := diff_re_b_scope >= -g_diff_margin and diff_re_b_scope <= g_diff_margin;
          if not v_test_pass then
            v_test_msg := pad("Output data B real error, expected: " & integer'image(exp_re_b_scope) & "but got: " & integer'image(out_re_b_scope),o_test_msg'length,'.');
            report v_test_msg severity failure;
          end if;
          v_test_pass := diff_im_b_scope >= -g_diff_margin and diff_im_b_scope <= g_diff_margin;
          if not v_test_pass then
            v_test_msg := pad("Output data B imag error, expected: " & integer'image(exp_im_b_scope) & "but got: " & integer'image(out_im_b_scope),o_test_msg'length,'.');
            report v_test_msg severity failure;
          end if;
        end if;
      else
        if out_val_c = '1' then
          v_test_pass := diff_re_c_scope >= -g_diff_margin and diff_re_c_scope <= g_diff_margin;
          if not v_test_pass then
            v_test_msg := pad("Output data C real error, expected: " & integer'image(exp_re_c_scope) & "but got: " & integer'image(out_re_c_scope),o_test_msg'length,'.');
            report v_test_msg severity failure;
          end if;
          v_test_pass := diff_im_c_scope >= -g_diff_margin and diff_im_c_scope <= g_diff_margin;
          if not v_test_pass then
            v_test_msg := pad("Output data C imag error, expected: " & integer'image(exp_im_c_scope) & "but got: " & integer'image(out_im_c_scope),o_test_msg'length,'.');
            report v_test_msg severity failure;
          end if;
        end if;
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

  -- clk diff to avoid combinatorial glitches when selecting the data with out_val_a,b, out_val
  reg_out_val_a   <= out_val_a   when rising_edge(tb_clk);
  reg_out_val_b   <= out_val_b   when rising_edge(tb_clk);
  reg_out_val_c   <= out_val_c   when rising_edge(tb_clk);
  reg_out_bin_cnt <= out_bin_cnt when rising_edge(tb_clk);
  reg_out_bin     <= out_bin     when rising_edge(tb_clk);

  out_re_a_scope <= TO_SINT(out_re) when rising_edge(tb_clk) and out_val_a='1';
  out_im_a_scope <= TO_SINT(out_im) when rising_edge(tb_clk) and out_val_a='1';
  out_re_b_scope <= TO_SINT(out_re) when rising_edge(tb_clk) and out_val_b='1';
  out_im_b_scope <= TO_SINT(out_im) when rising_edge(tb_clk) and out_val_b='1';
  out_re_c_scope <= TO_SINT(out_re) when rising_edge(tb_clk) and out_val_c='1';
  out_im_c_scope <= TO_SINT(out_im) when rising_edge(tb_clk) and out_val_c='1';

  exp_re_a_scope <= expected_data_a_re_arr(out_bin_cnt) when rising_edge(tb_clk) and out_val_a='1';
  exp_im_a_scope <= expected_data_a_im_arr(out_bin_cnt) when rising_edge(tb_clk) and out_val_a='1';
  exp_re_b_scope <= expected_data_b_re_arr(out_bin_cnt) when rising_edge(tb_clk) and out_val_b='1';
  exp_im_b_scope <= expected_data_b_im_arr(out_bin_cnt) when rising_edge(tb_clk) and out_val_b='1';  
  exp_re_c_scope <= expected_data_c_re_arr(out_bin_cnt) when rising_edge(tb_clk) and out_val_c='1';
  exp_im_c_scope <= expected_data_c_im_arr(out_bin_cnt) when rising_edge(tb_clk) and out_val_c='1';

  diff_re_a_scope <= exp_re_a_scope - out_re_a_scope;
  diff_im_a_scope <= exp_im_a_scope - out_im_a_scope;
  diff_re_b_scope <= exp_re_b_scope - out_re_b_scope;
  diff_im_b_scope <= exp_im_b_scope - out_im_b_scope;
  diff_re_c_scope <= exp_re_c_scope - out_re_c_scope;
  diff_im_c_scope <= exp_im_c_scope - out_im_c_scope;

end tb;
