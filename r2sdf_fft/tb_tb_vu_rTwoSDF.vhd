library ieee, std, common_pkg_lib, vunit_lib;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all; -- @suppress "Deprecated package"
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use common_pkg_lib.common_pkg.all;
use work.rTwoSDFPkg.all;
context vunit_lib.vunit_context;

entity tb_tb_vu_rTwoSDF is
    GENERIC(
        g_use_uniNoise_file : boolean  := true;
        g_in_en             : natural  := 1;     -- 1 = always active, others = random control
        -- generics for rTwoSDF
        g_use_reorder       : boolean  := false;  -- tb supports both true and false
        g_nof_points        : natural  := 1024;
        g_in_dat_w          : natural  := 8;   
        g_out_dat_w         : natural  := 14;   
        g_guard_w           : natural  := 2;      -- guard bits are used to avoid overflow in single FFT stage.
        g_diff_margin       : natural  := 2;
		g_twid_file_stem    : string   := "UNUSED";
        g_file_loc_prefix   : string   := "../../../../../";
        runner_cfg : string
    );
end tb_tb_vu_rTwoSDF;

architecture tb of tb_tb_vu_rTwoSDF is

    SIGNAL rst      	: STD_LOGIC;
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg     : STRING(1 to 80);
	SIGNAL test_pass	: BOOLEAN;

BEGIN
	tb_ut : ENTITY work.tb_rTwoSDF
        GENERIC MAP(
            g_use_uniNoise_file => g_use_uniNoise_file,        
            g_in_en => g_in_en,
            g_use_reorder => g_use_reorder,
            g_nof_points => g_nof_points,
            g_in_dat_w => g_in_dat_w,
            g_out_dat_w => g_out_dat_w,
            g_guard_w => g_guard_w,
            g_diff_margin => g_diff_margin,
            g_file_loc_prefix => g_file_loc_prefix,
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
			END IF;
		END IF;

	END PROCESS;
END tb;