library ieee, common_pkg_lib, vunit_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
context vunit_lib.vunit_context;

entity tb_tb_vu_pulse_ext is
    GENERIC(
        g_extension : NATURAL;
        runner_cfg	: string
    );
end tb_tb_vu_pulse_ext;

architecture tb of tb_tb_vu_pulse_ext is

    SIGNAL rst      	: STD_LOGIC := '0';
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg     : STRING(1 to 80);
	SIGNAL test_pass	: BOOLEAN;

BEGIN
	tb_ut : ENTITY work.tb_pulse_ext
        GENERIC MAP(
            g_extension => g_extension
        )
		PORT MAP(
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

	p_verify : PROCESS(clk)
	BEGIN
		IF rising_edge(clk) THEN
			check(test_pass, "Test Failed: " & test_msg);
		END IF;
	END PROCESS;
END tb;