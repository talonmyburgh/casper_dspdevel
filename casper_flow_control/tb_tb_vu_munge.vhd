library ieee, common_pkg_lib, vunit_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
context vunit_lib.vunit_context;

entity tb_tb_vu_munge is
    GENERIC(
        g_number_of_divisions : NATURAL;
        g_division_size_bits : NATURAL;
        g_order : string; -- CSV list of naturals
        g_values : string; -- CSV list of naturals
        runner_cfg              : string
    );
end tb_tb_vu_munge;

architecture tb of tb_tb_vu_munge is

    SIGNAL rst      	: STD_LOGIC := '0';
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg     : STRING(1 to 255);
	SIGNAL test_pass	: BOOLEAN;

	impure function decode(encoded_natural_vector : string) return t_natural_arr is
		variable parts : lines_t := split(encoded_natural_vector, ",");
		variable return_value : t_natural_arr(parts'range);
	begin
		for i in parts'range loop
			return_value(i) := natural'value(parts(i).all);
		end loop;

		return return_value;
	end;

	CONSTANT c_order : t_natural_arr(g_number_of_divisions-1 downto 0) := decode(g_order);
	CONSTANT c_values : t_natural_arr(g_number_of_divisions-1 downto 0) := decode(g_values);
BEGIN
	tb_ut : ENTITY work.tb_munge
        GENERIC MAP(
            g_number_of_divisions => g_number_of_divisions,
            g_division_size_bits => g_division_size_bits,
            g_order => c_order,
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