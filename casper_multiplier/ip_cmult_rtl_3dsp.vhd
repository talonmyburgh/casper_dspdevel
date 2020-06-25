library ieee;
USE ieee.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

entity ip_cmult_rtl_3dsp is
	GENERIC(
		g_use_dsp		   : STRING := "YES"; --! Implement multiplications in DSP48 or not
		g_in_a_w            : POSITIVE := 8; --! A input bit width
		g_in_b_w            : POSITIVE := 8; --! B input bit width
		g_out_p_w           : POSITIVE := 16; --! default use g_out_p_w = g_in_a_w+g_in_b_w = c_prod_w
		g_conjugate_b       : BOOLEAN  := FALSE; --! Whether or not to conjugate B value
		g_pipeline_input    : NATURAL  := 1; --! 0 or 1
		g_pipeline_product  : NATURAL  := 0; --! 0 or 1
		g_pipeline_adder    : NATURAL  := 1; --! 0 or 1
		g_pipeline_output   : NATURAL  := 1 --! >= 0
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
	attribute use_dsp : string;
	attribute use_dsp of ip_cmult_rtl_3dsp : entity is g_use_dsp;
end entity ip_cmult_rtl_3dsp;

architecture RTL of ip_cmult_rtl_3dsp is
	FUNCTION RESIZE_NUM(s : SIGNED; w : NATURAL) RETURN SIGNED IS
	BEGIN
		-- extend sign bit or keep LS part
		IF w > s'LENGTH THEN
			RETURN RESIZE(s, w);        -- extend sign bit
		ELSE
			RETURN SIGNED(RESIZE(UNSIGNED(s), w)); -- keep LSbits (= vec[w-1:0])
		END IF;
	END;

	CONSTANT c_prod_w  : NATURAL := g_in_a_w + g_in_b_w + 1;
	CONSTANT c_sum_w   : NATURAL := c_prod_w + 1;
	Constant c_a_sum_w : NATURAL := g_in_a_w + 1;
	Constant c_b_sum_w : NATURAL := g_in_b_w + 1;

	-- registers
	SIGNAL reg_ar        : SIGNED(g_in_a_w - 1 DOWNTO 0);
	SIGNAL reg_ai        : SIGNED(g_in_a_w - 1 DOWNTO 0);
	SIGNAL reg_br        : SIGNED(g_in_b_w - 1 DOWNTO 0);
	SIGNAL reg_bi        : SIGNED(g_in_b_w - 1 DOWNTO 0);
	SIGNAL reg_k1        : SIGNED(c_prod_w - 1 DOWNTO 0);
	SIGNAL reg_k2        : SIGNED(c_prod_w - 1 DOWNTO 0);
	SIGNAL reg_k3        : SIGNED(c_prod_w - 1 DOWNTO 0);
	SIGNAL reg_sum_re    : SIGNED(c_sum_w - 1 DOWNTO 0);
	SIGNAL reg_sum_im    : SIGNED(c_sum_w - 1 DOWNTO 0);
	SIGNAL reg_result_re : SIGNED(g_out_p_w - 1 DOWNTO 0);
	SIGNAL reg_result_im : SIGNED(g_out_p_w - 1 DOWNTO 0);

	-- combinatorial
	SIGNAL nxt_ar        : SIGNED(g_in_a_w - 1 DOWNTO 0);
	SIGNAL nxt_ai        : SIGNED(g_in_a_w - 1 DOWNTO 0);
	SIGNAL nxt_br        : SIGNED(g_in_b_w - 1 DOWNTO 0);
	SIGNAL nxt_bi        : SIGNED(g_in_b_w - 1 DOWNTO 0);
	SIGNAL nxt_k1        : SIGNED(c_prod_w - 1 DOWNTO 0);
	SIGNAL nxt_k2        : SIGNED(c_prod_w - 1 DOWNTO 0);
	SIGNAL nxt_k3        : SIGNED(c_prod_w - 1 DOWNTO 0);
	SIGNAL nxt_sum_re    : SIGNED(c_sum_w - 1 DOWNTO 0);
	SIGNAL nxt_sum_im    : SIGNED(c_sum_w - 1 DOWNTO 0);
	SIGNAL nxt_result_re : SIGNED(g_out_p_w - 1 DOWNTO 0);
	SIGNAL nxt_result_im : SIGNED(g_out_p_w - 1 DOWNTO 0);

	-- the active signals
	SIGNAL ar     : SIGNED(g_in_a_w - 1 DOWNTO 0);
	SIGNAL ai     : SIGNED(g_in_a_w - 1 DOWNTO 0);
	SIGNAL br     : SIGNED(g_in_b_w - 1 DOWNTO 0);
	SIGNAL bi     : SIGNED(g_in_b_w - 1 DOWNTO 0);
	signal k1     : SIGNED(c_prod_w - 1 DOWNTO 0);
	signal k2     : SIGNED(c_prod_w - 1 DOWNTO 0);
	signal k3     : SIGNED(c_prod_w - 1 DOWNTO 0);
	SIGNAL sum_re : SIGNED(c_sum_w - 1 DOWNTO 0);
	SIGNAL sum_im : SIGNED(c_sum_w - 1 DOWNTO 0);

	--enforce dsp usage
--	attribute use_dsp of k1 : signal is "yes";
--	attribute use_dsp of k2 : signal is "yes";
--	attribute use_dsp of k3 : signal is "yes";

begin

	------------------------------------------------------------------------------
	-- Registers
	------------------------------------------------------------------------------

	-- Put all potential registers in a single process for optimal DSP inferrence
	-- Use rst only if it is supported by the DSP primitive, else leave it at '0'
	p_reg : PROCESS(clk)
	BEGIN
		IF rising_edge(clk) THEN
			IF rst = '1' THEN
				reg_ar        <= (OTHERS => '0');
				reg_ai        <= (OTHERS => '0');
				reg_br        <= (OTHERS => '0');
				reg_bi        <= (OTHERS => '0');
				reg_k1        <= (OTHERS => '0');
				reg_k2        <= (OTHERS => '0');
				reg_k3        <= (OTHERS => '0');
				reg_sum_re    <= (OTHERS => '0');
				reg_sum_im    <= (OTHERS => '0');
				reg_result_re <= (OTHERS => '0');
				reg_result_im <= (OTHERS => '0');
			ELSIF clken = '1' THEN
				reg_ar        <= nxt_ar; -- inputs
				reg_ai        <= nxt_ai;
				reg_br        <= nxt_br;
				reg_bi        <= nxt_bi;
				reg_k1        <= nxt_k1; -- 3 products
				reg_k2        <= nxt_k2;
				reg_k3        <= nxt_k3;
				reg_sum_re    <= nxt_sum_re; -- 5 sums
				reg_sum_im    <= nxt_sum_im;
				reg_result_re <= nxt_result_re; -- result sum after optional register stage
				reg_result_im <= nxt_result_im;
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
	-- Products c(a+b), a(d-c) and b(c+d)
	------------------------------------------------------------------------------

	gen_k_mult : IF NOT g_conjugate_b GENERATE
		nxt_k1 <= br * (resize(ar, c_a_sum_w) + resize(ai, c_b_sum_w));
		nxt_k2 <= ar * (resize(bi, c_a_sum_w) - resize(br, c_b_sum_w));
		nxt_k3 <= ai * (resize(br, c_a_sum_w) + resize(bi, c_b_sum_w));
	END GENERATE;

	gen_k_mult_conj_b : IF g_conjugate_b GENERATE
		nxt_k1 <= br * (resize(ar, c_a_sum_w) + resize(ai, c_b_sum_w));
		nxt_k2 <= ar * (resize(-bi, c_a_sum_w) - resize(br, c_b_sum_w));
		nxt_k3 <= ai * (resize(br, c_a_sum_w) - resize(bi, c_b_sum_w));
	END GENERATE;

	no_product_reg : IF g_pipeline_product = 0 GENERATE -- wired
		k1 <= nxt_k1;
		k2 <= nxt_k2;
		k3 <= nxt_k3;
	END GENERATE;
	gen_product_reg : IF g_pipeline_product > 0 GENERATE -- register
		k1 <= reg_k1;
		k2 <= reg_k2;
		k3 <= reg_k3;
	END GENERATE;

	------------------------------------------------------------------------------
	-- Sum
	------------------------------------------------------------------------------

	nxt_sum_re <= resize(k1, c_sum_w) - resize(k3, c_sum_w);
	nxt_sum_im <= resize(k1, c_sum_w) + resize(k2, c_sum_w);

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

end architecture RTL;
