
LIBRARY IEEE, common_pkg_lib, common_components_lib, vunit_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
context vunit_lib.vunit_context;

ENTITY tb_tb_vu_common_multiplexer IS
	GENERIC(
    g_pipeline_demux_in  : NATURAL := 1;
    g_pipeline_demux_out : NATURAL := 1;
    g_nof_streams        : NATURAL := 3;
    g_pipeline_mux_in    : NATURAL := 1;
    g_pipeline_mux_out   : NATURAL := 1;
    g_dat_w              : NATURAL := 8;
    g_random_in_val      : BOOLEAN := FALSE;
    g_test_nof_cycles    : NATURAL := 500;
		runner_cfg     : string
	);
END tb_tb_vu_common_multiplexer;

ARCHITECTURE tb OF tb_tb_vu_common_multiplexer IS

	SIGNAL rst      	: STD_LOGIC;
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg   : STRING(1 to 120);
	SIGNAL test_pass	: BOOLEAN;
	
	SIGNAL s_test_count : natural := 0;
BEGIN
	
	tb_ut : ENTITY work.tb_common_multiplexer
		GENERIC MAP(
			g_pipeline_demux_in  => g_pipeline_demux_in,
			g_pipeline_demux_out => g_pipeline_demux_out,
			g_nof_streams        => g_nof_streams,
			g_pipeline_mux_in    => g_pipeline_mux_in,
			g_pipeline_mux_out   => g_pipeline_mux_out,
			g_dat_w              => g_dat_w,
			g_random_in_val      => g_random_in_val,
			g_test_nof_cycles    => g_test_nof_cycles
		)
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
				IF tb_end THEN
					report "Tests completed: " & integer'image(s_test_count+1);
				END IF;
				s_test_count <= 1;
			END IF;
		END IF;

	END PROCESS;
END tb;
