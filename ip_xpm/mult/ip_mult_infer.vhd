--! @file
--! @brief Inference multiplier

--! library IEEE
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @dot 
--! digraph ip_mult_rtl {
--!	rankdir="LR";
--! node [shape=box, fontname=Helvetica, fontsize=12,color="black"];
--! ip_mult_rtl;
--! node [shape=plaintext];
--! a;
--! b;
--! clk;
--! rst;
--! ce;
--! p;
--! clk -> ip_mult_rtl;
--! ce -> ip_mult_rtl;
--! a -> ip_mult_rtl;
--! b -> ip_mult_rtl;
--! rst -> ip_mult_rtl;
--! ip_mult_rtl -> p;
--!}
--! @enddot

--! Purpose:
--!   - Inference multiplier. This will most likely be mapped to DSP elements when using Xilinx tools
entity ip_mult_infer is
	GENERIC(
		g_use_dsp          : STRING   := "YES";
		g_in_a_w           : POSITIVE := 4; --! A input bit width
		g_in_b_w           : POSITIVE := 4; --! B input bit width
		g_out_p_w          : POSITIVE := 8; --! default use g_out_p_w = g_in_a_w+g_in_b_w = c_prod_w
		g_pipeline_input   : NATURAL  := 1; --! 0 or 1
		g_pipeline_product : NATURAL  := 0; --! 0 or 1
		g_pipeline_output  : NATURAL  := 1 --! >= 0
	);
	port(
		in_a  : in  std_logic_vector(g_in_a_w - 1 downto 0); --! Input A (width = AWIDTH)
		in_b  : in  std_logic_vector(g_in_b_w - 1 downto 0); --! Input B (width = BWIDTH)
		clk   : in  std_logic;          --! Input clock
		rst   : in  std_logic;          --! Reset signal
		ce    : in  std_logic;          --! Clock enable
		out_p : out std_logic_vector(g_out_p_w - 1 downto 0) --! Output signal
	);
	attribute use_dsp : string;
	attribute use_dsp of ip_mult_infer : entity is g_use_dsp;
end entity;

architecture rtl of ip_mult_infer is

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

	signal nxt_a      : signed(g_in_a_w - 1 downto 0);
	signal nxt_b      : signed(g_in_b_w - 1 downto 0);
	signal nxt_p      : signed(c_prod_w - 1 downto 0);
	signal nxt_result : signed(g_out_p_w - 1 downto 0);
	signal prod_a_b   : signed(c_prod_w - 1 downto 0);
	signal reg_p      : signed(c_prod_w - 1 downto 0);
	signal a          : signed(g_in_a_w - 1 downto 0);
	signal b          : signed(g_in_b_w - 1 downto 0);
	signal reg_a      : signed(g_in_a_w - 1 downto 0);
	signal reg_b      : signed(g_in_b_w - 1 downto 0);
	signal reg_result : signed(g_out_p_w - 1 downto 0);

begin

	process(clk) is
	begin
		if rising_edge(clk) then
			if rst = '1' then
				reg_a      <= (OTHERS => '0');
				reg_p      <= (OTHERS => '0');
				reg_b      <= (OTHERS => '0');
				reg_p      <= (others => '0');
				reg_result <= (others => '0');

			elsif ce = '1' then
				reg_a      <= nxt_a;
				reg_b      <= nxt_b;
				reg_p      <= nxt_p;
				reg_p      <= nxt_p;
				reg_result <= nxt_result;
			end if;
		end if;
	end process;

	------------------------------------------------------------------------------
	-- Inputs
	------------------------------------------------------------------------------
	nxt_a <= signed(in_a);
	nxt_b <= signed(in_b);

	no_input_reg : IF g_pipeline_input = 0 GENERATE -- wired
		a <= nxt_a;
		b <= nxt_b;
	END GENERATE;

	gen_input_reg : IF g_pipeline_input > 0 GENERATE -- register input
		a <= reg_a;
		b <= reg_b;
	END GENERATE;

	------------------------------------------------------------------------------
	-- Product
	------------------------------------------------------------------------------
	nxt_p <= a * b;

	no_product_reg : IF g_pipeline_product = 0 GENERATE -- wired
		prod_a_b <= nxt_p;
	END GENERATE;
	gen_product_reg : IF g_pipeline_product > 0 GENERATE -- register
		prod_a_b <= reg_p;
	END GENERATE;

	------------------------------------------------------------------------------
	-- Result sum after optional rounding
	------------------------------------------------------------------------------
	nxt_result <= RESIZE_NUM(prod_a_b, g_out_p_w);

	no_result_reg : IF g_pipeline_output = 0 GENERATE
		out_p <= std_logic_vector(nxt_result);
	END GENERATE;

	gen_result_reg : IF g_pipeline_output > 0 GENERATE
		out_p <= std_logic_vector(reg_result);
	END GENERATE;

end architecture;
