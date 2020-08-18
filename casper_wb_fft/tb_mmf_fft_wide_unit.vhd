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
--
-- Purpose: Testbench for the FFT Wide Unit.
--
--          The testbech uses blockgenerators to generate data for 
--          every input of the FFT. 
--          The output of the FFT is stored in databuffers. 
--          Both the block generators and databuffers are controlled
--          via a mm interface. 
--          The MM interface that is connected to the statistic mopdules is
--          also connected and can be read from the python script. 
--          Use this testbench in conjunction with ../python/tc_mmf_fft_wide_unit.py
--
-- The testbench can be used in two modes: auto-mode and non-auto-mode. The mode
-- is determined by the constant c_modelsim_start in the tc_mmf_fft_wide_unit.py script. 
-- 
-- Usage in auto-mode (c_modelsim_start = 1 in python):
--   > Run python script in separate terminal: "python tc_mmf_fft_wide_unit.py --unb 0 --bn 0 --sim"
--
-- Usage in non-auto-mode (c_modelsim_start = 0 in python):
--   > run -all
--   > Run python script in separate terminal: "python tc_mmf_fft_wide_unit.py --unb 0 --bn 0 --sim"
--   > Check the results of the python script. 
--   > Stop the simulation manually in Modelsim by pressing the stop-button. 

LIBRARY IEEE, common_pkg_lib, casper_mm_lib, casper_diagnostics_lib, dp_pkg_lib, r2sdf_fft_lib, casper_ram_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE common_pkg_lib.common_str_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;
USE casper_mm_lib.tb_common_mem_pkg.ALL;
USE casper_mm_lib.mm_file_unb_pkg.ALL;
USE casper_mm_lib.mm_file_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;
USE r2sdf_fft_lib.rTwoSDFPkg.all;
USE work.fft_pkg.all;

ENTITY tb_mmf_fft_wide_unit IS
	GENERIC(
		g_fft_type         : string  := "wide"; -- = default "wide", 3 fft types possible: pipe, wide or par 
		g_nof_chan         : natural := 0; -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan         
		g_wb_factor        : natural := 4; -- = default 1, wideband factor
		g_nof_points       : natural := 64; -- = 1024, N point FFT
		g_nof_integrations : natural := 4; -- = 4, the number of accumulations. 
		g_in_dat_w         : natural := 8; -- = 8, number of input bits                                                       
		g_out_dat_w        : natural := 14; -- = 14, number of output bits: in_dat_w + natural((ceil_log2(nof_points))/2) 
		g_use_separate     : boolean := false -- = false for complex input, true for two real inputs

	);
END tb_mmf_fft_wide_unit;

