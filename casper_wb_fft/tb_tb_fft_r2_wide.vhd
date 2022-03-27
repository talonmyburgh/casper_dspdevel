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

-- Purpose: Multi-testbench for fft_r2_wide using file data
-- Description:
--   Verify fft_r2_wide using and data generated by Matlab scripts:
--
--   - $RADIOHDL/applications/apertif/matlab/run_pfft.m
--   - $RADIOHDL/applications/apertif/matlab/run_pfft_complex.m
--
-- Usage:
--   > as 4
--   > run -all

LIBRARY IEEE, common_pkg_lib, r2sdf_fft_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.all;
USE r2sdf_fft_lib.rTwoSDFPkg.all;
USE work.fft_gnrcs_intrfcs_pkg.all;
              
ENTITY tb_tb_fft_r2_wide IS
END tb_tb_fft_r2_wide;

ARCHITECTURE tb OF tb_tb_fft_r2_wide IS
  
  CONSTANT c_fft_wb4_two_real           : t_fft := ( true, false,  true, 0, 4, 0, 128, c_in_dat_w, c_out_dat_w, 0, c_dsp_mult_w, 2, true, 56, 2, false);
  CONSTANT c_fft_wb4_two_real_ip        : t_fft := ( true, false,  true, 0, 4, 0, 128, c_in_dat_w, c_out_dat_w, 0, c_dsp_mult_w, 2, true, 56, 2, true);
  CONSTANT c_fft_wb4_complex_fft_shift  : t_fft := ( true,  true, false, 0, 4, 0,  64, c_in_dat_w, c_out_dat_w, 0, c_dsp_mult_w, 2, true, 56, 2, false);
  CONSTANT c_fft_wb4_complex_flipped    : t_fft := (false, false, false, 0, 4, 0,  64, c_in_dat_w, c_out_dat_w, 0, c_dsp_mult_w, 2, true, 56, 2, false);
  CONSTANT c_fft_wb4_complex_flipped_ip : t_fft := (false, false, false, 0, 4, 0,  64, c_in_dat_w, c_out_dat_w, 0, c_dsp_mult_w, 2, true, 56, 2, true);
  CONSTANT c_fft_wb4_complex            : t_fft := ( true, false, false, 0, 4, 0,  64, c_in_dat_w, c_out_dat_w, 0, c_dsp_mult_w, 2, true, 56, 2, false);
  CONSTANT c_fft_wb4_complex_ip         : t_fft := ( true, false, false, 0, 4, 0,  64, c_in_dat_w, c_out_dat_w, 0, c_dsp_mult_w, 2, true, 56, 2, true);
                     
  CONSTANT c_fft_wb1_complex            : t_fft := ( true, false, false, 0, 1, 0,  64, c_in_dat_w, c_out_dat_w, 0, c_dsp_mult_w, 2, true, 56, 2, false);
  CONSTANT c_fft_wb1_complex_ip         : t_fft := ( true, false, false, 0, 1, 0,  64, c_in_dat_w, c_out_dat_w, 0, c_dsp_mult_w, 2, true, 56, 2, true);
  CONSTANT c_fft_wb64_complex           : t_fft := ( true, false, false, 0,64, 0,  64, c_in_dat_w, c_out_dat_w, 0, c_dsp_mult_w, 2, true, 56, 2, false);
  
  CONSTANT c_diff_margin    : natural := 2;
  
  -- Real input  
  CONSTANT c_impulse_chirp  : string := "run_pfft_m_impulse_chirp_8b_128points_16b.dat";          -- 25600 lines
  CONSTANT c_sinusoid_chirp : string := "run_pfft_m_sinusoid_chirp_8b_128points_16b.dat";         -- 25600 lines
  CONSTANT c_noise          : string := "run_pfft_m_noise_8b_128points_16b.dat";                  --  1280 lines
  CONSTANT c_dc_agwn        : string := "run_pfft_m_dc_agwn_8b_128points_16b.dat";                --  1280 lines
  -- Complex input  
  CONSTANT c_phasor_chirp   : string := "run_pfft_complex_m_phasor_chirp_8b_64points_16b.dat";    -- 12800 lines
  CONSTANT c_phasor         : string := "run_pfft_complex_m_phasor_8b_64points_16b.dat";          --   320 lines
  CONSTANT c_noise_complex  : string := "run_pfft_complex_m_noise_complex_8b_64points_16b.dat";   --   620 lines
  -- Zero input
  CONSTANT c_zero           : string := "UNUSED";
  CONSTANT c_unused         : string := "UNUSED";
 
  SIGNAL tb_end : STD_LOGIC := '0';  -- declare tb_end to avoid 'No objects found' error on 'when -label tb_end'
  
