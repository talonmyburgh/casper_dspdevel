
-------------------------------------------------------------------------------
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
-------------------------------------------------------------------------------
--
-- Purpose: Test bench for the wideband poly phase filterbank.
--
--          The testbech uses blockgenerators to generate data for 
--          every input of the wideband poly phase filterbank. 
--          The output of the WPFB is stored in databuffers. 
--          Both the block generators and databuffers are controlled
--          via a mm interface. 
--          Use this testbench in conjunction with: 
--
--          ../python/tc_mmf_wpfb_unit.py
--          For verifying the complete wideband polyphase filter bank: g_use_bg = FALSE
--
--          ../python/tc_mmf_wpfb_unit_functional.py
--          For verifying the different wide- and narrowband configurationss
--          of the wpfb_unit. 
--
-- (Automated) Usage: 
--   > Be sure that the c_start_modelsim variable is set to 1 in the script. 
--   > Run python script in separate terminal: "python tc_mmf_wpfb_unit.py --unb 0 --bn 0 --sim"
--          
-- (Manual) Usage:
--   > run -all
--   > Be sure that the c_start_modelsim variable is set to 0 in the script. 
--   > Run python script in separate terminal: "python tc_mmf_wpfb_unit.py --unb 0 --bn 0 --sim"
--   > Check the results of the python script. 
--   > Stop the simulation manually in Modelsim by pressing the stop-button. 
--   > For fractional frequencies set g_nof_blocks=32 to be able to simulate a sufficent number of periods without transition.


LIBRARY IEEE, common_pkg_lib, astron_mm_lib, astron_diagnostics_lib, dp_pkg_lib, astron_r2sdf_fft_lib, astron_wb_fft_lib, astron_filter_lib, astron_ram_lib, astron_sim_tools_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE IEEE.math_real.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE astron_ram_lib.common_ram_pkg.ALL;
USE common_pkg_lib.common_str_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;
USE astron_mm_lib.tb_common_mem_pkg.ALL;
USE astron_mm_lib.mm_file_unb_pkg.ALL;
USE astron_mm_lib.mm_file_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL; 
USE astron_diagnostics_lib.diag_pkg.ALL; 
USE astron_r2sdf_fft_lib.twiddlesPkg.all;
USE astron_r2sdf_fft_lib.rTwoSDFPkg.all;
USE astron_wb_fft_lib.tb_fft_pkg.all;
USE astron_wb_fft_lib.fft_pkg.all;
USE astron_filter_lib.fil_pkg.all;
USE work.wpfb_pkg.all;


ENTITY tb_wpfb_unit_dev IS 
  GENERIC(  
    g_wb_factor         : NATURAL := 1;      -- = default 1, wideband factor
    g_nof_wb_streams    : NATURAL := 1;      -- = 1, the number of parallel wideband streams. The filter coefficients are shared on every wb-stream.                      
    g_nof_chan          : NATURAL := 0;      -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan         
    g_nof_points        : NATURAL := 64;     -- = 1024, N point FFT
    g_nof_taps          : NATURAL := 8;      -- = 8 nof taps n the filter
    g_nof_blocks        : NATURAL := 4;      -- = 4, the number of blocks of g_nof_points each in the BG waveform (must be power of 2 due to that BG c_bg_block_len must be power of 2)
    g_in_dat_w          : NATURAL := 8;      -- = 8, number of input bits                                                       
    g_out_dat_w         : NATURAL := 16;     -- = 14, number of output bits: in_dat_w + natural((ceil_log2(nof_points))/2) 
    g_use_prefilter     : BOOLEAN := FALSE; --TRUE;
    g_use_separate      : BOOLEAN := FALSE;   -- = false for complex input, true for two real inputs
    g_use_bg            : BOOLEAN := FALSE;
    g_coefs_file_prefix : STRING  := "hex/chan_fil_coefs_wide"      
  );
END tb_wpfb_unit_dev;

