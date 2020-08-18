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

LIBRARY IEEE, common_pkg_lib, dp_pkg_lib, casper_mm_lib, casper_ram_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_textio.all;
USE STD.textio.all;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;
USE casper_mm_lib.tb_common_mem_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;
USE work.fft_pkg.ALL;

PACKAGE tb_fft_pkg IS

	CONSTANT c_fft_nof_subbands_max : NATURAL := 256;

	SUBTYPE t_fft_sst_arr IS t_slv_64_arr(c_fft_nof_subbands_max - 1 DOWNTO 0); -- use subtype to allow using assignments via t_slv_64_arr as well                                         
	TYPE t_fft_sst_arr2 IS ARRAY (INTEGER RANGE <>) OF t_fft_sst_arr; -- Private procedures

	-- map fft output index to bin frequency
	function fft_index_to_bin_frequency(wb_factor, nof_points, index : natural; use_reorder, use_fft_shift, use_separate : boolean) return natural;

	-- use out_val and out_val_cnt to determine the FFT output bin frequency and channel
	procedure proc_fft_out_control(wb_factor          : natural;
	                               nof_points         : natural;
	                               nof_channels       : natural;
	                               use_reorder        : boolean;
	                               use_fft_shift      : boolean;
	                               use_separate       : boolean;
	                               signal out_val_cnt : in natural; -- count at sclk sample rate
	                               signal out_val     : in std_logic;
	                               signal out_val_a   : out std_logic;
	                               signal out_val_b   : out std_logic;
	                               signal out_channel : out natural;
	                               signal out_bin     : out natural;
	                               signal out_bin_cnt : out natural);

	PROCEDURE proc_read_input_file(SIGNAL clk          : IN STD_LOGIC;
	                               SIGNAL in_file_data : OUT t_integer_matrix;
	                               SIGNAL in_file_sync : OUT STD_LOGIC_VECTOR;
	                               SIGNAL in_file_val  : OUT STD_LOGIC_VECTOR;
	                               file_name           : IN STRING);

	PROCEDURE proc_read_input_file(SIGNAL clk          : IN STD_LOGIC; -- Same read procedure for data files that do not contain a valid and sync column
	                               SIGNAL in_file_data : OUT t_integer_matrix;
	                               file_name           : IN STRING);

	PROCEDURE proc_fft_read_subband_statistics_memory(CONSTANT c_fft_lane   : IN NATURAL;
	                                                  CONSTANT c_fft        : IN t_fft;
	                                                  SIGNAL clk            : IN STD_LOGIC;
	                                                  SIGNAL mm_mosi        : OUT t_mem_mosi;
	                                                  SIGNAL mm_miso        : IN t_mem_miso;
	                                                  SIGNAL statistics_arr : OUT t_slv_64_arr);

	-- Private procedures  
	PROCEDURE proc_read_subband_stats(CONSTANT nof_subbands : IN NATURAL;
	                                  CONSTANT offset       : IN NATURAL;
	                                  SIGNAL clk            : IN STD_LOGIC;
	                                  SIGNAL mm_mosi        : OUT t_mem_mosi;
	                                  SIGNAL mm_miso        : IN t_mem_miso;
	                                  VARIABLE result       : OUT t_slv_64_arr);

	--  PROCEDURE proc_prepare_input_data(CONSTANT nof_subbands        : IN  NATURAL;      
	--                                    CONSTANT nof_inputs          : IN  NATURAL;      
	--                                    CONSTANT nof_input_streams   : IN  NATURAL;      
	--                                    CONSTANT input_stream_number : IN  NATURAL;      
	--                                    VARIABLE re_arr              : OUT t_integer_arr;
	--                                    VARIABLE im_arr              : OUT t_integer_arr;
	--                                             file_name           : IN  STRING);  

END tb_fft_pkg;

