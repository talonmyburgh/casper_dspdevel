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

library ieee, common_pkg_lib, common_components_lib, casper_counter_lib, casper_requantize_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use work.twiddlesPkg.all;
use work.rTwoSDFPkg.all;

entity rTwoSDFStage is
	generic(
		g_nof_chan       : natural        := 0; 			--! Exponent of nr of subbands (0 means 1 subband)
		g_stage          : natural        := 8; 			--! Stage number
		g_stage_offset   : natural        := 0; 			--! The Stage offset: 0 for normal FFT. Other than 0 in wideband FFT
		g_twiddle_offset : natural        := 0; 			--! The twiddle offset: 0 for normal FFT. Other than 0 in wideband FFT
		g_variant        : string         := "4DSP";		--! Cmult variant to use "3DSP" or "4DSP"
		g_use_dsp        : string         := "yes";			--! Use dsp for cmults
		g_representation : string 		  := "SIGNED";		--! Data representation "SIGNED" or "UNSIGNED"
		g_ovflw_behav	 : string		  := "WRAP";		--! Clip behaviour "WRAP" or "SATURATE"
		g_use_round		 : string		  := "ROUND";		--! Rounding behaviour "ROUND" or "TRUNCATE"
		g_pipeline       : t_fft_pipeline := c_fft_pipeline; --! internal pipeline settings
		g_technology	 : natural		  := 0
	);
	port(
		clk     : in  std_logic;        --! Input clock
		rst     : in  std_logic;        --! Input reset
		in_re   : in  std_logic_vector; --! Real input value
		in_im   : in  std_logic_vector; --! Imaginary input value
		scale 	: in  std_logic;		--! Scale (1) or not (0)
		in_val  : in  std_logic;        --! Input value select
		out_re  : out std_logic_vector; --! Output real value
		out_im  : out std_logic_vector; --! Output imaginary value
		ovflw	: out std_logic;		--! Overflow out (1 - ovflw, 0 - no ovflw)
		out_val : out std_logic         --! Output value select
	);
end entity rTwoSDFStage;

