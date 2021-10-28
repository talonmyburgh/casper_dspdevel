-------------------------------------------------------------------------------
--
-- Copyright 2020
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--     http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-------------------------------------------------------------------------------

LIBRARY IEEE, common_pkg_lib, common_components_lib, vunit_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
context vunit_lib.vunit_context;

ENTITY tb_tb_vu_common_add_sub IS
	GENERIC(
		g_direction    : STRING  := "SUB"; -- "SUB", "ADD" or "BOTH"
		g_sel_add      : NATURAL := 1; -- 0 = sub, 1 = add, only valid for g_direction = "BOTH"
		g_pipeline_in  : NATURAL := 0;  -- input pipelining 0 or 1
		g_pipeline_out : NATURAL := 2;  -- output pipelining >= 0
		g_in_dat_w     : NATURAL := 5;
		g_out_dat_w    : NATURAL := 5;  -- g_in_dat_w or g_in_dat_w+1;
		g_a_val_min    : INTEGER := 0;  -- -(2**(g_in_dat_w - 1)) if left as zero
		g_a_val_max    : INTEGER := 0;  -- 2**(g_in_dat_w - 1) - 1 if left as zero
		g_b_val_min    : INTEGER := 0;  -- -(2**(g_in_dat_w - 1)) if left as zero
		g_b_val_max    : INTEGER := 0;  -- 2**(g_in_dat_w - 1) - 1 if left as zero
		runner_cfg     : string
	);
END tb_tb_vu_common_add_sub;

ARCHITECTURE tb OF tb_tb_vu_common_add_sub IS

	SIGNAL rst      	: STD_LOGIC;
	SIGNAL clk      	: STD_LOGIC;
	SIGNAL tb_end   	: STD_LOGIC;
	SIGNAL test_msg   : STRING(1 to 80);
	SIGNAL test_pass	: BOOLEAN;
	
	SIGNAL s_test_count : natural := 0;
BEGIN
	
	tb_ut : ENTITY work.tb_common_add_sub
		GENERIC MAP(
			g_direction			=> g_direction,
			g_sel_add				=> sel_a_b(g_sel_add, '1',  '0'),
			g_pipeline_in		=> g_pipeline_in,
			g_pipeline_out	=> g_pipeline_out,
			g_in_dat_w			=> g_in_dat_w,
			g_out_dat_w			=> g_out_dat_w,
			g_a_val_min			=> g_a_val_min,
			g_a_val_max			=> g_a_val_max,
			g_b_val_min			=> g_b_val_min,
			g_b_val_max			=> g_b_val_max
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