PACKAGE BODY tb_fft_pkg IS

	function fft_index_to_bin_frequency(wb_factor, nof_points, index : natural; use_reorder, use_fft_shift, use_separate : boolean) return natural is
		-- Purpose: map fft output index to bin frequency
		-- Description:
		--   The input index counts the bins as they are output by the HDL implementation of the FFT.
		--   This function maps this index to the corresponding bin frequency in the reference FFT.
		--   For the complex input reference FFT the assumption is that the bins are in fft_shift(fft())
		--   order, so first the negative frequencies, then 0 and the positive frequencies. For
		--   the real input reference FFT only 0 and the positive frequency bins are available.
		--
		--   For a N=8 point (complex) FFT the FFT index corresponds to FFT bin frequency according to:
		--
		--     0 1 2 3 4 5 6 7  -- index i
		--     0 4 2 6 1 5 3 7  -- flip(i)            : FFT bin frequency in bit-reversed index output order
		--     0 1 2 3 4 5 6 7  -- flip(flip(i)) = i  : FFT bin frequency after bit-reversed index flip
		--                                              yields Matlab fft() output order starting with
		--                                              [0 Hz, pos freqs incrementing, neg freqs incrementing]
		--     4 5 6 7 0 1 2 3  -- fft_shift(i)       : FFT bin frequency after bit-reversed index flip and
		--                                              fft_shift yields Matlab fft_shift(fft()) output order:
		--                                              [neg freqs incrementing, 0 Hz in the center, pos
		--                                              freqs incrementing]
		--     1 5 3 7 0 4 2 6  -- flip(fft_shift(i))
		--     4 0 6 2 5 1 7 3  -- fft_shift(flip(i)) : the order of fft_shift() and flip() matters
		--
		--   For real input only the 0 and positive frequency bins need to be kept:
		--
		--     0 1 2 3
		--
		--   The FFT needs to buffer the complex FFT output to be able to separate the FFT for two real
		--   inputs, because it needs access at indices N-m and m to do the separate.
		--   Therefore when use_separate=true then the use_reorder index flip is also done to have the bin
		--   frequencies in increasing order. The use_fft_shift is not applicable for real input.
		--
		--   For the complex FFT the index flip and fft_shift both require reordering in time, so buffering
		--   of the FFT output. The fft_shift is only useful after the index flip. Therefore when
		--   use_fft_shift=true then require that use_reorder=true. 
		--
		--   The bit-reverse index is a flip of the index bits. The flip() is the same as the inverse flip(),
		--   so index = flip(flip(index)). For wb_factor = 1 the flip() is done by use_reorder. For
		--   wb_factor > 1 the use_reorder implies that both the pipelined sections and the parallel section
		--   do there local flips. This combination of P serial flips and 1 parallel flip is not the same
		--   as the index flip.
		--
		--   The fft_shift() inverts the MSbit of the index. The fft_shift() is the same as the inverse
		--   fft_shift(), so index = fft_shift(fft_shift(index)).
		--
		--   The index counts from 0..nof_points-1. For wb_factor>1 the index first counts parallel over
		--   the P wide band streams and then serially. The transpose(i, P, N) function in common_pkg shows
		--   how the index counts over the P parallel streams and in time:
		--
		--                      i = 0 1 2 3 4 5 6 7
		--                                           t=0 1 2 3  p=
		--     transpose(i, 2, 4) = 0 2 4 6 1 3 5 7 :  0 2 4 6   0
		--                                             1 3 5 7   1
		--
		--                                           t=0 1 2 3  p=
		--     transpose(i, 4, 2) = 0 4 1 5 2 6 3 7 :  0 4       0
		--                                             1 5       1
		--                                             2 6       2
		--                                             3 7       3
		--
		--   In the HDL testbench the index i counts the FFT output valid samples. This index has to be 
		--   related to the bin frequency of the HDL FFT and to the same bin frequency in the Matlab
		--   reference data, to be able to verify the bin frequency output value.
		--   
		-- Example: wb_factor = 1
		--
		--   The default complex input FFT bit-reversed bin order and the Matlab reference bin order
		--   can relate to i as follows:
		--
		--      [scrambled bins]                   [0, pos, neg bins]                     [neg, 0, pos bins]
		--     b=0 4 2 6 1 5 3 7  --> flip(i) --> b=0 1 2 3 4 5 6 7 --> fft_shift(i) --> b=4 5 6 7 0 1 2 3
		--     i=0 1 2 3 4 5 6 7                  i=0 1 2 3 4 5 6 7                      i=0 1 2 3 4 5 6 7
		--
		--   The two real input FFT bin order (with A via real input and B via imaginary input) and
		--   Matlab reference bin order relate to i as follows:
		--
		--      [0, pos; alternating A,B]
		--     b=0 0 1 1 2 2 3 3  --> b = i/2
		--     i=0 1 2 3 4 5 6 7
		--
		--   Which bins the index i represents depends on the HDL generics use_reorder, use_fft_shift
		--   and use separate.
		--
		--     nof_points = 32 : index = 0..nof_points-1 = 0..31
		--
		--              index i    0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
		--          fft_shift(i)  16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
		--               flip(i)   0 16  8 24  4 20 12 28  2 18 10 26  6 22 14 30  1 17  9 25  5 21 13 29  3 19 11 27  7 23 15 31
		--     fft_shift(flip(i)) 16  0 24  8 20  4 28 12 18  2 26 10 22  6 30 14 17  1 25  9 21  5 29 13 19  3 27 11 23  7 31 15
		--                    i/2  0  0  1  1  2  2  3  3  4  4  5  5  6  6  7  7  8  8  9  9 10 10 11 11 12 12 13 13 14 14 15 15
		--
		--   Conclusion:-
		--     use_reorder  use_fft_shift  use_separate  name                 reference bin frequency:
		--     false        false          false         Complex              b = fft_shift(flip(i))
		--     true         false          false         Complex reordered    b = fft_shift(i)
		--     true         true           false         Complex fft_shifted  b = i
		--     true         false          true          Two real reordered   b = i/2
		--
		-- Example: wb_factor = 4
		--
		--   The default complex input FFT bit-reversed bin order and the Matlab reference bin order
		--   can relate to i as follows in wideband parallel order:
		--
		--     [scrambled bins] --> flip() --> [0, pos, neg bins] --> fft_shift() --> [neg, 0, pos bins]
		--     b=0  4  2  6  1  5  3  7       b=0  4  8 12 16 20 24 28               b=16 20 24 28  0  4  8 12
		--      16 20 18 22 17 21 19 23         1  5  9 13 17 21 25 29                 17 21 25 29  1  5  9 13
		--       8 12 10 14  9 13 11 15         2  6 10 14 18 22 26 30                 18 22 26 30  2  6 10 14
		--      24 28 26 30 25 29 27 31         3  7 11 15 19 23 27 31                 19 23 27 31  3  7 11 15
		--     
		--     i=0  4  8 12 16 20 24 28       i=0  4  8 12 16 20 24 28               i= 0  4  8 12 16 20 24 28
		--       1  5  9 13 17 21 25 29         1  5  9 13 17 21 25 29                  1  5  9 13 17 21 25 29
		--       2  6 10 14 18 22 26 30         2  6 10 14 18 22 26 30                  2  6 10 14 18 22 26 30
		--       3  7 11 15 19 23 27 31         3  7 11 15 19 23 27 31                  3  7 11 15 19 23 27 31
		--
		--   In the serial order this becomes:
		--
		--     [scrambled bins]    0 16  8 24  4 20 12 28  2 18 10 26  6 22 14 30  1 17  9 25  5 21 13 29  3 19 11 27  7 23 15 31
		--     [0, pos, neg bins]  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
		--     [neg, 0, pos bins] 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
		--                      i= 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
		--
		--   The index flip in the HDL that is done in the P pipelined FFT sections and then in the
		--   parallel FFT section results in:
		--
		--     [scrambled bins]             flip serial()            --> flip parallel()
		--     b=0  4  2  6  1  5  3  7     b=0  1  2  3  4  5  6  7     b=0  1  2  3  4  5  6  7
		--      16 20 18 22 17 21 19 23      16 17 18 19 20 21 22 23       8  9 10 11 12 13 14 15
		--       8 12 10 14  9 13 11 15       8  9 10 11 12 13 14 15      16 17 18 19 20 21 22 23
		--      24 28 26 30 25 29 27 31      24 25 26 27 28 29 30 31      24 25 26 27 28 29 30 31
		--     
		--     i=0  4  8 12 16 20 24 28     i=0  4  8 12 16 20 24 28     i=0  4  8 12 16 20 24 28
		--       1  5  9 13 17 21 25 29       1  5  9 13 17 21 25 29       1  5  9 13 17 21 25 29
		--       2  6 10 14 18 22 26 30       2  6 10 14 18 22 26 30       2  6 10 14 18 22 26 30
		--       3  7 11 15 19 23 27 31       3  7 11 15 19 23 27 31       3  7 11 15 19 23 27 31
		--
		--   In the serial order this becomes:
		--
		--     [scrambled bins]    0 16  8 24  4 20 12 28  2 18 10 26  6 22 14 30  1 17  9 25  5 21 13 29  3 19 11 27  7 23 15 31
		--     [flip serial()]     0 16  8 24  1 17  9 25  2 18 10 26  3 19 11 27  4 20 12 28  5 21 13 29  6 22 14 30  7 23 15 31
		--     [flip parallel()]   0  8 16 24  1  9 17 25  2 10 18 26  3 11 19 27  4 12 20 28  5 13 21 29  6 14 22 30  7 15 23 31
		--
		--   Note that the order of flip serial() and flip parallel() does not matter. However the combination of
		--   flip serial() and flip parallel() is not the same as a single flip(), because a single flip at once 
		--   yields the [0, pos, neg bins] order. To get from i to the flip serial() and flip parallel() order of
		--   the HDL output index i requires a transpose(i,8,4).
		--
		--                     i= 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
		--     transpose(i,8,4) = 0  8 16 24  1  9 17 25  2 10 18 26  3 11 19 27  4 12 20 28  5 13 21 29  6 14 22 30  7 15 23 31
		--     transpose(i,8,4) = 0  8 16 24
		--                        1  9 17 25
		--                        2 10 18 26
		--                        3 11 19 27
		--                        4 12 20 28
		--                        5 13 21 29
		--                        6 14 22 30
		--                        7 15 23 31
		--
		--     transpose(i,4,8) = 0  4  8 12 16 20 24 28  1  5  9 13 17 21 25 29  2  6 10 14 18 22 26 30  3  7 11 15 19 23 27 31
		--     transpose(i,4,8) = 0  4  8 12 16 20 24 28
		--                        1  5  9 13 17 21 25 29
		--                        2  6 10 14 18 22 26 30
		--                        3  7 11 15 19 23 27 31
		--
		--   For the wideband two real input FFT bin order (with A via real input and B via imaginary input) the
		--   the HDL does the flip serial and flip parallel (so use_reorder) and an additional reorder after the
		--   FFT. The output order then becomes:
		--
		--       [0, pos]
		--       [A  B  A  B  A  B  A  B]
		--      b=0  0  1  1  2  2  3  3     b = i/2 + wb_factor
		--        4  4  5  5  6  6  7  7
		--        8  8  9  9 10 10 11 11
		--       12 12 13 13 14 14 15 15
		--     
		--      i=0  4  8 12 16 20 24 28
		--        1  5  9 13 17 21 25 29
		--        2  6 10 14 18 22 26 30
		--        3  7 11 15 19 23 27 31
		--
		--   In the serial order this becomes:
		--                          A  A  A  A  B  B  B  B  A  A  A  A  B  B  B  B  A  A  A  A  B  B  B  B  A  A  A  A  B  B  B  B
		--             [Two real] = 0  4  8 12  0  4  8 12  1  5  9 13  1  5  9 13  2  6 10 14  2  6 10 14  3  7 11 15  3  7 11 15
		--                       i= 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
		--     transpose(i,8,4)   = 0  8 16 24  1  9 17 25  2 10 18 26  3 11 19 27  4 12 20 28  5 13 21 29  6 14 22 30  7 15 23 31
		--     transpose(i,8,4)/2 = 0  4  8 12  0  4  8 12  1  5  9 13  1  5  9 13  2  6 10 14  2  6 10 14  3  7 11 15  3  7 11 15
		--
		--   Conclusion:
		--     use_reorder  use_fft_shift  use_separate  name                 reference bin frequency:
		--     false        false          false         Complex              fft_shift(flip(i))
		--     true         false          false         Complex reordered    fft_shift(transpose(i,4,8))  (See remark *)
		--     true         true           false         Complex fft_shifted  transpose(i,4,8)             (See remark *)
		--     true         false          true          Two real reordered   transpose(i,4,8)/2           (See remark *)
		--
		-- Remarks:
		-- * in the HDL use_fft_shift is not (yet) supported, so use_fft_shift = FALSE
		-- * for wb_factor > 1 the flip serial() and flip parallel() are better not done, because to fully reorder the 
		--   still needs a transpose() that requires a dual buffer after the wideband FFT.
		-- * strangely the analysis expects that transpose(i,8,4) is necessary to compensate for the incomplete
		--   use_reorder (by flip serial and flip parallel), however in practise transpose(i,4,8) is needed to match
		--   the HDL output
		--
		constant c_addr_w : natural := ceil_log2(nof_points);

		variable v_addr  : std_logic_vector(c_addr_w - 1 downto 0); -- used to convert index integer into slv
		variable v_index : natural;
		variable v_bin   : natural;
	begin
		-- index = i
		if wb_factor = 1 then
			-- Single serial data
			if use_separate = false then
				-- Complex input data
				if use_reorder = false then
					-- No HDL index flip
					v_addr := to_uvec(index, c_addr_w);
					v_addr := flip(v_addr);
					v_addr := fft_shift(v_addr); -- b = fft_shift(flip(i))
				else
					-- With HDL index flip
					if use_fft_shift = false then
						-- No HDL fft_shift
						v_addr := to_uvec(index, c_addr_w);
						v_addr := fft_shift(v_addr); -- b = fft_shift(i)
					else
						-- With HDL fft_shift
						v_addr := to_uvec(index, c_addr_w); -- b = i
					end if;
				end if;
				v_bin := to_uint(v_addr);
			else
				-- Two real input data
				v_bin := index / 2;     -- b = i/2
			end if;
		else
			-- Wideband parallel data
			if use_separate = false then
				-- Wideband complex input data
				if use_reorder = false then
					-- No HDL pipelined and parallel index flips
					v_addr := to_uvec(index, c_addr_w);
					v_addr := flip(v_addr);
					v_addr := fft_shift(v_addr); -- b = fft_shift(flip(i))
				else
					-- With HDL pipelined and parallel index flips
					if use_fft_shift = false then
						-- No HDL fft_shift
						v_index := transpose(index, wb_factor, nof_points / wb_factor); -- t = transpose(i, 4, 8)
						v_addr  := to_uvec(v_index, c_addr_w);
						v_addr  := fft_shift(v_addr); -- b = fft_shift(t)
					else
						-- With HDL fft_shift
						v_index := transpose(index, wb_factor, nof_points / wb_factor); -- t = transpose(i, 4, 8)
						v_addr  := to_uvec(v_index, c_addr_w); -- b = t
					end if;
				end if;
				v_bin := to_uint(v_addr);
			else
				-- Wideband two real input data
				v_index := transpose(index, wb_factor, nof_points / wb_factor); -- t = transpose(i, 4, 8)
				v_bin   := v_index / 2; -- b = t/2
			end if;
		end if;
		return v_bin;
	end fft_index_to_bin_frequency;

	procedure proc_fft_out_control(wb_factor          : natural;
	                               nof_points         : natural;
	                               nof_channels       : natural;
	                               use_reorder        : boolean;
	                               use_fft_shift      : boolean;
	                               use_separate       : boolean;
	                               signal out_val_cnt : in natural; -- count at sclk sample rate
	                               signal out_val     : in std_logic;
	                               signal out_val_a   : out std_logic;
	                               signal out_val_b   : out std_logic;
	                               signal out_channel : out natural;
	                               signal out_bin     : out natural;
	                               signal out_bin_cnt : out natural) is
		-- Purpose: Derive reference control signals from FFT out_val, out_val_cnt
		--          and derive an index per block that can be used to determine
		--          the frequency bin with fft_index_to_bin_frequency().
		-- Description:
		--   The out_val_cnt counts the valid output data from the FFT:
		--
		--   . out_val_a and out_val_b for interleaved output for two real inputs
		--   . out_channel index in range 0:nof_channels-1
		--
		--   Internally a v_index per block is determined that is independent of
		--   nof_channels and then fft_index_to_bin_frequency() is used with the
		--   reorder parameters use_reorder, use_fft_shift, use_separate,
		--   wb_factor to map this v_index to the bin frequency.
		--
		--   . out_bin is bin frequency index within a block
		--   . out_bin_cnt is bin frequency index in the reference data
		--
		variable v_blk_index : natural;
		variable v_index     : natural;
		variable v_bin       : natural;
	begin
		out_val_a <= '0';
		out_val_b <= '0';

		if use_separate = true then
			-- Two real input data
			-- Toggle out_val serially starting with wb_factor*A then wb_factor*B
			if out_val_cnt / wb_factor mod c_nof_complex = 0 then
				out_val_a <= out_val;
			else
				out_val_b <= out_val;
			end if;
		end if;

		if use_reorder = true then
			v_blk_index := out_val_cnt / nof_points; -- each block has nof_points
			out_channel <= v_blk_index mod nof_channels; -- the nof_channels are interleaved per block

			v_index := out_val_cnt mod nof_points; -- index within a block independent of nof_channels

			v_bin := fft_index_to_bin_frequency(wb_factor, nof_points, v_index, use_reorder, use_fft_shift, use_separate);

			out_bin <= v_bin;           -- bin frequency in a block
			if use_separate = true then
				-- Two real input data
				out_bin_cnt <= v_bin + (v_blk_index / nof_channels) * (nof_points / c_nof_complex); -- bin index in the half spectrum reference data stream of blocks
			else
				-- Complex input data
				out_bin_cnt <= v_bin + (v_blk_index / nof_channels) * nof_points; -- bin index in the full spectrum reference data stream of blocks
			end if;
		else
			-- Complex input data
			v_blk_index := out_val_cnt / nof_points / nof_channels; -- each block has nof_channels*nof_points
			out_channel <= (out_val_cnt / wb_factor) mod nof_channels; -- the nof_channels are interleaved per wb_factor number of samples

			v_index := ((out_val_cnt / wb_factor / nof_channels) * wb_factor + (out_val_cnt MOD wb_factor)) mod nof_points; -- index within a block independent of nof_channels

			v_bin := fft_index_to_bin_frequency(wb_factor, nof_points, v_index, use_reorder, use_fft_shift, use_separate);

			out_bin     <= v_bin;       -- bin frequency in a block
			out_bin_cnt <= v_bin + v_blk_index * nof_points; -- bin index in the full spectrum reference data stream of blocks
		end if;
	end proc_fft_out_control;

	------------------------------------------------------------------------------
	-- PROCEDURE: Read input file.
	--            Reads data (re, im, sync and val) from a file and writes values 
	--            to the output signals. 
	------------------------------------------------------------------------------
	PROCEDURE proc_read_input_file(SIGNAL clk          : IN STD_LOGIC;
	                               SIGNAL in_file_data : OUT t_integer_matrix;
	                               SIGNAL in_file_sync : OUT STD_LOGIC_VECTOR;
	                               SIGNAL in_file_val  : OUT STD_LOGIC_VECTOR;
	                               file_name           : IN STRING) IS

		VARIABLE v_file_status : FILE_OPEN_STATUS;
		FILE v_in_file         : TEXT;
		VARIABLE v_log_line    : LINE;
		VARIABLE v_input_line  : LINE;
		VARIABLE v_index       : INTEGER                                      := 0;
		VARIABLE v_comma       : CHARACTER;
		VARIABLE v_sync        : STD_LOGIC_VECTOR(in_file_sync'RANGE)         := (OTHERS => '0');
		VARIABLE v_val         : STD_LOGIC_VECTOR(in_file_val'RANGE)          := (OTHERS => '0');
		VARIABLE v_data        : t_integer_matrix(in_file_sync'RANGE, 1 to 2) := (OTHERS => (OTHERS => 0));
	BEGIN
		-- wait 1 clock cycle to avoid that the output messages 
		-- in the transcript window get lost in the 0 ps start up messages 
		proc_common_wait_some_cycles(clk, 1);
		write(v_log_line, string'("reading file : "));
		write(v_log_line, file_name);
		writeline(output, v_log_line);
		proc_common_open_file(v_file_status, v_in_file, file_name, READ_MODE); -- Open the file with data values for reading
		LOOP
			EXIT WHEN endfile(v_in_file);
			readline(v_in_file, v_input_line);

			read(v_input_line, v_sync(v_index)); -- sync
			read(v_input_line, v_comma);

			read(v_input_line, v_val(v_index)); -- valid
			read(v_input_line, v_comma);

			read(v_input_line, v_data(v_index, 1)); -- real
			read(v_input_line, v_comma);

			read(v_input_line, v_data(v_index, 2)); -- imag
			v_index := v_index + 1;
		END LOOP;
		proc_common_close_file(v_file_status, v_in_file); -- Close the file 
		write(v_log_line, string'("finished reading file : "));
		write(v_log_line, file_name);
		writeline(output, v_log_line);

		in_file_data <= v_data;
		in_file_sync <= v_sync;
		in_file_val  <= v_val;
		WAIT;
	END proc_read_input_file;

	------------------------------------------------------------------------------
	-- PROCEDURE: Read input file.
	--            Reads data (re, im, sync and val) from a file and writes values 
	--            to the output signals. 
	------------------------------------------------------------------------------
	PROCEDURE proc_read_input_file(SIGNAL clk          : IN STD_LOGIC;
	                               SIGNAL in_file_data : OUT t_integer_matrix;
	                               file_name           : IN STRING) IS

		VARIABLE v_file_status : FILE_OPEN_STATUS;
		FILE v_in_file         : TEXT;
		VARIABLE v_log_line    : LINE;
		VARIABLE v_input_line  : LINE;
		VARIABLE v_index       : INTEGER                                      := 0;
		VARIABLE v_comma       : CHARACTER;
		VARIABLE v_data        : t_integer_matrix(in_file_data'RANGE, 1 to 2) := (OTHERS => (OTHERS => 0));
	BEGIN
		-- wait 1 clock cycle to avoid that the output messages 
		-- in the transcript window get lost in the 0 ps start up messages 
		proc_common_wait_some_cycles(clk, 1);
		write(v_log_line, string'("reading file : "));
		write(v_log_line, file_name);
		writeline(output, v_log_line);
		proc_common_open_file(v_file_status, v_in_file, file_name, READ_MODE); -- Open the file with data values for reading
		LOOP
			EXIT WHEN v_index = in_file_data'HIGH + 1;
			readline(v_in_file, v_input_line);

			read(v_input_line, v_data(v_index, 1)); -- real
			read(v_input_line, v_comma);

			read(v_input_line, v_data(v_index, 2)); -- imag
			v_index := v_index + 1;
		END LOOP;
		proc_common_close_file(v_file_status, v_in_file); -- Close the file 
		write(v_log_line, string'("finished reading file : "));
		write(v_log_line, file_name);
		writeline(output, v_log_line);

		in_file_data <= v_data;
		WAIT;
	END proc_read_input_file;

	------------------------------------------------------------------------------
	-- PROCEDURE: Read the beamlet statistics memory into an matrix
	------------------------------------------------------------------------------

	PROCEDURE proc_fft_read_subband_statistics_memory(CONSTANT c_fft_lane   : IN NATURAL;
	                                                  CONSTANT c_fft        : IN t_fft;
	                                                  SIGNAL clk            : IN STD_LOGIC;
	                                                  SIGNAL mm_mosi        : OUT t_mem_mosi;
	                                                  SIGNAL mm_miso        : IN t_mem_miso;
	                                                  SIGNAL statistics_arr : OUT t_slv_64_arr) IS
		VARIABLE v_offset         : NATURAL;
		VARIABLE v_nof_stats      : NATURAL := c_fft.nof_points / c_fft.wb_factor;
		VARIABLE v_statistics_arr : t_slv_64_arr(statistics_arr'RANGE);
	BEGIN
		v_offset       := c_fft_lane * c_fft.stat_data_sz * v_nof_stats;
		proc_read_subband_stats(v_nof_stats, v_offset, clk, mm_mosi, mm_miso, v_statistics_arr);
		statistics_arr <= v_statistics_arr;
		proc_common_wait_some_cycles(clk, 1); -- ensure that the last statistics_arr value gets assigned too
	END proc_fft_read_subband_statistics_memory;

	------------------------------------------------------------------------------
	-- PROCEDURE: Reads the beamlet statistics into an array. 
	------------------------------------------------------------------------------
	PROCEDURE proc_read_subband_stats(CONSTANT nof_subbands : IN NATURAL;
	                                  CONSTANT offset       : IN NATURAL;
	                                  SIGNAL clk            : IN STD_LOGIC;
	                                  SIGNAL mm_mosi        : OUT t_mem_mosi;
	                                  SIGNAL mm_miso        : IN t_mem_miso;
	                                  VARIABLE result       : OUT t_slv_64_arr) IS
		VARIABLE v_data_lo : STD_LOGIC_VECTOR(31 DOWNTO 0);
	BEGIN
		FOR J IN 0 TO nof_subbands - 1 LOOP
			-- Memory is 32-bit, therefor each power value (56-bit wide) must be composed out of two reads. 
			proc_mem_mm_bus_rd(offset + 2 * J, clk, mm_mosi);
			proc_common_wait_some_cycles(clk, 1);
			v_data_lo := mm_miso.rddata(31 DOWNTO 0);
			proc_mem_mm_bus_rd(offset + 2 * J + 1, clk, mm_mosi);
			proc_common_wait_some_cycles(clk, 1);
			result(J) := mm_miso.rddata(31 DOWNTO 0) & v_data_lo;
		END LOOP;
	END proc_read_subband_stats;

	------------------------------------------------------------------------------
	-- PROCEDURE: Prepare input array.
	--            Combinatorial read data from source file and re-arrange in such
	--            a way that it represents the data of one input stream
	------------------------------------------------------------------------------
	--  PROCEDURE proc_prepare_input_data( CONSTANT nof_subbands        : IN  NATURAL;
	--                                     CONSTANT nof_inputs          : IN  NATURAL;
	--                                     CONSTANT nof_input_streams   : IN  NATURAL; 
	--                                     CONSTANT input_stream_number : IN  NATURAL; 
	--                                     VARIABLE re_arr              : OUT t_integer_arr;
	--                                     VARIABLE im_arr              : OUT t_integer_arr;
	--                                              file_name           : IN  STRING) IS
	--    VARIABLE v_file_status                        : FILE_OPEN_STATUS;                                  
	--    FILE     v_in_file                            : TEXT;
	--    VARIABLE v_line                               : LINE;   
	--    VARIABLE v_in_temp                            : t_integer_arr(2*nof_inputs-1 downto 0);
	--    CONSTANT c_nof_signal_inputs_per_input_stream : NATURAL := nof_inputs/nof_input_streams;
	--  BEGIN
	--    proc_common_open_file(v_file_status, v_in_file, file_name, READ_MODE);        -- Open the file with data values for reading
	--    FOR I IN 0 TO nof_subbands-1 LOOP                                                                                         
	--      proc_common_readline_file(v_file_status, v_in_file, v_in_temp, 2*nof_inputs);   -- Read line with complex subband samples from all inputs
	--      FOR J IN 0 TO c_nof_signal_inputs_per_input_stream-1 LOOP
	--        re_arr(J*nof_subbands+I) := v_in_temp(2*(J+input_stream_number*c_nof_signal_inputs_per_input_stream));
	--        im_arr(J*nof_subbands+I) := v_in_temp(2*(J+input_stream_number*c_nof_signal_inputs_per_input_stream)+1);         
	--      END LOOP;
	--    END LOOP;
	--    proc_common_close_file(v_file_status, v_in_file);                               -- Close the file 
	--  END proc_prepare_input_data;

END tb_fft_pkg;

