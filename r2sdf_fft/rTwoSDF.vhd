--! @file
--! @brief r2SDF pipelined FFT implementation

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

--! Purpose: Pipelined radix 2 FFT
--! Description: CASPER R2SDF FFT implementation
-- Remarks: doc/readme.txt

--! Library: IEEE, common_pkg_lib, casper_requantize_lib
library ieee, common_pkg_lib, casper_requantize_lib, common_components_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use work.rTwoSDFPkg.all;

--! @dot 
--! digraph rTwoSDF {
--!	rankdir="LR";
--! node [shape=box, fontname=Helvetica, fontsize=12,color="black"];
--! rTwoSDF;
--! node [shape=plaintext];
--! clk;
--! rst;
--! in_re;
--! in_im;
--! in_val;
--! out_re;
--! out_im;
--! out_val;
--! clk -> rTwoSDF;
--! in_re -> rTwoSDF;
--! in_im -> rTwoSDF;
--! in_val -> rTwoSDF;
--! rst -> rTwoSDF;
--! rTwoSDF -> out_re;
--! rTwoSDF -> out_im;
--! rTwoSDF -> out_val;
--!}
--! @enddot

entity rTwoSDF is
	generic(
		-- generics for the FFT    
		g_nof_chan      : natural := 0; --! Exponent of nr of subbands (0 means 1 subband)
		g_use_reorder   : boolean := true; --! Reorder output
		g_in_dat_w      : natural := 14; --! Number of input bits
		g_out_dat_w     : natural := 18; --! Number of output bits
		g_stage_dat_w   : natural := 18; --! Number of bits used between the stages
		g_guard_w       : natural := 2; --! Guard bits are used to avoid overflow in single FFT stage   
		g_nof_points    : natural := 1024; --! N point FFT
		-- generics for rTwoSDFStage
		g_variant       : string  := "4DSP"; --! Use 3dsp or 4dsp for multiplication
		g_use_dsp       : string  := "yes"; --! Use dsp48 chips (yes) or LUT's (no) for cmults in butterflies
		g_ovflw_behav   : string  := "WRAP";   --! = "WRAP" or "SATURATE" will default to WRAP if invalid option used
		g_round		    : t_rounding_mode  := ROUND;    --! ROUND, ROUNDINF or TRUNCATE
		g_use_mult_round: t_rounding_mode  := TRUNCATE; --! ROUND, ROUNDINF or TRUNCATE
		g_twid_dat_w	: natural := 18;
		g_max_addr_w	: natural := 9;
		g_twid_file_stem: string  := c_twid_file_stem;
		-- pipeline generics
		g_stage_lat     : natural := 1; --! stage latencies
		g_weight_lat    : natural := 1;
		g_mult_lat      : natural := 4;
		g_bf_lat        : natural := 1;
		g_bf_use_zdly   : natural := 1;
		g_bf_in_a_zdly  : natural := 0;
		g_bf_out_d_zdly : natural := 0;
		--generics for rTwoOrder
		g_ram_primitive : STRING  := "auto"
	);
	port(
		clk     	: in  std_logic;        							--! Clock input
		ce      	: in  std_logic := '1'; 							--! Clock enable
		rst     	: in  std_logic := '0'; 							--! Reset input (resets on high)
		in_re   	: in  std_logic_vector(g_in_dat_w - 1 downto 0); 	--! Real input (data width = g_in_dat_w)
		in_im   	: in  std_logic_vector(g_in_dat_w - 1 downto 0); 	--! Imag input (data width = g_in_dat_w)
		in_val  	: in  std_logic := '1'; 							--! Input select for delay component (i.e. accept input to delay)
		shiftreg	: in  std_logic_vector(ceil_log2(g_nof_points) - 1 downto 0); 	--! Shift register for specifying scaling at each of the r2SDFStages.
		out_re  	: out std_logic_vector(g_out_dat_w - 1 downto 0); 	--! Output real value (data width = g_out_dat_w)
		out_im  	: out std_logic_vector(g_out_dat_w - 1 downto 0); 	--! Output imag value (data width = g_out_dat_w)
		ovflw		: out std_logic_vector(ceil_log2(g_nof_points) - 1 downto 0);  --! Overflow register for specifying at which stage overflow may have occured.
		out_val 	: out std_logic         							--!Output valid signal (valid when high)
	);
end entity rTwoSDF;

