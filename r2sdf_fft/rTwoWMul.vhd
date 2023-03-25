--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------

library ieee, common_pkg_lib, common_components_lib, casper_multiplier_lib;
use IEEE.std_logic_1164.all;
--USE technology_lib.technology_select_pkg.ALL;
use common_pkg_lib.common_pkg.all;

entity rTwoWMul is
	generic(
		g_use_dsp    : STRING  := "yes";
		g_use_variant    : STRING  := "4DSP";
		g_use_truncate : boolean := true;
		g_stage      : natural := 1;
		g_lat        : natural := 3 + 1 -- 3 for mult, 1 for round
	);
	port(
		clk       	 : in  std_logic;
		rst       	 : in  std_logic;
		weight_re 	 : in  std_logic_vector;
		weight_im 	 : in  std_logic_vector;
		in_re     	 : in  std_logic_vector;
		in_im     	 : in  std_logic_vector;
		in_val    	 : in  std_logic;
		in_sel    	 : in  std_logic;
		out_re    	 : out std_logic_vector;
		out_im    	 : out std_logic_vector;
		out_val   	 : out std_logic
	);
end entity rTwoWMul;

architecture str of rTwoWMul is

	-- Use multiplier product truncate or signed rounding (= away from zero). On hardware for Fsub in
	-- Apertif and using the WG at various frequencies at subband or between subbands it appears that
	-- using truncate or sround does not make a noticable difference in the SST. Still choose to use
	-- signed rounding to preserve zero DC.
	constant c_use_truncate : boolean := g_use_truncate; --false;

	-- Derive the common_complex_mult g_pipeline_* values from g_lat. The sum c_total_lat = g_lat, so that g_lat defines
	-- the total latency from in_* to out_*.

	-- DSP multiplier IP
	constant c_dsp_mult_lat : natural := 3;

	-- Pipeline multiplier product rounding from c_prod_w via c_round_w to c_out_dat_w
	constant c_round_lat : natural := sel_a_b(g_lat > c_dsp_mult_lat, 1, 0); -- allocate 1 pipeline for round
	constant c_lat       : natural := g_lat - c_round_lat; -- allocate remaining pipeline to multiplier

	constant c_mult_input_lat   : natural := sel_a_b(c_lat > 1, 1, 0); -- second priority use DSP pipeline input
	constant c_mult_product_lat : natural := 0;
	constant c_mult_adder_lat   : natural := sel_a_b(c_lat > 2, 1, 0); -- third priority use DSP internal product-sum pipeline
	constant c_mult_extra_lat   : natural := sel_a_b(c_lat > 3, c_lat - 3, 0); -- remaining extra pipelining in logic
	constant c_mult_output_lat  : natural := sel_a_b(c_lat > 0, 1, 0) + c_mult_extra_lat; -- first priority use DSP pipeline output
	constant c_mult_lat         : natural := c_mult_input_lat + c_mult_product_lat + c_mult_adder_lat + c_mult_output_lat;

	-- Total input to output latency
	constant c_total_lat : natural := c_mult_lat + c_round_lat;

	-- Quantization
	constant c_in_dat_w  : natural := in_re'length;
	constant c_weight_w  : natural := weight_re'length;
	constant c_prod_w    : natural := c_in_dat_w + c_weight_w + 1;
	constant c_round_w   : natural := c_weight_w - c_sign_w; -- the weights are normalized
	constant c_out_dat_w : natural := out_re'length;

	signal in_re_dly  : std_logic_vector(in_re'range);
	signal in_im_dly  : std_logic_vector(in_re'range);
	signal product_re : std_logic_vector(c_prod_w - 1 downto 0);
	signal product_im : std_logic_vector(c_prod_w - 1 downto 0);
	signal round_re   : std_logic_vector(out_re'range);
	signal round_im   : std_logic_vector(out_re'range);
	signal out_sel    : std_logic;

begin

	-- Total latency check
	ASSERT c_total_lat = g_lat
	REPORT "rTwoWMul: total pipeline error"
	SEVERITY FAILURE;

	------------------------------------------------------------------------------
	-- Complex multiplication
	-- . use the common_complex_mult(rtl) for the output stage 1 because then
	--   the multiplier instance can get optimized away for the constant
	--   weight_re = 1 and weight_im = 0 inputs.
	-- . the IP in common_complex_mult(stratix4) only supports up to 18b wide
	--   inputs.
	--   . for c_lat = 0,1,2 use the RTL multiplier
	--   . for c_lat >= 3 default best use the FPGA multiplier IP block.
	------------------------------------------------------------------------------

	gen_rtl : if g_stage = 1 or c_in_dat_w > c_dsp_mult_w or c_lat < c_dsp_mult_lat generate
		u_CmplxMul : entity casper_multiplier_lib.common_complex_mult
			generic map(
				g_use_ip           => FALSE,
				g_use_variant      => g_use_variant,
				g_use_dsp          => g_use_dsp,
				g_in_a_w           => c_in_dat_w,
				g_in_b_w           => c_weight_w,
				g_out_p_w          => c_prod_w,
				g_conjugate_b      => False,
				g_pipeline_input   => c_mult_input_lat,
				g_pipeline_product => c_mult_product_lat,
				g_pipeline_adder   => c_mult_adder_lat,
				g_pipeline_output  => c_mult_output_lat
			)
			port map(
				clken   => '1',
				rst     => rst,
				clk     => clk,
				in_ar   => in_re,
				in_ai   => in_im,
				in_br   => weight_re,
				in_bi   => weight_im,
				in_val  => in_val,
				out_pr  => product_re,
				out_pi  => product_im,
				out_val => OPEN
			);
	end generate;

	gen_ip : if g_stage > 1 and c_in_dat_w <= c_dsp_mult_w and c_lat >= c_dsp_mult_lat generate
		u_cmplx_mul : entity casper_multiplier_lib.common_complex_mult
			generic map(
				g_use_ip           => TRUE,
				g_use_dsp          => g_use_dsp,
				g_use_variant      => g_use_variant,
				g_in_a_w           => in_re'length,
				g_in_b_w           => weight_re'length,
				g_out_p_w          => product_re'length,
				g_conjugate_b      => false,
				g_pipeline_input   => c_mult_input_lat,
				g_pipeline_product => c_mult_product_lat,
				g_pipeline_adder   => c_mult_adder_lat,
				g_pipeline_output  => c_mult_output_lat
			)
			port map(
				clken   => '1',
				rst     => rst,
				clk     => clk,
				in_ar   => in_re,
				in_ai   => in_im,
				in_br   => weight_re,
				in_bi   => weight_im,
				in_val  => in_val,
				out_pr  => product_re,
				out_pi  => product_im,
				out_val => OPEN
			);
	end generate;

	------------------------------------------------------------------------------
	-- Round WMult output
	------------------------------------------------------------------------------

	gen_truncate : if c_use_truncate = true GENERATE
		-- use truncate    that throws away the c_round_w lower bits as rounding function
		-- use resize_svec that keeps the c_out_dat_w lower bits to get to the output width
		gen_comb : if c_round_lat = 0 generate
			round_re <= truncate_and_resize_svec(product_re, c_round_w, c_out_dat_w);
			round_im <= truncate_and_resize_svec(product_im, c_round_w, c_out_dat_w);
		end generate;
		gen_reg : if c_round_lat = 1 generate
			round_re <= truncate_and_resize_svec(product_re, c_round_w, c_out_dat_w) when rising_edge(clk);
			round_im <= truncate_and_resize_svec(product_im, c_round_w, c_out_dat_w) when rising_edge(clk);
		end generate;
	end generate;

	gen_sround : if c_use_truncate = false GENERATE
		-- Use resize_svec(s_round()) instead of truncate_and_resize_svec() to have symmetrical rounding around 0
		-- Rounding takes logic due to adding 0.5 therefore need to use c_round_lat=1 to achieve timing
		gen_comb : if c_round_lat = 0 generate
			ASSERT false REPORT "rTwoWMul: can probably not achieve timing for sround without pipeline" SEVERITY FAILURE;
			round_re <= RESIZE_SVEC(s_round(product_re, c_round_w), c_out_dat_w);
			round_im <= RESIZE_SVEC(s_round(product_im, c_round_w), c_out_dat_w);
		end generate;
		gen_reg : if c_round_lat = 1 generate
			round_re <= RESIZE_SVEC(s_round(product_re, c_round_w), c_out_dat_w) when rising_edge(clk);
			round_im <= RESIZE_SVEC(s_round(product_im, c_round_w), c_out_dat_w) when rising_edge(clk);
		end generate;
	end generate;

	------------------------------------------------------------------------------
	-- Propagate data and control signals for input/output choice at WMult output
	------------------------------------------------------------------------------

	-- No need to use rst for data, because initial data value is don't care
	u_re_lat : entity common_components_lib.common_pipeline
		generic map(
			g_pipeline  => g_lat,
			g_in_dat_w  => in_re'length,
			g_out_dat_w => in_re'length
		)
		port map(
			clk     => clk,
			in_dat  => in_re,
			out_dat => in_re_dly
		);

	u_im_lat : entity common_components_lib.common_pipeline
		generic map(
			g_pipeline  => g_lat,
			g_in_dat_w  => in_im'length,
			g_out_dat_w => in_im'length
		)
		port map(
			clk     => clk,
			in_dat  => in_im,
			out_dat => in_im_dly
		);

	-- Use rst for control to ensure initial low
	u_sel_lat : entity common_components_lib.common_pipeline_sl
		generic map(
			g_pipeline => g_lat
		)
		port map(
			rst     => rst,
			clk     => clk,
			in_dat  => in_sel,
			out_dat => out_sel
		);

	u_pipeline_out_val : entity common_components_lib.common_pipeline_sl
		generic map(
			g_pipeline => g_lat
		)
		port map(
			rst     => rst,
			clk     => clk,
			in_dat  => in_val,
			out_dat => out_val
		);

	------------------------------------------------------------------------------
	-- Output real and imaginary, switch between input and product
	------------------------------------------------------------------------------
	out_re <= round_re when out_sel = '1' else in_re_dly;
	out_im <= round_im when out_sel = '1' else in_im_dly;

end str;
