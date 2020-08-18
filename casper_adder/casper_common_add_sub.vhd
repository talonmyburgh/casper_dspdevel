--! @file
--! @brief Common adder/subtractor for signed/unsigned values.

-- Copyright 2020
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands

-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at

--    http://www.apache.org/licenses/LICENSE-2.0

-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

--! Libraries: IEEE, common_pkg_lib and common_components_lib
LIBRARY IEEE, common_pkg_lib, common_components_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

--! @dot 
--! digraph common_add_sub {
--!	rankdir="LR";
--! node [shape=box, fontname=Helvetica, fontsize=12,color="black", width = 0.5, height = 1];
--! common_add_sub;
--! node [shape=plaintext];
--! clk;
--! clken;
--! sel_add;
--! in_a;
--! in_b;
--! result;
--! clk -> common_add_sub ;
--! clken -> common_add_sub;
--! sel_add -> common_add_sub;
--! in_a -> common_add_sub;
--! in_b -> common_add_sub;
--! common_add_sub -> result;
--!}
--! @enddot

--! Purpose : Adder with extra functionality
--! Description:
--!   + Allow for function select (subtract or add) with sel_add signal
--!   + Specify input and output widths
--!   + Enable/disable option
--!   + Sum signed or unsigned values
--! Remarks:
--!  + Currently only support for g_out_dat_w=g_in_dat_w and g_out_dat_w=g_in_dat_w+1
--!  + Specifying signed or unsiged is only important if g_out_dat_w > g_in_dat_w. It is not relevant if g_out_dat_w = g_in_dat_w
ENTITY common_add_sub IS
	GENERIC(
		g_direction       : STRING  := "ADD"; --! "ADD", "SUB" or "BOTH" and use sel_add to pick
		g_representation  : STRING  := "SIGNED"; --! "SIGNED" or "UNSIGNED"
		g_pipeline_input  : NATURAL := 0; --! 0 or 1
		g_pipeline_output : NATURAL := 1; --! >= 0
		g_in_dat_w        : NATURAL := 8; --! input data width
		g_out_dat_w       : NATURAL := 9 --! output data width. 
	);
	PORT(
		clk     : IN  STD_LOGIC;        --! input clock source
		clken   : IN  STD_LOGIC := '1'; --! enable process triggering on clock rising edge
		sel_add : IN  STD_LOGIC := '1'; --! decide whether to add or subtract (only used when g_direction is "BOTH")
		in_a    : IN  STD_LOGIC_VECTOR(g_in_dat_w - 1 DOWNTO 0); --! input value A - must be width of g_in_dat_w
		in_b    : IN  STD_LOGIC_VECTOR(g_in_dat_w - 1 DOWNTO 0); --! input value B - must be width of g_in_dat_w
		result  : OUT STD_LOGIC_VECTOR(g_out_dat_w - 1 DOWNTO 0) --! result of A +/- B of width g_out_dat_w
	);
END common_add_sub;

ARCHITECTURE add_sub OF common_add_sub IS

	CONSTANT c_res_w : NATURAL := g_in_dat_w + 1;

	SIGNAL in_a_p : STD_LOGIC_VECTOR(in_a'RANGE);
	SIGNAL in_b_p : STD_LOGIC_VECTOR(in_b'RANGE);

	SIGNAL in_add    : STD_LOGIC;
	SIGNAL sel_add_p : STD_LOGIC;

	SIGNAL result_p : STD_LOGIC_VECTOR(c_res_w - 1 DOWNTO 0);

BEGIN

	in_add <= '1' WHEN g_direction = "ADD" OR (g_direction = "BOTH" AND sel_add = '1') ELSE '0';

	no_input_reg : IF g_pipeline_input = 0 GENERATE -- wired input
		in_a_p    <= in_a;
		in_b_p    <= in_b;
		sel_add_p <= in_add;
	END GENERATE;
	gen_input_reg : IF g_pipeline_input > 0 GENERATE -- register input
		p_reg : PROCESS(clk)
		BEGIN
			IF rising_edge(clk) THEN
				IF clken = '1' THEN
					in_a_p    <= in_a;
					in_b_p    <= in_b;
					sel_add_p <= in_add;
				END IF;
			END IF;
		END PROCESS;
	END GENERATE;

	-- Where the addition/subtraction actually occurs.
	--Signed addition/subtraction.
	gen_signed : IF g_representation = "SIGNED" GENERATE
		result_p <= ADD_SVEC(in_a_p, in_b_p, c_res_w) WHEN sel_add_p = '1' ELSE SUB_SVEC(in_a_p, in_b_p, c_res_w);
	END GENERATE;
	--Unsigned addition/subtraction.
	gen_unsigned : IF g_representation = "UNSIGNED" GENERATE
		result_p <= ADD_UVEC(in_a_p, in_b_p, c_res_w) WHEN sel_add_p = '1' ELSE SUB_UVEC(in_a_p, in_b_p, c_res_w);
	END GENERATE;

	u_output_pipe : ENTITY common_components_lib.common_pipeline -- pipeline output
		GENERIC MAP(
			g_representation => g_representation,
			g_pipeline       => g_pipeline_output, -- 0 for wires, >0 for register stages
			g_in_dat_w       => result'LENGTH,
			g_out_dat_w      => result'LENGTH
		)
		PORT MAP(
			clk     => clk,
			clken   => clken,
			in_dat  => result_p(result'RANGE),
			out_dat => result
		);
END add_sub;
