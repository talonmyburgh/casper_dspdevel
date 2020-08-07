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

-- Purpose : Switch output high or low
-- Description:
-- . The output goes high when switch_high='1' and low when switch_low='1'.
-- . If g_or_high is true then the output follows the switch_high immediately,
--   else it goes high in the next clk cycle.
-- . If g_and_low is true then the output follows the switch_low immediately,
--   else it goes low in the next clk cycle.
--   The g_priority_lo defines which input has priority when switch_high and
--   switch_low are active simultaneously.

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

ENTITY common_switch IS
	GENERIC(
		g_rst_level   : STD_LOGIC := '0'; -- Defines the output level at reset.
		g_priority_lo : BOOLEAN   := TRUE; -- When TRUE then input switch_low has priority, else switch_high. Don't care when switch_high and switch_low are pulses that do not occur simultaneously.
		g_or_high     : BOOLEAN   := FALSE; -- When TRUE and priority hi then the registered switch_level is OR-ed with the input switch_high to get out_level, else out_level is the registered switch_level
		g_and_low     : BOOLEAN   := FALSE -- When TRUE and priority lo then the registered switch_level is AND-ed with the input switch_low to get out_level, else out_level is the registered switch_level
	);
	PORT(
		rst         : IN  STD_LOGIC;
		clk         : IN  STD_LOGIC;
		clken       : IN  STD_LOGIC := '1';
		switch_high : IN  STD_LOGIC;    -- A pulse on switch_high makes the out_level go high
		switch_low  : IN  STD_LOGIC;    -- A pulse on switch_low makes the out_level go low
		out_level   : OUT STD_LOGIC
	);
END;

ARCHITECTURE rtl OF common_switch IS

	SIGNAL switch_level     : STD_LOGIC := g_rst_level;
	SIGNAL nxt_switch_level : STD_LOGIC;

BEGIN

	gen_wire : IF g_or_high = FALSE AND g_and_low = FALSE GENERATE
		out_level <= switch_level;
	END GENERATE;

	gen_or : IF g_or_high = TRUE AND g_and_low = FALSE GENERATE
		out_level <= switch_level OR switch_high;
	END GENERATE;

	gen_and : IF g_or_high = FALSE AND g_and_low = TRUE GENERATE
		out_level <= switch_level AND (NOT switch_low);
	END GENERATE;

	gen_or_and : IF g_or_high = TRUE AND g_and_low = TRUE GENERATE
		out_level <= (switch_level OR switch_high) AND (NOT switch_low);
	END GENERATE;

	p_reg : PROCESS(rst, clk)
	BEGIN
		IF rst = '1' THEN
			switch_level <= g_rst_level;
		ELSIF rising_edge(clk) THEN
			IF clken = '1' THEN
				switch_level <= nxt_switch_level;
			END IF;
		END IF;
	END PROCESS;

	p_switch_level : PROCESS(switch_level, switch_low, switch_high)
	BEGIN
		nxt_switch_level <= switch_level;
		IF g_priority_lo = TRUE THEN
			IF switch_low = '1' THEN
				nxt_switch_level <= '0';
			ELSIF switch_high = '1' THEN
				nxt_switch_level <= '1';
			END IF;
		ELSE
			IF switch_high = '1' THEN
				nxt_switch_level <= '1';
			ELSIF switch_low = '1' THEN
				nxt_switch_level <= '0';
			END IF;
		END IF;
	END PROCESS;
END rtl;