BEGIN

-- -- DUT generics
-- --g_fft : t_fft := ( true, false,  true, 0, 4, 0, 128, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- two real inputs A and B
-- g_fft : t_fft := ( true, false,  true, 0, 4, 0,  32, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- two real inputs A and B
-- --g_fft : t_fft := ( true, false, false, 0, 4, 0,  32, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- complex input reordered
-- --g_fft : t_fft := (false, false, false, 0, 4, 0,  32, 8, 16, 0, c_dsp_mult_w, 2, true, 56, 2);         -- complex input flipped
-- --  type t_rtwo_fft is record
-- --    use_reorder    : boolean;  -- = false for bit-reversed output, true for normal output
-- --    use_fft_shift  : boolean;  -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
-- --    use_separate   : boolean;  -- = false for complex input, true for two real inputs
-- --    nof_chan       : natural;  -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan         
-- --    wb_factor      : natural;  -- = default 1, wideband factor
-- --    twiddle_offset : natural;  -- = default 0, twiddle offset for PFT sections in a wideband FFT
-- --    nof_points     : natural;  -- = 1024, N point FFT
-- --    in_dat_w       : natural;  -- = 8, number of input bits
-- --    out_dat_w      : natural;  -- = 13, number of output bits, bit growth: in_dat_w + natural((ceil_log2(nof_points))/2 + 2)  
-- --    out_gain_w     : natural;  -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
-- --    stage_dat_w    : natural;  -- = 18, data width used between the stages(= DSP multiplier-width)
-- --    guard_w        : natural;  -- = 2,  Guard used to avoid overflow in FFT stage. 
-- --    guard_enable   : boolean;  -- = true when input needs guarding, false when input requires no guarding but scaling must be skipped at the last stage(s) (used in wb fft)
-- --    stat_data_w    : positive; -- = 56 (= 18b+18b)+log2(781250)
-- --    stat_data_sz   : positive; -- = 2 (complex re and im)
-- --  end record;
-- --
-- -- TB generics
-- g_diff_margin           : integer := 2;  -- maximum difference between HDL output and expected output (> 0 to allow minor rounding differences)
-- 
-- -- Two real input data files A and B used when g_fft.use_separate = true
-- -- * 128 points = 64 subbands
-- --g_data_file_a           : string := "data/run_pfft_m_sinusoid_chirp_8b_128points_16b.dat";
-- --g_data_file_a_nof_lines : natural := 25600;
-- --g_data_file_b           : string := "UNUSED";
-- --g_data_file_b_nof_lines : natural := 0;
-- 
-- -- * 32 points = 16 subbands
-- g_data_file_a           : string := "data/run_pfft_m_sinusoid_chirp_8b_32points_16b.dat";
-- g_data_file_a_nof_lines : natural := 6400;
-- --g_data_file_a           : string := "data/run_pfft_m_sinusoid_8b_32points_16b.dat";
-- --g_data_file_a_nof_lines : natural := 160;
-- 
-- --g_data_file_b           : string := "data/run_pfft_m_impulse_chirp_8b_32points_16b.dat";
-- --g_data_file_b_nof_lines : natural := 6400;
-- g_data_file_b           : string := "UNUSED";
-- g_data_file_b_nof_lines : natural := 0;
-- 
-- -- One complex input data file C used when g_fft.use_separate = false
-- -- * 64 points = 64 channels
-- --g_data_file_c           : string := "data/run_pfft_complex_m_phasor_chirp_8b_64points_16b.dat";
-- --g_data_file_c_nof_lines : natural := 12800;
-- --g_data_file_c           : string := "data/run_pfft_complex_m_phasor_8b_64points_16b.dat";
-- --g_data_file_c_nof_lines : natural := 320;
-- --g_data_file_c           : string := "data/run_pfft_complex_m_noise_8b_64points_16b.dat";
-- --g_data_file_c_nof_lines : natural := 640;
--
-- -- * 32 points = 32 channels
-- g_data_file_c           : string := "data/run_pfft_complex_m_phasor_chirp_8b_32points_16b.dat";
-- g_data_file_c_nof_lines : natural := 6400;
-- --g_data_file_c           : string := "data/run_pfft_complex_m_phasor_8b_32points_16b.dat";
-- --g_data_file_c_nof_lines : natural := 160;
-- --g_data_file_c           : string := "data/run_pfft_complex_m_noise_8b_32points_16b.dat";
-- --g_data_file_c_nof_lines : natural := 320;
-- 
-- g_data_file_nof_lines   : natural := 6400;    -- actual number of lines with input data to simulate from the data files, must be <= g_data_file_*_nof_lines
-- g_enable_in_val_gaps    : boolean := TRUE   -- when false then in_val flow control active continuously, else with random inactive gaps
  
  -- Two real input data A and B
  u_act_two_real_chirp      : ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb4_two_real,     c_diff_margin, c_sinusoid_chirp, 25600, c_impulse_chirp, 25600, c_unused, 0, 25600, FALSE);
  u_act_two_real_chirp_ip   : ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb4_two_real_ip,  c_diff_margin, c_sinusoid_chirp, 25600, c_impulse_chirp, 25600, c_unused, 0, 25600, FALSE);
  u_act_two_real_a0         : ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb4_two_real,     c_diff_margin, c_zero,           25600, c_impulse_chirp, 25600, c_unused, 0,  5120, FALSE);
  u_act_two_real_b0         : ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb4_two_real,     c_diff_margin, c_sinusoid_chirp, 25600, c_zero,          25600, c_unused, 0,  5120, FALSE);
  u_rnd_two_real_noise      : ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb4_two_real,     c_diff_margin, c_noise,           1280, c_dc_agwn,        1280, c_unused, 0,  1280, TRUE);
  
  -- Complex input data
  u_act_complex_chirp       : ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb4_complex,            c_diff_margin, c_unused, 0, c_unused, 0, c_phasor_chirp,  12800, 12800, FALSE);
  u_act_complex_fft_shift   : ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb4_complex_fft_shift,  c_diff_margin, c_unused, 0, c_unused, 0, c_phasor_chirp,  12800,  1280, FALSE);
  u_act_complex_flipped     : ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb4_complex_flipped,    c_diff_margin, c_unused, 0, c_unused, 0, c_phasor_chirp,  12800,  1280, FALSE);
  u_act_complex_flipped_ip  : ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb4_complex_flipped_ip, c_diff_margin, c_unused, 0, c_unused, 0, c_phasor_chirp,  12800,  1280, FALSE);
  u_rnd_complex_noise       : ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb4_complex,            c_diff_margin, c_unused, 0, c_unused, 0, c_noise_complex,   640,   640, TRUE);
  u_rnd_complex_noise_ip    : ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb4_complex_ip,         c_diff_margin, c_unused, 0, c_unused, 0, c_noise_complex,   640,   640, TRUE);

  -- Extreme wb_factor=1 and wb_factor=nof_points
  u_act_wb1_complex_noise   : ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb1_complex,    c_diff_margin, c_unused, 0, c_unused, 0, c_noise_complex,   640,   640, FALSE);
  u_act_wb1_complex_noise_ip: ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb1_complex_ip, c_diff_margin, c_unused, 0, c_unused, 0, c_noise_complex,   640,   640, FALSE);
  u_act_wb64_complex_noise  : ENTITY work.tb_fft_r2_wide GENERIC MAP (c_fft_wb64_complex,   c_diff_margin, c_unused, 0, c_unused, 0, c_noise_complex,   640,   640, FALSE);
END tb;
