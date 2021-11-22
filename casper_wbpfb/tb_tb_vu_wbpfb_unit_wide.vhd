library ieee, std, common_pkg_lib, vunit_lib;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use common_pkg_lib.common_pkg.all;
use work.fft_gnrcs_intrfcs_pkg.all;
context vunit_lib.vunit_context;

entity tb_tb_vu_wbpfb_unit_wide is
    GENERIC(
        g_wb_factor             : natural;  -- = default 1, wideband factor
        g_nof_points            : natural;  -- = 1024, N point FFT
        g_nof_chan              : natural;  -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan         
        g_nof_wb_streams        : natural;
        
        g_use_reorder           : boolean;  -- = false for bit-reversed output, true for normal output
        g_use_fft_shift         : boolean;  -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
        g_use_separate          : boolean;  -- = false for complex input, true for two real inputs
        g_fft_in_dat_w          : natural;  -- = 8, number of input bits
        g_fft_out_dat_w         : natural;  -- = 13, number of output bits, bit growth: in_dat_w + natural((ceil_log2(nof_points))/2 + 2)  
        g_fft_out_gain_w        : natural;  -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
        g_stage_dat_w           : natural;  -- = 18, data width used between the stages(= DSP multiplier-width)
        g_guard_w               : natural;  -- = 2,  Guard used to avoid overflow in FFT stage. 
        g_guard_enable          : boolean;  -- = true when input needs guarding, false when input requires no guarding but scaling must be skipped at the last stage(s) (used in wb fft)
        g_diff_margin           : integer    := 2;  -- maximum difference between HDL output and expected output (> 0 to allow minor rounding differences)
        g_data_file_a           : string     := "data/run_pfft_m_sinusoid_chirp_8b_32points_16b.dat";
        g_data_file_a_nof_lines : natural    := 6400;
        g_data_file_b           : string     := "UNUSED";
        g_data_file_b_nof_lines : natural    := 0;
        g_data_file_c           : string     := "data/run_pfft_complex_m_phasor_8b_64points_16b.dat";
        g_data_file_c_nof_lines : natural    := 320;
        g_data_file_nof_lines   : natural    := 6400;
        g_enable_in_val_gaps    : boolean    := FALSE;   -- when false then in_val flow control active continuously, else with random inactive gaps
        g_use_variant           : STRING     := "4DSP";
        g_ovflw_behav           : STRING     := "WRAP";
        g_use_round             : STRING     := "TRUNCATE";
        runner_cfg              : string
    );
end tb_tb_vu_wbpfb_unit_wide;

architecture tb of tb_tb_vu_wbpfb_unit_wide is

    SIGNAL rst      	: STD_LOGIC;
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg     : STRING(1 to 80);
	SIGNAL test_pass	: BOOLEAN;

    CONSTANT c_fft_vu : t_fft := (g_use_reorder, g_use_fft_shift, g_use_separate, g_nof_chan, g_wb_factor, g_twiddle_offset, g_nof_points, g_in_dat_w, g_out_dat_w, g_out_gain_w, g_stage_dat_w, g_guard_w, g_guard_enable, 56, 2);

BEGIN
	tb_ut : ENTITY work.tb_wbpfb_unit_wide
        GENERIC MAP(
            g_fft => c_fft_vu,        
            g_diff_margin => g_diff_margin,
            g_data_file_a => g_data_file_a,
            g_data_file_a_nof_lines => g_data_file_a_nof_lines,
            g_data_file_b => g_data_file_b,
            g_data_file_b_nof_lines => g_data_file_b_nof_lines,
            g_data_file_c => g_data_file_c,
            g_data_file_c_nof_lines => g_data_file_c_nof_lines,
            g_data_file_nof_lines => g_data_file_nof_lines,
            g_enable_in_val_gaps => g_enable_in_val_gaps,
            g_use_variant => g_use_variant,
            g_ovflw_behav => g_ovflw_behav,
            g_use_round => g_use_round
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
			END IF;
		END IF;

	END PROCESS;
END tb;