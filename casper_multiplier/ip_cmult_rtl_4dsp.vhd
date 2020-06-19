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
--! @file
--! @brief RTL Complex Multiplier using 4 mults and 2 adds -> 4 dsp48 chips

--! Library IEEE
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

--! Function: Signed complex multiply
--!   p = a * b       when g_conjugate_b = FALSE
--!     = (ar + j ai) * (br + j bi)
--!     =  ar*br - ai*bi + j ( ar*bi + ai*br)
--!
--!   p = a * conj(b) when g_conjugate_b = TRUE
--!     = (ar + j ai) * (br - j bi)
--!     =  ar*br + ai*bi + j (-ar*bi + ai*br)
--! This RTL complex multiply is unlikely to be implemented in DSP48.
--! Use inference version if that is required.

--! @dot 
--! digraph ip_mult_rtl {
--!	rankdir="LR";
--! node [shape=box, fontname=Helvetica, fontsize=12,color="black"];
--! ip_mult_rtl;
--! node [shape=plaintext];
--! in_ar;
--! in_ai;
--! in_br;
--! in_bi;
--! clk;
--! rst;
--! clken;
--! result_re;
--! result_im;
--! clk -> ip_mult_rtl;
--! clken -> ip_mult_rtl;
--! in_ar -> ip_mult_rtl;
--! in_ai -> ip_mult_rtl;
--! in_br -> ip_mult_rtl;
--! in_bi -> ip_mult_rtl;
--! rst -> ip_mult_rtl;
--! ip_mult_rtl -> result_re;
--! ip_mult_rtl -> result_im;
--!}
--! @enddot

ENTITY ip_cmult_rtl_4dsp IS
	GENERIC(
		g_in_a_w           : POSITIVE;  --! A input bit width
		g_in_b_w           : POSITIVE;  --! B input bit width
		g_out_p_w          : POSITIVE;  --! default use g_out_p_w = g_in_a_w+g_in_b_w = c_prod_w
		g_conjugate_b      : BOOLEAN := FALSE; --! Whether or not to conjugate B value
		g_pipeline_input   : NATURAL := 1; --! 0 or 1
		g_pipeline_product : NATURAL := 0; --! 0 or 1
		g_pipeline_adder   : NATURAL := 1; --! 0 or 1
		g_pipeline_output  : NATURAL := 1 --! >= 0
	);
	PORT(
		rst       : IN  STD_LOGIC := '0'; --! Reset signal
		clk       : IN  STD_LOGIC;      --! Input clock signal
		clken     : IN  STD_LOGIC := '1'; --! Clock enable
		in_ar     : IN  STD_LOGIC_VECTOR(g_in_a_w - 1 DOWNTO 0); --! Real input A
		in_ai     : IN  STD_LOGIC_VECTOR(g_in_a_w - 1 DOWNTO 0); --! Imaginary input A
		in_br     : IN  STD_LOGIC_VECTOR(g_in_b_w - 1 DOWNTO 0); --! Real input B
		in_bi     : IN  STD_LOGIC_VECTOR(g_in_b_w - 1 DOWNTO 0); --! Imaginary input B
		result_re : OUT STD_LOGIC_VECTOR(g_out_p_w - 1 DOWNTO 0); --! Real result
		result_im : OUT STD_LOGIC_VECTOR(g_out_p_w - 1 DOWNTO 0) --! Imaginary result
	);
END ip_cmult_rtl_4dsp;

