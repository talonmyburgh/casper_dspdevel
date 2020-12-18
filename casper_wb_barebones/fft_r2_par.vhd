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
-- Purpose: The fft_r2_par unit performs a complex parallel FFT.
--
--          There are two optional features: 
--
--          * Reordering: When enabled the output bins of the FFT are re-ordered in 
--                        in such a way that the bins represent the frequencies in an 
--                        incrementing way. 
--
--          * Separation: When enabled the rtwo_fft can be used to process two real streams.
--                        The first real stream (A) presented on the real input, the second 
--                        real stream (B) presented on the imaginary input. 
--                        The separation unit outputs the spectrum of A and B in 
--                        an alternating way: A(0), B(0), A(1), B(1).... etc
--                        The separate function adds and subtracts two complex bins. 
--                        Therefore it causes 1 bit growth that needs to be rounded, as
--                        explained in fft_sepa.vhd

library ieee, common_pkg_lib, common_components_lib, casper_adder_lib, casper_requantize_lib, r2sdf_fft_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;
use work.fft_gnrcs_intrfcs_pkg.all;

entity fft_r2_par is
	generic(
		g_fft      : t_fft          := c_fft; 				--! generics for the FFT
		g_pipeline : t_fft_pipeline := c_fft_pipeline	 	--! generics for pipelining, defined in r2sdf_fft_lib.rTwoSDFPkg
	);
	port(
		clk        : in  std_logic;											--! Clock
		rst        : in  std_logic := '0';									--! Reset
		in_re_arr  : in  t_fft_slv_arr_stg(g_fft.nof_points - 1 downto 0);	--! Input real data (nof_points wide)
		in_im_arr  : in  t_fft_slv_arr_stg(g_fft.nof_points - 1 downto 0);	--! Input imag data (nof_points wide)
		shiftreg   : in  std_logic_vector(c_stages_par - 1 downto 0); 		--! Par stage long shiftreg
		in_val     : in  std_logic := '1';									--! In data valid
		out_re_arr : out t_fft_slv_arr_stg(g_fft.nof_points - 1 downto 0);	--! Output real data (nof_points wide)
		out_im_arr : out t_fft_slv_arr_stg(g_fft.nof_points - 1 downto 0);	--! Output imag data (nof_points wide)
		ovflw	   : out std_logic_vector(c_stages_par - 1 downto 0);		--! Par stage long ovflw register
		out_val    : out std_logic											--! Out data valid
	);
end entity fft_r2_par;

