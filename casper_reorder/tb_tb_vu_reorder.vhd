-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, vunit_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
context vunit_lib.vunit_context;

ENTITY tb_tb_vu_reorder IS
	GENERIC(
    g_input_bit_width: NATURAL;
    g_nof_inputs: NATURAL;
    g_reorder_map: STRING;
		
    g_reorder_order: NATURAL;
    g_map_latency: NATURAL;
    g_bram_latency: NATURAL;
    g_fanout_latency: NATURAL;
    g_double_buffer: BOOLEAN;
    g_block_ram: BOOLEAN;
    g_software_controlled: BOOLEAN;
    g_mem_filepath: STRING;
		runner_cfg      : string
	);
END tb_tb_vu_reorder;

ARCHITECTURE tb OF tb_tb_vu_reorder IS

	impure function decode(encoded_natural_vector : string) return t_nat_natural_arr is
		variable parts : lines_t := split(encoded_natural_vector, ",");
		variable return_value : t_nat_natural_arr(parts'range);
	begin
		for i in parts'range loop
			return_value(i) := natural'value(parts(i).all);
		end loop;
		return return_value;
	end;

	constant c_reorder_map : t_nat_natural_arr := decode(g_reorder_map);

	SIGNAL rst      	: STD_LOGIC;
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg   : STRING(1 to 80);
	SIGNAL test_pass	: BOOLEAN;
	
	SIGNAL s_test_count : natural := 0;
BEGIN
	
	tb_ut : ENTITY work.tb_reorder
		GENERIC MAP(
			g_input_bit_width => g_input_bit_width,
			g_nof_inputs => g_nof_inputs,
			g_reorder_map => c_reorder_map,

			g_reorder_order => g_reorder_order,
			g_map_latency => g_map_latency,
			g_bram_latency => g_bram_latency,
			g_fanout_latency => g_fanout_latency,
			g_double_buffer => g_double_buffer,
			g_block_ram => g_block_ram,
			g_software_controlled => g_software_controlled,
			g_mem_filepath => g_mem_filepath
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