architecture str of rTwoSDFStage is

	-- The amplification factor per stage is 2, therefor bit growth defintion of 1.
	-- Scale enable is defined by generic.
    constant c_rtwo_stage_bit_growth : natural := 1;
	-- counter for ctrl_sel 
	constant c_cnt_lat  : integer := 1;
	constant c_cnt_init : integer := 0;

	constant c_round	: boolean := sel_a_b(g_use_round ="ROUND", TRUE, FALSE);
	constant c_clip		: boolean := sel_a_b(g_ovflw_behav="SATURATE", TRUE, FALSE);

	signal ctrl_sel : std_logic_vector(g_stage + g_nof_chan downto 1);

	signal in_sel : std_logic;

	signal bf_re  : std_logic_vector(in_re'range);
	signal bf_im  : std_logic_vector(in_im'range);
	signal bf_sel : std_logic;
	signal bf_val : std_logic;

	signal weight_addr : std_logic_vector(g_stage - 1 downto 1);
	signal weight_re   : wTyp;
	signal weight_im   : wTyp;

	signal mul_out_re  : std_logic_vector(out_re'range);
	signal mul_out_im  : std_logic_vector(out_im'range);
	signal mul_out_val : std_logic;

	signal quant_out_re : std_logic_vector(out_re'range);
	signal quant_out_im : std_logic_vector(out_im'range);

	-- signal for detection of overflow in any of the requantizations
	signal ovflw_det	: std_logic_vector(1 DOWNTO 0);

begin

	------------------------------------------------------------------------------
	-- stage counter
	------------------------------------------------------------------------------
	u_control : entity casper_counter_lib.common_counter
		generic map(
			g_latency   => c_cnt_lat,
			g_init      => c_cnt_init,
			g_width     => g_stage + g_nof_chan,
			g_step_size => 1
		)
		port map(
			clken  => '1',
			rst    => rst,
			clk    => clk,
			cnt_en => in_val,
			count  => ctrl_sel
		);

	------------------------------------------------------------------------------
	-- complex butterfly
	------------------------------------------------------------------------------
	in_sel <= ctrl_sel(g_stage + g_nof_chan);

	u_butterfly : entity work.rTwoBFStage
		generic map(
			g_nof_chan      => g_nof_chan,
			g_stage         => g_stage,
			g_bf_lat        => g_pipeline.bf_lat,
			g_bf_use_zdly   => g_pipeline.bf_use_zdly,
			g_bf_in_a_zdly  => g_pipeline.bf_in_a_zdly,
			g_bf_out_d_zdly => g_pipeline.bf_out_d_zdly
		)
		port map(
			clk     => clk,
			rst     => rst,
			in_re   => in_re,
			in_im   => in_im,
			in_sel  => in_sel,
			in_val  => in_val,
			out_re  => bf_re,
			out_im  => bf_im,
			out_sel => bf_sel,
			out_val => bf_val
		);

	------------------------------------------------------------------------------
	-- get twiddles
	------------------------------------------------------------------------------
	weight_addr <= ctrl_sel(g_stage + g_nof_chan - 1 downto g_nof_chan + 1);

	u_weights : entity work.rTwoWeights
		generic map(
			g_stage          => g_stage,
			g_twiddle_offset => g_twiddle_offset,
			g_stage_offset   => g_stage_offset,
			g_lat            => g_pipeline.weight_lat
		)
		port map(
			clk       => clk,
			in_wAdr   => weight_addr,
			weight_re => weight_re,
			weight_im => weight_im
		);

	------------------------------------------------------------------------------
	-- twiddle multiplication
	------------------------------------------------------------------------------
	u_TwiddleMult : entity work.rTwoWMul
		generic map(
			g_technology => g_technology,
			g_variant 	 => g_variant,
			g_stage   	 => g_stage,
			g_use_dsp 	 => g_use_dsp,
			g_lat     	 => g_pipeline.mul_lat
		)
		port map(
			clk       => clk,
			rst       => rst,
			weight_re => weight_re,
			weight_im => weight_im,
			in_re     => bf_re,
			in_im     => bf_im,
			in_val    => bf_val,
			in_sel    => bf_sel,
			out_re    => mul_out_re,
			out_im    => mul_out_im,
			out_val   => mul_out_val
		);

	------------------------------------------------------------------------------
	-- stage requantization
	------------------------------------------------------------------------------
	u_requantize_re : entity casper_requantize_lib.r_shift_requantize
		generic map(
			g_representation      => "SIGNED",
			g_lsb_round           => c_round,
			g_lsb_round_clip      => FALSE,
			g_msb_clip            => c_clip,
			g_msb_clip_symmetric  => FALSE,
			g_pipeline_remove_lsb => 0,
			g_pipeline_remove_msb => 0,
			g_in_dat_w            => in_re'LENGTH,
			g_out_dat_w           => out_re'LENGTH
		)
		port map(
			clk     => clk,
			clken   => '1',
			scale	=> scale,
			in_dat  => mul_out_re,
			out_dat => quant_out_re,
			out_ovr => ovflw_det(1)
		);
	u_requantize_im : entity casper_requantize_lib.r_shift_requantize
		generic map(
			g_representation      => "SIGNED",
			g_lsb_round           => c_round,
			g_lsb_round_clip      => FALSE,
			g_msb_clip            => c_clip,
			g_msb_clip_symmetric  => FALSE,
			g_pipeline_remove_lsb => 0,
			g_pipeline_remove_msb => 0,
			g_in_dat_w            => in_im'LENGTH,
			g_out_dat_w           => out_im'LENGTH
		)
		port map(
			clk     => clk,
			clken   => '1',
			scale	=> scale,
			in_dat  => mul_out_im,
			out_dat => quant_out_im,
			out_ovr => ovflw_det(0)
		);
    
	------------------------------------------------------------------------------
	-- output
	------------------------------------------------------------------------------
	u_re_lat : entity common_components_lib.common_pipeline
		generic map(
			g_pipeline  => g_pipeline.stage_lat,
			g_in_dat_w  => out_re'length,
			g_out_dat_w => out_re'length
		)
		port map(
			clk     => clk,
			in_dat  => quant_out_re,
			out_dat => out_re
		);

	u_im_lat : entity common_components_lib.common_pipeline
		generic map(
			g_pipeline  => g_pipeline.stage_lat,
			g_in_dat_w  => out_im'length,
			g_out_dat_w => out_im'length
		)
		port map(
			clk     => clk,
			in_dat  => quant_out_im,
			out_dat => out_im
		);

	u_val_lat : entity common_components_lib.common_pipeline_sl
		generic map(
			g_pipeline => g_pipeline.stage_lat
		)
		port map(
			clk     => clk,
			in_dat  => mul_out_val,
			out_dat => out_val
		);

	-- Check if overflow occured when processing either im or re sigs	
	ovflw <= not(ovflw_det(1) nor ovflw_det(0));

end str;