architecture str of fft_r2_par is

	------------------------------------------------------------------------------------------------
	-- This function determines the input number (return value) to which the output of a butterfly 
	-- should be connected, based on the output-sequence-number(element), the stage number(stage) 
	-- and the number of points of the FFT (nr_of_points).                        
	--
	-- The following table shows the connection matrix for a 16-point parallel FFT, where the 
	-- output column refers to the output sequence number of each stage and the stage columns
	-- give the corresponding input sequence number of the connected stage. In other words:
	--  output 3 of stage 4 is connected to input 10 of stage 3. 
	--  output 6 of stage 3 is connected to input  3 of stage 2. 
	--
	--  output  stage 3  stage 2  stage 1
	--
	--    0        0 |      0 |      0 |
	--    1        8 |      4 |      2 |
	--    2        2 |      2 |      1    
	--    3       10 |      6 |      3  
	--    4        4 |      1        4 |
	--    5       12 |      5        6 |
	--    6        6 |      3        5      
	--    7       14 |      7        7    
	--    8        1        8 |      8 |
	--    9        9       12 |     10 |
	--   10        3       10 |      9       
	--   11       11       14 |     11     
	--   12        5        9       12 |
	--   13       13       13       14 |
	--   14        7       11       13       
	--   15       15       15       15     
	--
	-- The function first checks if the output element falls in one of the "even" areas that 
	-- are marked by a "|". If so, it checks if the input element is odd or even. If even
	-- then output is equal to the input element. If odd then output is element+offset. 
	-- It the output element falls in an "odd" area: input element even => output= element - offset
	-- input element odd => output = element.   

	function func_butterfly_connect(array_index, stage, nr_of_points : natural) return natural is
		variable v_nr_of_domains : natural; -- Variable that represents the number of "even" areas. 
		variable v_return        : natural; -- Holds the return value
		variable v_offset        : natural; -- Offset
	begin
		v_nr_of_domains := nr_of_points / 2**(stage + 1);
		v_offset        := 2**stage;
		for I in 0 to v_nr_of_domains loop
			if array_index >= (2 * I) * 2**stage and array_index < (2 * I + 1) * 2**stage then -- Detect if output is an even section
				if (array_index mod 2) = 0 then -- Check if input value is odd or even
					v_return := array_index; -- When even: value of element                                                 
				else
					v_return := array_index + v_offset - 1; -- When odd: value of element + offset
				end if;
			elsif array_index >= (2 * I + 1) * 2**stage and array_index < (2 * I + 2) * 2**stage then
				if (array_index mod 2) = 0 then -- Check if input value is odd or even
					v_return := array_index - v_offset + 1; -- When even: offset is subtracted from the element
				else
					v_return := array_index; -- When odd: element stays the the same.       
				end if;
			end if;
		end loop;
		return v_return;
	end;

	constant c_pipeline_add_sub    : natural := 1;
	constant c_pipeline_remove_lsb : natural := 1;
	constant c_sepa_round          : boolean := true; -- must be true, because separate should round the 1 bit growth

	constant c_nof_stages        : natural := ceil_log2(g_fft.nof_points);
	constant c_nof_bf_per_stage  : natural := g_fft.nof_points / 2;
	constant c_in_scale_w_tester : integer := g_fft.stage_dat_w - g_fft.in_dat_w - sel_a_b(g_fft.guard_enable, g_fft.guard_w, 0);
	constant c_in_scale_w        : natural := sel_a_b(c_in_scale_w_tester > 0, c_in_scale_w_tester, 0); -- Only scale when in_dat_w is not too big. 

	constant c_out_scale_w : integer := g_fft.stage_dat_w - g_fft.out_dat_w - g_fft.out_gain_w; -- Estimate number of LSBs to throw away when > 0 or insert when < 0

	type t_stage_dat_arr is array (integer range <>) of std_logic_vector(g_fft.stage_dat_w - 1 downto 0);
	type t_stage_sum_arr is array (integer range <>) of std_logic_vector(g_fft.stage_dat_w downto 0);
	type t_data_arr2 is array (c_nof_stages downto 0) of t_stage_dat_arr(g_fft.nof_points - 1 downto 0);
	type t_val_arr is array (c_nof_stages downto 0) of std_logic_vector(g_fft.nof_points - 1 downto 0);

	signal data_re    : t_data_arr2;
	signal data_im    : t_data_arr2;
	signal data_val   : t_val_arr;
	signal int_re_arr : t_stage_dat_arr(g_fft.nof_points - 1 downto 0);
	signal int_im_arr : t_stage_dat_arr(g_fft.nof_points - 1 downto 0);
	signal fft_re_arr : t_stage_dat_arr(g_fft.nof_points - 1 downto 0);
	signal fft_im_arr : t_stage_dat_arr(g_fft.nof_points - 1 downto 0);
	signal add_arr    : t_stage_sum_arr(g_fft.nof_points - 1 downto 0);
	signal sub_arr    : t_stage_sum_arr(g_fft.nof_points - 1 downto 0);
	signal int_val    : std_logic;
	signal fft_val    : std_logic;

