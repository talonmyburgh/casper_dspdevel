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

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
--USE work.common_mem_pkg.ALL;

--! Purpose: Component declarations to check positional mapping
-- Description:
-- Remarks:

PACKAGE common_components_pkg IS

	COMPONENT common_pipeline IS
		GENERIC(
			g_representation : STRING  := "SIGNED"; -- or "UNSIGNED"
			g_pipeline       : NATURAL := 1; -- 0 for wires, > 0 for registers, 
			g_reset_value    : INTEGER := 0;
			g_in_dat_w       : NATURAL := 8;
			g_out_dat_w      : NATURAL := 9
		);
		PORT(
			rst     : IN  STD_LOGIC := '0';
			clk     : IN  STD_LOGIC;
			clken   : IN  STD_LOGIC := '1';
			in_clr  : IN  STD_LOGIC := '0';
			in_en   : IN  STD_LOGIC := '1';
			in_dat  : IN  STD_LOGIC_VECTOR(g_in_dat_w - 1 DOWNTO 0);
			out_dat : OUT STD_LOGIC_VECTOR(g_out_dat_w - 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT common_pipeline_sl IS
		GENERIC(
			g_pipeline    : NATURAL := 1; -- 0 for wires, > 0 for registers, 
			g_reset_value : NATURAL := 0; -- 0 or 1, bit reset value,
			g_out_invert  : BOOLEAN := FALSE
		);
		PORT(
			rst     : IN  STD_LOGIC := '0';
			clk     : IN  STD_LOGIC;
			clken   : IN  STD_LOGIC := '1';
			in_clr  : IN  STD_LOGIC := '0';
			in_en   : IN  STD_LOGIC := '1';
			in_dat  : IN  STD_LOGIC;
			out_dat : OUT STD_LOGIC
		);
	END COMPONENT;

END common_components_pkg;

PACKAGE BODY common_components_pkg IS
END common_components_pkg;
