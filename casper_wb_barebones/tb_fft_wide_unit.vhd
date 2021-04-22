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
-- Purpose: Test bench for the Wideband Complex radix 2 FFT
--
--
-- Usage:
--   > run -all
--   > testbench is selftesting. The first four spectrums are verified. 
--

library ieee, common_pkg_lib, dp_pkg_lib, astron_diagnostics_lib, astron_r2sdf_fft_lib, astron_ram_lib, astron_mm_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use common_pkg_lib.common_pkg.all;
use astron_ram_lib.common_ram_pkg.ALL;
use common_pkg_lib.common_lfsr_sequences_pkg.all;
use common_pkg_lib.tb_common_pkg.all;
use astron_mm_lib.tb_common_mem_pkg.ALL;
use dp_pkg_lib.dp_stream_pkg.ALL;
use astron_r2sdf_fft_lib.twiddlesPkg.all;
use astron_r2sdf_fft_lib.rTwoSDFPkg.all;
use work.tb_fft_pkg.all;
use work.fft_pkg.all;

entity tb_fft_wide_unit is
  generic(
    -- generics for tb
    g_use_uniNoise_file  : boolean  := true;  
    g_use_sinus_file     : boolean  := false;  
    g_use_sinNoise_file  : boolean  := false;  
    g_use_impulse_file   : boolean  := false;
    g_use_2xreal_inputs  : boolean  := false;  -- Set to true for running the two-real input variants  
    g_fft : t_fft := (true, false, false, 0, 4, 0, 1024, 16, 18, 0, 18, 2, true, 56, 2) 
    --  type t_rtwo_fft is record
    --    use_reorder    : boolean;  -- = false for bit-reversed output, true for normal output
    --    use_fft_shift  : boolean;  -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
    --    use_separate   : boolean;  -- = false for complex input, true for two real inputs
    --    nof_chan       : natural;  -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan         
    --    wb_factor      : natural;  -- = default 1, wideband factor
    --    twiddle_offset : natural;  -- = default 0, twiddle offset for PFT sections in a wideband FFT
    --    nof_points     : natural;  -- = 1024, N point FFT
    --    in_dat_w       : natural;  -- = 8, number of input bits
    --    out_dat_w      : natural;  -- = 13, number of output bits: in_dat_w + natural((ceil_log2(nof_points))/2 + 2)  
    --    out_gain_w     : natural;  -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
    --    stage_dat_w    : natural;  -- = 18, data width used between the stages(= DSP multiplier-width)
    --    guard_w        : natural;  -- = 2,  Guard used to avoid overflow in FFT stage. 
    --    guard_enable   : boolean;  -- = true when input needs guarding, false when input requires no guarding but scaling must be skipped at the last stage(s) (used in wb fft)
    --    stat_data_w    : positive; -- = 56
    --    stat_data_sz   : positive; -- = 2
    --  end record;
  );
end entity tb_fft_wide_unit;