begin

	------------------------------------------------------------------------------
	-- Inputs are prepared/shuffled for the input stage    
	------------------------------------------------------------------------------
	gen_get_the_inputs : for I in 0 to g_fft.nof_points / 2 - 1 generate
		data_re(c_nof_stages)(2 * I)     <= scale_and_resize_svec(in_re_arr(I), c_in_scale_w, g_fft.stage_dat_w);
		data_re(c_nof_stages)(2 * I + 1) <= scale_and_resize_svec(in_re_arr(I + g_fft.nof_points / 2), c_in_scale_w, g_fft.stage_dat_w);
		data_im(c_nof_stages)(2 * I)     <= scale_and_resize_svec(in_im_arr(I), c_in_scale_w, g_fft.stage_dat_w);
		data_im(c_nof_stages)(2 * I + 1) <= scale_and_resize_svec(in_im_arr(I + g_fft.nof_points / 2), c_in_scale_w, g_fft.stage_dat_w);
		data_val(c_nof_stages)(I)        <= in_val;
	end generate;

	------------------------------------------------------------------------------
	-- parallel FFT stages
	------------------------------------------------------------------------------
	gen_fft_stages : for stage in c_nof_stages downto 1 generate
		gen_fft_elements : for element in 0 to c_nof_bf_per_stage - 1 generate
			u_element : entity work.fft_r2_bf_par
				generic map(
					g_stage        => stage,
					g_element      => element,
					g_pipeline     => g_pipeline
				)
				port map(
					clk      => clk,
					rst      => rst,
					x_in_re  => data_re(stage)(2 * element),
					x_in_im  => data_im(stage)(2 * element),
					y_in_re  => data_re(stage)(2 * element + 1),
					y_in_im  => data_im(stage)(2 * element + 1),
					scale	 => shiftreg(stage-1),				-- Scale or not at stage
					in_val   => data_val(stage)(element),
					x_out_re => data_re(stage - 1)(func_butterfly_connect(2 * element, stage - 1, g_fft.nof_points)),
					x_out_im => data_im(stage - 1)(func_butterfly_connect(2 * element, stage - 1, g_fft.nof_points)),
					y_out_re => data_re(stage - 1)(func_butterfly_connect(2 * element + 1, stage - 1, g_fft.nof_points)),
					y_out_im => data_im(stage - 1)(func_butterfly_connect(2 * element + 1, stage - 1, g_fft.nof_points)),
					ovflw	 => ovflw(stage - 1),				-- Record if overflow occured at stage
					out_val  => data_val(stage - 1)(element)
				);
		end generate;
	end generate;

	--------------------------------------------------------------------------------
	-- Optional output reorder 
	--------------------------------------------------------------------------------
	gen_reorder : if g_fft.use_reorder and not g_fft.use_fft_shift generate
		-- unflip the bin indices for complex and also required to prepare for g_fft.use_separate of two real
		gen_reordering : for I in 0 to g_fft.nof_points - 1 generate
			int_re_arr(I) <= data_re(0)(flip(I, c_nof_stages));
			int_im_arr(I) <= data_im(0)(flip(I, c_nof_stages));
		end generate;
	end generate;

	gen_fft_shift : if g_fft.use_reorder and g_fft.use_fft_shift generate
		-- unflip the bin indices and apply fft_shift for complex only, to have bin frequencies from negative via zero to positive
		gen_reordering : for I in 0 to g_fft.nof_points - 1 generate
			int_re_arr(fft_shift(I, c_nof_stages)) <= data_re(0)(flip(I, c_nof_stages));
			int_im_arr(fft_shift(I, c_nof_stages)) <= data_im(0)(flip(I, c_nof_stages));
		end generate;
	end generate;

	no_reorder : if g_fft.use_reorder = false generate
		-- use flipped bin index order as it comes by default
		int_re_arr <= data_re(0);
		int_im_arr <= data_im(0);
	end generate;
	int_val <= data_val(0)(0);

	--------------------------------------------------------------------------------
	-- Optional separate 
	--------------------------------------------------------------------------------
	gen_separate : if g_fft.use_separate generate
		---------------------------------------------------------------------------
		-- Calulate the positive bins
		---------------------------------------------------------------------------
		gen_positive_bins : for I in 1 to g_fft.nof_points / 2 - 1 generate
			-- common_add_sub
			a_output_real_adder : entity casper_adder_lib.common_add_sub
				generic map(
					g_direction       => "ADD",
					g_representation  => "SIGNED",
					g_pipeline_input  => 0,
					g_pipeline_output => c_pipeline_add_sub,
					g_in_dat_w        => g_fft.stage_dat_w,
					g_out_dat_w       => g_fft.stage_dat_w + 1
				)
				port map(
					clk    => clk,
					in_a   => int_re_arr(g_fft.nof_points - I),
					in_b   => int_re_arr(I),
					result => add_arr(2 * I)
				);

			b_output_real_adder : entity casper_adder_lib.common_add_sub
				generic map(
					g_direction       => "ADD",
					g_representation  => "SIGNED",
					g_pipeline_input  => 0,
					g_pipeline_output => c_pipeline_add_sub,
					g_in_dat_w        => g_fft.stage_dat_w,
					g_out_dat_w       => g_fft.stage_dat_w + 1
				)
				port map(
					clk    => clk,
					in_a   => int_im_arr(g_fft.nof_points - I),
					in_b   => int_im_arr(I),
					result => add_arr(2 * I + 1)
				);

			a_output_imag_subtractor : entity casper_adder_lib.common_add_sub
				generic map(
					g_direction       => "SUB",
					g_representation  => "SIGNED",
					g_pipeline_input  => 0,
					g_pipeline_output => c_pipeline_add_sub,
					g_in_dat_w        => g_fft.stage_dat_w,
					g_out_dat_w       => g_fft.stage_dat_w + 1
				)
				port map(
					clk    => clk,
					in_a   => int_im_arr(I),
					in_b   => int_im_arr(g_fft.nof_points - I),
					result => sub_arr(2 * I)
				);

			b_output_imag_subtractor : entity casper_adder_lib.common_add_sub
				generic map(
					g_direction       => "SUB",
					g_representation  => "SIGNED",
					g_pipeline_input  => 0,
					g_pipeline_output => c_pipeline_add_sub,
					g_in_dat_w        => g_fft.stage_dat_w,
					g_out_dat_w       => g_fft.stage_dat_w + 1
				)
				port map(
					clk    => clk,
					in_a   => int_re_arr(g_fft.nof_points - I),
					in_b   => int_re_arr(I),
					result => sub_arr(2 * I + 1)
				);

			gen_sepa_truncate : IF c_sepa_round = false GENERATE
				-- truncate the one LSbit
				fft_re_arr(2 * I)     <= add_arr(2 * I)(g_fft.stage_dat_w DOWNTO 1); -- A real
				fft_re_arr(2 * I + 1) <= add_arr(2 * I + 1)(g_fft.stage_dat_w DOWNTO 1); -- B real
				fft_im_arr(2 * I)     <= sub_arr(2 * I)(g_fft.stage_dat_w DOWNTO 1); -- A imag
				fft_im_arr(2 * I + 1) <= sub_arr(2 * I + 1)(g_fft.stage_dat_w DOWNTO 1); -- B imag
			end generate;

			gen_sepa_round : IF c_sepa_round = true GENERATE
				-- round the one LSbit
				round_re_a : ENTITY casper_requantize_lib.common_round
					GENERIC MAP(
						g_representation  => "SIGNED", -- SIGNED (round +-0.5 away from zero to +- infinity) or UNSIGNED rounding (round 0.5 up to + inifinity)
						g_round           => TRUE, -- when TRUE round the input, else truncate the input
						g_round_clip      => FALSE, -- when TRUE clip rounded input >= +max to avoid wrapping to output -min (signed) or 0 (unsigned)
						g_pipeline_input  => 0, -- >= 0
						g_pipeline_output => 0, -- >= 0, use g_pipeline_input=0 and g_pipeline_output=0 for combinatorial output
						g_in_dat_w        => g_fft.stage_dat_w + 1,
						g_out_dat_w       => g_fft.stage_dat_w
					)
					PORT MAP(
						clk     => clk,
						in_dat  => add_arr(2 * I),
						out_dat => fft_re_arr(2 * I)
					);

				round_re_b : ENTITY casper_requantize_lib.common_round
					GENERIC MAP(
						g_representation  => "SIGNED", -- SIGNED (round +-0.5 away from zero to +- infinity) or UNSIGNED rounding (round 0.5 up to + inifinity)
						g_round           => TRUE, -- when TRUE round the input, else truncate the input
						g_round_clip      => FALSE, -- when TRUE clip rounded input >= +max to avoid wrapping to output -min (signed) or 0 (unsigned)
						g_pipeline_input  => 0, -- >= 0
						g_pipeline_output => 0, -- >= 0, use g_pipeline_input=0 and g_pipeline_output=0 for combinatorial output
						g_in_dat_w        => g_fft.stage_dat_w + 1,
						g_out_dat_w       => g_fft.stage_dat_w
					)
					PORT MAP(
						clk     => clk,
						in_dat  => add_arr(2 * I + 1),
						out_dat => fft_re_arr(2 * I + 1)
					);

				round_im_a : ENTITY casper_requantize_lib.common_round
					GENERIC MAP(
						g_representation  => "SIGNED", -- SIGNED (round +-0.5 away from zero to +- infinity) or UNSIGNED rounding (round 0.5 up to + inifinity)
						g_round           => TRUE, -- when TRUE round the input, else truncate the input
						g_round_clip      => FALSE, -- when TRUE clip rounded input >= +max to avoid wrapping to output -min (signed) or 0 (unsigned)
						g_pipeline_input  => 0, -- >= 0
						g_pipeline_output => 0, -- >= 0, use g_pipeline_input=0 and g_pipeline_output=0 for combinatorial output
						g_in_dat_w        => g_fft.stage_dat_w + 1,
						g_out_dat_w       => g_fft.stage_dat_w
					)
					PORT MAP(
						clk     => clk,
						in_dat  => sub_arr(2 * I),
						out_dat => fft_im_arr(2 * I)
					);

				round_im_b : ENTITY casper_requantize_lib.common_round
					GENERIC MAP(
						g_representation  => "SIGNED", -- SIGNED (round +-0.5 away from zero to +- infinity) or UNSIGNED rounding (round 0.5 up to + inifinity)
						g_round           => TRUE, -- when TRUE round the input, else truncate the input
						g_round_clip      => FALSE, -- when TRUE clip rounded input >= +max to avoid wrapping to output -min (signed) or 0 (unsigned)
						g_pipeline_input  => 0, -- >= 0
						g_pipeline_output => 0, -- >= 0, use g_pipeline_input=0 and g_pipeline_output=0 for combinatorial output
						g_in_dat_w        => g_fft.stage_dat_w + 1,
						g_out_dat_w       => g_fft.stage_dat_w
					)
					PORT MAP(
						clk     => clk,
						in_dat  => sub_arr(2 * I + 1),
						out_dat => fft_im_arr(2 * I + 1)
					);
			end generate;
		end generate;

		---------------------------------------------------------------------------
		-- Generate bin 0 directly
		---------------------------------------------------------------------------
		-- Index N=g_fft.nof_points wraps to index 0:
		-- . fft_re_arr(0) = (int_re_arr(0) + int_re_arr(N)) / 2 = int_re_arr(0)
		-- . fft_re_arr(1) = (int_im_arr(0) + int_im_arr(N)) / 2 = int_im_arr(0)
		-- . fft_im_arr(0) = (int_im_arr(0) - int_im_arr(N)) / 2 = 0
		-- . fft_im_arr(1) = (int_re_arr(0) - int_re_arr(N)) / 2 = 0

		u_pipeline_a_re_0 : entity common_components_lib.common_pipeline
			generic map(
				g_pipeline  => c_pipeline_add_sub,
				g_in_dat_w  => g_fft.stage_dat_w,
				g_out_dat_w => g_fft.stage_dat_w
			)
			port map(
				clk     => clk,
				in_dat  => int_re_arr(0),
				out_dat => fft_re_arr(0)
			);

		u_pipeline_b_re_0 : entity common_components_lib.common_pipeline
			generic map(
				g_pipeline  => c_pipeline_add_sub,
				g_in_dat_w  => g_fft.stage_dat_w,
				g_out_dat_w => g_fft.stage_dat_w
			)
			port map(
				clk     => clk,
				in_dat  => int_im_arr(0),
				out_dat => fft_re_arr(1)
			);

		-- The imaginary outputs of A(0) and B(0) are always zero in case two real inputs are provided
		fft_im_arr(0) <= (others => '0');
		fft_im_arr(1) <= (others => '0');

		------------------------------------------------------------------------------
		-- Valid pipelining for separate
		------------------------------------------------------------------------------
		u_seperate_fft_val : entity common_components_lib.common_pipeline_sl
			generic map(
				g_pipeline => c_pipeline_add_sub
			)
			port map(
				clk     => clk,
				in_dat  => int_val,
				out_dat => fft_val
			);
	end generate;

	no_separate : if g_fft.use_separate = false generate
		assign_outputs : for I in 0 to g_fft.nof_points - 1 generate
			fft_re_arr(I) <= int_re_arr(I);
			fft_im_arr(I) <= int_im_arr(I);
		end generate;
		fft_val <= int_val;
	end generate;

	------------------------------------------------------------------------------
	-- Parallel FFT output requantization
	------------------------------------------------------------------------------
	gen_output_requantizers : for I in 0 to g_fft.nof_points - 1 generate
		u_requantize_re : entity casper_requantize_lib.common_requantize
			generic map(
				g_representation      => "SIGNED",
				g_lsb_w               => c_out_scale_w,
				g_lsb_round           => TRUE,
				g_lsb_round_clip      => FALSE,
				g_msb_clip            => FALSE,
				g_msb_clip_symmetric  => FALSE,
				g_pipeline_remove_lsb => c_pipeline_remove_lsb,
				g_pipeline_remove_msb => 0,
				g_in_dat_w            => g_fft.stage_dat_w,
				g_out_dat_w           => g_fft.out_dat_w
			)
			port map(
				clk     => clk,
				in_dat  => fft_re_arr(I),
				out_dat => out_re_arr(I),
				out_ovr => open
			);

		u_requantize_im : entity casper_requantize_lib.common_requantize
			generic map(
				g_representation      => "SIGNED",
				g_lsb_w               => c_out_scale_w,
				g_lsb_round           => TRUE,
				g_lsb_round_clip      => FALSE,
				g_msb_clip            => FALSE,
				g_msb_clip_symmetric  => FALSE,
				g_pipeline_remove_lsb => c_pipeline_remove_lsb,
				g_pipeline_remove_msb => 0,
				g_in_dat_w            => g_fft.stage_dat_w,
				g_out_dat_w           => g_fft.out_dat_w
			)
			port map(
				clk     => clk,
				in_dat  => fft_im_arr(I),
				out_dat => out_im_arr(I),
				out_ovr => open
			);

	end generate;

	u_out_val : entity common_components_lib.common_pipeline_sl
		generic map(
			g_pipeline => c_pipeline_remove_lsb
		)
		port map(
			rst     => rst,
			clk     => clk,
			in_dat  => fft_val,
			out_dat => out_val
		);
end str;