ARCHITECTURE tb OF tb_wpfb_unit_dev IS

    CONSTANT c_wpfb : t_wpfb  := (g_wb_factor, g_nof_points, g_nof_chan, g_nof_wb_streams,
                                  g_nof_taps, 0, g_in_dat_w, 16, 16,
                                  true, false, g_use_separate, 16, g_out_dat_w, 0, 18, 2, true, 56, 2, 20,
                                  c_fft_pipeline, c_fft_pipeline, c_fil_ppf_pipeline);

    --  type t_wpfb is record  
    --  -- General parameters for the wideband poly phase filter
    --  wb_factor         : natural;        -- = default 4, wideband factor
    --  nof_points        : natural;        -- = 1024, N point FFT (Also the number of subbands for the filetr part)
    --  nof_chan          : natural;        -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan     
    --  nof_wb_streams    : natural;        -- = 1, the number of parallel wideband streams. The filter coefficients are shared on every stream.                      
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

  ----------------------------------------------------------------------------
  -- Clocks and resets
  ----------------------------------------------------------------------------   
  CONSTANT c_mm_clk_period         : TIME := 100 ps;
  CONSTANT c_dp_clk_period         : TIME := 5 ns;
  CONSTANT c_sclk_period           : TIME := c_dp_clk_period / c_wpfb.wb_factor;
  CONSTANT c_dp_pps_period         : NATURAL := 64;
                                  
  SIGNAL dp_pps                    : STD_LOGIC;
                                  
  SIGNAL mm_rst                    : STD_LOGIC;
  SIGNAL mm_clk                    : STD_LOGIC := '0';
                                  
  SIGNAL dp_rst                    : STD_LOGIC;
  SIGNAL dp_clk                    : STD_LOGIC := '0';

  SIGNAL SCLK                      : STD_LOGIC := '0';
  
  ----------------------------------------------------------------------------
  -- MM buses
  ----------------------------------------------------------------------------                                         
  SIGNAL reg_diag_bg_mosi          : t_mem_mosi;
  SIGNAL reg_diag_bg_miso          : t_mem_miso;
                                
  SIGNAL ram_diag_bg_mosi          : t_mem_mosi;
  SIGNAL ram_diag_bg_miso          : t_mem_miso;
                                
  SIGNAL ram_diag_data_buf_re_mosi : t_mem_mosi;
  SIGNAL ram_diag_data_buf_re_miso : t_mem_miso;
  
  SIGNAL reg_diag_data_buf_re_mosi : t_mem_mosi;
  SIGNAL reg_diag_data_buf_re_miso : t_mem_miso;

  SIGNAL ram_diag_data_buf_im_mosi : t_mem_mosi;
  SIGNAL ram_diag_data_buf_im_miso : t_mem_miso;

  SIGNAL reg_diag_data_buf_im_mosi : t_mem_mosi;
  SIGNAL reg_diag_data_buf_im_miso : t_mem_miso;
 
  SIGNAL ram_st_sst_mosi           : t_mem_mosi := c_mem_mosi_rst;
  SIGNAL ram_st_sst_miso           : t_mem_miso := c_mem_miso_rst; 
                                   
  SIGNAL ram_fil_coefs_mosi        : t_mem_mosi := c_mem_mosi_rst;  
  SIGNAL ram_fil_coefs_miso        : t_mem_miso := c_mem_miso_rst;  
  
  SIGNAL reg_diag_bg_pfb_mosi      : t_mem_mosi := c_mem_mosi_rst; 
  SIGNAL reg_diag_bg_pfb_miso      : t_mem_miso := c_mem_miso_rst; 
                                
  SIGNAL ram_diag_bg_pfb_mosi      : t_mem_mosi := c_mem_mosi_rst; 
  SIGNAL ram_diag_bg_pfb_miso      : t_mem_miso := c_mem_miso_rst; 
  
  CONSTANT c_coefs_file_prefix      : STRING  := g_coefs_file_prefix & NATURAL'IMAGE(c_wpfb.wb_factor) & "_p"& NATURAL'IMAGE(c_wpfb.nof_points) & "_t"& NATURAL'IMAGE(c_wpfb.nof_taps);
  
  CONSTANT c_nof_streams            : POSITIVE := c_wpfb.nof_wb_streams*c_wpfb.wb_factor;
  CONSTANT c_nof_channels           : NATURAL  := 2**c_wpfb.nof_chan;
  CONSTANT c_bg_block_len           : NATURAL  := c_wpfb.nof_points*g_nof_blocks*c_nof_channels/c_wpfb.wb_factor;
  
  CONSTANT c_bg_buf_adr_w           : NATURAL := ceil_log2(c_bg_block_len);                  
  CONSTANT c_bg_data_file_index_arr : t_nat_natural_arr := array_init(0, c_nof_streams, 1);
  CONSTANT c_bg_data_file_prefix    : STRING := "UNUSED";                                    
    
  SIGNAL bg_siso_arr                : t_dp_siso_arr(c_nof_streams-1 DOWNTO 0) := (OTHERS=>c_dp_siso_rdy);
  SIGNAL bg_sosi_arr                : t_dp_sosi_arr(c_nof_streams-1 DOWNTO 0);
  SIGNAL out_sosi_arr               : t_dp_sosi_arr(c_nof_streams-1 DOWNTO 0);
  
  SIGNAL scope_in_sosi              : t_dp_sosi_integer_arr(c_wpfb.nof_wb_streams-1 DOWNTO 0);
  SIGNAL scope_out_sosi             : t_dp_sosi_integer_arr(c_wpfb.nof_wb_streams-1 DOWNTO 0);
  SIGNAL scope_out_power            : REAL := 0.0;
  SIGNAL scope_out_ampl             : REAL := 0.0;
  SIGNAL scope_out_index            : NATURAL;
  SIGNAL scope_out_bin              : NATURAL;
  SIGNAL scope_out_band             : NATURAL;
  SIGNAL scope_out_ampl_x           : REAL := 0.0;
  SIGNAL scope_out_ampl_y           : REAL := 0.0;
  
