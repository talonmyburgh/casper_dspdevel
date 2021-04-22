-- Author: Harm Jan Pepping : HJP at astron.nl: April 2012
--------------------------------------------------------------------------------
--
-- Copyright (C) 2012
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
-- Purpose: Test bench for the Wideband Poly Phase Filter Bank
--
--
-- Usage:
--   > run -all
--   > testbench is selftesting. 
--
-- Remarks:
--         . The first c_nof_spectra_in_file(= 8) spectrums are verified.
--         . The statistics are verified, based on the raw output of the DUT. 
--         . Currently only the Noise file is tested.
--
--!!!NOTE!!! This testbench has become obsolete since the quantization of 
--           the FFT algorithm is changed. The testbench still works, but 
--           the goldenfiles are not valid anymore and therefor the test-
--           bench will report that the output contains errors. 
--           The tb_wpfb_unit testbench is replaced by the tb_mmf_wpfb_unit
--           testbench, which is a co-simulation between modelsim and python.  
--                 
--

library ieee, common_pkg_lib, dp_pkg_lib, astron_diagnostics_lib, astron_r2sdf_fft_lib, astron_wb_fft_lib, astron_filter_lib, astron_ram_lib, astron_mm_lib;
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
use astron_wb_fft_lib.tb_fft_pkg.all;
use astron_wb_fft_lib.fft_pkg.all;
use astron_filter_lib.fil_pkg.all;
use work.wpfb_pkg.all;

entity tb_wpfb_unit is
  generic(
    -- generics for tb
    g_use_uniNoise_file  : boolean  := true;  
    g_use_sinus_file     : boolean  := false;  
    g_use_sinNoise_file  : boolean  := false;  
    g_use_impulse_file   : boolean  := false;
    
    --  type t_wpfb is record  
    --  -- General parameters for the wideband poly phase filter
    --  wb_factor         : natural;        -- = default 4, wideband factor
    --  nof_points        : natural;        -- = 1024, N point FFT (Also the number of subbands for the filetr part)
    --  nof_chan          : natural;        -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan     
    --  nof_streams       : natural;        -- = 1, the number of parallel streams. The filter coefficients are shared on every stream. 
    --  
    --  -- Parameters for the poly phase filter
    --  nof_taps          : natural;        -- = 16, the number of FIR taps per subband
    --  fil_backoff_w     : natural;        -- = 0, number of bits for input backoff to avoid output overflow
    --  fil_in_dat_w      : natural;        -- = 8, number of input bits
    --  fil_out_dat_w     : natural;        -- = 16, number of output bits
    --  coef_dat_w        : natural;        -- = 16, data width of the FIR coefficients
    --                                    
    --  -- Parameters for the FFT         
    --  use_reorder       : boolean;        -- = false for bit-reversed output, true for normal output
    --  use_fft_shift     : boolean;        -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
    --  use_separate      : boolean;        -- = false for complex input, true for two real inputs
    --  fft_in_dat_w      : natural;        -- = 16, number of input bits
    --  fft_out_dat_w     : natural;        -- = 13, number of output bits
    --  fft_out_gain_w    : natural;        -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
    --  stage_dat_w       : natural;        -- = 18, number of bits that are used inter-stage
    --  guard_w           : natural;        -- = 2
    --  guard_enable      : boolean;        -- = true
    --
    --  -- Parameters for the statistics
    --  stat_data_w       : positive;       -- = 56
    --  stat_data_sz      : positive;       -- = 2
    --  nof_blk_per_sync  : natural;        -- = 800000, number of FFT output blocks per sync interval
    --
    --  -- Pipeline parameters for both poly phase filter and FFT. These are heritaged from the filter and fft libraries.  
    --  pft_pipeline      : t_fft_pipeline;     -- Pipeline settings for the pipelined FFT
    --  fft_pipeline      : t_fft_pipeline;     -- Pipeline settings for the parallel FFT
    --  fil_pipeline      : t_fil_ppf_pipeline; -- Pipeline settings for the filter units 
    --  
    --  end record;

    g_wpfb   : t_wpfb  := (4, 1024, 0, 1,                                        
                           16, 0, 8, 16, 16,                                  
                           true, false, true, 16, 16, 0, 18, 2, true, 56, 2, 10,
                           c_fft_pipeline, c_fft_pipeline, c_fil_ppf_pipeline);
    
    g_coefs_file_prefix : string            := "data/coefs_wide"      
    
  );
  
