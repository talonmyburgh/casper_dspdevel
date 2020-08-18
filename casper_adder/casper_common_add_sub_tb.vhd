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

ENTITY common_add_sub_tb IS
	GENERIC(
		g_direction    : STRING  := "SUB"; -- "SUB", "ADD" or "BOTH"
		s_sel_add      : STRING  := "1"; -- '0' = sub, '1' = add, only valid for g_direction = "BOTH"
		g_pipeline_in  : NATURAL := 0;  -- input pipelining 0 or 1
		g_pipeline_out : NATURAL := 2;  -- output pipelining >= 0
		g_in_dat_w     : NATURAL := 5;
		g_out_dat_w    : NATURAL := 5;  -- g_in_dat_w or g_in_dat_w+1;
		runner_cfg     : string
	);
END common_add_sub_tb;

ARCHITECTURE tb OF common_add_sub_tb IS

	CONSTANT clk_period : TIME    := 10 ns;
	CONSTANT c_pipeline : NATURAL := g_pipeline_in + g_pipeline_out;

	FUNCTION str_to_std(strval : STRING) RETURN STD_LOGIC IS
	BEGIN
		if (strval = "1") then
			return '1';
		elsif (strval = "0") then
			return '0';
		else
			null;
		end if;
	END;

	SIGNAL g_sel_add : STD_LOGIC := '1';

	-- This is function used to generate the expected result for the test bench.
	FUNCTION func_result(in_a, in_b : STD_LOGIC_VECTOR; g_sel_add : std_logic) RETURN STD_LOGIC_VECTOR IS
		VARIABLE v_a, v_b, v_result : INTEGER;
	BEGIN
		-- Calculate expected result
		v_a := TO_SINT(in_a);
		v_b := TO_SINT(in_b);
		IF g_direction = "ADD" THEN
			v_result := v_a + v_b;
		END IF;
		IF g_direction = "SUB" THEN
			v_result := v_a - v_b;
		END IF;
		IF g_direction = "BOTH" AND g_sel_add = '1' THEN
			v_result := v_a + v_b;
		END IF;
		IF g_direction = "BOTH" AND g_sel_add = '0' THEN
			v_result := v_a - v_b;
		END IF;
		-- Wrap to avoid warning: NUMERIC_STD.TO_SIGNED: vector truncated
		IF v_result > 2**(g_out_dat_w - 1) - 1 THEN
			v_result := v_result - 2**g_out_dat_w;
		END IF;
		IF v_result < -2**(g_out_dat_w - 1) THEN
			v_result := v_result + 2**g_out_dat_w;
		END IF;
		RETURN TO_SVEC(v_result, g_out_dat_w);
	END;

	SIGNAL tb_end          : STD_LOGIC := '0';
	SIGNAL rst             : STD_LOGIC;
	SIGNAL clk             : STD_LOGIC := '0';
	SIGNAL in_a            : STD_LOGIC_VECTOR(g_in_dat_w - 1 DOWNTO 0);
	SIGNAL in_b            : STD_LOGIC_VECTOR(g_in_dat_w - 1 DOWNTO 0);
	SIGNAL out_result      : STD_LOGIC_VECTOR(g_out_dat_w - 1 DOWNTO 0); -- combinatorial result
	SIGNAL result_expected : STD_LOGIC_VECTOR(g_out_dat_w - 1 DOWNTO 0); -- pipelined results
	SIGNAL result_rtl      : STD_LOGIC_VECTOR(g_out_dat_w - 1 DOWNTO 0);

BEGIN
	g_sel_add <= str_to_std(s_sel_add);
	clk       <= NOT clk OR tb_end AFTER clk_period / 2;

	-- run 1 us or -all
	p_in_stimuli : PROCESS
	BEGIN
		test_runner_setup(runner, runner_cfg);
		rst  <= '1';
		in_a <= TO_SVEC(0, g_in_dat_w);
		in_b <= TO_SVEC(0, g_in_dat_w);
		WAIT UNTIL rising_edge(clk);
		FOR I IN 0 TO 9 LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;
		rst  <= '0';
		FOR I IN 0 TO 9 LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- Some special combinations
		in_a <= TO_SVEC(2, g_in_dat_w);
		in_b <= TO_SVEC(5, g_in_dat_w);
		WAIT UNTIL rising_edge(clk);
		in_a <= TO_SVEC(2, g_in_dat_w);
		in_b <= TO_SVEC(-5, g_in_dat_w);
		WAIT UNTIL rising_edge(clk);
		in_a <= TO_SVEC(-3, g_in_dat_w);
		in_b <= TO_SVEC(-9, g_in_dat_w);
		WAIT UNTIL rising_edge(clk);
		in_a <= TO_SVEC(-3, g_in_dat_w);
		in_b <= TO_SVEC(9, g_in_dat_w);
		WAIT UNTIL rising_edge(clk);
		in_a <= TO_SVEC(11, g_in_dat_w);
		in_b <= TO_SVEC(15, g_in_dat_w);
		WAIT UNTIL rising_edge(clk);
		in_a <= TO_SVEC(11, g_in_dat_w);
		in_b <= TO_SVEC(-15, g_in_dat_w);
		WAIT UNTIL rising_edge(clk);
		in_a <= TO_SVEC(-11, g_in_dat_w);
		in_b <= TO_SVEC(15, g_in_dat_w);
		WAIT UNTIL rising_edge(clk);
		in_a <= TO_SVEC(-11, g_in_dat_w);
		in_b <= TO_SVEC(-15, g_in_dat_w);
		WAIT UNTIL rising_edge(clk);

		FOR I IN 0 TO 49 LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- All combinations
		FOR I IN -2**(g_in_dat_w - 1) TO 2**(g_in_dat_w - 1) - 1 LOOP
			FOR J IN -2**(g_in_dat_w - 1) TO 2**(g_in_dat_w - 1) - 1 LOOP
				in_a <= TO_SVEC(I, g_in_dat_w);
				in_b <= TO_SVEC(J, g_in_dat_w);
				WAIT UNTIL rising_edge(clk);
			END LOOP;
		END LOOP;
		WAIT UNTIL rising_edge(clk);
		tb_end <= '1';
		test_runner_cleanup(runner);

	END PROCESS;

	out_result <= func_result(in_a, in_b, g_sel_add);

	u_result : ENTITY common_components_lib.common_pipeline
		GENERIC MAP(
			g_representation => "SIGNED",
			g_pipeline       => c_pipeline,
			g_reset_value    => 0,
			g_in_dat_w       => g_out_dat_w,
			g_out_dat_w      => g_out_dat_w
		)
		PORT MAP(
			rst     => rst,
			clk     => clk,
			clken   => '1',
			in_dat  => out_result,
			out_dat => result_expected
		);

	u_dut_rtl : ENTITY work.common_add_sub
		GENERIC MAP(
			g_direction       => g_direction,
			g_representation  => "SIGNED",
			g_pipeline_input  => g_pipeline_in,
			g_pipeline_output => g_pipeline_out,
			g_in_dat_w        => g_in_dat_w,
			g_out_dat_w       => g_out_dat_w
		)
		PORT MAP(
			clk     => clk,
			clken   => '1',
			sel_add => g_sel_add,
			in_a    => in_a,
			in_b    => in_b,
			result  => result_rtl
		);

	p_verify : PROCESS(rst, clk)
	BEGIN
		IF rst = '0' THEN
			IF rising_edge(clk) THEN
				check(result_rtl = result_expected, "Error: wrong RTL result, expected: " & to_hstring(result_expected) & " but got: " & to_hstring(result_rtl));
			END IF;
		END IF;

	END PROCESS;
END tb;