BEGIN

  ----------------------------------------------------------------------------
  -- Clock and reset generation
  ----------------------------------------------------------------------------
  mm_clk <= NOT mm_clk AFTER c_mm_clk_period/2;
  mm_rst <= '1', '0' AFTER c_mm_clk_period*5;

  dp_clk <= NOT dp_clk AFTER c_dp_clk_period/2;
  dp_rst <= '1', '0' AFTER c_dp_clk_period*5;

  SCLK   <= NOT SCLK AFTER c_sclk_period/2;
  
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
  
  u_mm_file_ram_diag_data_buf_re : mm_file GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "RAM_DIAG_DATA_BUFFER_REAL")
                                           PORT MAP(mm_rst, mm_clk, ram_diag_data_buf_re_mosi, ram_diag_data_buf_re_miso);

  u_mm_file_reg_diag_data_buf_re : mm_file GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "REG_DIAG_DATA_BUFFER_REAL")     
                                           PORT MAP(mm_rst, mm_clk, reg_diag_data_buf_re_mosi, reg_diag_data_buf_re_miso);
                                           
  u_mm_file_ram_diag_data_buf_im : mm_file GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "RAM_DIAG_DATA_BUFFER_IMAG")
                                           PORT MAP(mm_rst, mm_clk, ram_diag_data_buf_im_mosi, ram_diag_data_buf_im_miso);

  u_mm_file_reg_diag_data_buf_im : mm_file GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "REG_DIAG_DATA_BUFFER_IMAG")                                                
                                           PORT MAP(mm_rst, mm_clk, reg_diag_data_buf_im_mosi, reg_diag_data_buf_im_miso);                                           

  u_mm_file_ram_fil_coefs        : mm_file GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "RAM_FIL_COEFS")
                                           PORT MAP(mm_rst, mm_clk, ram_fil_coefs_mosi, ram_fil_coefs_miso);

  u_mm_file_ram_st_sst           : mm_file GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "RAM_ST_SST")
                                           PORT MAP(mm_rst, mm_clk, ram_st_sst_mosi, ram_st_sst_miso);

  u_mm_file_reg_diag_pfb_bg      : mm_file GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "REG_DIAG_BG_PFB")
                                           PORT MAP(mm_rst, mm_clk, reg_diag_bg_pfb_mosi, reg_diag_bg_pfb_miso);

  u_mm_file_ram_diag_pfb_bg      : mm_file GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "RAM_DIAG_BG_PFB")
                                           PORT MAP(mm_rst, mm_clk, ram_diag_bg_pfb_mosi, ram_diag_bg_pfb_miso);

  ----------------------------------------------------------------------------
  -- Source: block generator
  ---------------------------------------------------------------------------- 
  u_bg : ENTITY astron_diagnostics_lib.mms_diag_block_gen
  GENERIC MAP(
    g_nof_streams        => c_nof_streams,
    g_buf_dat_w          => c_nof_complex*c_wpfb.fil_in_dat_w,
    g_buf_addr_w         => c_bg_buf_adr_w,               -- Waveform buffer size 2**g_buf_addr_w nof samples
    g_file_index_arr     => c_bg_data_file_index_arr,
    g_file_name_prefix   => c_bg_data_file_prefix
  )
  PORT MAP(
    -- System
    mm_rst           => mm_rst,
    mm_clk           => mm_clk,
    dp_rst           => dp_rst,
    dp_clk           => dp_clk,
    en_sync          => dp_pps,
    -- MM interface
    reg_bg_ctrl_mosi => reg_diag_bg_mosi,
    reg_bg_ctrl_miso => reg_diag_bg_miso,
    ram_bg_data_mosi => ram_diag_bg_mosi,
    ram_bg_data_miso => ram_diag_bg_miso,
    -- ST interface
    out_siso_arr     => bg_siso_arr,
    out_sosi_arr     => bg_sosi_arr
  );
  
  ----------------------------------------------------------------------------
  -- Source: DUT input scope 
  ---------------------------------------------------------------------------- 
  gen_input_scopes : FOR I IN 0 TO c_wpfb.nof_wb_streams-1 GENERATE
    u_in_scope : ENTITY astron_sim_tools_lib.dp_wideband_wb_arr_scope
    GENERIC MAP (
      g_sim                 => TRUE,
      g_wideband_factor     => c_wpfb.wb_factor,
      g_wideband_big_endian => FALSE,
      g_dat_w               => c_wpfb.fil_in_dat_w
    )
    PORT MAP (
      SCLK         => SCLK,
      wb_sosi_arr  => bg_sosi_arr((I+1)*c_wpfb.wb_factor-1 DOWNTO I*c_wpfb.wb_factor),
      scope_sosi   => scope_in_sosi(I)
    );
  END GENERATE;
  ---------------------------------------------------------------------------- 
  -- DUT = Device Under Test
  ---------------------------------------------------------------------------- 
  u_dut : ENTITY work.wpfb_unit_dev
  GENERIC MAP(
    g_wpfb              => c_wpfb,     
    g_use_bg            => g_use_bg,        
    g_use_prefilter     => g_use_prefilter,
    g_coefs_file_prefix => c_coefs_file_prefix 
  )
  PORT MAP(
    dp_rst             => dp_rst,
    dp_clk             => dp_clk,
    mm_rst             => mm_rst,
    mm_clk             => mm_clk,  
    ram_fil_coefs_mosi => ram_fil_coefs_mosi,
    ram_fil_coefs_miso => ram_fil_coefs_miso,
    ram_st_sst_mosi    => ram_st_sst_mosi,
    ram_st_sst_miso    => ram_st_sst_miso, 
    reg_bg_ctrl_mosi   => reg_diag_bg_pfb_mosi,
    reg_bg_ctrl_miso   => reg_diag_bg_pfb_miso,
    ram_bg_data_mosi   => ram_diag_bg_pfb_mosi,
    ram_bg_data_miso   => ram_diag_bg_pfb_miso,
    in_sosi_arr        => bg_sosi_arr,     
    out_sosi_arr       => out_sosi_arr
  ); 

  time_map : process is
    variable sim_time_str_v : string(1 to 30);  -- 30 chars should be enough
    variable sim_time_len_v : natural;
  begin
    wait for 1000 ns; 
    sim_time_len_v := time'image(now)'length;
    sim_time_str_v := (others => ' ');
    sim_time_str_v(1 to sim_time_len_v) := time'image(now);
    report "Sim time string length: " & integer'image(sim_time_len_v);
    report "Sim time string.......:'" & sim_time_str_v & "'";
  end process;

  ----------------------------------------------------------------------------
  -- Sink: DUT output scope 
  ---------------------------------------------------------------------------- 
  gen_output_scopes : FOR I IN 0 TO c_wpfb.nof_wb_streams-1 GENERATE
    u_out_scope : ENTITY astron_sim_tools_lib.dp_wideband_wb_arr_scope
    GENERIC MAP (
      g_sim                 => TRUE,
      g_wideband_factor     => c_wpfb.wb_factor,
      g_wideband_big_endian => FALSE,
      g_dat_w               => c_wpfb.fft_out_dat_w
    )
    PORT MAP (
      SCLK         => SCLK,
      wb_sosi_arr  => out_sosi_arr((I+1)*c_wpfb.wb_factor-1 DOWNTO I*c_wpfb.wb_factor),
      scope_sosi   => scope_out_sosi(I)
    );                        
  END GENERATE;
  
  p_scope_out_index : PROCESS(SCLK)
  BEGIN
    IF rising_edge(SCLK) THEN
      IF scope_out_sosi(0).valid='1' THEN
        scope_out_index <= scope_out_index+1;
        IF scope_out_index>=g_nof_points-1 THEN
          scope_out_index <= 0;
        END IF;
      END IF;
    END IF;
  END PROCESS;
  scope_out_bin    <= fft_index_to_bin_frequency(c_wpfb.wb_factor, c_wpfb.nof_points, scope_out_index, TRUE, FALSE, TRUE);  -- complex bin
  scope_out_band   <= fft_index_to_bin_frequency(c_wpfb.wb_factor, c_wpfb.nof_points, scope_out_index, TRUE, TRUE, TRUE);   -- two real bin
  
  scope_out_power  <= REAL(scope_out_sosi(0).re)**2 + REAL(scope_out_sosi(0).im)**2;
  scope_out_ampl   <= SQRT(scope_out_power);
  scope_out_ampl_x <= scope_out_ampl WHEN (scope_out_bin MOD 2)=0 ELSE 0.0;
  scope_out_ampl_y <= scope_out_ampl WHEN (scope_out_bin MOD 2)=1 ELSE 0.0;
  
  ----------------------------------------------------------------------------
  -- Sink: data buffer real 
  ---------------------------------------------------------------------------- 
  u_data_buf_re : ENTITY astron_diagnostics_lib.mms_diag_data_buffer
  GENERIC MAP (    
    g_nof_streams  => c_nof_streams,
    g_data_type    => e_real,
    g_data_w       => c_wpfb.fft_out_dat_w,
    g_buf_nof_data => c_bg_block_len,
    g_buf_use_sync => TRUE
  )
  PORT MAP (
    -- System
    mm_rst            => mm_rst,
    mm_clk            => mm_clk,
    dp_rst            => dp_rst,
    dp_clk            => dp_clk,
    
    -- MM interface
    ram_data_buf_mosi => ram_diag_data_buf_re_mosi,
    ram_data_buf_miso => ram_diag_data_buf_re_miso,
    
    reg_data_buf_mosi => reg_diag_data_buf_re_mosi,
    reg_data_buf_miso => reg_diag_data_buf_re_miso,

    -- ST interface
    in_sync           => out_sosi_arr(0).sync,
    in_sosi_arr       => out_sosi_arr         
  );

  ----------------------------------------------------------------------------
  -- Sink: data buffer imag 
  ---------------------------------------------------------------------------- 
  u_data_buf_im : ENTITY astron_diagnostics_lib.mms_diag_data_buffer
  GENERIC MAP (    
    g_nof_streams  => c_nof_streams,
    g_data_type    => e_imag,
    g_data_w       => c_wpfb.fft_out_dat_w,
    g_buf_nof_data => c_bg_block_len,
    g_buf_use_sync => TRUE
  )
  PORT MAP (
    -- System
    mm_rst            => mm_rst,
    mm_clk            => mm_clk,
    dp_rst            => dp_rst,
    dp_clk            => dp_clk,
    
    -- MM interface
    ram_data_buf_mosi => ram_diag_data_buf_im_mosi,
    ram_data_buf_miso => ram_diag_data_buf_im_miso,
    
    reg_data_buf_mosi => reg_diag_data_buf_im_mosi,
    reg_data_buf_miso => reg_diag_data_buf_im_miso,

    -- ST interface
    in_sync           => out_sosi_arr(0).sync, 
    in_sosi_arr       => out_sosi_arr          
  );

END tb;