end entity tb_wpfb_unit;

architecture tb of tb_wpfb_unit is
  
  constant c_clk_period : time    := 100 ns;   
  
  constant c_fft        : t_fft   := (g_wpfb.use_reorder,
                                      g_wpfb.use_fft_shift,  
                                      g_wpfb.use_separate,  
                                      0,                                            
                                      g_wpfb.wb_factor,
                                      0,
                                      g_wpfb.nof_points, 
                                      g_wpfb.fft_in_dat_w, 
                                      g_wpfb.fft_out_dat_w,
                                      g_wpfb.fft_out_gain_w,
                                      g_wpfb.stage_dat_w,
                                      g_wpfb.guard_w,
                                      g_wpfb.guard_enable,
                                      g_wpfb.stat_data_w, 
                                      g_wpfb.stat_data_sz); 

  -- input/output data width
  constant c_in_dat_w   : natural := g_wpfb.fil_in_dat_w;   
  constant c_twiddle_w  : natural := 16;
  constant c_out_dat_w  : natural := g_wpfb.fft_out_dat_w; --   g_rtwo_fft.in_dat_w + natural((ceil_log2(g_rtwo_fft.nof_points))/2 + 2);  -- bit growth

  -- input/output files
  constant c_nof_spectra_in_file : natural := 8;
  constant c_file_len            : natural := c_nof_spectra_in_file*g_wpfb.nof_points;
  constant c_nof_spectra_to_output_file : natural := 8; 
  
  -- block generator  
  constant c_bg_mem_size           : natural := g_wpfb.nof_points/g_wpfb.wb_factor;
  constant c_bg_addr_w             : natural := ceil_log2(c_bg_mem_size);
  constant c_nof_samples_in_packet : natural := c_bg_mem_size;
  constant c_gap                   : natural := 0;    -- Gapsize is set to 0 in order to generate a continuous stream of packets. 
  constant c_nof_accum_per_sync    : natural := g_wpfb.nof_blk_per_sync;
  constant c_bsn_init              : natural := 32; 
  constant c_bg_prefix             : string  := "UNUSED";
  constant c_nof_sync_periods      : natural := 10; 
  constant c_bst_skip_nof_sync     : natural := 3;  
  
  constant c_nof_bands_per_chn     : natural := g_wpfb.nof_points/g_wpfb.wb_factor;
  constant c_normal                : boolean := true; 
  
  -- input from uniform noise file created automatically by MATLAB testFFT_input.m
  constant c_noiseInputFile    : string := "data/uniNoise_in.txt";
  constant c_noiseGoldenFile   : string := "data/uniNoise_p" & natural'image(g_wpfb.nof_points)& "_t"& natural'image(g_wpfb.nof_taps) & "_gold.txt";
  constant c_noiseOutputFile   : string := "data/uniNoise_out.txt";
  
  constant c_inputFile  : string := c_noiseInputFile;
                                    
  constant c_goldenFile : string := c_noiseGoldenFile;
                                    
  constant c_outputFile : string := c_noiseOutputFile;

  constant c_coefs_file_prefix : string := g_coefs_file_prefix & natural'image(g_wpfb.wb_factor) & "_p"& natural'image(g_wpfb.nof_points) & "_t"& natural'image(g_wpfb.nof_taps);

  -- signal definitions
  signal tb_end         : std_logic := '0';
  signal clk            : std_logic := '0';
  signal rst            : std_logic := '0';

  signal out_sync       : std_logic:= '0';
  signal out_val        : std_logic:= '0';
  signal out_re_arr     : t_fft_slv_arr(g_wpfb.wb_factor-1 downto 0);
  signal out_im_arr     : t_fft_slv_arr(g_wpfb.wb_factor-1 downto 0);

  signal in_file_data   : t_integer_matrix(0 to c_file_len-1, 1 to 2) := (others=>(others=>0));  -- [re, im]
  signal in_file_sync   : std_logic_vector(0 to c_file_len-1):= (others=>'0');
  signal in_file_val    : std_logic_vector(0 to c_file_len-1):= (others=>'0');

  signal gold_file_data : t_integer_matrix(0 to c_file_len-1, 1 to 2) := (others=>(others=>0));  -- [re, im]
  signal gold_file_sync : std_logic_vector(0 to c_file_len-1):= (others=>'0');
  signal gold_file_val  : std_logic_vector(0 to c_file_len-1):= (others=>'0');
  
  signal gold_sync      : std_logic;
  signal gold_re_arr    : t_integer_arr(g_wpfb.wb_factor-1 downto 0);
  signal gold_im_arr    : t_integer_arr(g_wpfb.wb_factor-1 downto 0);    
  
  signal init_waveforms_done   : std_logic;
  
  signal in_sosi_arr     : t_dp_sosi_arr(g_wpfb.wb_factor-1 downto 0);
  signal in_siso_arr     : t_dp_siso_arr(g_wpfb.wb_factor-1 downto 0);
  
  type   t_dp_sosi_matrix  is array (integer range <>) of t_dp_sosi_arr(0 downto 0);
  type   t_dp_siso_matrix  is array (integer range <>) of t_dp_siso_arr(0 downto 0);
  
  signal in_sosi_matrix  : t_dp_sosi_matrix(g_wpfb.wb_factor-1 downto 0);  
  signal in_siso_matrix  : t_dp_siso_matrix(g_wpfb.wb_factor-1 downto 0);  
  
  signal result_sosi_arr : t_dp_sosi_arr(g_wpfb.wb_factor-1 downto 0);
  
  signal ram_sst_mosi    : t_mem_mosi := c_mem_mosi_rst;
  signal ram_sst_miso    : t_mem_miso := c_mem_miso_rst; 

  signal ram_coefs_mosi  : t_mem_mosi := c_mem_mosi_rst;  
  signal ram_coefs_miso  : t_mem_miso := c_mem_miso_rst;  
  signal coefs_arr       : t_integer_arr (c_nof_bands_per_chn-1 downto 0); 
  
  signal ram_bg_data_mosi_arr : t_mem_mosi_arr(g_wpfb.wb_factor-1 downto 0) := (others => c_mem_mosi_rst );  
  signal reg_bg_ctrl_mosi     : t_mem_mosi; 
  
  signal reg_diag_bg_dut_mosi : t_mem_mosi := c_mem_mosi_rst; 
  signal reg_diag_bg_dut_miso : t_mem_miso := c_mem_miso_rst; 
                                                              
  signal ram_diag_bg_dut_mosi : t_mem_mosi := c_mem_mosi_rst; 
  signal ram_diag_bg_dut_miso : t_mem_miso := c_mem_miso_rst;  
  
  -- Subband Statistics output
  -- . DUT result
  signal result_sst_arr_temp   : t_slv_64_arr(c_nof_samples_in_packet-1 downto 0);
  signal result_sst_arr        : t_slv_64_arr(g_wpfb.nof_points-1 downto 0);
  -- . Expected result
  signal expected_sst_arr      : t_slv_64_arr(g_wpfb.nof_points-1 downto 0) := (others => (others => '0'));
  
  signal coefs_mem_write : boolean := FALSE;                             
  signal temp_reg        : integer;
  
