-- @author: Talon Myburgh
-- @company: Mydon Solutions

library ieee, common_pkg_lib, vunit_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use work.correlator_pkg.all;
context vunit_lib.vunit_context;

entity tb_tb_vu_cross_multiplier is
    GENERIC(
        g_values : string; -- CSV matrix of integers where ; demarcate new rows
		g_results : string;
        runner_cfg              : string
    );
end tb_tb_vu_cross_multiplier;

architecture tb of tb_tb_vu_cross_multiplier is

    SIGNAL rst      	: STD_LOGIC := '0';
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg     : STRING(1 to 200);
	SIGNAL test_pass	: BOOLEAN;

		impure function decodeinpt(encoded_natural_matrix : string) return t_natural_matrix is
	    VARIABLE parts : lines_t := split(encoded_natural_matrix, ",");
		VARIABLE row : NATURAL := 0;
		VARIABLE col : NATURAL := 0;
		VARIABLE new_row : BOOLEAN := FALSE;
		variable return_value : t_natural_matrix(0 TO c_cross_mult_nof_input_streams - 1,0 TO c_cross_mult_aggregation_per_stream - 1);
	begin

		for i in parts'range loop

			return_value(row, col) := integer'value(parts(i).all);
			new_row := (col = c_cross_mult_aggregation_per_stream - 1) AND (row /= c_cross_mult_nof_input_streams - 1);
			if new_row then
				row := row + 1;
				col := 0;
			else
				col := col + 1;
			end if;
		end loop;
		return return_value;
	end;
		impure function decodeoutpt(encoded_natural_matrix : string) return t_natural_matrix is
	    VARIABLE parts : lines_t := split(encoded_natural_matrix, ",");
		VARIABLE row : NATURAL := 0;
		VARIABLE col : NATURAL := 0;
		VARIABLE new_row : BOOLEAN := FALSE;
		variable return_value : t_natural_matrix (0 TO c_cross_mult_nof_output_streams - 1, 0 TO c_cross_mult_aggregation_per_stream - 1);
	begin
		for i in parts'range loop
		
			return_value(row, col) := integer'value(parts(i).all);
			new_row := (col = c_cross_mult_aggregation_per_stream - 1) AND (row /= c_cross_mult_nof_output_streams - 1);
			if new_row then
				row := row + 1;
				col := 0;
			else
				col := col + 1;
			end if;
		end loop;
		return return_value;
	end;

	CONSTANT c_values : t_natural_matrix := decodeinpt(g_values);
	CONSTANT c_results : t_natural_matrix := decodeoutpt(g_results);
BEGIN
	tb_ut : ENTITY work.tb_cross_multiplier
        GENERIC MAP(
            g_values => c_values,
			g_results => c_results
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