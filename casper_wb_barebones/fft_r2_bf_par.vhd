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
--
-- Purpose: The fft_r2_bf_par describes a parallel complex butterfly.
--
-- Description: Output x is defined as x+y
--              Output y is defined as (x-y)*W
--             
--
-- Remarks: 
-- 

library ieee, common_pkg_lib, common_components_lib, casper_requantize_lib, r2sdf_fft_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use common_pkg_lib.common_str_pkg.all;
use r2sdf_fft_lib.twiddlesPkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;

entity fft_r2_bf_par is
	generic(
		g_stage        : natural        := 3;
		g_element      : natural        := 1;
		-- internal pipeline settings
		g_pipeline     : t_fft_pipeline := c_fft_pipeline; -- defined in r2sdf_fft_lib.rTwoSDFPkg
		-- multiplier settings
		g_use_variant  : STRING     	:= "4DSP";
		g_ovflw_behav  : string			:= "WRAP";
		g_use_round	   : string			:= "ROUND";
		g_technology   : natural        := 0;
		g_use_dsp      : STRING         := "yes"
	);
	port(
		clk      : in  std_logic;
		rst      : in  std_logic;
		x_in_re  : in  std_logic_vector;
		x_in_im  : in  std_logic_vector;
		y_in_re  : in  std_logic_vector;
		y_in_im  : in  std_logic_vector;
		scale    : in  std_logic;
		in_val   : in  std_logic;
		x_out_re : out std_logic_vector;
		x_out_im : out std_logic_vector;
		y_out_re : out std_logic_vector;
		y_out_im : out std_logic_vector;
		ovflw	 : out std_logic;
		out_val  : out std_logic
	);
end entity fft_r2_bf_par;

