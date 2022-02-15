LIBRARY IEEE, common_pkg_lib, vunit_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
context vunit_lib.vunit_context;

entity tb_tb_vu_common_paged_ram_crw_crw is
    GENERIC(
    runner_cfg : string
    );
end tb_tb_vu_common_paged_ram_crw_crw;

architecture tb of tb_tb_vu_common_paged_ram_crw_crw is

    SIGNAL rst      	: STD_LOGIC;
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg   : STRING(1 to 80);
	SIGNAL test_pass	: BOOLEAN;

BEGIN
	tb_ut : ENTITY work.tb_common_paged_ram_crw_crw
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