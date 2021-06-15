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
--------------------------------------------------------------------------------  --
-- Purpose:  Complex Pipelined Fast Fourier Transform
-- 
-- Description: The fft_r2_pipe unit performs a complex pipelined FFT on the incoming data stream.
--              The implementation is pipelined which means that at every stage only one 
--              multiplier is used to perform all N/2 twiddle multiplications. 
--              
--              There are two optional features: 
--              
--              * Reordering: When enabled the output bins of the FFT are re-ordered in 
--                            in such a way that the bins represent the frequencies in an 
--                            incrementing way. 
--              
--              * Separation: When enabled the fft_r2_pipe can be used to process two real streams.
--                            The first real stream (A) presented on the real input, the second 
--                            real stream (B) presented on the imaginary input. 
--                            The separation unit processes outputs the spectrum of A and B in 
--                            an alternating way: A(0), B(0), A(1), B(1).... etc
--
--
-- Remarks: When g_fft.nof_chan is used the spectrums at the output will be interleaved
--          per spectrum and NOT per sample. So in case g_fft.nof_chan = 1 there will be
--          two multiplexed channels at the input (c0t0 means channel 0, timestamp 0) :
--         
--          c0t0 c1t0s c0t1 c1t1 c0t2 c1t2 ... c0t15 c1t15 
--
--          At the output will find: 
--
--          c0f0 c0f1 c0f2 ... c0f15 c1f0 c1f1 c1f2 ... c1f15  (c0f0 means channel 0, frequency bin 0)     

library ieee, common_pkg_lib, common_components_lib, casper_requantize_lib, r2sdf_fft_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;
use work.fft_gnrcs_intrfcs_pkg.all;

entity fft_r2_pipe is
	generic(
		g_fft                : t_fft          				:= c_fft; 		 			--! generics for the FFT
		g_pipeline           : t_fft_pipeline 				:= c_fft_pipeline; 			--! generics for pipelining in each stage, defined in r2sdf_fft_lib.rTwoSDFPkg
		g_dont_flip_channels : boolean        				:= false; 					--! generic to prevent re-ordering of the channels
		g_use_variant    	 : string  		  				:= "4DSP";        			--! = "4DSP" or "3DSP" for 3 or 4 mult cmult.
		g_use_dsp        	 : string  		  				:= "yes";        			--! = "yes" or "no"
		g_ovflw_behav    	 : string  		  				:= "WRAP";        			--! = "WRAP" or "SATURATE" will default to WRAP if invalid option used
		g_use_round      	 : string  		  				:= "ROUND";        			--! = "ROUND" or "TRUNCATE" will default to TRUNCATE if invalid option used
		g_ram_primitive  	 : string  		  				:= "auto"					--! = "auto", "distributed", "ultra" or "block"
	);
	port(
		clken    			 : in  std_logic;											--! Clock enable
		clk      			 : in  std_logic;											--! Clock
		rst      			 : in  std_logic := '0';									--! Reset
		shiftreg 			 : in  std_logic_vector(ceil_log2(g_fft.nof_points) -1 downto 0);			--! Shift register
		in_re    			 : in  std_logic_vector(g_fft.in_dat_w - 1 downto 0);		--! Input real signal
		in_im    			 : in  std_logic_vector(g_fft.in_dat_w - 1 downto 0);		--! Input imaginary signal
		in_val   			 : in  std_logic := '1';									--! In data valid
		out_re   			 : out std_logic_vector(g_fft.out_dat_w - 1 downto 0);		--! Output real signal
		out_im   			 : out std_logic_vector(g_fft.out_dat_w - 1 downto 0);		--! Output imaginary signal
		ovflw	 			 : out std_logic_vector(ceil_log2(g_fft.nof_points) - 1 downto 0);		--! Overflow register (detects overflow in add/sub of butterfly)
		out_val  			 : out std_logic											--! Output data valid
	);
end entity fft_r2_pipe;

architecture str of fft_r2_pipe is

	constant c_round		: boolean := sel_a_b(g_use_round ="ROUND", TRUE, FALSE);
	constant c_clip			: boolean := sel_a_b(g_ovflw_behav = "SATURATE", TRUE, FALSE);

	constant c_pipeline_remove_lsb : natural := 0;

	constant c_nof_stages   : natural := ceil_log2(g_fft.nof_points);
	constant c_stage_offset : natural := true_log2(g_fft.wb_factor); -- Stage offset is required for twiddle generation in wideband fft
	constant c_in_scale_w   : natural := g_fft.stage_dat_w - g_fft.in_dat_w - sel_a_b(g_fft.guard_enable, g_fft.guard_w, 0);
	constant c_out_scale_w  : integer := g_fft.stage_dat_w - g_fft.out_dat_w - g_fft.out_gain_w; -- Estimate number of LSBs to throw throw away when > 0 or insert when < 0

	-- number the stage instances from c_nof_stages:1
	-- . the data input for the first stage has index c_nof_stages
	-- . the data output of the last stage has index 0
	type t_data_arr is array (c_nof_stages downto 0) of std_logic_vector(g_fft.stage_dat_w - 1 downto 0);

	signal data_re     : t_data_arr;
	signal data_im     : t_data_arr;
	signal data_val    : std_logic_vector(c_nof_stages downto 0) := (others => '0');

	signal out_cplx    : std_logic_vector(c_nof_complex * g_fft.stage_dat_w - 1 downto 0);
	signal in_cplx     : std_logic_vector(c_nof_complex * g_fft.stage_dat_w - 1 downto 0);
	signal raw_out_re  : std_logic_vector(g_fft.stage_dat_w - 1 downto 0);
	signal raw_out_im  : std_logic_vector(g_fft.stage_dat_w - 1 downto 0);
	signal raw_out_val : std_logic;
	signal shift_bool  : boolean;

