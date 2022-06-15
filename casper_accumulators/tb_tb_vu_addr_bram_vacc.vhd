-- @author: Talon Myburgh
-- @company: Mydon Solutions

library ieee, common_pkg_lib, vunit_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
context vunit_lib.vunit_context;

entity tb_tb_vu_addr_bram_vacc is
    GENERIC(
        g_vector_length : NATURAL := 8;
        g_bit_w         : NATURAL := 8;
        g_values        : STRING; -- CSV list of naturals
        runner_cfg      : STRING
    );
end tb_tb_vu_addr_bram_vacc;

architecture tb of tb_tb_vu_addr_bram_vacc is

    SIGNAL rst      	: STD_LOGIC := '0';
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg     : STRING(1 to 80);
	SIGNAL test_pass	: BOOLEAN;

	IMPURE FUNCTION decode(encoded_natural_vector : string) return t_integer_arr is
		VARIABLE parts : lines_t := split(encoded_natural_vector, ",");
		VARIABLE return_value : t_integer_arr(parts'range);
	BEGIN
		for i in parts'range loop
			return_value(i) := natural'value(parts(i).all);
		end loop;
		return return_value;
	END;

	CONSTANT c_values : t_integer_arr := decode(g_values);
BEGIN
	tb_ut : ENTITY work.tb_addr_bram_vacc
        GENERIC MAP(
            g_vector_length => g_vector_length,
            g_bit_w_out => 32,
            g_bit_w => g_bit_w,
            g_values => c_values
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