ARCHITECTURE str OF ip_cmult_rtl_4dsp IS

	FUNCTION RESIZE_NUM(s : SIGNED; w : NATURAL) RETURN SIGNED IS
	BEGIN
		-- extend sign bit or keep LS part
		IF w > s'LENGTH THEN
			RETURN RESIZE(s, w);        -- extend sign bit
		ELSE
			RETURN SIGNED(RESIZE(UNSIGNED(s), w)); -- keep LSbits (= vec[w-1:0])
		END IF;
	END;

	CONSTANT c_prod_w : NATURAL := g_in_a_w + g_in_b_w;
	CONSTANT c_sum_w  : NATURAL := c_prod_w + 1;

	--  CONSTANT c_re_add_sub : STRING := sel_a_b(g_conjugate_b, "ADD", "SUB");
	--  CONSTANT c_im_add_sub : STRING := sel_a_b(g_conjugate_b, "SUB", "ADD");

	-- registers
	SIGNAL reg_ar         : SIGNED(g_in_a_w - 1 DOWNTO 0);
	SIGNAL reg_ai         : SIGNED(g_in_a_w - 1 DOWNTO 0);
	SIGNAL reg_br         : SIGNED(g_in_b_w - 1 DOWNTO 0);
	SIGNAL reg_bi         : SIGNED(g_in_b_w - 1 DOWNTO 0);
	SIGNAL reg_prod_ar_br : SIGNED(c_prod_w - 1 DOWNTO 0); -- re
	SIGNAL reg_prod_ai_bi : SIGNED(c_prod_w - 1 DOWNTO 0);
	SIGNAL reg_prod_ai_br : SIGNED(c_prod_w - 1 DOWNTO 0); -- im
	SIGNAL reg_prod_ar_bi : SIGNED(c_prod_w - 1 DOWNTO 0);
	SIGNAL reg_sum_re     : SIGNED(c_sum_w - 1 DOWNTO 0);
	SIGNAL reg_sum_im     : SIGNED(c_sum_w - 1 DOWNTO 0);
	SIGNAL reg_result_re  : SIGNED(g_out_p_w - 1 DOWNTO 0);
	SIGNAL reg_result_im  : SIGNED(g_out_p_w - 1 DOWNTO 0);

	-- combinatorial
	SIGNAL nxt_ar         : SIGNED(g_in_a_w - 1 DOWNTO 0);
	SIGNAL nxt_ai         : SIGNED(g_in_a_w - 1 DOWNTO 0);
	SIGNAL nxt_br         : SIGNED(g_in_b_w - 1 DOWNTO 0);
	SIGNAL nxt_bi         : SIGNED(g_in_b_w - 1 DOWNTO 0);
	SIGNAL nxt_prod_ar_br : SIGNED(c_prod_w - 1 DOWNTO 0); -- re
	SIGNAL nxt_prod_ai_bi : SIGNED(c_prod_w - 1 DOWNTO 0);
	SIGNAL nxt_prod_ai_br : SIGNED(c_prod_w - 1 DOWNTO 0); -- im
	SIGNAL nxt_prod_ar_bi : SIGNED(c_prod_w - 1 DOWNTO 0);
	SIGNAL nxt_sum_re     : SIGNED(c_sum_w - 1 DOWNTO 0);
	SIGNAL nxt_sum_im     : SIGNED(c_sum_w - 1 DOWNTO 0);
	SIGNAL nxt_result_re  : SIGNED(g_out_p_w - 1 DOWNTO 0);
	SIGNAL nxt_result_im  : SIGNED(g_out_p_w - 1 DOWNTO 0);

	-- the active signals
	SIGNAL ar         : SIGNED(g_in_a_w - 1 DOWNTO 0);
	SIGNAL ai         : SIGNED(g_in_a_w - 1 DOWNTO 0);
	SIGNAL br         : SIGNED(g_in_b_w - 1 DOWNTO 0);
	SIGNAL bi         : SIGNED(g_in_b_w - 1 DOWNTO 0);
	SIGNAL prod_ar_br : SIGNED(c_prod_w - 1 DOWNTO 0); -- re
	SIGNAL prod_ai_bi : SIGNED(c_prod_w - 1 DOWNTO 0);
	SIGNAL prod_ai_br : SIGNED(c_prod_w - 1 DOWNTO 0); -- im
	SIGNAL prod_ar_bi : SIGNED(c_prod_w - 1 DOWNTO 0);
	SIGNAL sum_re     : SIGNED(c_sum_w - 1 DOWNTO 0);
	SIGNAL sum_im     : SIGNED(c_sum_w - 1 DOWNTO 0);