architecture tb of tb_fft_wide_unit is
  
  constant c_clk_period : time    := 100 ns;

  -- input/output data width
  constant c_in_dat_w   : natural := g_fft.in_dat_w;   
  constant c_twiddle_w  : natural := 16;
  constant c_out_dat_w  : natural := g_fft.out_dat_w; --   g_rtwo_fft.in_dat_w + natural((ceil_log2(g_rtwo_fft.nof_points))/2 + 2);  -- bit growth

  -- input/output files
  constant c_nof_spectra_in_file : natural := 4;
  constant c_file_len            : natural := c_nof_spectra_in_file*g_fft.nof_points;
  
  -- block generator  
  constant c_bg_mem_size           : natural := c_nof_spectra_in_file*g_fft.nof_points/g_fft.wb_factor;
  constant c_bg_addr_w             : natural := ceil_log2(c_bg_mem_size);
  constant c_nof_samples_in_packet : natural := c_bg_mem_size/c_nof_spectra_in_file;
  constant c_gap                   : natural := 3;    -- Gapsize is set to 0 in order to generate a continuous stream of packets. 
  constant c_nof_accum_per_sync    : natural := 8;
  constant c_bsn_init              : natural := 32; 
  constant c_bg_prefix             : string  := "UNUSED";
  constant c_nof_sync_periods      : natural := 6; 
  constant c_bst_skip_nof_sync     : natural := 3;  
  
  constant c_normal                : BOOLEAN  := TRUE; 
  
      -- input from uniform noise file created automatically by MATLAB testFFT_input.m
  constant c_noiseInputFile    : string := "data/test/in/uniNoise_p"  & natural'image(g_fft.nof_points)& "_b"& natural'image(c_twiddle_w) &"_in.txt";
  constant c_noiseGoldenFile   : string := "data/test/out/uniNoise_p" & natural'image(g_fft.nof_points)& "_b"& natural'image(c_twiddle_w) &"_tb"&natural'image(wTyp'length) &"_out.txt";
  constant c_noiseOutputFile   : string := "data/test/out/uniNoise_out.txt";
  
  -- input from sinus file. Data is from diag_wg_wideband. 
  constant c_sinusInputFile    : string := "data/test/in/sinus_p"     & natural'image(g_fft.nof_points)& "_b"& natural'image(g_fft.in_dat_w) &"_in.txt";
  constant c_sinusGoldenFile   : string := "data/test/out/sinus_p"    & natural'image(g_fft.nof_points)& "_b"& natural'image(g_fft.in_dat_w) &"_tb"&natural'image(wTyp'length) &"_out.txt";
  constant c_sinusOutputFile   : string := "data/test/out/sinus_out.txt";

  -- input from combined sinus with noise file. Real part is sinus, imaginary part is noise
  constant c_sinNoiseInputFile    : string := "data/test/in/sinNoise_p"     & natural'image(g_fft.nof_points)& "_b"& natural'image(g_fft.in_dat_w) &"_in.txt";
  constant c_sinNoiseGoldenFile   : string := "data/test/out/sinNoise_p"    & natural'image(g_fft.nof_points)& "_b"& natural'image(g_fft.in_dat_w) &"_tb"&natural'image(wTyp'length) &"_out.txt";
  constant c_sinNoiseOutputFile   : string := "data/test/out/sinNoise_out.txt";
  
  -- input from impulse files
  constant c_impulseInputFile  : string := "data/impulse_p"           & natural'image(g_fft.nof_points)& "_b"& natural'image(c_twiddle_w)& "_in.txt";
  constant c_impulseGoldenFile : string := "data/impulse_p"           & natural'image(g_fft.nof_points)& "_b"& natural'image(c_twiddle_w)& "_out.txt";
  constant c_impulseOutputFile : string := "data/impulse_out.txt";

  -- input from 2xreal impulse files
  constant c_2xrealImpulseInputFile   : string := "data/2xreal_impulse_p"    & natural'image(g_fft.nof_points)& "_b"& natural'image(c_twiddle_w)& "_in.txt";
  constant c_2xrealImpulseGoldenFile  : string := "data/2xreal_impulse_p"    & natural'image(g_fft.nof_points)& "_b"& natural'image(c_twiddle_w)& "_out.txt";
  constant c_2xrealImpulseOutputFile  : string := "data/2xreal_impulse_out.txt";
 
  constant c_2xrealNoiseGoldenFile    : string := "data/test/out/uniNoise_2xreal_p" & natural'image(g_fft.nof_points)& "_b"& natural'image(c_twiddle_w) &"_tb"&natural'image(wTyp'length) &"_out.txt";
  constant c_2xrealSinusGoldenFile    : string := "data/test/out/sinus_2xreal_p"    & natural'image(g_fft.nof_points)& "_b"& natural'image(g_fft.in_dat_w) &"_tb"&natural'image(wTyp'length) &"_out.txt";
  constant c_2xrealSinNoiseGoldenFile : string := "data/test/out/sinNoise_2xreal_p" & natural'image(g_fft.nof_points)& "_b"& natural'image(g_fft.in_dat_w) &"_tb"&natural'image(wTyp'length) &"_out.txt";

  -- determine active stimuli and result files
  constant c_preSelImpulseInputFile   : string := sel_a_b(g_use_2xreal_inputs, c_2xrealImpulseInputFile,   c_impulseInputFile); 
  constant c_preSelImpulseGoldenFile  : string := sel_a_b(g_use_2xreal_inputs, c_2xrealImpulseGoldenFile,  c_impulseGoldenFile); 
  constant c_preSelImpulseOutputFile  : string := sel_a_b(g_use_2xreal_inputs, c_2xrealImpulseOutputFile,  c_impulseOutputFile); 
  constant c_preSelNoiseGoldenFile    : string := sel_a_b(g_use_2xreal_inputs, c_2xrealNoiseGoldenFile,    c_noiseGoldenFile); 
  constant c_preSelSinusGoldenFile    : string := sel_a_b(g_use_2xreal_inputs, c_2xrealSinusGoldenFile,    c_sinusGoldenFile); 
  constant c_preSelSinNoiseGoldenFile : string := sel_a_b(g_use_2xreal_inputs, c_2xrealSinNoiseGoldenFile, c_sinNoiseGoldenFile); 
  
  constant c_inputFile  : string := sel_a_b(g_use_uniNoise_file, c_noiseInputFile,
                                    sel_a_b(g_use_sinus_file,    c_sinusInputFile,        
                                    sel_a_b(g_use_sinNoise_file, c_sinNoiseInputFile,        c_preSelImpulseInputFile)));
                                    
  constant c_goldenFile : string := sel_a_b(g_use_uniNoise_file, c_preSelNoiseGoldenFile,
                                    sel_a_b(g_use_sinus_file,    c_preSelSinusGoldenFile, 
                                    sel_a_b(g_use_sinNoise_file, c_preSelSinNoiseGoldenFile, c_preSelImpulseGoldenFile)));
                                    
  constant c_outputFile : string := sel_a_b(g_use_uniNoise_file, c_noiseOutputFile,
                                    sel_a_b(g_use_sinus_file,    c_sinusOutputFile,       
                                    sel_a_b(g_use_sinNoise_file, c_sinNoiseOutputFile,       c_preSelImpulseOutputFile)));

  -- signal definitions
  signal tb_end         : std_logic := '0';
  signal clk            : std_logic := '0';
  signal rst            : std_logic := '0';

  signal out_sync       : std_logic:= '0';
  signal out_val        : std_logic:= '0';
  signal out_re_arr     : t_fft_slv_arr(g_fft.wb_factor-1 downto 0);
  signal out_im_arr     : t_fft_slv_arr(g_fft.wb_factor-1 downto 0);

  signal in_file_data   : t_integer_matrix(0 to c_file_len-1, 1 to 2) := (others=>(others=>0));  -- [re, im]
  signal in_file_sync   : std_logic_vector(0 to c_file_len-1):= (others=>'0');
  signal in_file_val    : std_logic_vector(0 to c_file_len-1):= (others=>'0');

  signal gold_file_data : t_integer_matrix(0 to c_file_len-1, 1 to 2) := (others=>(others=>0));  -- [re, im]
  signal gold_file_sync : std_logic_vector(0 to c_file_len-1):= (others=>'0');
  signal gold_file_val  : std_logic_vector(0 to c_file_len-1):= (others=>'0');
  
  signal gold_sync      : std_logic;
  signal gold_re_arr    : t_integer_arr(g_fft.wb_factor-1 downto 0);
  signal gold_im_arr    : t_integer_arr(g_fft.wb_factor-1 downto 0);    
  
  signal init_waveforms_done   : std_logic;
  
  signal in_sosi_arr     : t_dp_sosi_arr(g_fft.wb_factor-1 downto 0);
  signal in_siso_arr     : t_dp_siso_arr(g_fft.wb_factor-1 downto 0);
  
  type   t_dp_sosi_matrix  is array (integer range <>) of t_dp_sosi_arr(0 downto 0);
  type   t_dp_siso_matrix  is array (integer range <>) of t_dp_siso_arr(0 downto 0);
  
  signal in_sosi_matrix  : t_dp_sosi_matrix(g_fft.wb_factor-1 downto 0);  
  signal in_siso_matrix  : t_dp_siso_matrix(g_fft.wb_factor-1 downto 0);  
  
  signal result_sosi_arr : t_dp_sosi_arr(g_fft.wb_factor-1 downto 0);
  
  signal ram_sst_mosi    : t_mem_mosi := c_mem_mosi_rst;
  signal ram_sst_miso    : t_mem_miso := c_mem_miso_rst; 
  
  signal ram_bg_data_mosi_arr : t_mem_mosi_arr(g_fft.wb_factor-1 downto 0) := (others => c_mem_mosi_rst );  
  signal reg_bg_ctrl_mosi : t_mem_mosi;  
  
  -- Subband Statistics output
  -- . DUT result
  signal result_sst_arr_temp   : t_slv_64_arr(c_nof_samples_in_packet-1 downto 0);
  signal result_sst_arr        : t_slv_64_arr(g_fft.nof_points-1 downto 0);
  -- . Expected result
  signal expected_sst_arr      : t_slv_64_arr(g_fft.nof_points-1 downto 0) := (others => (others => '0'));
  
