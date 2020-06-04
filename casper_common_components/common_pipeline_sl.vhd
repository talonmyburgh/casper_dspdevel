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

--! IEEE and common_pkg_lib
LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;

ENTITY common_pipeline_sl IS
	GENERIC(
		g_pipeline    : NATURAL := 1;   --! 0 for wires, > 0 for registers, 
		g_reset_value : NATURAL := 0;   --! 0 or 1, bit reset value,
		g_out_invert  : BOOLEAN := FALSE
	);
	PORT(
		rst     : IN  STD_LOGIC := '0'; --! Reset signal
		clk     : IN  STD_LOGIC; --! Clock input
		clken   : IN  STD_LOGIC := '1'; --! Clock enable signal
		in_clr  : IN  STD_LOGIC := '0'; --! Clear input signal 
		in_en   : IN  STD_LOGIC := '1'; --! Enable input
		in_dat  : IN  STD_LOGIC; --! Signal used to pass data to common_pipeline
		out_dat : OUT STD_LOGIC --! Output valid signal
	);
END common_pipeline_sl;

ARCHITECTURE str OF common_pipeline_sl IS

	SIGNAL in_dat_slv  : STD_LOGIC_VECTOR(0 DOWNTO 0);
	SIGNAL out_dat_slv : STD_LOGIC_VECTOR(0 DOWNTO 0);

BEGIN

	in_dat_slv(0) <= in_dat WHEN g_out_invert = FALSE ELSE NOT in_dat;
	out_dat       <= out_dat_slv(0);

	u_sl : ENTITY work.common_pipeline
		GENERIC MAP(
			g_representation => "UNSIGNED",
			g_pipeline       => g_pipeline,
			g_reset_value    => sel_a_b(g_out_invert, 1 - g_reset_value, g_reset_value),
			g_in_dat_w       => 1,
			g_out_dat_w      => 1
		)
		PORT MAP(
			rst     => rst,
			clk     => clk,
			clken   => clken,
			in_clr  => in_clr,
			in_en   => in_en,
			in_dat  => in_dat_slv,
			out_dat => out_dat_slv
		);

END str;
