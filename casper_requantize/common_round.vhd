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

LIBRARY ieee, common_pkg_lib, common_components_lib;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;

ENTITY common_round IS

	--
	-- ISE XST results for rounding 36b --> 18b:
	--    int      clip  -->  slices  FFs  LUTs
	-- 1) signed   TRUE       63      54   80       -- increases with input widths > 18b
	-- 2) signed   FALSE      59      54   73       -- increases with input widths > 18b
	-- 3) unsigned TRUE       34      37   43       -- same for all input widths > 18b
	-- 4) unsigned FALSE      21      37   19       -- same for all input widths > 18b
	--
	-- If the input comes from a product and is rounded to the input width then g_round_clip can safely be FALSE, because e.g. for unsigned
	-- 4b*4b=8b->4b the maximum product is 15*15=225 <= 255-8, so wrapping will never occur.
	-- 

	GENERIC(
		g_representation  : STRING  := "SIGNED"; -- SIGNED (round +-0.5 away from zero to +- infinity) or UNSIGNED rounding (round 0.5 up to + inifinity)
		g_round           : BOOLEAN := TRUE; -- when TRUE round the input, else truncate the input
		g_round_clip      : BOOLEAN := FALSE; -- when TRUE clip rounded input >= +max to avoid wrapping to output -min (signed) or 0 (unsigned)
		g_pipeline_input  : NATURAL := 0; -- >= 0
		g_pipeline_output : NATURAL := 1; -- >= 0, use g_pipeline_input=0 and g_pipeline_output=0 for combinatorial output
		g_in_dat_w        : NATURAL := 36;
		g_out_dat_w       : NATURAL := 18
	);
	PORT(
		clk     : IN  STD_LOGIC;
		clken   : IN  STD_LOGIC := '1';
		in_dat  : IN  STD_LOGIC_VECTOR(g_in_dat_w - 1 DOWNTO 0);
		out_dat : OUT STD_LOGIC_VECTOR(g_out_dat_w - 1 DOWNTO 0)
	);
END;

ARCHITECTURE rtl OF common_round IS

	CONSTANT c_remove_w : INTEGER := g_in_dat_w - g_out_dat_w;

	SIGNAL reg_dat : STD_LOGIC_VECTOR(in_dat'RANGE);
	SIGNAL res_dat : STD_LOGIC_VECTOR(out_dat'RANGE);

BEGIN

	u_input_pipe : ENTITY common_components_lib.common_pipeline
		GENERIC MAP(
			g_representation => g_representation,
			g_pipeline       => g_pipeline_input,
			g_in_dat_w       => g_in_dat_w,
			g_out_dat_w      => g_in_dat_w
		)
		PORT MAP(
			clk     => clk,
			clken   => clken,
			in_dat  => in_dat,
			out_dat => reg_dat
		);

	-- Increase to out_dat width
	no_s : IF c_remove_w <= 0 AND g_representation = "SIGNED" GENERATE
		res_dat <= RESIZE_SVEC(reg_dat, g_out_dat_w);
	END GENERATE;
	no_u : IF c_remove_w <= 0 AND g_representation = "UNSIGNED" GENERATE
		res_dat <= RESIZE_UVEC(reg_dat, g_out_dat_w);
	END GENERATE;

	-- Decrease to out_dat width by c_remove_w number of LSbits
	-- . rounding
	gen_s : IF c_remove_w > 0 AND g_round = TRUE AND g_representation = "SIGNED" GENERATE
		res_dat <= s_round(reg_dat, c_remove_w, g_round_clip);
	END GENERATE;
	gen_u : IF c_remove_w > 0 AND g_round = TRUE AND g_representation = "UNSIGNED" GENERATE
		res_dat <= u_round(reg_dat, c_remove_w, g_round_clip);
	END GENERATE;
	-- . truncating
	gen_t : IF c_remove_w > 0 AND g_round = FALSE GENERATE
		res_dat <= truncate(reg_dat, c_remove_w);
	END GENERATE;

	u_output_pipe : ENTITY common_components_lib.common_pipeline
		GENERIC MAP(
			g_representation => g_representation,
			g_pipeline       => g_pipeline_output,
			g_in_dat_w       => g_out_dat_w,
			g_out_dat_w      => g_out_dat_w
		)
		PORT MAP(
			clk     => clk,
			clken   => clken,
			in_dat  => res_dat,
			out_dat => out_dat
		);

END rtl;
