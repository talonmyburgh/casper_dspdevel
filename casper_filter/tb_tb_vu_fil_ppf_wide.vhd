library ieee, std, common_pkg_lib, vunit_lib;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use common_pkg_lib.common_pkg.all;
use work.fil_pkg.all;
context vunit_lib.vunit_context;

entity tb_tb_vu_fil_ppf_wide is
    GENERIC(
        g_big_endian_wb_in      : boolean := true; -- These should be overriden when actually using wideband, but in single mode they aren't set by the python
        g_big_endian_wb_out     : boolean := true; 
        g_wb_factor             : natural;  -- = default 1, wideband factor
        g_nof_chan              : natural;  -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan         
        g_nof_bands             : natural;  -- = 1024, N point FFT
        g_nof_taps              : natural;
        g_nof_streams           : natural;
        g_backoff_w             : natural;
        g_fil_in_dat_w          : natural;  -- = 8, number of input bits
        g_fil_out_dat_w         : natural;  -- = 13, number of output bits, bit growth: in_dat_w + natural((ceil_log2(nof_points))/2 + 2)  
        g_coef_dat_w            : natural;  -- = 18, data width used between the stages(= DSP multiplier-width)
        g_coefs_file_prefix     : string;
        g_enable_in_val_gaps    : boolean    := FALSE;   -- when false then in_val flow control active continuously, else with random inactive gaps
        runner_cfg              : string
    );
end tb_tb_vu_fil_ppf_wide;

architecture tb of tb_tb_vu_fil_ppf_wide is

    SIGNAL rst      	: STD_LOGIC;
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg     : STRING(1 to 80);
	SIGNAL test_pass	: BOOLEAN;

    CONSTANT c_fil_ppf_pipeline : t_fil_ppf_pipeline := (1, 1, 1, 1, 1, 1, 0);
    CONSTANT c_fil_ppf_vu : t_fil_ppf := (g_wb_factor, g_nof_chan, g_nof_bands, g_nof_taps, g_nof_streams, g_backoff_w, g_fil_in_dat_w, g_fil_out_dat_w, g_coef_dat_w);

BEGIN
	tb_ut : ENTITY work.tb_fil_ppf_wide
        GENERIC MAP(
            g_big_endian_wb_in => g_big_endian_wb_in,
            g_big_endian_wb_out => g_big_endian_wb_out,
            g_fil_ppf_pipeline => c_fil_ppf_pipeline,
            g_fil_ppf => c_fil_ppf_vu,
            g_coefs_file_prefix => g_coefs_file_prefix,
            g_enable_in_val_gaps => g_enable_in_val_gaps 
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