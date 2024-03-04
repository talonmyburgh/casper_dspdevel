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

ENTITY common_pipeline IS
	GENERIC(
		g_representation : STRING  := "SIGNED"; --! or "UNSIGNED"
		g_pipeline       : NATURAL := 1; --! 0 for wires, > 0 for registers, 
		g_reset_value    : INTEGER := 0;
		g_in_dat_w       : NATURAL := 8;
		g_out_dat_w      : NATURAL := 9
	);
	PORT(
		rst     : IN  STD_LOGIC := '0'; --! Reset signal
		clk     : IN  STD_LOGIC;        --! Input clock signal
		clken   : IN  STD_LOGIC := '1'; --! Enable clock
		in_clr  : IN  STD_LOGIC := '0'; --! Clear input
		in_en   : IN  STD_LOGIC := '1'; --! Enable input
		in_dat  : IN  STD_LOGIC_VECTOR(g_in_dat_w - 1 DOWNTO 0); --! Input data
		out_dat : OUT STD_LOGIC_VECTOR(g_out_dat_w - 1 DOWNTO 0) --! Output data
	);
END common_pipeline;

ARCHITECTURE rtl OF common_pipeline IS

	CONSTANT c_reset_value : STD_LOGIC_VECTOR(out_dat'RANGE) := TO_SVEC(g_reset_value, out_dat'LENGTH);

	TYPE t_out_dat IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(out_dat'RANGE);

	SIGNAL out_dat_p : t_out_dat(0 TO g_pipeline); -- := (OTHERS => c_reset_value);

BEGIN

	gen_pipe_n : IF g_pipeline > 0 GENERATE
		p_clk : PROCESS(clk, rst)
		BEGIN
			--IF rst = '1' THEN
			--	out_dat_p(1 TO g_pipeline) <= (OTHERS => c_reset_value);
			IF rising_edge(clk) THEN
				IF clken = '1' THEN
					IF in_clr = '1' THEN
						out_dat_p(1 TO g_pipeline) <= (OTHERS => c_reset_value);
					ELSIF in_en = '1' THEN
						out_dat_p(1 TO g_pipeline) <= out_dat_p(0 TO g_pipeline - 1);
					END IF;
				END IF;
			END IF;
		END PROCESS;
	END GENERATE;

	out_dat_p(0) <= RESIZE_SVEC(in_dat, out_dat'LENGTH) WHEN g_representation = "SIGNED"
	                ELSE RESIZE_UVEC(in_dat, out_dat'LENGTH) WHEN g_representation = "UNSIGNED"
	              ;

	out_dat <= out_dat_p(g_pipeline);

END rtl;
