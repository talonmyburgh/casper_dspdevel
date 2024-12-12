LIBRARY IEEE, common_pkg_lib, vunit_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
context vunit_lib.vunit_context;

ENTITY tb_tb_vu_bus_mux IS
	GENERIC(
        g_delay         : NATURAL := 6;
        g_nof_inputs 	: NATURAL := 4;
        g_bit_width 	: NATURAL := 4;
		runner_cfg      : string
	);
END tb_tb_vu_bus_mux;

ARCHITECTURE tb OF tb_tb_vu_bus_mux IS

	SIGNAL rst      	: STD_LOGIC;
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg   : STRING(1 to 80);
	SIGNAL test_pass	: BOOLEAN;
	
	SIGNAL s_test_count : natural := 0;
BEGIN
	
	tb_ut : ENTITY work.tb_bus_mux
		GENERIC MAP(
			g_delay     => g_delay,
			g_nof_inputs=> g_nof_inputs,
			g_bit_width	=> g_bit_width
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


	p_verify : PROCESS(rst, clk)
	BEGIN
		IF rst = '0' THEN
			IF rising_edge(clk) THEN
				check(test_pass, "Test Failed: " & test_msg);
				IF tb_end THEN
					report "Tests completed: " & integer'image(s_test_count+1);
				END IF;
				s_test_count <= 1;
			END IF;
		END IF;

	END PROCESS;
END tb;
