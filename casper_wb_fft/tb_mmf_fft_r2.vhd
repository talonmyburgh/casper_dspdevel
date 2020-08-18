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
-- Purpose: Testbench for the radix-2 FFT.
--
--          The testbench serves the pipelined, wideband and parallel FFTs.
--          The generic g_fft_type is used to select the desired FFT. 
--
--          The testbech uses blockgenerators to generate data for 
--          every input of the FFT. 
--          The output of the FFT is stored in databuffers. 
--          Both the block generators and databuffers are controlled
--          via a mm interface. 
--          Use this testbench in conjunction with ../python/tc_mmf_fft_r2.py
--
-- The testbench can be used in two modes: auto-mode and non-auto-mode. The mode
-- is determined by the constant c_modelsim_start in the tc_mmf_fft_r2.py script. 
-- 
-- Usage in auto-mode (c_modelsim_start = 1 in python):
--   > Run python script in separate terminal: "python tc_mmf_fft_r2.py --unb 0 --bn 0 --sim"
--
-- Usage in non-auto-mode (c_modelsim_start = 0 in python):
--   > run -all
--   > Run python script in separate terminal: "python tc_mmf_fft_r2.py --unb 0 --bn 0 --sim"
--   > Check the results of the python script. 
--   > Stop the simulation manually in Modelsim by pressing the stop-button. 

LIBRARY IEEE, common_pkg_lib, casper_mm_lib, casper_diagnostics_lib, dp_pkg_lib, r2sdf_fft_lib, casper_ram_lib, casper_mm_lib, casper_sim_tools_lib;
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
USE casper_diagnostics_lib.diag_pkg.ALL;
USE r2sdf_fft_lib.rTwoSDFPkg.all;
USE work.fft_pkg.all;

ENTITY tb_mmf_fft_r2 IS
	GENERIC(
		g_fft_type     : string  := "wide"; -- = default "wide", 3 fft types possible: pipe, wide or par 
		g_nof_chan     : natural := 0;  -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan         
		g_wb_factor    : natural := 4;  -- = default 1, wideband factor
		g_nof_points   : natural := 1024; -- = 1024, N point FFT
		g_nof_blocks   : natural := 4;  -- = 4, the number of blocks of g_nof_points each in the BG waveform (must be power of 2 due to that BG c_bg_block_len must be power of 2)
		g_in_dat_w     : natural := 8;  -- = 8, number of input bits                                                       
		g_out_dat_w    : natural := 16; -- = 14, number of output bits: in_dat_w + natural((ceil_log2(nof_points))/2) 
		g_use_separate : boolean := false -- = false for complex input, true for two real inputs

	);
END tb_mmf_fft_r2;

