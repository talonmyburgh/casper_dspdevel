LIBRARY IEEE, vunit_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
context vunit_lib.vunit_context;

ENTITY tb_tb_vu_power IS
	GENERIC(
        g_bit_width_in : NATURAL := 8;
        g_add_latency  : NATURAL := 2;
        g_mult_latency : NATURAL := 3;
        g_use_dsp      : STRING  := "NO";

        g_value_re     : INTEGER := 9;
        g_value_im     : INTEGER := 3;
        runner_cfg     : string
	);
END tb_tb_vu_power;

ARCHITECTURE tb OF tb_tb_vu_power IS

	SIGNAL rst      	: STD_LOGIC;
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg     : STRING(1 to 80);
	SIGNAL test_pass	: BOOLEAN;
	
	SIGNAL s_test_count : natural := 0;
BEGIN
	
    tb_power_inst : entity work.tb_power
        generic map(
            g_bit_width_in => g_bit_width_in,
            g_add_latency  => g_add_latency,
            g_mult_latency => g_mult_latency,
            g_use_dsp      => g_use_dsp,
            g_value_re     => g_value_re,
            g_value_im     => g_value_im
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