ARCHITECTURE tb OF tb_mmf_fft_wide_unit IS

	CONSTANT c_fft : t_fft := (true, false, g_use_separate, g_nof_chan, g_wb_factor, 0, g_nof_points, g_in_dat_w, g_out_dat_w, 0, c_dsp_mult_w, 2, true, 56, 2);
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

	CONSTANT c_sim : BOOLEAN := TRUE;

	----------------------------------------------------------------------------
	-- Clocks and resets
	----------------------------------------------------------------------------   
	CONSTANT c_mm_clk_period : TIME    := 100 ps;
	CONSTANT c_dp_clk_period : TIME    := 5 ns;
	CONSTANT c_dp_pps_period : NATURAL := 64;

	SIGNAL dp_pps : STD_LOGIC;

	SIGNAL mm_rst : STD_LOGIC;
	SIGNAL mm_clk : STD_LOGIC := '0';

	SIGNAL dp_rst : STD_LOGIC;
	SIGNAL dp_clk : STD_LOGIC := '0';

	----------------------------------------------------------------------------
	-- MM buses
	----------------------------------------------------------------------------                                         
	SIGNAL reg_diag_bg_mosi : t_mem_mosi;
	SIGNAL reg_diag_bg_miso : t_mem_miso;

	SIGNAL ram_diag_bg_mosi : t_mem_mosi;
	SIGNAL ram_diag_bg_miso : t_mem_miso;

	SIGNAL ram_ss_ss_wide_mosi : t_mem_mosi;
	SIGNAL ram_ss_ss_wide_miso : t_mem_miso;

	SIGNAL ram_diag_data_buf_re_mosi : t_mem_mosi;
	SIGNAL ram_diag_data_buf_re_miso : t_mem_miso;

	SIGNAL reg_diag_data_buf_re_mosi : t_mem_mosi;
	SIGNAL reg_diag_data_buf_re_miso : t_mem_miso;

	SIGNAL ram_diag_data_buf_im_mosi : t_mem_mosi;
	SIGNAL ram_diag_data_buf_im_miso : t_mem_miso;

	SIGNAL reg_diag_data_buf_im_mosi : t_mem_mosi;
	SIGNAL reg_diag_data_buf_im_miso : t_mem_miso;

	SIGNAL ram_st_sst_mosi : t_mem_mosi := c_mem_mosi_rst;
	SIGNAL ram_st_sst_miso : t_mem_miso := c_mem_miso_rst;

	CONSTANT c_nof_channels : NATURAL  := 2**c_fft.nof_chan;
	CONSTANT c_nof_streams  : POSITIVE := c_fft.wb_factor;
	CONSTANT c_bg_block_len : NATURAL  := c_fft.nof_points * g_nof_integrations * c_nof_channels / c_fft.wb_factor;

	CONSTANT c_bg_buf_adr_w           : NATURAL           := ceil_log2(c_bg_block_len);
	CONSTANT c_bg_data_file_index_arr : t_nat_natural_arr := array_init(0, c_fft.wb_factor, 1);
	CONSTANT c_bg_data_file_prefix    : STRING            := "UNUSED";

	SIGNAL bg_siso_arr : t_dp_siso_arr(c_fft.wb_factor - 1 DOWNTO 0) := (OTHERS => c_dp_siso_rdy);
	SIGNAL bg_sosi_arr : t_dp_sosi_arr(c_fft.wb_factor - 1 DOWNTO 0);

	SIGNAL result_siso_arr : t_dp_siso_arr(c_fft.wb_factor - 1 DOWNTO 0) := (OTHERS => c_dp_siso_rdy);
	SIGNAL result_sosi_arr : t_dp_sosi_arr(c_fft.wb_factor - 1 DOWNTO 0);

	SIGNAL ss_out_sosi_re_arr : t_dp_sosi_arr(c_fft.wb_factor - 1 DOWNTO 0) := (OTHERS => c_dp_sosi_rst);
	SIGNAL ss_out_sosi_im_arr : t_dp_sosi_arr(c_fft.wb_factor - 1 DOWNTO 0) := (OTHERS => c_dp_sosi_rst);

