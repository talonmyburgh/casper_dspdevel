LIBRARY IEEE, common_pkg_lib, vunit_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
context vunit_lib.vunit_context;

ENTITY tb_tb_vu_common_mult IS
	GENERIC(
		g_in_dat_w         : NATURAL := 4;
        g_out_dat_w        : NATURAL := 8;       -- g_in_dat_w*2 for multiply and +1 for adder
        g_pipeline_input   : NATURAL := 1;
        g_pipeline_product : NATURAL := 0;
  	    g_pipeline_output  : NATURAL := 1;
		g_a_val_min        : INTEGER := 0;            -- -(2**(g_in_dat_w - 1)) if left as zero
		g_a_val_max        : INTEGER := 0;            -- 2**(g_in_dat_w - 1) - 1 if left as zero
		g_b_val_min        : INTEGER := 0;            -- -(2**(g_in_dat_w - 1)) if left as zero
		g_b_val_max        : INTEGER := 0;            -- 2**(g_in_dat_w - 1) - 1 if left as zero
		runner_cfg     	   : string
	);
END tb_tb_vu_common_mult;

ARCHITECTURE tb OF tb_tb_vu_common_mult IS

SIGNAL rst      	: STD_LOGIC;
SIGNAL clk      	: STD_LOGIC;
SIGNAL tb_end   	: STD_LOGIC;
SIGNAL test_msg   	: STRING(1 to 80);
SIGNAL test_pass	: BOOLEAN;

SIGNAL s_test_count : natural := 0;BEGIN

tb_ut : ENTITY work.tb_common_mult
	GENERIC MAP(
		g_in_dat_w         => g_in_dat_w,        
		g_out_dat_w        => g_out_dat_w,           -- g_in_dat_w*2 for multiply and +1 for adder
		g_pipeline_input   => g_pipeline_input,  
		g_pipeline_product => g_pipeline_product,
		g_pipeline_output  => g_pipeline_output, 
		g_a_val_min        => g_a_val_min,           -- -(2**(g_in_dat_w - 1)) if left as zero
		g_a_val_max        => g_a_val_max,           -- 2**(g_in_dat_w - 1) - 1 if left as zero
		g_b_val_min        => g_b_val_min,           -- -(2**(g_in_dat_w - 1)) if left as zero
		g_b_val_max        => g_b_val_max            -- 2**(g_in_dat_w - 1) - 1 if left as zero
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
				IF tb_end = '1' THEN
					report "Tests completed: " & integer'image(s_test_count+1);
				END IF;
				s_test_count <= 1;
			END IF;
		END IF;
	END PROCESS;
END tb;