begin

  clk <= (not clk) or tb_end after c_clk_period/2;
  rst <= '1', '0' after c_clk_period*7;

  ---------------------------------------------------------------
  -- READ STIMULI DATA FROM INPUT FILE
  ---------------------------------------------------------------  
  proc_read_input_file(clk, in_file_data, in_file_sync, in_file_val, c_inputFile); 
  
  ------------------------------------------------------------------------------
  -- WRITE THE WAVEFORMS INTO MEMORY FOR EACH INPUT STREAM.
  ------------------------------------------------------------------------------
  gen_init_waveforms : for I in 0 to g_fft.wb_factor-1 generate
    p_init_waveforms_memory : process
      variable v_mem_data : std_logic_vector(c_nof_complex*g_fft.in_dat_w-1 downto 0);
    begin
      init_waveforms_done <= '0';
      
      proc_common_wait_until_low(clk, rst);      -- Wait until reset has finished
      proc_common_wait_some_cycles(clk, 10);     -- Wait an additional amount of cycles
      
      for J in 0 to c_bg_mem_size-1 loop
        v_mem_data := (others => '0');
        v_mem_data := TO_SVEC(in_file_data(I+J*g_fft.wb_factor, 2), g_fft.in_dat_w) & TO_SVEC(in_file_data(I+J*g_fft.wb_factor, 1), g_fft.in_dat_w);  -- two k_bf.in_dat_w = 16 fits in c_word_w = 32 bit
        proc_mem_mm_bus_wr(J, v_mem_data, clk, ram_bg_data_mosi_arr(I));
      end loop;
    
      init_waveforms_done <= '1';
      wait;
    end process;    
  end generate;

  ------------------------------------------------------------------------------
  -- CONFIGURE AND ENABLE THE BLOCK GENERATORS (Start Stimuli)
  ------------------------------------------------------------------------------
  p_control_input_stream : process
  begin   
    reg_bg_ctrl_mosi <= c_mem_mosi_rst;  

    -- Wait until reset is done
    proc_common_wait_until_high(clk, rst);
    proc_common_wait_some_cycles(clk, 10);
    wait until init_waveforms_done = '1';       -- Wait until the waveform data is written. 
   
    -- Set and enable the waveform generators. All generators are controlled by the same registers
    proc_mem_mm_bus_wr(1, c_nof_samples_in_packet, clk, reg_bg_ctrl_mosi);  -- Set the number of samples per block
    proc_mem_mm_bus_wr(2, c_nof_accum_per_sync,    clk, reg_bg_ctrl_mosi);  -- Set the number of blocks per sync
    proc_mem_mm_bus_wr(3, c_gap,                   clk, reg_bg_ctrl_mosi);  -- Set the gapsize
    proc_mem_mm_bus_wr(4, 0,                       clk, reg_bg_ctrl_mosi);  -- Set the start address of the memory
    proc_mem_mm_bus_wr(5, c_bg_mem_size-1,         clk, reg_bg_ctrl_mosi);  -- Set the end address of the memory
    proc_mem_mm_bus_wr(6, c_bsn_init,              clk, reg_bg_ctrl_mosi);  -- Set the BSNInit low  value
    proc_mem_mm_bus_wr(7, 0,                       clk, reg_bg_ctrl_mosi);  -- Set the BSNInit high value
    proc_mem_mm_bus_wr(0, 1,                       clk, reg_bg_ctrl_mosi);  -- Enable the BG
    
    -- Run time is defined by:
    --   * the number of sync periods
    --   * the number of packets in a sync period (c_nof_accum_per_sync)
    --   * the number of samples in a packet
    --   * the gap size
    proc_common_wait_some_cycles(clk, c_nof_sync_periods*c_nof_accum_per_sync*(c_nof_samples_in_packet+c_gap));
    
    -- Disable the BG
    proc_mem_mm_bus_wr(0, 0, clk, reg_bg_ctrl_mosi);              
    
    -- Wait some additional time in order to let release the pipline stages of the FFT. 
    proc_common_wait_some_cycles(clk, 4*g_fft.nof_points);
    tb_end <= '1';

    wait;    
  end process;

  ---------------------------------------------------------------  
  -- GENERATE BLOCK GENERATORS FOR STIMULI GENERATION
  ---------------------------------------------------------------  
  gen_block_gen : for I in 0 to g_fft.wb_factor-1 generate
    u_block_generator : entity astron_diagnostics_lib.mms_diag_block_gen 
    generic map(    
      g_nof_streams        => 1,
      g_buf_dat_w          => c_nof_complex*g_fft.in_dat_w, 
      g_buf_addr_w         => c_bg_addr_w,  
      g_file_name_prefix   => c_bg_prefix
    )
    port map(
     -- Clocks and Reset
      mm_rst           => rst, 
      mm_clk           => clk, 
      dp_rst           => rst, 
      dp_clk           => clk,
      en_sync          => '1',
      ram_bg_data_mosi => ram_bg_data_mosi_arr(I), 
      ram_bg_data_miso => open, 
      reg_bg_ctrl_mosi => reg_bg_ctrl_mosi, 
      reg_bg_ctrl_miso => open, 
      out_siso_arr     => in_siso_matrix(I),
      out_sosi_arr     => in_sosi_matrix(I)
    ); 
    in_sosi_arr(I)       <= in_sosi_matrix(I)(0);
    in_siso_matrix(I)(0) <= c_dp_siso_rdy;
  end generate;
  
  ------------------------------------------------------------------------------  
  -- READ THE BEAMLET STATISTICS     
  ------------------------------------------------------------------------------
  -- Read statistics from the memory interface once every sync interval.
  p_read_sst_memory : process
    variable c_sync_cnt : natural;
  begin
    proc_common_wait_until_low(clk, rst);    -- Wait until reset has finished
    
    -- Skip reading for the initial syncs to save simulation time
    for J in 0 to c_bst_skip_nof_sync-2 loop
      wait until result_sosi_arr(0).sync = '1';
      wait until result_sosi_arr(0).sync = '0';
    end loop;
    
    while(true) loop
      wait until result_sosi_arr(0).sync = '1';
      proc_common_wait_some_cycles(clk, c_nof_samples_in_packet+10);

      for I in 0 to g_fft.wb_factor-1 loop
        proc_fft_read_subband_statistics_memory(I, g_fft, clk, ram_sst_mosi, ram_sst_miso, result_sst_arr_temp);
        result_sst_arr((I+1)*c_nof_samples_in_packet-1 downto I*c_nof_samples_in_packet) <= result_sst_arr_temp;  -- can not use result_bst_arr2(I) directly as argument in proc_bf_read_beamlet_statistics_memory()
      end loop;
    end loop;
  end process;
  
  ---------------------------------------------------------------  
  -- DUT = Device Under Test
  ---------------------------------------------------------------  
  u_dut : entity work.fft_wide_unit
  generic map (
    g_fft          => g_fft
  )
  port map (
    dp_rst          => rst,
    dp_clk          => clk,
    mm_rst          => rst,
    mm_clk          => clk,
    ram_st_sst_mosi => ram_sst_mosi,
    ram_st_sst_miso => ram_sst_miso, 
    in_sosi_arr     => in_sosi_arr,     
    out_sosi_arr    => result_sosi_arr
  );  
  ---------------------------------------------------------------  
  -- REARRANGE THE OUTPUT-DATA FOR VERIFICATION
  ---------------------------------------------------------------  
  gen_extract_data : for I in 0 to g_fft.wb_factor-1 generate
    out_re_arr(I) <= RESIZE_SVEC(result_sosi_arr(I).re, out_re_arr(I)'length);
    out_im_arr(I) <= RESIZE_SVEC(result_sosi_arr(I).im, out_im_arr(I)'length);
  end generate;
  out_val <= result_sosi_arr(0).valid; 

  ---------------------------------------------------------------  
  -- READ GOLDEN FILE WITH THE EXPECTED DUT OUTPUT
  ---------------------------------------------------------------  
  proc_read_input_file(clk, gold_file_data, gold_file_sync, gold_file_val, c_goldenFile);   

  ---------------------------------------------------------------  
  -- CREATE THE GOLDEN ARRAY FOR VERIFICATION
  ---------------------------------------------------------------  
  p_create_golden_array : process    
    constant c_sst_in_w       : natural := 16;
    variable v_nof_outs       : natural := g_fft.nof_points/g_fft.wb_factor;
    variable v_bin_index      : natural := 0;
    variable v_spectrum_index : natural := 0;  
    variable v_list_index     : natural := 0;  
    variable v_int_time       : integer := 0;   
    variable v_subband_cnt    : integer := 0;   

    variable v_sum_re         : std_logic_vector(c_sst_in_w-1 downto 0);  
    variable v_sum_im         : std_logic_vector(c_sst_in_w-1 downto 0);
    
    variable v_sum_pwr        : std_logic_vector(g_fft.stat_data_w-1 downto 0) := (others => '0');
    variable v_acc_pwr_arr    : t_slv_64_arr(g_fft.nof_points-1 downto 0) := (others => (others => '0'));
  begin
    wait until rising_edge(clk); 
    if(out_val = '1') then 
      if(v_spectrum_index = v_nof_outs - 1) then
        v_spectrum_index := 0; 
        v_bin_index := v_bin_index + g_fft.nof_points - v_nof_outs;
      else 
        v_spectrum_index := v_spectrum_index + 1;   
      end if;
      v_bin_index := v_bin_index + 1; 

      if(v_list_index = c_file_len/g_fft.wb_factor-1) then 
        v_bin_index    := 0; 
        v_list_index   := 0;
      else 
        v_list_index := v_list_index + 1;
      end if;    
      
      for I in 0 to g_fft.wb_factor-1 loop
        -- Calculate the auto correlation power:
        v_sum_re := RESIZE_SVEC(TO_SVEC(gold_re_arr(I), c_word_w), v_sum_re'length);
        v_sum_im := RESIZE_SVEC(TO_SVEC(gold_im_arr(I), c_word_w), v_sum_im'length);
        v_sum_pwr(32 downto 0) := func_complex_multiply(v_sum_re, v_sum_im, v_sum_re, v_sum_im, c_normal, "RE", 33); 
        v_acc_pwr_arr(I*v_nof_outs + v_subband_cnt) := ADD_UVEC(v_acc_pwr_arr(I*v_nof_outs + v_subband_cnt), v_sum_pwr);
      end loop;           
      
      if(v_subband_cnt = v_nof_outs-1) then 
        v_subband_cnt := 0;
      else 
        v_subband_cnt := v_subband_cnt + 1;
      end if;
      
      ------------------------------------------------------------------------
      -- Latch the expected accumulated statistics to the output at the sync
      ------------------------------------------------------------------------
      if(v_int_time = c_nof_accum_per_sync*v_nof_outs-1) then 
        v_int_time := 0;
        -- Output the expected BST array
        expected_sst_arr <= v_acc_pwr_arr;
        v_acc_pwr_arr    :=(others => (others => '0')); 
        assert expected_sst_arr = result_sst_arr   report "Output statistics error" severity error;
        assert expected_sst_arr /= result_sst_arr   report "Output statistics OK!!!!" severity note;
      else
        v_int_time := v_int_time + 1;
      end if;      
    end if;
    
    for I in 0 to g_fft.wb_factor-1 loop
      gold_re_arr(I) <= gold_file_data(v_bin_index + I*v_nof_outs, 1);
      gold_im_arr(I) <= gold_file_data(v_bin_index + I*v_nof_outs, 2);
    end loop;  
    
    gold_sync  <= gold_file_sync(v_bin_index);  
                                    
  end process; 

  -- Verify the output of the DUT with the expected output from the golden reference file
  p_verify_output : process(clk)
  begin
    -- Compare
    if rising_edge(clk) then
      if out_val='1' then
        -- only write when out_val='1', because then the file is independent of cycles with invalid out_dat
        assert out_sync = gold_sync report "Output sync error"  severity error;
        for I in 0 to g_fft.wb_factor-1 loop
          assert TO_SINT(out_re_arr(I)) = gold_re_arr(I)   report "Output real data error" severity error;
          assert TO_SINT(out_im_arr(I)) = gold_im_arr(I)   report "Output imag data error" severity error;
        end loop;
      end if;
    end if;
  end process;

end tb;
