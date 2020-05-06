/*!
 * @file
 * @brief Common counter with sync or async clear.*/
 
 /* Copyright 2020
 * ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
 * P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 
 *    http://www.apache.org/licenses/LICENSE-2.0
 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/

--! Purpose : Counter with extra options
--! Description:
--!   + default wrap at 2**g_width or special wrap at fixed g_max or dynamically via cnt_max
--!   + default increment +1 or other g_step_size
--!   + external clr
--!   + external load with g_init or dynamically via load
--! Remarks:
--!   If g_max = 2**g_width then use g_max=0 for default wrap and avoid truncation warning.
--!   The check g_max = 2**g_width does not work for g_width >= 31 due to that the INTEGER
--!   range in VHDL is limited to -2**31 to +2**31-1. Therefore detect that g_max = 2**g_width
--!   via ceil_log2(g_max+1)>g_width and use this to init the cnt_max input.

--! Use standard library logic elements and common_pkg_lib
LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.ALL;

ENTITY common_counter IS
	GENERIC(
		g_latency   : NATURAL := 1;     --! default 1 for registered count output, use 0 for immediate combinatorial count output
		g_init      : INTEGER := 0;
		g_width     : NATURAL := 32;
		g_max       : NATURAL := 0;     --! default 0 to disable the g_max setting. 
		g_step_size : INTEGER := 1      --! counting in steps of g_step_size, can be + or -
	);
	PORT(
		rst     : IN  STD_LOGIC                              := '0'; --! either use asynchronous rst or synchronous cnt_clr
		clk     : IN  STD_LOGIC;
		clken   : IN  STD_LOGIC                              := '1';
		cnt_clr : IN  STD_LOGIC                              := '0'; --! synchronous cnt_clr is only interpreted when clken is active
		cnt_ld  : IN  STD_LOGIC                              := '0'; --! cnt_ld loads the output count with the input load value, independent of cnt_en
		cnt_en  : IN  STD_LOGIC                              := '1';
		cnt_max : IN  STD_LOGIC_VECTOR(g_width - 1 DOWNTO 0) := TO_UVEC(sel_a_b(ceil_log2(g_max + 1) > g_width, 0, g_max), g_width); -- see remarks
		load    : IN  STD_LOGIC_VECTOR(g_width - 1 DOWNTO 0) := TO_SVEC(g_init, g_width);
		count   : OUT STD_LOGIC_VECTOR(g_width - 1 DOWNTO 0)
	);
END common_counter;

ARCHITECTURE rtl OF common_counter IS

	CONSTANT zeros    : STD_LOGIC_VECTOR(count'RANGE) := (OTHERS => '0'); --! used to check if cnt_max is zero
	SIGNAL reg_count  : STD_LOGIC_VECTOR(count'RANGE) := TO_SVEC(g_init, g_width); --! in case rst is not used
	SIGNAL nxt_count  : STD_LOGIC_VECTOR(count'RANGE) := TO_SVEC(g_init, g_width); --! to avoid Warning: NUMERIC_STD.">=": metavalue detected, returning FALSE, when using unsigned()
	SIGNAL comb_count : STD_LOGIC_VECTOR(count'RANGE) := TO_SVEC(g_init, g_width); --! to avoid Warning: NUMERIC_STD.">=": metavalue detected, returning FALSE, when using unsigned()

BEGIN

	comb_count <= nxt_count;

	count <= comb_count WHEN g_latency = 0 ELSE reg_count;

	ASSERT g_step_size /= 0 REPORT "common_counter: g_step_size must be /= 0" SEVERITY FAILURE;

	p_clk : PROCESS(rst, clk)
	BEGIN
		IF rst = '1' THEN
			reg_count <= TO_SVEC(g_init, g_width);
		ELSIF rising_edge(clk) THEN
			IF clken = '1' THEN
				reg_count <= nxt_count;
			END IF;
		END IF;
	END PROCESS;

	p_count : PROCESS(reg_count, cnt_clr, cnt_en, cnt_ld, load, cnt_max)
	BEGIN
		nxt_count <= reg_count;
		IF cnt_clr = '1' OR (reg_count = cnt_max AND cnt_max /= zeros) THEN
			nxt_count <= (OTHERS => '0');
		ELSIF cnt_ld = '1' THEN
			nxt_count <= load;
		ELSIF cnt_en = '1' THEN
			nxt_count <= INCR_UVEC(reg_count, g_step_size);
		END IF;
	END PROCESS;

END rtl;