ARCHITECTURE tb OF tb_mmf_fft_r2 IS

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
	CONSTANT c_sclk_period   : TIME    := 1250 ps;
	CONSTANT c_dp_pps_period : NATURAL := 64;

	SIGNAL dp_pps : STD_LOGIC;

	SIGNAL mm_rst : STD_LOGIC;
	SIGNAL mm_clk : STD_LOGIC := '0';

	SIGNAL dp_rst : STD_LOGIC;
	SIGNAL dp_clk : STD_LOGIC := '0';

	SIGNAL SCLK : STD_LOGIC := '0';

	----------------------------------------------------------------------------
	-- MM buses
	----------------------------------------------------------------------------                                         
	SIGNAL reg_diag_bg_mosi : t_mem_mosi;
	SIGNAL reg_diag_bg_miso : t_mem_miso;

	SIGNAL ram_diag_bg_mosi : t_mem_mosi;
	SIGNAL ram_diag_bg_miso : t_mem_miso;

	SIGNAL ram_diag_data_buf_re_mosi : t_mem_mosi;
	SIGNAL ram_diag_data_buf_re_miso : t_mem_miso;

	SIGNAL reg_diag_data_buf_re_mosi : t_mem_mosi;
	SIGNAL reg_diag_data_buf_re_miso : t_mem_miso;

	SIGNAL ram_diag_data_buf_im_mosi : t_mem_mosi;
	SIGNAL ram_diag_data_buf_im_miso : t_mem_miso;

	SIGNAL reg_diag_data_buf_im_mosi : t_mem_mosi;
	SIGNAL reg_diag_data_buf_im_miso : t_mem_miso;

	CONSTANT c_nof_channels : NATURAL  := 2**c_fft.nof_chan;
	CONSTANT c_nof_streams  : POSITIVE := c_fft.wb_factor;
	CONSTANT c_bg_block_len : NATURAL  := c_fft.nof_points * g_nof_blocks * c_nof_channels / c_fft.wb_factor;

	CONSTANT c_bg_buf_adr_w           : NATURAL           := ceil_log2(c_bg_block_len);
	CONSTANT c_bg_data_file_index_arr : t_nat_natural_arr := array_init(0, c_fft.wb_factor, 1);
	CONSTANT c_bg_data_file_prefix    : STRING            := "UNUSED";

	SIGNAL bg_siso_arr : t_dp_siso_arr(c_fft.wb_factor - 1 DOWNTO 0) := (OTHERS => c_dp_siso_rdy);
	SIGNAL bg_sosi_arr : t_dp_sosi_arr(c_fft.wb_factor - 1 DOWNTO 0);

	SIGNAL out_sosi_arr : t_dp_sosi_arr(c_fft.wb_factor - 1 DOWNTO 0) := (OTHERS => c_dp_sosi_rst);

	SIGNAL in_re_arr : t_fft_slv_arr(c_fft.wb_factor - 1 DOWNTO 0);
	SIGNAL in_im_arr : t_fft_slv_arr(c_fft.wb_factor - 1 DOWNTO 0);
	SIGNAL in_val    : STD_LOGIC := '0';

	SIGNAL out_re_arr : t_fft_slv_arr(c_fft.wb_factor - 1 DOWNTO 0);
	SIGNAL out_im_arr : t_fft_slv_arr(c_fft.wb_factor - 1 DOWNTO 0);
	SIGNAL out_val    : STD_LOGIC := '0';

	SIGNAL scope_in_sosi  : t_dp_sosi_integer;
	SIGNAL scope_out_sosi : t_dp_sosi_integer;