BEGIN

	------------------------------------------------------------------------------
	-- Registers
	------------------------------------------------------------------------------

	-- Put all potential registers in a single process for optimal DSP inferrence
	-- Use rst only if it is supported by the DSP primitive, else leave it at '0'
	p_reg : PROCESS(clk)
	BEGIN
		IF rising_edge(clk) THEN
			IF rst = '1' THEN
				reg_ar         <= (OTHERS => '0');
				reg_ai         <= (OTHERS => '0');
				reg_br         <= (OTHERS => '0');
				reg_bi         <= (OTHERS => '0');
				reg_prod_ar_br <= (OTHERS => '0');
				reg_prod_ai_bi <= (OTHERS => '0');
				reg_prod_ai_br <= (OTHERS => '0');
				reg_prod_ar_bi <= (OTHERS => '0');
				reg_sum_re     <= (OTHERS => '0');
				reg_sum_im     <= (OTHERS => '0');
				reg_result_re  <= (OTHERS => '0');
				reg_result_im  <= (OTHERS => '0');
			ELSIF clken = '1' THEN
				reg_ar         <= nxt_ar; -- inputs
				reg_ai         <= nxt_ai;
				reg_br         <= nxt_br;
				reg_bi         <= nxt_bi;
				reg_prod_ar_br <= nxt_prod_ar_br; -- products for re
				reg_prod_ai_bi <= nxt_prod_ai_bi;
				reg_prod_ai_br <= nxt_prod_ai_br; -- products for im
				reg_prod_ar_bi <= nxt_prod_ar_bi;
				reg_sum_re     <= nxt_sum_re; -- sum
				reg_sum_im     <= nxt_sum_im;
				reg_result_re  <= nxt_result_re; -- result sum after optional register stage
				reg_result_im  <= nxt_result_im;
			END IF;
		END IF;
	END PROCESS;

	------------------------------------------------------------------------------
	-- Inputs
	------------------------------------------------------------------------------

	nxt_ar <= SIGNED(in_ar);
	nxt_ai <= SIGNED(in_ai);
	nxt_br <= SIGNED(in_br);
	nxt_bi <= SIGNED(in_bi);

	no_input_reg : IF g_pipeline_input = 0 GENERATE -- wired
		ar <= nxt_ar;
		ai <= nxt_ai;
		br <= nxt_br;
		bi <= nxt_bi;
	END GENERATE;

	gen_input_reg : IF g_pipeline_input > 0 GENERATE -- register input
		ar <= reg_ar;
		ai <= reg_ai;
		br <= reg_br;
		bi <= reg_bi;
	END GENERATE;

	------------------------------------------------------------------------------
	-- Products
	------------------------------------------------------------------------------

	nxt_prod_ar_br <= ar * br;          -- products for re
	nxt_prod_ai_bi <= ai * bi;
	nxt_prod_ai_br <= ai * br;          -- products for im
	nxt_prod_ar_bi <= ar * bi;

	no_product_reg : IF g_pipeline_product = 0 GENERATE -- wired
		prod_ar_br <= nxt_prod_ar_br;
		prod_ai_bi <= nxt_prod_ai_bi;
		prod_ai_br <= nxt_prod_ai_br;
		prod_ar_bi <= nxt_prod_ar_bi;
	END GENERATE;
	gen_product_reg : IF g_pipeline_product > 0 GENERATE -- register
		prod_ar_br <= reg_prod_ar_br;
		prod_ai_bi <= reg_prod_ai_bi;
		prod_ai_br <= reg_prod_ai_br;
		prod_ar_bi <= reg_prod_ar_bi;
	END GENERATE;

	------------------------------------------------------------------------------
	-- Sum
	------------------------------------------------------------------------------

	-- Re
	-- . "ADD" for a*conj(b) : ar*br + ai*bi
	-- . "SUB" for a*b       : ar*br - ai*bi
	gen_re_add : IF g_conjugate_b GENERATE
		nxt_sum_re <= RESIZE_NUM(prod_ar_br, c_sum_w) + prod_ai_bi;
	END GENERATE;
	gen_re_sub : IF NOT g_conjugate_b GENERATE
		nxt_sum_re <= RESIZE_NUM(prod_ar_br, c_sum_w) - prod_ai_bi;
	END GENERATE;

	-- Im
	-- . "ADD" for a*b       : ai*br + ar*bi
	-- . "SUB" for a*conj(b) : ai*br - ar*bi
	gen_im_add : IF NOT g_conjugate_b GENERATE
		nxt_sum_im <= RESIZE_NUM(prod_ai_br, c_sum_w) + prod_ar_bi;
	END GENERATE;
	gen_im_sub : IF g_conjugate_b GENERATE
		nxt_sum_im <= RESIZE_NUM(prod_ai_br, c_sum_w) - prod_ar_bi;
	END GENERATE;

	no_adder_reg : IF g_pipeline_adder = 0 GENERATE -- wired
		sum_re <= nxt_sum_re;
		sum_im <= nxt_sum_im;
	END GENERATE;
	gen_adder_reg : IF g_pipeline_adder > 0 GENERATE -- register
		sum_re <= reg_sum_re;
		sum_im <= reg_sum_im;
	END GENERATE;

	------------------------------------------------------------------------------
	-- Result sum after optional rounding
	------------------------------------------------------------------------------

	nxt_result_re <= RESIZE_NUM(sum_re, g_out_p_w);
	nxt_result_im <= RESIZE_NUM(sum_im, g_out_p_w);

	no_result_reg : IF g_pipeline_output = 0 GENERATE -- wired
		result_re <= STD_LOGIC_VECTOR(nxt_result_re);
		result_im <= STD_LOGIC_VECTOR(nxt_result_im);
	END GENERATE;
	gen_result_reg : IF g_pipeline_output > 0 GENERATE -- register
		result_re <= STD_LOGIC_VECTOR(reg_result_re);
		result_im <= STD_LOGIC_VECTOR(reg_result_im);
	END GENERATE;

END ARCHITECTURE;
