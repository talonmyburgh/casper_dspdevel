-- Author: Eric Kooistra    : kooistra at astron.nl: july 2016
--------------------------------------------------------------------------------
--
-- Copyright (C) 2016
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--------------------------------------------------------------------------------
--
-- Purpose: Test bench for wpfb_unit_dev.vhd using file data
--
-- Description:
--   This tb uses the Matlab stimuli and expected results obtained with:
--
--   $RADIOHDL_WORK/applications/apertif/matlab/run_pfb.m
--   $RADIOHDL_WORK/applications/apertif/matlab/run_pfb_complex.m
--
--   For more description see:
--   . tb_fil_ppf_wide_file_data.vhd
--   . tb_fft_r2_wide.vhd
--
-- Remark:
--   . tb supports wb_factor = 1 and wb_factor > 1
--   . tb supports use_separate for complex and two real input 
--   . tb supports use_reorder for complex input with flipped or reordered output
--   . tb supports use_reorder for two real input with reordered output
--   . tb does support nof_wb_streams > 1
--   . tb does support nof_chan > 0 
-- 
-- Usage:
--   > run -all
--   > testbench is selftesting.
--   > observe the *_scope signals as radix decimal, format analogue format
--     signals in the Wave window
--
library ieee, common_pkg_lib, dp_pkg_lib, casper_filter_lib, r2sdf_fft_lib, wb_fft_lib, casper_ram_lib, dp_components_lib, casper_sim_tools_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.ALL;
use common_pkg_lib.common_lfsr_sequences_pkg.ALL;
use common_pkg_lib.tb_common_pkg.all;
use casper_filter_lib.fil_pkg.all; 
use r2sdf_fft_lib.rTwoSDFPkg.all;
use wb_fft_lib.fft_gnrcs_intrfcs_pkg.all;
use wb_fft_lib.tb_fft_pkg.all;
use work.wbpfb_gnrcs_intrfcs_pkg.all;

