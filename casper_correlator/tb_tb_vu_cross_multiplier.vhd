-- @author: Talon Myburgh
-- @company: Mydon Solutions

library ieee, common_pkg_lib, vunit_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use work.correlator_pkg.all;
--context vunit_lib.vunit_context;

entity tb_tb_vu_cross_multiplier is
    GENERIC(
        g_values : string; -- CSV matrix of integers where ; demarcate new rows
        runner_cfg              : string
    );
end tb_tb_vu_cross_multiplier;

architecture tb of tb_tb_vu_cross_multiplier is

    SIGNAL rst      	: STD_LOGIC := '0';
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg     : STRING(1 to 80);
	SIGNAL test_pass	: BOOLEAN;

	impure function decode(encoded_natural_matrix : string) return t_integer_matrix is
	    variable rows  : lines_t := split(encoded_natural_matrix, ";");
		variable columns : lines_t;
		variable return_value : t_integer_matrix(0 TO c_cross_mult_nof_input_streams - 1,0 TO c_cross_mult_aggregation_per_stream - 1);
	begin
		FOR i IN 0 TO c_cross_mult_nof_input_streams - 1 LOOP
		    columns := split(rows(i),",");
		    FOR j IN 0 TO c_cross_mult_aggregation_per_stream - 1 LOOP
		      return_value(i,j) := columns(j);
		    end LOOP;
		end LOOP;
		return return_value;
	end;

	CONSTANT c_values : t_integer_matrix := decode(g_values);
BEGIN
	tb_ut : ENTITY work.tb_cross_multiplier
        GENERIC MAP(
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