begin

	-- Inputs
	data_re(c_nof_stages)  <= scale_and_resize_svec(in_re, c_in_scale_w, g_fft.stage_dat_w);
	data_im(c_nof_stages)  <= scale_and_resize_svec(in_im, c_in_scale_w, g_fft.stage_dat_w);
	data_val(c_nof_stages) <= in_val;

	------------------------------------------------------------------------------
	-- pipelined FFT stages
	------------------------------------------------------------------------------
	gen_fft : for stage in c_nof_stages downto 1 generate
        u_stage : entity r2sdf_fft_lib.rTwoSDFStage
            generic map(
                g_nof_chan       => g_fft.nof_chan,
                g_stage          => stage,
                g_stage_offset   => c_stage_offset,
				g_twiddle_offset => g_fft.twiddle_offset,
				g_use_variant	 => g_use_variant,
				g_use_dsp        => g_use_dsp,
				g_ovflw_behav	 => g_ovflw_behav,
				g_use_round		 => g_use_round, 
				g_pipeline       => g_pipeline
			)
			port map(
				clk     => clk,
				rst     => rst,
				in_re   => data_re(stage),
				in_im   => data_im(stage),
				scale   => shiftreg(stage-1),
				in_val  => data_val(stage),
				out_re  => data_re(stage - 1),
				out_im  => data_im(stage - 1),
				ovflw	=> ovflw(stage - 1),
				out_val => data_val(stage - 1)
			);
	end generate;

	------------------------------------------------------------------------------
	-- Optional output reorder and separation
	------------------------------------------------------------------------------
	gen_reorder_and_separate : if (g_fft.use_separate or g_fft.use_reorder) generate
		in_cplx <= data_im(0) & data_re(0);

		u_reorder_sep : entity work.fft_reorder_sepa_pipe
			generic map(
				g_bit_flip           => g_fft.use_reorder,
				g_fft_shift          => g_fft.use_fft_shift,
				g_separate           => g_fft.use_separate,
				g_dont_flip_channels => g_dont_flip_channels,
				g_nof_points         => g_fft.nof_points,
				g_nof_chan           => g_fft.nof_chan,
				g_ram_primitive 	 => g_ram_primitive
			)
			port map(
				clken   => clken,
				clk     => clk,
				rst     => rst,
				in_dat  => in_cplx,
				in_val  => data_val(0),
				out_dat => out_cplx,
				out_val => raw_out_val
			);

		raw_out_re <= out_cplx(g_fft.stage_dat_w - 1 downto 0);
		raw_out_im <= out_cplx(2 * g_fft.stage_dat_w - 1 downto g_fft.stage_dat_w);

	end generate;

	no_reorder_no_generate : if (g_fft.use_separate = false and g_fft.use_reorder = false) generate
		raw_out_re  <= data_re(0);
		raw_out_im  <= data_im(0);
		raw_out_val <= data_val(0);
	end generate;

	------------------------------------------------------------------------------
	-- pipelined FFT output requantization
	------------------------------------------------------------------------------
	u_requantize_re : entity casper_requantize_lib.common_requantize
		generic map(
			g_representation      => "SIGNED",
			g_lsb_w               => c_out_scale_w,
			g_lsb_round           => c_round,
			g_lsb_round_clip      => FALSE,
			g_msb_clip            => c_clip,
			g_msb_clip_symmetric  => FALSE,
			g_pipeline_remove_lsb => c_pipeline_remove_lsb,
			g_pipeline_remove_msb => 0,
			g_in_dat_w            => g_fft.stage_dat_w,
			g_out_dat_w           => g_fft.out_dat_w
		)
		port map(
			clk     => clk,
			in_dat  => raw_out_re,
			out_dat => out_re,
			out_ovr => open
		);

	u_requantize_im : entity casper_requantize_lib.common_requantize
		generic map(
			g_representation      => "SIGNED",
			g_lsb_w               => c_out_scale_w,
			g_lsb_round           => c_round,
			g_lsb_round_clip      => FALSE,
			g_msb_clip            => c_clip,
			g_msb_clip_symmetric  => FALSE,
			g_pipeline_remove_lsb => c_pipeline_remove_lsb,
			g_pipeline_remove_msb => 0,
			g_in_dat_w            => g_fft.stage_dat_w,
			g_out_dat_w           => g_fft.out_dat_w
		)
		port map(
			clk     => clk,
			in_dat  => raw_out_im,
			out_dat => out_im,
			out_ovr => open
		);

	-- Valid Output
	u_out_val : entity common_components_lib.common_pipeline_sl
		generic map(
			g_pipeline => c_pipeline_remove_lsb
		)
		port map(
			rst     => rst,
			clk     => clk,
			in_dat  => raw_out_val,
			out_dat => out_val
		);
end str;