entity tb_wbpfb_unit_wide is
  generic(
    -- DUT generics
    g_wpfb : t_wpfb := (4, 32, 0, 1,
                        16, 1, 8, 16, 16,
                        true, false, true, 16, 16, 1, c_dsp_mult_w, 2, true, 56, 2, 20,
                        c_fft_pipeline, c_fft_pipeline, c_fil_ppf_pipeline);
    --  type t_wpfb is record  
    --    -- General parameters for the wideband poly phase filter
    --    wb_factor         : natural;        -- = default 4, wideband factor
    --    nof_points        : natural;        -- = 1024, N point FFT (Also the number of subbands for the filter part)
    --    nof_chan          : natural;        -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan
    --    nof_wb_streams    : natural;        -- = 1, the number of parallel wideband streams. The filter coefficients are shared on every wb-stream. 
    --    
    --    -- Parameters for the poly phase filter
    --    nof_taps          : natural;        -- = 16, the number of FIR taps per subband
    --    fil_backoff_w     : natural;        -- = 0, number of bits for input backoff to avoid output overflow
    --    fil_in_dat_w      : natural;        -- = 8, number of input bits
    --    fil_out_dat_w     : natural;        -- = 16, number of output bits
    --    coef_dat_w        : natural;        -- = 16, data width of the FIR coefficients
    --                                      
    --    -- Parameters for the FFT         
    --    use_reorder       : boolean;        -- = false for bit-reversed output, true for normal output
    --    use_fft_shift     : boolean;        -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
    --    use_separate      : boolean;        -- = false for complex input, true for two real inputs
    --    fft_in_dat_w      : natural;        -- = 16, number of input bits
    --    fft_out_dat_w     : natural;        -- = 13, number of output bits
    --    fft_out_gain_w    : natural;        -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
    --    stage_dat_w       : natural;        -- = 18, number of bits that are used inter-stage
    --    guard_w           : natural;        -- = 2
    --    guard_enable      : boolean;        -- = true
    --
    --    -- Parameters for the statistics
    --    stat_data_w       : positive;       -- = 56
    --    stat_data_sz      : positive;       -- = 2
    --    nof_blk_per_sync  : natural;        -- = 800000, number of FFT output blocks per sync interval
    -- 
    --    -- Pipeline parameters for both poly phase filter and FFT. These are heritaged from the filter and fft libraries.  
    --    pft_pipeline      : t_fft_pipeline;     -- Pipeline settings for the pipelined FFT
    --    fft_pipeline      : t_fft_pipeline;     -- Pipeline settings for the parallel FFT
    --    fil_pipeline      : t_fil_ppf_pipeline; -- Pipeline settings for the filter units 
    --  end record;
    
    -- TB generics
    g_diff_margin           : integer := 5;  -- maximum difference between HDL output and expected output (> 0 to allow minor rounding differences)
                                             -- for complex  diff margin = 3 appears sufficient
                                             -- for two_real diff margin = 5 appears sufficient
                                             -- if stage_dat_w >> 18 >= fft_out_dat_w then g_diff_margin = 1 is sufficient
    
    -- PFIR coefficients
    g_coefs_file_prefix_ab    : string := "data/run_pfb_m_pfir_coeff_fircls1";
    g_coefs_file_prefix_c     : string := "data/run_pfb_complex_m_pfir_coeff_fircls1";
    
    -- Two real input data files A and B used when g_fft.use_separate = true
    -- * 1024 points = 512 subbands
    --g_data_file_a           : string := "data/run_pfb_m_sinusoid_chirp_8b_16taps_1024points_16b_16b.dat";
    --g_data_file_a_nof_lines : natural := 204800;
    --g_data_file_b           : string := "UNUSED";
    --g_data_file_b_nof_lines : natural := 0;
    
    -- * 32 points = 16 subbands
    --g_data_file_a           : string := "data/run_pfb_m_sinusoid_chirp_8b_16taps_32points_16b_16b.dat";
    --g_data_file_a_nof_lines : natural := 6400;
    g_data_file_a           : string := "data/run_pfb_m_sinusoid_8b_16taps_32points_16b_16b.dat";
    g_data_file_a_nof_lines : natural := 1600;
    
    --g_data_file_b           : string := "data/run_pfb_m_impulse_chirp_8b_16taps_32points_16b_16b.dat";
    --g_data_file_b_nof_lines : natural := 6400;
    g_data_file_b           : string := "UNUSED";
    g_data_file_b_nof_lines : natural := 0;
    
    -- One complex input data file C used when g_fft.use_separate = false
    -- * 64 points = 64 channels
    --g_data_file_c           : string := "data/run_pfb_complex_m_phasor_chirp_8b_16taps_64points_16b_16b.dat";
    --g_data_file_c_nof_lines : natural := 12800;
    --g_data_file_c           : string := "data/run_pfb_complex_m_phasor_8b_16taps_64points_16b_16b.dat";
    --g_data_file_c_nof_lines : natural := 320;
    --g_data_file_c           : string := "data/run_pfb_complex_m_noise_8b_16taps_64points_16b_16b.dat";
    --g_data_file_c_nof_lines : natural := 640;

    -- * 32 points = 32 channels
    --g_data_file_c           : string := "data/run_pfb_complex_m_phasor_chirp_8b_16taps_32points_16b_16b.dat";
    --g_data_file_c_nof_lines : natural := 6400;
    --g_data_file_c           : string := "data/run_pfb_complex_m_phasor_8b_16taps_32points_16b_16b.dat";
    --g_data_file_c_nof_lines : natural := 1600;
    g_data_file_c           : string := "data/run_pfb_complex_m_noise_complex_8b_16taps_32points_16b_16b.dat";
    g_data_file_c_nof_lines : natural := 1600;
    
    g_data_file_nof_lines   : natural := 1600;   -- actual number of lines with input data to simulate from the data files, must be <= g_data_file_*_nof_lines
    g_enable_in_val_gaps    : boolean := FALSE   -- when false then in_val flow control active continuously, else with random inactive gaps
  );
end entity tb_wbpfb_unit_wide;