begin

  clk <= (not clk) or tb_end after c_clk_period/2;
  rst <= '1', '0' after c_clk_period*7;
  
  ---------------------------------------------------------------
  -- WRITE AND READ THE COEFFICIENTS TO THE COEFS MEMORY
  ---------------------------------------------------------------  
  p_coefs_memory_write : process    
  begin
    coefs_mem_write <= FALSE;                           
    ram_coefs_mosi  <= c_mem_mosi_rst;             -- Reset the master out interface
    -- Write the coefficients
    for L in 0 to c_nof_complex loop               -- There are two filters in the DUT: real and imaginary
      for K in 0 to g_wpfb.wb_factor-1 loop
        for J in 0 to g_wpfb.nof_taps-1 loop
          proc_common_read_mif_file(c_coefs_file_prefix & "_" & integer'image(k*g_wpfb.nof_taps+J) & ".mif", coefs_arr); 
          wait for 1 ns; 
          for I in 0 to c_nof_bands_per_chn-1 loop 
            proc_mem_mm_bus_wr(L*g_wpfb.nof_points*g_wpfb.nof_taps + K*c_nof_bands_per_chn*g_wpfb.nof_taps + J*c_nof_bands_per_chn + I, coefs_arr(I), clk, ram_coefs_mosi); -- Write the coefficient to the memory       
          end loop;
        end loop; 
      end loop;
    end loop;                
    -- Read the coefficients back and verify
    for L in 0 to c_nof_complex loop               -- There are two filters in the DUT: real and imaginary
      for K in 0 to g_wpfb.wb_factor-1 loop
        for J in 0 to g_wpfb.nof_taps-1 loop
          proc_common_read_mif_file(c_coefs_file_prefix & "_" & integer'image(k*g_wpfb.nof_taps+J) & ".mif", coefs_arr); 
          wait for 1 ns; 
          for I in 0 to c_nof_bands_per_chn-1 loop 
            proc_mem_mm_bus_rd(L*g_wpfb.nof_points*g_wpfb.nof_taps + K*c_nof_bands_per_chn*g_wpfb.nof_taps + J*c_nof_bands_per_chn + I, clk, ram_coefs_miso, ram_coefs_mosi); -- Read the coefficient from the memory       
            temp_reg <= coefs_arr(I);
            if(ram_coefs_miso.rdval = '1') then 
              assert temp_reg = TO_UINT(ram_coefs_miso.rddata(g_wpfb.coef_dat_w-1 downto 0))  report "Read data from memory error" severity error;
            end if; 
          end loop;
          proc_common_wait_some_cycles(clk, 1); 
        end loop; 
      end loop;
    end loop;                
    
    coefs_mem_write <= TRUE;                           
    wait;
  end process;
 
  ---------------------------------------------------------------
  -- READ STIMULI DATA FROM INPUT FILE
  ---------------------------------------------------------------  
  proc_read_input_file(clk, in_file_data, c_inputFile); 
  
  ------------------------------------------------------------------------------
  -- WRITE THE WAVEFORMS INTO MEMORY FOR EACH INPUT STREAM.
  ------------------------------------------------------------------------------
  gen_init_waveforms : for I in 0 to g_wpfb.wb_factor-1 generate
    p_init_waveforms_memory : process
      variable v_mem_data : std_logic_vector(c_nof_complex*g_wpfb.fil_in_dat_w-1 downto 0);
    begin
      init_waveforms_done <= '0';
      
      proc_common_wait_until_low(clk, rst);      -- Wait until reset has finished
      proc_common_wait_some_cycles(clk, 10);     -- Wait an additional amount of cycles
      
      for J in 0 to c_bg_mem_size-1 loop
        v_mem_data := (others => '0');
        v_mem_data := TO_SVEC(in_file_data(I+J*g_wpfb.wb_factor, 2), g_wpfb.fil_in_dat_w) & TO_SVEC(in_file_data(I+J*g_wpfb.wb_factor, 1), g_wpfb.fil_in_dat_w); 
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
    wait until coefs_mem_write     = TRUE;      -- Wait until the coefficients are written. 
   
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
    proc_common_wait_some_cycles(clk, 4*g_wpfb.nof_points);
    tb_end <= '1';

    wait;    
  end process;

  ---------------------------------------------------------------  
  -- GENERATE BLOCK GENERATORS FOR STIMULI GENERATION
  ---------------------------------------------------------------  
  gen_block_gen : for I in 0 to g_wpfb.wb_factor-1 generate
    u_block_generator : entity astron_diagnostics_lib.mms_diag_block_gen 
    generic map(    
      g_nof_streams        => 1,
      g_buf_dat_w          => c_nof_complex*g_wpfb.fil_in_dat_w, 
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
  -- READ THE BEAMLET STATISTICS AND VERIFY  
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
      proc_common_wait_some_cycles(clk, c_nof_samples_in_packet+6);

      for I in 0 to g_wpfb.wb_factor-1 loop
        proc_fft_read_subband_statistics_memory(I, c_fft, clk, ram_sst_mosi, ram_sst_miso, result_sst_arr_temp);
        result_sst_arr((I+1)*c_nof_samples_in_packet-1 downto I*c_nof_samples_in_packet) <= result_sst_arr_temp;  -- can not use result_bst_arr2(I) directly as argument in proc_bf_read_beamlet_statistics_memory()
      end loop;
      
      proc_common_wait_some_cycles(clk, 10);
      
      assert expected_sst_arr  = result_sst_arr   report "Output statistics error"  severity error;
      assert expected_sst_arr /= result_sst_arr   report "Output statistics OK!!!!" severity note;

    end loop;
  end process;
  
  ---------------------------------------------------------------  
  -- DUT = Device Under Test
  ---------------------------------------------------------------  
  u_dut : entity work.wpfb_unit
  generic map (
    g_wpfb              => g_wpfb,
    g_use_bg            => FALSE,         
    g_coefs_file_prefix => c_coefs_file_prefix 
  )
  port map (
    dp_rst             => rst,
    dp_clk             => clk,
    mm_rst             => rst,
    mm_clk             => clk,  
    ram_fil_coefs_mosi => ram_coefs_mosi,
    ram_fil_coefs_miso => ram_coefs_miso,
    ram_st_sst_mosi    => ram_sst_mosi,
    ram_st_sst_miso    => ram_sst_miso, 
    reg_bg_ctrl_mosi   => reg_diag_bg_dut_mosi,
    reg_bg_ctrl_miso   => reg_diag_bg_dut_miso,
    ram_bg_data_mosi   => ram_diag_bg_dut_mosi,
    ram_bg_data_miso   => ram_diag_bg_dut_miso,
    in_sosi_arr        => in_sosi_arr,     
    out_sosi_arr       => result_sosi_arr
  );
  
  ---------------------------------------------------------------  
  -- REARRANGE THE OUTPUT-DATA FOR VERIFICATION
  ---------------------------------------------------------------  
  gen_extract_data : for I in 0 to g_wpfb.wb_factor-1 generate
    out_re_arr(I) <= RESIZE_SVEC(result_sosi_arr(I).re, out_re_arr(I)'length);
    out_im_arr(I) <= RESIZE_SVEC(result_sosi_arr(I).im, out_im_arr(I)'length);
  end generate;
  out_val <= result_sosi_arr(0).valid; 

  ---------------------------------------------------------------  
  -- READ GOLDEN FILE WITH THE EXPECTED DUT OUTPUT
  ---------------------------------------------------------------  
  proc_read_input_file(clk, gold_file_data, c_goldenFile);   

  ---------------------------------------------------------------  
  -- CALCULATE THE STATISTICS, BASED ON THE RAW OUTPUT DATA 
  -- OF THE DUT
  ---------------------------------------------------------------  
  p_calculate_stats_reference_array : process    
    constant c_sst_in_w       : natural := 18;
    variable v_nof_outs       : natural := g_wpfb.nof_points/g_wpfb.wb_factor;
    variable v_int_time       : integer := 0;   
    variable v_subband_cnt    : integer := 0;   

    variable v_sum_re         : std_logic_vector(c_sst_in_w-1 downto 0);  
    variable v_sum_im         : std_logic_vector(c_sst_in_w-1 downto 0);
    
    variable v_sum_pwr        : std_logic_vector(g_wpfb.stat_data_w-1 downto 0) := (others => '0');
    variable v_acc_pwr_arr    : t_slv_64_arr(g_wpfb.nof_points-1 downto 0) := (others => (others => '0'));
  begin
    wait until rising_edge(clk); 
    if(out_val = '1') then 
      for I in 0 to g_wpfb.wb_factor-1 loop
        -- Calculate the auto correlation power:
        v_sum_re := RESIZE_SVEC(SHIFT_SVEC(out_re_arr(I), g_wpfb.fft_out_dat_w-c_sst_in_w), v_sum_re'length);
        v_sum_im := RESIZE_SVEC(SHIFT_SVEC(out_im_arr(I), g_wpfb.fft_out_dat_w-c_sst_in_w), v_sum_im'length);
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
      else
        v_int_time := v_int_time + 1;
      end if;      
    end if;
    
  end process; 

  ---------------------------------------------------------------  
  -- CREATE THE GOLDEN ARRAY FOR VERIFICATION
  ---------------------------------------------------------------  
  p_create_golden_array : process    
    constant c_sst_in_w       : natural := 16;
    variable v_nof_outs       : natural := g_wpfb.nof_points/g_wpfb.wb_factor;
    variable v_bin_index      : natural := 0;
    variable v_spectrum_index : natural := 0;  
    variable v_list_index     : natural := 0;  
  begin
    wait until rising_edge(clk); 
    if(out_val = '1') then 
      if(v_spectrum_index = v_nof_outs - 1) then
        v_spectrum_index := 0; 
        v_bin_index := v_bin_index + g_wpfb.nof_points - v_nof_outs;
      else 
        v_spectrum_index := v_spectrum_index + 1;   
      end if;
      v_bin_index := v_bin_index + 1; 

      if(v_list_index = c_file_len/g_wpfb.wb_factor-1) then 
        v_bin_index    := 0; 
        v_list_index   := 0;
      else 
        v_list_index := v_list_index + 1;
      end if;    
      
    end if;
    
    for I in 0 to g_wpfb.wb_factor-1 loop
      gold_re_arr(I) <= gold_file_data(v_bin_index + I*v_nof_outs, 1);
      gold_im_arr(I) <= gold_file_data(v_bin_index + I*v_nof_outs, 2);
    end loop;  
    
    gold_sync  <= gold_file_sync(v_bin_index);  
                                    
  end process; 

  -- Verify the output of the DUT with the expected output from the golden reference file
  p_verify_output : process(clk)
    variable v_output_cnt : integer := 0;
  begin
    -- Compare
    if rising_edge(clk) then
      if (out_val='1' and v_output_cnt < (c_nof_spectra_in_file*g_wpfb.nof_points/g_wpfb.wb_factor)) then
        -- only write when out_val='1', because then the file is independent of cycles with invalid out_dat
        -- only check the first c_nof_spectra_in_file spectrums. 
        assert out_sync = gold_sync report "Output sync error"  severity error;
        for I in 0 to g_wpfb.wb_factor-1 loop
          assert TO_SINT(out_re_arr(I)) = gold_re_arr(I)   report "Output real data error" severity error;
          assert TO_SINT(out_im_arr(I)) = gold_im_arr(I)   report "Output imag data error" severity error;
        end loop;
        v_output_cnt := v_output_cnt + 1;
      end if;
    end if;
  end process;
  
  -- Write to default output file, this allows using command line diff or graphical diff viewer to compare it with the golden result file
  p_write_output_file : process(clk)
    file     v_output        : text open WRITE_MODE is c_outputFile;
    variable v_line          : line;
    constant c_nof_bins      : natural := g_wpfb.nof_points/g_wpfb.wb_factor;
    variable v_out_re_matrix : t_integer_matrix(g_wpfb.wb_factor-1 downto 0, c_nof_bins-1 downto 0); 
    variable v_out_im_matrix : t_integer_matrix(g_wpfb.wb_factor-1 downto 0, c_nof_bins-1 downto 0);     
    variable v_bin_cnt       : integer := 0;
    variable v_spectra_cnt   : integer := 0;
  begin
    if rising_edge(clk) then
      if out_val='1' then
        -- only write when out_val='1', because then the file is independent of cycles with invalid out_dat
        for I in 0 to g_wpfb.wb_factor-1 loop
          v_out_re_matrix(I, v_bin_cnt) := TO_SINT(out_re_arr(I));
          v_out_im_matrix(I, v_bin_cnt) := TO_SINT(out_im_arr(I)); 
        end loop;

        if(v_bin_cnt = c_nof_bins-1) then  
          if (v_spectra_cnt < c_nof_spectra_to_output_file) then 
            for K in 0 to g_wpfb.wb_factor-1 loop
              for L in 0 to c_nof_bins-1 loop
                write(v_line, v_out_re_matrix(K,L));
                write(v_line, string'(","));
                write(v_line, v_out_im_matrix(K,L));
                writeline(v_output, v_line);
              end loop;
            end loop;      
          end if; 
          v_spectra_cnt := v_spectra_cnt + 1;
          v_bin_cnt     := 0;
        else 
          v_bin_cnt := v_bin_cnt + 1;
        end if;
      end if;
    end if;
  end process;

end tb;
