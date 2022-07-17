library ieee, std, common_pkg_lib, r2sdf_fft_lib, casper_filter_lib, wb_fft_lib, wpfb_lib, vunit_lib;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;
use casper_filter_lib.fil_pkg.all;
use common_pkg_lib.common_pkg.all;
use wb_fft_lib.fft_gnrcs_intrfcs_pkg.all;
use wpfb_lib.wbpfb_gnrcs_intrfcs_pkg.all;
context vunit_lib.vunit_context;

entity tb_tb_vu_wbpfb_unit_wide is
    GENERIC(
        g_wb_factor             : natural   := c_fft_wb_factor;  -- = default 1, wideband factor
        g_nof_points            : natural   := c_fft_nof_points;  -- = 1024, N point FFT
        g_nof_chan              : natural   := c_fft_nof_chan;  -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan         
        g_nof_wb_streams        : natural   := c_wbpfb_nof_wb_streams;
        g_nof_taps              : natural   := c_fil_nof_taps;
        g_fil_backoff_w         : natural   := c_fil_backoff_w;
        g_fil_in_dat_w          : natural   := c_fil_in_dat_w;
        g_fil_out_dat_w         : natural   := c_fil_out_dat_w;
        g_coef_dat_w            : natural   := c_fil_coef_dat_w;
        g_use_reorder           : boolean   := c_fft_use_reorder;  -- = false for bit-reversed output, true for normal output
        g_use_fft_shift         : boolean   := c_fft_use_fft_shift;  -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
        g_use_separate          : boolean   := c_fft_use_separate;  -- = false for complex input, true for two real inputs
        g_fft_in_dat_w          : natural   := c_fft_in_dat_w;  -- = 8, number of input bits
        g_fft_out_dat_w         : natural   := c_fft_out_dat_w;  -- = 13, number of output bits, bit growth: in_dat_w + natural((ceil_log2(nof_points))/2 + 2)  
        g_fft_out_gain_w        : natural   := c_fft_out_gain_w;  -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
        g_stage_dat_w           : natural   := c_fft_stage_dat_w;  -- = 18, data width used between the stages(= DSP multiplier-width)
        g_twiddle_dat_w         : natural   := c_fft_twiddle_dat_w;
        g_max_addr_w            : natural   := c_max_addr_w;
        g_guard_w               : natural   := c_fft_guard_w;  -- = 2,  Guard used to avoid overflow in FFT stage. 
        g_guard_enable          : boolean   := c_fft_guard_enable;  -- = true when input needs guarding, false when input requires no guarding but scaling must be skipped at the last stage(s) (used in wb fft)
        g_diff_margin           : integer   := 2;  -- maximum difference between HDL output and expected output (> 0 to allow minor rounding differences)
        g_coefs_file_prefix_ab  : string    := "data/run_pfb_m_pfir_coeff_fircls1";
        g_coefs_file_prefix_c   : string    := "data/run_pfb_complex_m_pfir_coeff_fircls1";
        g_data_file_a           : string    := "data/run_pfft_m_sinusoid_chirp_8b_32points_16b.dat";
        g_data_file_a_nof_lines : natural   := 6400;
        g_data_file_b           : string    := "UNUSED";
        g_data_file_b_nof_lines : natural   := 0;
        g_data_file_c           : string    := "data/run_pfft_complex_m_phasor_8b_64points_16b.dat";
        g_data_file_c_nof_lines : natural   := 320;
        g_data_file_nof_lines   : natural   := 6400;
        g_enable_in_val_gaps    : boolean   := FALSE;   -- when false then in_val flow control active continuously, else with random inactive gaps
        g_twid_file_stem        : string    := c_twid_file_stem;
        runner_cfg              : string    := runner_cfg_default 
    );
end tb_tb_vu_wbpfb_unit_wide;

architecture tb of tb_tb_vu_wbpfb_unit_wide is

    SIGNAL rst      	: STD_LOGIC;
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg     : STRING(1 to 80);
	SIGNAL test_pass	: BOOLEAN;

    CONSTANT c_nof_blk_per_sync          : natural := 20;
    CONSTANT c_wpfb_vu : t_wpfb := (
        wb_factor => g_wb_factor,
        nof_points => g_nof_points,
        nof_chan => g_nof_chan,
        nof_wb_streams => g_nof_wb_streams,
        nof_taps => g_nof_taps,
        fil_backoff_w => g_fil_backoff_w,
        fil_in_dat_w => g_fil_in_dat_w,
        fil_out_dat_w => g_fil_out_dat_w,
        coef_dat_w => g_coef_dat_w,
        use_reorder => g_use_reorder,
        use_fft_shift => g_use_fft_shift,
        use_separate => g_use_separate,
        fft_in_dat_w => g_fft_in_dat_w,
        fft_out_dat_w => g_fft_out_dat_w,
        fft_out_gain_w => g_fft_out_gain_w,
        stage_dat_w => g_stage_dat_w,
        twiddle_dat_w  => g_twiddle_dat_w,
        max_addr_w  => g_max_addr_w,
        guard_w => g_guard_w,
        guard_enable => g_guard_enable,
        pipe_reo_in_place => FALSE,
        stat_data_w => 56,
        stat_data_sz => 2,
        nof_blk_per_sync => c_nof_blk_per_sync,
        pft_pipeline => c_fft_pipeline,
        fft_pipeline => c_fft_pipeline,
        fil_pipeline => c_fil_ppf_pipeline
        );
BEGIN
	tb_ut : ENTITY work.tb_wbpfb_unit_wide
        GENERIC MAP(
            g_wpfb => c_wpfb_vu,        
            g_diff_margin => g_diff_margin,
            g_coefs_file_prefix_ab => g_coefs_file_prefix_ab,
            g_coefs_file_prefix_c => g_coefs_file_prefix_c,
            g_data_file_a => g_data_file_a,
            g_data_file_a_nof_lines => g_data_file_a_nof_lines,
            g_data_file_b => g_data_file_b,
            g_data_file_b_nof_lines => g_data_file_b_nof_lines,
            g_data_file_c => g_data_file_c,
            g_data_file_c_nof_lines => g_data_file_c_nof_lines,
            g_data_file_nof_lines => g_data_file_nof_lines,
            g_enable_in_val_gaps => g_enable_in_val_gaps,
            g_twid_file_stem => g_twid_file_stem
        )
		PORT MAP(
			o_rst => rst,
			o_clk => clk,
			o_tb_end => tb_end,
			o_test_msg => test_msg,
			o_test_pass => test_pass
		);

	p_vunit : PROCESS
	BEGIN
		test_runner_setup(runner, runner_cfg);
		wait until tb_end = '1';
		test_runner_cleanup(runner);
		wait;
	END PROCESS;

	p_verify : PROCESS(rst, clk)
	BEGIN
		IF rst = '0' THEN
			IF rising_edge(clk) THEN
				check(test_pass, "Test Failed: " & test_msg);
                assert test_pass report test_msg severity failure;
			END IF;
		END IF;

	END PROCESS;
END tb;