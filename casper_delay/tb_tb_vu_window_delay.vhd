LIBRARY IEEE, vunit_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
context vunit_lib.vunit_context;

ENTITY tb_tb_vu_window_delay IS
	GENERIC(
        g_delay : NATURAL := 8;
        runner_cfg     : string
	);
END tb_tb_vu_window_delay;

ARCHITECTURE tb OF tb_tb_vu_window_delay IS

	SIGNAL rst      	: STD_LOGIC;
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg     : STRING(1 to 80);
	SIGNAL test_pass	: BOOLEAN;
	
	SIGNAL s_test_count : natural := 0;
BEGIN
	
    tb_window_delay_inst : entity work.tb_window_delay
        generic map(
            g_delay => g_delay
        )
        port map(
            o_rst       => rst,
            o_clk       => clk,
            o_tb_end    => tb_end,
            o_test_msg  => test_msg,
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