BEGIN

	----------------------------------------------------------------------------
	-- Clock and reset generation
	----------------------------------------------------------------------------
	mm_clk <= NOT mm_clk AFTER c_mm_clk_period / 2;
	mm_rst <= '1', '0' AFTER c_mm_clk_period * 5;

	dp_clk <= NOT dp_clk AFTER c_dp_clk_period / 2;
	dp_rst <= '1', '0' AFTER c_dp_clk_period * 5;

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
	u_mm_file_reg_diag_bg : mm_file
		GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "REG_DIAG_BG")
		PORT MAP(mm_rst, mm_clk, reg_diag_bg_mosi, reg_diag_bg_miso);

	u_mm_file_ram_diag_bg : mm_file
		GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "RAM_DIAG_BG")
		PORT MAP(mm_rst, mm_clk, ram_diag_bg_mosi, ram_diag_bg_miso);

	u_mm_file_ram_diag_data_buf_re : mm_file
		GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "RAM_DIAG_DATA_BUFFER_REAL")
		PORT MAP(mm_rst, mm_clk, ram_diag_data_buf_re_mosi, ram_diag_data_buf_re_miso);

	u_mm_file_reg_diag_data_buf_re : mm_file
		GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "REG_DIAG_DATA_BUFFER_REAL")
		PORT MAP(mm_rst, mm_clk, reg_diag_data_buf_re_mosi, reg_diag_data_buf_re_miso);

	u_mm_file_ram_diag_data_buf_im : mm_file
		GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "RAM_DIAG_DATA_BUFFER_IMAG")
		PORT MAP(mm_rst, mm_clk, ram_diag_data_buf_im_mosi, ram_diag_data_buf_im_miso);

	u_mm_file_reg_diag_data_buf_im : mm_file
		GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "REG_DIAG_DATA_BUFFER_IMAG")
		PORT MAP(mm_rst, mm_clk, reg_diag_data_buf_im_mosi, reg_diag_data_buf_im_miso);

	u_mm_file_ram_st_sst : mm_file
		GENERIC MAP(mmf_unb_file_prefix(0, 0, "BN") & "RAM_ST_SST")
		PORT MAP(mm_rst, mm_clk, ram_st_sst_mosi, ram_st_sst_miso);

	----------------------------------------------------------------------------
	-- Source: block generator
	---------------------------------------------------------------------------- 
	u_bg : ENTITY casper_diagnostics_lib.mms_diag_block_gen
		GENERIC MAP(
			g_nof_streams      => c_nof_streams,
			g_buf_dat_w        => c_nof_complex * c_fft.in_dat_w,
			g_buf_addr_w       => c_bg_buf_adr_w, -- Waveform buffer size 2**g_buf_addr_w nof samples
			g_file_index_arr   => c_bg_data_file_index_arr,
			g_file_name_prefix => c_bg_data_file_prefix
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

	---------------------------------------------------------------  
	-- DUT = Device Under Test
	---------------------------------------------------------------  
	u_dut : ENTITY work.fft_wide_unit
		GENERIC MAP(
			g_fft => c_fft
		)
		PORT MAP(
			clken           => '1',
			dp_rst          => dp_rst,
			dp_clk          => dp_clk,
			mm_rst          => mm_rst,
			mm_clk          => mm_clk,
			ram_st_sst_mosi => ram_st_sst_mosi,
			ram_st_sst_miso => ram_st_sst_miso,
			in_sosi_arr     => bg_sosi_arr,
			out_sosi_arr    => result_sosi_arr
		);

	connect_output_data : FOR I IN 0 TO c_fft.wb_factor - 1 GENERATE
		ss_out_sosi_re_arr(I).data  <= RESIZE_SVEC(result_sosi_arr(I).re, ss_out_sosi_re_arr(I).data'LENGTH);
		ss_out_sosi_re_arr(I).valid <= result_sosi_arr(I).valid;
		ss_out_sosi_re_arr(I).sync  <= result_sosi_arr(I).sync;

		ss_out_sosi_im_arr(I).data  <= RESIZE_SVEC(result_sosi_arr(I).im, ss_out_sosi_im_arr(I).data'LENGTH);
		ss_out_sosi_im_arr(I).valid <= result_sosi_arr(I).valid;
		ss_out_sosi_im_arr(I).sync  <= result_sosi_arr(I).sync;
	END GENERATE;

	----------------------------------------------------------------------------
	-- Sink: data buffer real 
	---------------------------------------------------------------------------- 
	u_data_buf_re : ENTITY casper_diagnostics_lib.mms_diag_data_buffer
		GENERIC MAP(
			g_nof_streams  => c_nof_streams,
			g_data_w       => c_fft.out_dat_w,
			g_buf_nof_data => c_bg_block_len,
			g_buf_use_sync => TRUE
		)
		PORT MAP(
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
			in_sync           => ss_out_sosi_re_arr(0).sync,
			in_sosi_arr       => ss_out_sosi_re_arr
		);

	----------------------------------------------------------------------------
	-- Sink: data buffer imag 
	---------------------------------------------------------------------------- 
	u_data_buf_im : ENTITY casper_diagnostics_lib.mms_diag_data_buffer
		GENERIC MAP(
			g_nof_streams  => c_nof_streams,
			g_data_w       => c_fft.out_dat_w,
			g_buf_nof_data => c_bg_block_len,
			g_buf_use_sync => TRUE
		)
		PORT MAP(
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
			in_sync           => ss_out_sosi_im_arr(0).sync,
			in_sosi_arr       => ss_out_sosi_im_arr
		);

END tb;