architecture str of fft_r2_bf_par is

	constant c_round	: boolean := sel_a_b(g_use_round ="ROUND", TRUE, FALSE);
	constant c_clip		: boolean := sel_a_b(g_ovflw_behav="SATURATE", TRUE, FALSE);

	constant c_out_dat_w : natural := x_out_re'length; -- re and im have same width  

	constant c_bf_in_a_zdly  : natural := 0; -- No delays in bf_stage, since they only apply to one in- or output
	constant c_bf_out_b_zdly : natural := 0; -- No delays in bf_stage, since they only apply to one in- or output

	signal sum_re       : std_logic_vector(x_out_re'range);
	signal sum_im       : std_logic_vector(x_out_im'range);
	signal sum_quant_re : std_logic_vector(x_out_re'range);
	signal sum_quant_im : std_logic_vector(x_out_im'range);

	signal dif_re : std_logic_vector(y_out_re'range);
	signal dif_im : std_logic_vector(y_out_im'range);

	signal dif_out_re : std_logic_vector(y_out_re'range);
	signal dif_out_im : std_logic_vector(y_out_im'range);

	signal bf_sum_complex     : std_logic_vector(c_nof_complex * c_out_dat_w - 1 downto 0);
	signal bf_sum_complex_dly : std_logic_vector(bf_sum_complex'range);
	signal bf_dif_complex     : std_logic_vector(c_nof_complex * c_out_dat_w - 1 downto 0);
	signal bf_dif_complex_dly : std_logic_vector(bf_dif_complex'range);

	signal weight_addr : std_logic_vector(g_stage - 1 downto 1);
	signal weight_re   : wTyp;
	signal weight_im   : wTyp;

	signal mul_out_re   : std_logic_vector(y_out_re'range);
	signal mul_out_im   : std_logic_vector(y_out_im'range);
	signal mul_quant_re : std_logic_vector(y_out_re'range);
	signal mul_quant_im : std_logic_vector(y_out_im'range);
	signal mul_out_val  : std_logic;
	signal mul_in_val   : std_logic;

	signal ovflw_det	: std_logic_vector(1 DOWNTO 0); -- record overflow in any of the requantizings

begin

	------------------------------------------------------------------------------
	-- complex butterfly
	------------------------------------------------------------------------------
	u_bf_re : entity r2sdf_fft_lib.rTwoBF
		generic map(
			g_in_a_zdly  => c_bf_in_a_zdly,
			g_out_d_zdly => c_bf_out_b_zdly
		)
		port map(
			clk    => clk,
			in_a   => x_in_re,
			in_b   => y_in_re,
			in_sel => '1',
			in_val => in_val,
			ovflw  => ovflw_det(0),
			out_c  => sum_re,
			out_d  => dif_re
		);

	u_bf_im : entity r2sdf_fft_lib.rTwoBF
		generic map(
			g_in_a_zdly  => c_bf_in_a_zdly,
			g_out_d_zdly => c_bf_out_b_zdly
		)
		port map(
			clk    => clk,
			in_a   => x_in_im,
			in_b   => y_in_im,
			in_sel => '1',
			in_val => in_val,
			ovflw  => ovflw_det(1),
			out_c  => sum_im,
			out_d  => dif_im
		);

	ovflw <= (ovflw_det(1) or ovflw_det(0)); -- Detect if overflow is detected in either butterfly add/sub
	------------------------------------------------------------------------------
	-- requantize x output
	------------------------------------------------------------------------------
	u_requantize_x_re : entity casper_requantize_lib.r_shift_requantize
		generic map(
			g_lsb_round           => c_round,
			g_lsb_round_clip      => FALSE,
			g_in_dat_w            => sum_re'LENGTH,
			g_out_dat_w           => sum_quant_re'LENGTH
		)
		port map(
			clk     => clk,
			clken   => '1',
			scale	=> '1',
			in_dat  => sum_re,
			out_dat => sum_quant_re
		);

	u_requantize_x_im : entity casper_requantize_lib.r_shift_requantize
		generic map(
			g_lsb_round           => c_round,
			g_lsb_round_clip      => FALSE,
			g_in_dat_w            => sum_im'LENGTH,
			g_out_dat_w           => sum_quant_im'LENGTH
		)
		port map(
			clk     => clk,
			clken   => '1',
			scale	=> '1',
			in_dat  => sum_im,
			out_dat => sum_quant_im
		);

	------------------------------------------------------------------------------
	-- Butterfly output pipelining: the sum output (output C)
	-- 
	-- The instantiated pipeline for the sum output takes into account the 
	-- bf_lat + mul_lat + stage_lat. Output of the pipeline is directly connected 
	-- to the output. 
	------------------------------------------------------------------------------
	bf_sum_complex <= sum_quant_im & sum_quant_re;

	u_pipeline_sum : entity common_components_lib.common_pipeline
		generic map(
			g_pipeline  => g_pipeline.bf_lat + g_pipeline.mul_lat + g_pipeline.stage_lat,
			g_in_dat_w  => bf_sum_complex'length,
			g_out_dat_w => bf_sum_complex'length
		)
		port map(
			clk     => clk,
			in_dat  => bf_sum_complex,
			out_dat => bf_sum_complex_dly
		);
	-- connect to the output. 
	x_out_re <= bf_sum_complex_dly(c_out_dat_w - 1 downto 0);
	x_out_im <= bf_sum_complex_dly(2 * c_out_dat_w - 1 downto c_out_dat_w);

	------------------------------------------------------------------------------
	-- Butterfly output pipelining: the dif output (output D)
	-- 
	-- The dif output requires only the bf_lat pipelining. The data of the dif
	-- output is than fed to the multiplier. 
	------------------------------------------------------------------------------
	bf_dif_complex <= dif_im & dif_re;

	u_pipeline_dif : entity common_components_lib.common_pipeline
		generic map(
			g_pipeline  => g_pipeline.bf_lat,
			g_in_dat_w  => bf_dif_complex'length,
			g_out_dat_w => bf_dif_complex'length
		)
		port map(
			clk     => clk,
			in_dat  => bf_dif_complex,
			out_dat => bf_dif_complex_dly
		);

	dif_out_re <= bf_dif_complex_dly(c_out_dat_w - 1 downto 0);
	dif_out_im <= bf_dif_complex_dly(2 * c_out_dat_w - 1 downto c_out_dat_w);

	------------------------------------------------------------------------------
	-- In_valid pipelining. The in_val signal must be pipelined for bf_lat cycles
	-- before it drives to the multiplier. 
	------------------------------------------------------------------------------
	u_val_bf_lat : entity common_components_lib.common_pipeline_sl
		generic map(
			g_pipeline => g_pipeline.bf_lat
		)
		port map(
			clk     => clk,
			in_dat  => in_val,
			out_dat => mul_in_val
		);

	------------------------------------------------------------------------------
	-- twiddle multiplication
	------------------------------------------------------------------------------
	u_TwiddleMult : entity r2sdf_fft_lib.rTwoWMul
		generic map(
			g_technology 	=> g_technology,
			g_use_dsp    	=> g_use_dsp,
			g_variant		=> g_use_variant,
			g_stage      	=> g_stage,
			g_lat        	=> g_pipeline.mul_lat
		)
		port map(
			clk       => clk,
			rst       => rst,
			weight_re => weight_re,
			weight_im => weight_im,
			in_re     => dif_out_re,
			in_im     => dif_out_im,
			in_val    => mul_in_val,
			in_sel    => '1',           -- Always select the multiplier output
			out_re    => mul_out_re,
			out_im    => mul_out_im,
			out_val   => mul_out_val
		);

	weight_re <= wRe(wMap(g_element, g_stage));
	weight_im <= wIm(wMap(g_element, g_stage));

	print_str("Parallel: [stage = " & integer'image(g_stage) & " [element = " & integer'image(g_element) & "] " & "[index = " & integer'image(wMap(g_element, g_stage)) & "] ");

	------------------------------------------------------------------------------
	-- requantize y output
	------------------------------------------------------------------------------
	u_requantize_y_re : entity casper_requantize_lib.r_shift_requantize
		generic map(
			g_lsb_round           => c_round,
			g_lsb_round_clip      => FALSE,
			g_in_dat_w            => mul_out_re'LENGTH,
			g_out_dat_w           => mul_quant_re'LENGTH
		)
		port map(
			clk     => clk,
			clken   => '1',
			scale	=> '1',
			in_dat  => mul_out_re,
			out_dat => mul_quant_re
		);

	u_requantize_y_im : entity casper_requantize_lib.r_shift_requantize
		generic map(
			g_lsb_round           => c_round,
			g_lsb_round_clip      => FALSE,
			g_in_dat_w            => mul_out_im'LENGTH,
			g_out_dat_w           => mul_quant_im'LENGTH
		)
		port map(
			clk     => clk,
			clken   => '1',
			scale	=> '1',
			in_dat  => mul_out_im,
			out_dat => mul_quant_im
		);

	------------------------------------------------------------------------------
	-- output
	------------------------------------------------------------------------------
	u_y_re_stage_lat : entity common_components_lib.common_pipeline
		generic map(
			g_pipeline  => g_pipeline.stage_lat,
			g_in_dat_w  => mul_quant_re'LENGTH,
			g_out_dat_w => y_out_re'LENGTH
		)
		port map(
			clk     => clk,
			in_dat  => mul_quant_re,
			out_dat => y_out_re
		);

	u_y_im_stage_lat : entity common_components_lib.common_pipeline
		generic map(
			g_pipeline  => g_pipeline.stage_lat,
			g_in_dat_w  => mul_quant_im'LENGTH,
			g_out_dat_w => y_out_im'LENGTH
		)
		port map(
			clk     => clk,
			in_dat  => mul_quant_im,
			out_dat => y_out_im
		);

	u_val_stage_lat : entity common_components_lib.common_pipeline_sl
		generic map(
			g_pipeline => g_pipeline.stage_lat
		)
		port map(
			clk     => clk,
			in_dat  => mul_out_val,
			out_dat => out_val
		);
end str;
