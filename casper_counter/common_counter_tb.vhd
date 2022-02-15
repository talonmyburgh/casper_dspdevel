-------------------------------------------------------------------------------
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
-------------------------------------------------------------------------------

--! Libraries IEEE, common_pkg_lib and VUnit
LIBRARY IEEE, common_pkg_lib, vunit_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
context vunit_lib.vunit_context;

ENTITY common_counter_tb IS
	GENERIC(runner_cfg : string);
END common_counter_tb;

ARCHITECTURE tb OF common_counter_tb IS

	CONSTANT clk_period : TIME := 10 ns;

	CONSTANT c_cnt_init : NATURAL := 3;
	CONSTANT c_cnt_w    : NATURAL := 5;

	SIGNAL rst : STD_LOGIC;
	SIGNAL clk : STD_LOGIC := '0';

	SIGNAL cnt_clr  : STD_LOGIC                              := '0'; --! synchronous cnt_clr is only interpreted when clken is active
	SIGNAL cnt_ld   : STD_LOGIC                              := '0'; --! cnt_ld loads the output count with the input load value, independent of cnt_en
	SIGNAL cnt_en   : STD_LOGIC                              := '1';
	SIGNAL load     : STD_LOGIC_VECTOR(c_cnt_w - 1 DOWNTO 0) := TO_UVEC(c_cnt_init, c_cnt_w);
	SIGNAL count    : STD_LOGIC_VECTOR(c_cnt_w - 1 DOWNTO 0);
	SIGNAL cnt_max  : STD_LOGIC_VECTOR(c_cnt_w - 1 DOWNTO 0);
	SIGNAL stdcheck : STD_LOGIC_VECTOR(c_cnt_w - 1 downto 0) := "01100";
BEGIN

	clk <= NOT clk AFTER clk_period / 2;
	rst <= '1', '0' AFTER clk_period * 3;

	-- run 1 us
	p_in_stimuli : PROCESS
	BEGIN
		test_runner_setup(runner, runner_cfg);
		cnt_clr <= '0';
		cnt_ld  <= '0';
		cnt_en  <= '0';
		cnt_max <= (OTHERS => '0');
		WAIT UNTIL rst = '0';
		WAIT UNTIL rising_edge(clk);

		-- Start counting
		cnt_en <= '1';
		FOR I IN 0 TO 9 LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;
		check(count = stdcheck, "Invalid count value. Expected: " & to_hstring(stdcheck) & " but got: " & to_hstring(count));

		-- Reload counter
		cnt_ld <= '1';
		WAIT UNTIL rising_edge(clk);
		cnt_ld <= '0';
		FOR I IN 0 TO 9 LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;
		check(count = stdcheck, "Invalid count value. Expected: " & to_hstring(stdcheck) & " but got: " & to_hstring(count));
		-- briefly stop counting
		cnt_en <= '0';
		WAIT UNTIL rising_edge(clk);
		-- countinue counting    
		cnt_en <= '1';
		FOR I IN 0 TO 9 LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- set the cnt_max
		cnt_max <= TO_UVEC(2**(c_cnt_w - 1), c_cnt_w);
		wait for clk_period * 5;
		test_runner_cleanup(runner);
	END PROCESS;

	-- device under test
	u_dut : ENTITY work.common_counter
		GENERIC MAP(
			g_init      => c_cnt_init,
			g_width     => c_cnt_w,
			g_step_size => 1
		)
		PORT MAP(
			rst     => rst,
			clk     => clk,
			cnt_clr => cnt_clr,
			cnt_ld  => cnt_ld,
			cnt_en  => cnt_en,
			cnt_max => cnt_max,
			load    => load,
			count   => count
		);

END tb;