architecture tb of tb_wbpfb_unit_wide is

  constant c_big_endian_wb_in      : boolean := true;
  
  constant c_clk_period            : time := 10 ns;
  constant c_sclk_period           : time := c_clk_period / g_wpfb.wb_factor;
  
  constant c_in_complex            : boolean := not g_wpfb.use_separate;
  
  constant c_nof_channels          : natural := 2**g_wpfb.nof_chan;
  constant c_nof_coefs             : natural := g_wpfb.nof_taps * g_wpfb.nof_points;       -- nof PFIR coef

  constant c_nof_data_per_block    : natural := g_wpfb.nof_points * c_nof_channels;
  constant c_nof_valid_per_block   : natural := c_nof_data_per_block / g_wpfb.wb_factor;

  constant c_rnd_factor            : natural := sel_a_b(g_enable_in_val_gaps, 3, 1);
  constant c_dut_block_latency     : natural := func_wpfb_maximum_sop_latency(g_wpfb);  -- choose large enough for output to have become available
  constant c_dut_clk_latency       : natural := c_nof_valid_per_block * c_dut_block_latency * c_rnd_factor;  -- worst case

  -- PFIR coefficients file access
  constant c_coefs_dat_file_prefix    : string  := sel_a_b(c_in_complex, g_coefs_file_prefix_c, g_coefs_file_prefix_ab);
  constant c_coefs_memory_file_prefix : string  := c_coefs_dat_file_prefix;
  
  -- input/output data width
  constant c_in_dat_w              : natural := g_wpfb.fil_in_dat_w;   
  constant c_fil_dat_w             : natural := g_wpfb.fil_out_dat_w;   
  constant c_out_dat_w             : natural := g_wpfb.fft_out_dat_w;

  -- Data file access (Header + PFIR coefficients + WG data + PFIR data + PFFT data)
  constant c_nof_lines_header        : natural := 4;
  constant c_nof_lines_pfir_coefs    : natural := c_nof_coefs;                                -- PFIR coefficients
  constant c_nof_lines_a_wg_dat      : natural := g_data_file_a_nof_lines;                    -- Real input A via in_re, one value per line
  constant c_nof_lines_a_pfir_dat    : natural := g_data_file_a_nof_lines;                    -- Real pfir A, one value per line
  constant c_nof_lines_a_pfft_dat    : natural := g_data_file_a_nof_lines/c_nof_complex;      -- Half spectrum, two values per line (re, im)
  constant c_nof_lines_a_wg_header   : natural := c_nof_lines_header + c_nof_lines_pfir_coefs;
  constant c_nof_lines_a_pfir_header : natural := c_nof_lines_header + c_nof_lines_pfir_coefs + c_nof_lines_a_wg_dat;
  constant c_nof_lines_a_pfft_header : natural := c_nof_lines_header + c_nof_lines_pfir_coefs + c_nof_lines_a_wg_dat + c_nof_lines_a_pfir_dat;
  constant c_nof_lines_b_wg_dat      : natural := g_data_file_b_nof_lines;                    -- Real input A via in_re, one value per line
  constant c_nof_lines_b_pfir_dat    : natural := g_data_file_b_nof_lines;                    -- Real pfir A, one value per line
  constant c_nof_lines_b_pfft_dat    : natural := g_data_file_b_nof_lines/c_nof_complex;      -- Half spectrum, two values per line (re, im)
  constant c_nof_lines_b_wg_header   : natural := c_nof_lines_header + c_nof_lines_pfir_coefs;
  constant c_nof_lines_b_pfir_header : natural := c_nof_lines_header + c_nof_lines_pfir_coefs + c_nof_lines_b_wg_dat;
  constant c_nof_lines_b_pfft_header : natural := c_nof_lines_header + c_nof_lines_pfir_coefs + c_nof_lines_b_wg_dat + c_nof_lines_b_pfir_dat;
  constant c_nof_lines_c_wg_dat      : natural := g_data_file_c_nof_lines;                    -- Complex input, two values per line (re, im)
  constant c_nof_lines_c_pfir_dat    : natural := g_data_file_c_nof_lines;                    -- Complex pfir, two values per line (re, im)
  constant c_nof_lines_c_pfft_dat    : natural := g_data_file_c_nof_lines;                    -- Full spectrum, two values per line (re, im)
  constant c_nof_lines_c_wg_header   : natural := c_nof_lines_header + c_nof_lines_pfir_coefs;
  constant c_nof_lines_c_pfir_header : natural := c_nof_lines_header + c_nof_lines_pfir_coefs + c_nof_lines_c_wg_dat;
  constant c_nof_lines_c_pfft_header : natural := c_nof_lines_header + c_nof_lines_pfir_coefs + c_nof_lines_c_wg_dat + c_nof_lines_c_pfir_dat;

  -- signal definitions
  signal tb_end                 : std_logic := '0';
  signal tb_end_almost          : std_logic := '0';
  signal clk                    : std_logic := '0';
  signal sclk                   : std_logic := '0';
  signal rst                    : std_logic := '0';
  signal random                 : std_logic_vector(15 DOWNTO 0) := (OTHERS=>'0');  -- use different lengths to have different random sequences

  signal coefs_dat_arr          : t_integer_arr(c_nof_coefs-1 downto 0) := (OTHERS=>0);  -- = PFIR coef for all taps as read from via c_coefs_dat_file_prefix
  signal coefs_ref_c_arr        : t_integer_arr(c_nof_coefs-1 downto 0) := (OTHERS=>0);  -- = PFIR coef for all taps as read from via g_data_file_c
  signal coefs_ref_a_arr        : t_integer_arr(c_nof_coefs-1 downto 0) := (OTHERS=>0);  -- = PFIR coef for all taps as read from via g_data_file_a
  signal coefs_ref_b_arr        : t_integer_arr(c_nof_coefs-1 downto 0) := (OTHERS=>0);  -- = PFIR coef for all taps as read from via g_data_file_b
  
  signal input_data_a_arr       : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- one value per line (A via re input)
  signal input_data_b_arr       : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- one value per line (B via im input)
  signal input_data_c_arr       : t_integer_arr(0 to g_data_file_nof_lines*c_nof_complex-1) := (OTHERS=>0);  -- two values per line (re, im)

  signal exp_filter_data_a_arr     : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- one value per line (A via re input)
  signal exp_filter_data_b_arr     : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- one value per line (B via im input)
  signal exp_filter_data_c_arr     : t_integer_arr(0 to g_data_file_nof_lines*c_nof_complex-1) := (OTHERS=>0);  -- two values per line (re, im)
  signal exp_filter_data_c_re_arr  : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- one value per line (re input)
  signal exp_filter_data_c_im_arr  : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- one value per line (im input)
  
  signal output_data_a_re_arr   : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, re
  signal output_data_a_im_arr   : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, im
  signal output_data_b_re_arr   : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, re
  signal output_data_b_im_arr   : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, im
  signal output_data_c_re_arr   : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- full spectrum, re
  signal output_data_c_im_arr   : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- full spectrum, im  
  
  signal exp_output_data_a_arr    : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- half spectrum, two values per line (re, im)
  signal exp_output_data_a_re_arr : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, re
  signal exp_output_data_a_im_arr : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, im
  signal exp_output_data_b_arr    : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- half spectrum, two values per line (re, im)
  signal exp_output_data_b_re_arr : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, re
  signal exp_output_data_b_im_arr : t_integer_arr(0 to g_data_file_nof_lines/c_nof_complex-1) := (OTHERS=>0);  -- half spectrum, im
  signal exp_output_data_c_arr    : t_integer_arr(0 to g_data_file_nof_lines*c_nof_complex-1) := (OTHERS=>0);  -- full spectrum, two values per line (re, im)
  signal exp_output_data_c_re_arr : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- full spectrum, re
  signal exp_output_data_c_im_arr : t_integer_arr(0 to g_data_file_nof_lines-1) := (OTHERS=>0);                -- full spectrum, im  

  -- Input
  signal in_re_arr              : t_fil_slv_arr_in(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal in_im_arr              : t_fil_slv_arr_in(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal in_re_data             : std_logic_vector(g_wpfb.wb_factor*c_in_dat_w-1 DOWNTO 0);  -- scope data only for stream 0
  signal in_im_data             : std_logic_vector(g_wpfb.wb_factor*c_in_dat_w-1 DOWNTO 0);  -- scope data only for stream 0
  signal in_val                 : std_logic:= '0';
  signal in_val_cnt             : natural := 0;
  signal in_blk_val             : std_logic;
  signal in_blk_val_cnt         : natural := 0;
  signal in_gap                 : std_logic := '0';
  signal in_sosi_arr            : t_fil_sosi_arr_in(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0) := (others=>c_fil_sosi_rst_in);
  signal in_blk_time            : integer := 0;  -- input block time counter
  
  signal in_sosi_val            : t_fil_sosi_in;
  signal ref_sosi_ctrl          : t_fil_sosi_in;
  signal ref_re_arr             : t_fil_slv_arr_in(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal ref_im_arr             : t_fil_slv_arr_in(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);

  signal shiftreg               : std_logic_vector(ceil_log2(g_wpfb.nof_points) - 1 DOWNTO 0) := (0=>'0', 1=>'0', others=>'1');

  -- Input in sclk domain  
  signal in_re_scope            : integer;
  signal in_im_scope            : integer;
  signal in_val_scope           : std_logic:= '0';

  -- Filter in sclk domain
  signal fil_re_scope           : integer;
  signal fil_im_scope           : integer;
  signal fil_val_scope          : std_logic:= '0';
  signal exp_fil_re_scope       : integer;
  signal exp_fil_im_scope       : integer;
  
  -- Observe common sosi fields via sosi_arr(0)
  signal in_sosi_0              : t_fil_sosi_in;
  signal out_sosi_0             : t_fft_sosi_out;
  
  -- Output
  signal out_sosi_arr           : t_fft_sosi_arr_out(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0) := (others=>c_fft_sosi_rst_out);
  signal out_re_arr             : t_fft_slv_arr_out(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal out_im_arr             : t_fft_slv_arr_out(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal out_re_data            : std_logic_vector(g_wpfb.wb_factor*c_out_dat_w-1 DOWNTO 0);  -- scope data only for stream 0
  signal out_im_data            : std_logic_vector(g_wpfb.wb_factor*c_out_dat_w-1 DOWNTO 0);  -- scope data only for stream 0
  signal out_val                : std_logic:= '0';  -- for parallel output
  signal out_val_cnt            : natural := 0;
  signal out_blk_time           : integer := 0;  -- output block time counter

  signal ovflw               : std_logic_vector(ceil_log2(g_wpfb.nof_points) - 1 DOWNTO 0);

  
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
  signal reg_out_blk_time       : integer := 0;
  
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

  in_sosi_0  <= in_sosi_arr(0);
  out_sosi_0 <= out_sosi_arr(0);
  
  ---------------------------------------------------------------
  -- DATA INPUT
  ---------------------------------------------------------------
  p_input_stimuli : process
    variable vP : natural;
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
    for I in 0 to g_data_file_nof_lines/g_wpfb.wb_factor-1 loop  -- serial
      for K in 0 to c_nof_channels-1 loop  -- serial
        for S in 0 to g_wpfb.nof_wb_streams-1 loop  -- parallel
          for P in 0 to g_wpfb.wb_factor-1 loop  -- parallel
            if c_big_endian_wb_in=TRUE then
              vP := g_wpfb.wb_factor-1-P;        -- time to big endian
            else
              vP := P;                           -- time in little endian
            end if;
            if K=1 or S=1 then
              -- if present then serial channel  1 carries zero data to be able to recognize the serial channel  order in the wave window
              -- if present then parallel stream 1 carries zero data to be able to recognize the parallel stream order in the wave window
              in_re_arr(S*g_wpfb.wb_factor + vP) <= (OTHERS=>'0');
              in_im_arr(S*g_wpfb.wb_factor + vP) <= (OTHERS=>'0');
            else
              -- stream 0 and if present the other streams >= 2 carry the same input reference data to verify the filter function
              if c_in_complex then
                in_re_arr(S*g_wpfb.wb_factor + vP) <= TO_SVEC(input_data_c_arr((I*g_wpfb.wb_factor+P)*c_nof_complex),g_wpfb.fil_in_dat_w);
                in_im_arr(S*g_wpfb.wb_factor + vP) <= TO_SVEC(input_data_c_arr((I*g_wpfb.wb_factor+P)*c_nof_complex+1),g_wpfb.fil_in_dat_w);
              else
                in_re_arr(S*g_wpfb.wb_factor + vP) <= TO_SVEC(input_data_a_arr(I*g_wpfb.wb_factor+P),g_wpfb.fil_in_dat_w);
                in_im_arr(S*g_wpfb.wb_factor + vP) <= TO_SVEC(input_data_b_arr(I*g_wpfb.wb_factor+P),g_wpfb.fil_in_dat_w);
              end if;
            end if;
          end loop;
        end loop;
        in_val <= '1';  -- serial
        proc_common_wait_some_cycles(clk, 1);
        if in_gap='1' then
          in_val <= '0';  -- serial
          proc_common_wait_some_cycles(clk, 1);
        end if;
      end loop;
    end loop;

    -- Wait until done
    in_val <= '0';
    proc_common_wait_some_cycles(clk, c_dut_clk_latency);  -- wait for DUT latency
    tb_end_almost <= '1';
    proc_common_wait_some_cycles(clk, 100);
    tb_end <= '1';
    wait;
  end process;
  
  in_sosi_val.valid <= in_val;
  
--   u_ref_sosi_ctrl : entity dp_components_lib.dp_block_gen
--   generic map (
--     g_use_src_in         => false,                  -- when true use src_in.ready else use snk_in.valid for flow control
--     g_nof_data           => c_nof_valid_per_block,  -- nof data per block
--     g_nof_blk_per_sync   => g_wpfb.nof_blk_per_sync,
--     g_empty              => 0,
--     g_channel            => 0,
--     g_error              => 0,
--     g_bsn                => 12,
--     g_preserve_sync      => false,
--     g_preserve_bsn       => false
--   )
--   port map (
--     rst        => rst,
--     clk        => clk,
--     -- Streaming sink
--     snk_in     => in_sosi_val,
--     -- Streaming source
--     src_in     => c_dp_siso_rdy,
--     src_out    => ref_sosi_ctrl,
--     -- MM control
--     en         => '1'
--   );  

  ref_re_arr <= in_re_arr when rising_edge(clk);
  ref_im_arr <= in_im_arr when rising_edge(clk);
  
  ---------------------------------------------------------------
  -- DUT = Device Under Test
  ---------------------------------------------------------------
  p_in_sosi_arr : process(ref_re_arr, ref_im_arr, ref_sosi_ctrl)
  begin
    for I in 0 to g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 loop
      -- DUT input
      -- in_sosi_arr(I)    <= ref_sosi_ctrl;
      in_sosi_arr(I).valid <='1';
      in_sosi_arr(I).re <= ref_re_arr(I);
      in_sosi_arr(I).im <= ref_im_arr(I);
    end loop;
  end process;

  u_dut : entity work.wbpfb_unit
  generic map (
    g_big_endian_wb_in  => c_big_endian_wb_in,
    g_wpfb              => g_wpfb,
    g_use_prefilter     => TRUE,
    g_coefs_file_prefix => c_coefs_memory_file_prefix
  )
  port map (
    rst                 => rst,
    clk                 => clk,
    ce                  => std_logic'('1'),
    shiftreg            => shiftreg,
    in_sosi_arr         => in_sosi_arr,
    ovflw               => ovflw,
    out_sosi_arr        => out_sosi_arr
  );
  
  p_out_sosi_arr : process(out_sosi_arr)
  begin
    for I in 0 to g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 loop
      out_re_arr(I) <= out_sosi_arr(I).re;
      out_im_arr(I) <= out_sosi_arr(I).im;
    end loop;
  end process;
  out_val <= out_sosi_arr(0).valid;
  
  -- Data valid count
  in_val_cnt  <= in_val_cnt+1  when rising_edge(clk) and in_val='1'  else in_val_cnt;
  out_val_cnt <= out_val_cnt+1 when rising_edge(clk) and out_val='1' else out_val_cnt;

  -- Block count blocks for c_nof_channels>=1 channels per block
  in_blk_val  <= '1' when in_val='1'  and (in_val_cnt  mod c_nof_channels)=0 else '0';
  in_blk_val_cnt  <= in_val_cnt/c_nof_channels;

  -- Block count time axis
  in_blk_time <= in_blk_val_cnt / (g_wpfb.nof_points/g_wpfb.wb_factor);                       

  -- Verify nof valid counts
  p_verify_out_val_cnt : process
  begin
    -- Wait until tb_end_almost
    proc_common_wait_until_high(clk, tb_end_almost);
    assert in_val_cnt > 0 report "Test did not run, no valid input data"  severity error;
    -- The WPFB has a memory of 2 block, independent of use_reorder and use_separate, but without the
    -- reorder buffer it outputs 1 sample more, because that is immediately available in a new block.
    -- Ensure g_data_file_nof_lines is multiple of g_wpfb.nof_points.
    if g_wpfb.use_reorder=true then
      assert out_val_cnt = in_val_cnt-2*c_nof_valid_per_block                report "Unexpected number of valid output data" severity error;
    else
      assert out_val_cnt = in_val_cnt-2*c_nof_valid_per_block+c_nof_channels report "Unexpected number of valid output data" severity error;
    end if;
    wait;
  end process;
  
  ---------------------------------------------------------------
  -- DATA OUTPUT CONTROL IN SCLK DOMAIN
  ---------------------------------------------------------------
  out_cnt <= out_cnt + 1 when rising_edge(sclk) and out_val_c='1' else out_cnt;

  out_blk_time <= (out_cnt / c_nof_channels) / g_wpfb.nof_points;
    
  proc_fft_out_control(g_wpfb.wb_factor, g_wpfb.nof_points, c_nof_channels, g_wpfb.use_reorder, g_wpfb.use_fft_shift, g_wpfb.use_separate,
                       out_cnt, out_val_c, out_val_a, out_val_b, out_channel, out_bin, out_bin_cnt);
  
  -- clk diff to avoid combinatorial glitches when selecting the data with out_val_a,b,c
  reg_out_val_a    <= out_val_a    when rising_edge(sclk);
  reg_out_val_b    <= out_val_b    when rising_edge(sclk);
  reg_out_val_c    <= out_val_c    when rising_edge(sclk);
  reg_out_channel  <= out_channel  when rising_edge(sclk);
  reg_out_cnt      <= out_cnt      when rising_edge(sclk);
  reg_out_bin_cnt  <= out_bin_cnt  when rising_edge(sclk);
  reg_out_bin      <= out_bin      when rising_edge(sclk);
  reg_out_blk_time <= out_blk_time when rising_edge(sclk);
  
  out_re_a_scope <= out_re_scope when rising_edge(sclk) and out_val_a='1';
  out_im_a_scope <= out_im_scope when rising_edge(sclk) and out_val_a='1';
  out_re_b_scope <= out_re_scope when rising_edge(sclk) and out_val_b='1';
  out_im_b_scope <= out_im_scope when rising_edge(sclk) and out_val_b='1';
  out_re_c_scope <= out_re_scope when rising_edge(sclk) and out_val_c='1';
  out_im_c_scope <= out_im_scope when rising_edge(sclk) and out_val_c='1';

  exp_re_a_scope <= exp_output_data_a_re_arr(out_bin_cnt) when rising_edge(sclk) and out_val_a='1';
  exp_im_a_scope <= exp_output_data_a_im_arr(out_bin_cnt) when rising_edge(sclk) and out_val_a='1';
  exp_re_b_scope <= exp_output_data_b_re_arr(out_bin_cnt) when rising_edge(sclk) and out_val_b='1';
  exp_im_b_scope <= exp_output_data_b_im_arr(out_bin_cnt) when rising_edge(sclk) and out_val_b='1';  
  exp_re_c_scope <= exp_output_data_c_re_arr(out_bin_cnt) when rising_edge(sclk) and out_val_c='1';
  exp_im_c_scope <= exp_output_data_c_im_arr(out_bin_cnt) when rising_edge(sclk) and out_val_c='1';

  diff_re_a_scope <= exp_re_a_scope - out_re_a_scope;
  diff_im_a_scope <= exp_im_a_scope - out_im_a_scope;
  diff_re_b_scope <= exp_re_b_scope - out_re_b_scope;
  diff_im_b_scope <= exp_im_b_scope - out_im_b_scope;
  diff_re_c_scope <= exp_re_c_scope - out_re_c_scope;
  diff_im_c_scope <= exp_im_c_scope - out_im_c_scope;

  ---------------------------------------------------------------
  -- VERIFY OUTPUT DATA
  ---------------------------------------------------------------
  p_verify_output : process(sclk)
  begin
    -- verify at sclk rising edge to avoid void differences due to delta-cycle differences that can occur between combinatorial signals
    if rising_edge(sclk) then
      if not c_in_complex then
        if reg_out_channel=1 then
          --if reg_out_val_a='1' then
            assert out_re_a_scope = 0 report "Output data A real error in channel" severity error;
            assert out_im_a_scope = 0 report "Output data A imag error in channel" severity error;
          --end if;
          if reg_out_val_b='1' then
            assert out_re_b_scope = 0 report "Output data B real error in channel" severity error;
            assert out_im_b_scope = 0 report "Output data B imag error in channel" severity error;
          end if;
        else
          --if reg_out_val_a='1' then
            assert diff_re_a_scope >= -g_diff_margin and diff_re_a_scope <= g_diff_margin report "Output data A real error" severity error;
            assert diff_im_a_scope >= -g_diff_margin and diff_im_a_scope <= g_diff_margin report "Output data A imag error" severity error;
          --end if;
          if reg_out_val_b='1' then
            assert diff_re_b_scope >= -g_diff_margin and diff_re_b_scope <= g_diff_margin report "Output data B real error" severity error;
            assert diff_im_b_scope >= -g_diff_margin and diff_im_b_scope <= g_diff_margin report "Output data B imag error" severity error;
          end if;
        end if;
      else
        if reg_out_val_c='1' then
          if reg_out_channel=1 then
            assert out_re_c_scope = 0 report "Output data C real error in channel" severity error;
            assert out_im_c_scope = 0 report "Output data C imag error in channel" severity error;
          else
            assert diff_re_c_scope >= -g_diff_margin and diff_re_c_scope <= g_diff_margin report "Output data C real error" severity error;
            assert diff_im_c_scope >= -g_diff_margin and diff_im_c_scope <= g_diff_margin report "Output data C imag error" severity error;
          end if;
        end if;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------
  -- READ EXPECTED FILTER OUTPUT DATA FROM FILE
  ---------------------------------------------------------------
  p_exp_filter_data : process
  begin
    -- read filter data from file
    if c_in_complex then
      proc_common_read_integer_file(g_data_file_c, c_nof_lines_c_pfir_header, g_data_file_nof_lines, c_nof_complex, exp_filter_data_c_arr);
      wait for 1 ns;
      for I in 0 to g_data_file_nof_lines-1 loop
        exp_filter_data_c_re_arr(I) <= exp_filter_data_c_arr(2*I);
        exp_filter_data_c_im_arr(I) <= exp_filter_data_c_arr(2*I+1);
      end loop;
    else
      proc_common_read_integer_file(g_data_file_a, c_nof_lines_a_pfir_header, g_data_file_nof_lines, 1, exp_filter_data_a_arr);
      proc_common_read_integer_file(g_data_file_b, c_nof_lines_b_pfir_header, g_data_file_nof_lines, 1, exp_filter_data_b_arr);
      wait for 1 ns;
    end if;
    wait;
  end process;
  
  ---------------------------------------------------------------
  -- READ EXPECTED WPFB OUTPUT DATA FROM FILE
  ---------------------------------------------------------------
  p_expected_wpfb_output : process
  begin
    if c_in_complex then
      proc_common_read_integer_file(g_data_file_c, c_nof_lines_c_pfft_header, g_data_file_nof_lines, c_nof_complex, exp_output_data_c_arr);
      wait for 1 ns;
      for I in 0 to g_data_file_nof_lines-1 loop
        exp_output_data_c_re_arr(I) <= exp_output_data_c_arr(2*I);
        exp_output_data_c_im_arr(I) <= exp_output_data_c_arr(2*I+1);
      end loop;
    else
      proc_common_read_integer_file(g_data_file_a, c_nof_lines_a_pfft_header, g_data_file_nof_lines/c_nof_complex, c_nof_complex, exp_output_data_a_arr);
      proc_common_read_integer_file(g_data_file_b, c_nof_lines_b_pfft_header, g_data_file_nof_lines/c_nof_complex, c_nof_complex, exp_output_data_b_arr);
      wait for 1 ns;
      for I in 0 to g_data_file_nof_lines/c_nof_complex-1 loop
        exp_output_data_a_re_arr(I) <= exp_output_data_a_arr(2*I);
        exp_output_data_a_im_arr(I) <= exp_output_data_a_arr(2*I+1);
        exp_output_data_b_re_arr(I) <= exp_output_data_b_arr(2*I);
        exp_output_data_b_im_arr(I) <= exp_output_data_b_arr(2*I+1);
      end loop;
    end if;
    wait;
  end process;
  
  ---------------------------------------------------------------
  -- INPUT AND OUTPUT DATA SCOPES : ONLY FOR WB STREAM S = 0
  ---------------------------------------------------------------
  rewire_scope_data : for P in 0 to g_wpfb.wb_factor-1 generate
    in_re_data((P+1)*c_in_dat_w-1 downto P*c_in_dat_w) <= in_re_arr(P)(c_in_dat_w-1 downto 0);
    in_im_data((P+1)*c_in_dat_w-1 downto P*c_in_dat_w) <= in_im_arr(P)(c_in_dat_w-1 downto 0);
     
    out_re_data((P+1)*c_out_dat_w-1 downto P*c_out_dat_w) <= out_re_arr(P)(c_out_dat_w-1 downto 0);
    out_im_data((P+1)*c_out_dat_w-1 downto P*c_out_dat_w) <= out_im_arr(P)(c_out_dat_w-1 downto 0);
  end generate;

  u_in_re_scope : entity casper_sim_tools_lib.common_wideband_data_scope
  generic map (
    g_sim                 => TRUE,
    g_wideband_factor     => g_wpfb.wb_factor,  -- Wideband rate factor = 4 for dp_clk processing frequency is 200 MHz frequency and SCLK sample frequency Fs is 800 MHz
    g_wideband_big_endian => TRUE,              -- When true in_data[3:0] = sample[t0,t1,t2,t3], else when false : in_data[3:0] = sample[t3,t2,t1,t0]
    g_dat_w               => c_in_dat_w         -- Actual width of the data samples
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
    g_wideband_factor     => g_wpfb.wb_factor,  -- Wideband rate factor = 4 for dp_clk processing frequency is 200 MHz frequency and SCLK sample frequency Fs is 800 MHz
    g_wideband_big_endian => TRUE,              -- When true in_data[3:0] = sample[t0,t1,t2,t3], else when false : in_data[3:0] = sample[t3,t2,t1,t0]
    g_dat_w               => c_in_dat_w         -- Actual width of the data samples
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
    g_wideband_factor     => g_wpfb.wb_factor,  -- Wideband rate factor = 4 for dp_clk processing frequency is 200 MHz frequency and SCLK sample frequency Fs is 800 MHz
    g_wideband_big_endian => FALSE,             -- When true in_data[3:0] = sample[t0,t1,t2,t3], else when false : in_data[3:0] = sample[t3,t2,t1,t0]
    g_dat_w               => c_out_dat_w        -- Actual width of the data samples
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
    g_wideband_factor     => g_wpfb.wb_factor,  -- Wideband rate factor = 4 for dp_clk processing frequency is 200 MHz frequency and SCLK sample frequency Fs is 800 MHz
    g_wideband_big_endian => FALSE,             -- When true in_data[3:0] = sample[t0,t1,t2,t3], else when false : in_data[3:0] = sample[t3,t2,t1,t0]
    g_dat_w               => c_out_dat_w        -- Actual width of the data samples
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