BEGIN

	----------------------------------------------------------------------------
	-- Clock and reset generation
	----------------------------------------------------------------------------
	mm_clk <= NOT mm_clk AFTER c_mm_clk_period / 2;
	mm_rst <= '1', '0' AFTER c_mm_clk_period * 5;

	SCLK   <= NOT SCLK AFTER c_sclk_period / 2;
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

	u_in_scope : ENTITY casper_sim_tools_lib.dp_wideband_wb_arr_scope
		GENERIC MAP(
			g_sim                 => TRUE,
			g_wideband_factor     => c_fft.wb_factor,
			g_wideband_big_endian => FALSE,
			g_dat_w               => c_fft.in_dat_w
		)
		PORT MAP(
			SCLK        => SCLK,
			wb_sosi_arr => bg_sosi_arr,
			scope_sosi  => scope_in_sosi
		);

	connect_input_data : FOR I IN 0 TO c_fft.wb_factor - 1 GENERATE
		in_re_arr(I) <= RESIZE_SVEC(bg_sosi_arr(I).re(c_fft.in_dat_w - 1 DOWNTO 0), in_re_arr(I)'LENGTH);
		in_im_arr(I) <= RESIZE_SVEC(bg_sosi_arr(I).im(c_fft.in_dat_w - 1 DOWNTO 0), in_im_arr(I)'LENGTH);
	END GENERATE;

	in_val <= bg_sosi_arr(0).valid;

	-- DUT = Device Under Test  
	-- Based on the g_fft_type generic the appropriate 
	-- DUT is instantiated.  
	gen_wideband_fft : IF g_fft_type = "wide" GENERATE
		u_dut : ENTITY work.fft_r2_wide
			GENERIC MAP(
				g_fft => c_fft          -- generics for the FFT
			)
			PORT MAP(
				clken      => '1',
				clk        => dp_clk,
				rst        => dp_rst,
				in_re_arr  => in_re_arr,
				in_im_arr  => in_im_arr,
				in_val     => in_val,
				out_re_arr => out_re_arr,
				out_im_arr => out_im_arr,
				out_val    => out_val
			);
	END GENERATE;

	gen_pipelined_fft : IF g_fft_type = "pipe" GENERATE
		u_dut : ENTITY work.fft_r2_pipe
			GENERIC MAP(
				g_fft => c_fft
			)
			port map(
				clken   => '1',
				clk     => dp_clk,
				rst     => dp_rst,
				in_re   => in_re_arr(0)(c_fft.in_dat_w - 1 DOWNTO 0),
				in_im   => in_im_arr(0)(c_fft.in_dat_w - 1 DOWNTO 0),
				in_val  => in_val,
				out_re  => out_re_arr(0)(c_fft.out_dat_w - 1 DOWNTO 0),
				out_im  => out_im_arr(0)(c_fft.out_dat_w - 1 DOWNTO 0),
				out_val => out_val
			);
	END GENERATE;

	gen_parallel_fft : IF g_fft_type = "par" GENERATE
		u_dut : ENTITY work.fft_r2_par
			GENERIC MAP(
				g_fft => c_fft
			)
			PORT MAP(
				clk        => dp_clk,
				rst        => dp_rst,
				in_re_arr  => in_re_arr,
				in_im_arr  => in_im_arr,
				in_val     => in_val,
				out_re_arr => out_re_arr,
				out_im_arr => out_im_arr,
				out_val    => out_val
			);
	END GENERATE;

	connect_output_data : FOR I IN 0 TO c_fft.wb_factor - 1 GENERATE
		out_sosi_arr(I).re    <= RESIZE_DP_DSP_DATA(out_re_arr(I));
		out_sosi_arr(I).im    <= RESIZE_DP_DSP_DATA(out_im_arr(I));
		out_sosi_arr(I).valid <= out_val;
	END GENERATE;

	u_out_scope : ENTITY casper_sim_tools_lib.dp_wideband_wb_arr_scope
		GENERIC MAP(
			g_sim                 => TRUE,
			g_wideband_factor     => c_fft.wb_factor,
			g_wideband_big_endian => FALSE,
			g_dat_w               => c_fft.out_dat_w
		)
		PORT MAP(
			SCLK        => SCLK,
			wb_sosi_arr => out_sosi_arr,
			scope_sosi  => scope_out_sosi
		);

	----------------------------------------------------------------------------
	-- Sink: data buffer real 
	---------------------------------------------------------------------------- 
	u_data_buf_re : ENTITY casper_diagnostics_lib.mms_diag_data_buffer
		GENERIC MAP(
			g_nof_streams  => c_nof_streams,
			g_data_type    => e_real,
			g_data_w       => c_fft.out_dat_w,
			g_buf_nof_data => c_bg_block_len,
			g_buf_use_sync => FALSE
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
			in_sync           => OPEN,
			in_sosi_arr       => out_sosi_arr
		);

	----------------------------------------------------------------------------
	-- Sink: data buffer imag 
	---------------------------------------------------------------------------- 
	u_data_buf_im : ENTITY casper_diagnostics_lib.mms_diag_data_buffer
		GENERIC MAP(
			g_nof_streams  => c_nof_streams,
			g_data_type    => e_imag,
			g_data_w       => c_fft.out_dat_w,
			g_buf_nof_data => c_bg_block_len,
			g_buf_use_sync => FALSE
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
			in_sync           => OPEN,
			in_sosi_arr       => out_sosi_arr
		);

END tb;