architecture str of rTwoSDF is

	constant c_clip			: boolean := sel_a_b(g_ovflw_behav = "SATURATE", TRUE, FALSE);
	constant c_nof_stages   : natural := ceil_log2(g_nof_points);

	
	constant c_pipeline_remove_lsb : natural := 0;

	-- Round last stage output to g_out_dat_w if g_out_dat_w < g_stage_dat_w else resize to g_out_dat_w
	constant c_out_scale_w : integer := g_stage_dat_w - g_out_dat_w; -- Estimate number of LSBs to round throw away when > 0 or insert when < 0

	-- Scale the input to make optimal use of the g_stage_dat_w of the stages, using a margin of g_guard_w to account for factor > 2 gain of the first stage
	constant c_in_scale_w : natural := g_stage_dat_w - g_guard_w - g_in_dat_w; -- use type natural instead of integer to implicitly ensure that the g_stage_dat_w >= g_input_dat_w

	-- number the stage instances from c_nof_stages:1
	-- . the data input for the first stage has index c_nof_stages
	-- . the data output of the last stage has index 0
	type t_data_arr is array (c_nof_stages downto 0) of std_logic_vector(g_stage_dat_w - 1 downto 0);

	signal data_re  : t_data_arr;
	signal data_im  : t_data_arr;
	signal data_val : std_logic_vector(c_nof_stages downto 0) := (others => '0');

	signal out_cplx     : std_logic_vector(2 * g_stage_dat_w - 1 downto 0);
	signal raw_out_cplx : std_logic_vector(2 * g_stage_dat_w - 1 downto 0);
	signal raw_out_re   : std_logic_vector(g_stage_dat_w - 1 downto 0);
	signal raw_out_im   : std_logic_vector(g_stage_dat_w - 1 downto 0);
	signal raw_out_val  : std_logic;
	constant pipeline   : t_fft_pipeline := (g_stage_lat, g_weight_lat, g_mult_lat, g_bf_lat, g_bf_use_zdly, g_bf_in_a_zdly, g_bf_out_d_zdly);

begin
	-- Inputs
	data_re(c_nof_stages)  <= scale_and_resize_svec(in_re, c_in_scale_w, g_stage_dat_w);
	data_im(c_nof_stages)  <= scale_and_resize_svec(in_im, c_in_scale_w, g_stage_dat_w);
	data_val(c_nof_stages) <= in_val;

	------------------------------------------------------------------------------
	-- pipelined FFT stages
	------------------------------------------------------------------------------

	gen_fft : for stage in c_nof_stages downto 1 generate
		u_stage : entity work.rTwoSDFStage
			generic map(
				g_nof_chan       => g_nof_chan,
				g_stage          => stage,
				g_nof_points	 => g_nof_points,
				g_wb_factor		 => 1,
				g_wb_inst		 => 0,
				g_twid_dat_w	 => g_twid_dat_w,
				g_max_addr_w	 => g_max_addr_w,
				g_use_variant    => g_variant,
				g_use_dsp        => g_use_dsp,
				g_ovflw_behav	 => g_ovflw_behav,
				g_round		 	 => g_round, 
				g_use_mult_round => g_use_mult_round,
				g_ram_primitive	 => g_ram_primitive,
				g_twid_file_stem => g_twid_file_stem,
				g_pipeline       => pipeline
			)
			port map(
                clk     => clk,
                rst     => rst,
                in_re   => data_re(stage),
                in_im   => data_im(stage),
                scale   => shiftreg(stage-1), -- On average all stages have a gain factor of 2 therefore each stage needs to round 1 bit except for the last g_guard_w nof stages due to the input c_in_scale_w
                in_val  => data_val(stage),
                out_re  => data_re(stage - 1),
                out_im  => data_im(stage - 1),
                ovflw    => ovflw(stage-1),
                out_val => data_val(stage - 1)
			);
	end generate;

	------------------------------------------------------------------------------
	-- Optional output reorder
	------------------------------------------------------------------------------

	no_reorder : if g_use_reorder = false generate
		raw_out_re  <= data_re(0);
		raw_out_im  <= data_im(0);
		raw_out_val <= data_val(0);
	end generate;

	gen_reorder : if g_use_reorder = true generate
		raw_out_cplx <= data_im(0) & data_re(0);

		raw_out_re <= out_cplx(g_stage_dat_w - 1 downto 0);
		raw_out_im <= out_cplx(2 * g_stage_dat_w - 1 downto g_stage_dat_w);

		u_cplx : entity work.rTwoOrder
			generic map(
				g_nof_points    => g_nof_points,
				g_nof_chan      => g_nof_chan,
				g_dat_w         => 2 * g_stage_dat_w,
				g_ram_primitive => g_ram_primitive
			)
			port map(
				clk     => clk,
				ce      => ce,
				rst     => rst,
				in_dat  => raw_out_cplx,
				in_val  => data_val(0),
				out_dat => out_cplx,
				out_val => raw_out_val
			);
	end generate;

	------------------------------------------------------------------------------
	-- pipelined FFT output requantization
	------------------------------------------------------------------------------
	u_requantize_re : entity casper_requantize_lib.common_requantize
		generic map(
			g_representation      => "SIGNED",
			g_lsb_w               => c_out_scale_w,
			g_lsb_round           => g_round,
			g_lsb_round_clip      => FALSE,
			g_msb_clip            => c_clip,
			g_msb_clip_symmetric  => FALSE,
			g_pipeline_remove_lsb => c_pipeline_remove_lsb,
			g_pipeline_remove_msb => 0,
			g_in_dat_w            => g_stage_dat_w,
			g_out_dat_w           => g_out_dat_w
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
			g_lsb_round           => g_round,
			g_lsb_round_clip      => FALSE,
			g_msb_clip            => c_clip,
			g_msb_clip_symmetric  => FALSE,
			g_pipeline_remove_lsb => c_pipeline_remove_lsb,
			g_pipeline_remove_msb => 0,
			g_in_dat_w            => g_stage_dat_w,
			g_out_dat_w           => g_out_dat_w
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
