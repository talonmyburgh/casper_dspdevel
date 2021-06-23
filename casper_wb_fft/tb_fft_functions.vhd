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

-- Purpose: Test bench for functions in fft_pkg.vhd
--
-- Description:
--   Use signals to observe the result of functions in the Wave Window.
--   Manually verify that the functions yield the expected result.
-- Usage:
--   > as 3
--   > run 1 us
--

LIBRARY IEEE, common_pkg_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;     
USE work.fft_pkg.ALL;
USE work.tb_fft_pkg.ALL;

ENTITY tb_fft_functions IS
END tb_fft_functions;

ARCHITECTURE tb OF tb_fft_functions IS
  
  CONSTANT c_wb_factor     : NATURAL := 4;
  CONSTANT c_nof_points    : NATURAL := 32;
  CONSTANT c_w             : NATURAL := ceil_log2(c_nof_points);

  -- index_arr                          =  0  1  2  3   4  5  6  7   8  9 10 11  12 13 14 15  16 17 18 19  20 21 22 23  24 25 26 27  28 29 30 31
  -- index_transpose_P_N_arr            =  0  8 16 24   1  9 17 25   2 10 18 26   3 11 19 27   4 12 20 28   5 13 21 29   6 14 22 30   7 15 23 31
  -- index_transpose_N_P_arr            =  0  4  8 12  16 20 24 28   1  5  9 13  17 21 25 29   2  6 10 14  18 22 26 30   3  7 11 15  19 23 27 31
  -- bin_complex_arr                    = 16  0 24  8  20  4 28 12  18  2 26 10  22  6 30 14  17  1 25  9  21  5 29 13  19  3 27 11  23  7 31 15
  -- bin_complex_flip_arr               = 16 17 18 19  20 21 22 23  24 25 26 27  28 29 30 31   0  1  2  3   4  5  6  7   8  9 10 11  12 13 14 15
  -- bin_complex_flip_transpose_arr     =  4 12 20 28   5 13 21 29   6 14 22 30   7 15 23 31   0  8 16 24   1  9 17 25   2 10 18 26   3 11 19 27
  -- bin_complex_reorder_arr            =  0  1  2  3   4  5  6  7   8  9 10 11  12 13 14 15  16 17 18 19  20 21 22 23  24 25 26 27  28 29 30 31
  -- bin_complex_reorder_transpose_arr  =  0  8 16 24   1  9 17 25   2 10 18 26   3 11 19 27   4 12 20 28   5 13 21 29   6 14 22 30   7 15 23 31
  -- bin_two_real_reorder_arr           =  0  1  2  3   0  1  2  3   4  5  6  7   4  5  6  7   8  9 10 11   8  9 10 11  12 13 14 15  12 13 14 15
  -- bin_two_real_reorder_transpose_arr =  0  4  8 12   0  4  8 12   1  5  9 13   1  5  9 13   2  6 10 14   2  6 10 14   3  7 11 15   3  7 11 15
  SIGNAL index_arr                          : t_natural_arr(0 TO c_nof_points-1) := array_init(0, c_nof_points, 1);
  SIGNAL index_transpose_P_N_arr            : t_natural_arr(0 TO c_nof_points-1);
  SIGNAL index_transpose_N_P_arr            : t_natural_arr(0 TO c_nof_points-1);
  SIGNAL index_transpose_N_P_flip_arr       : t_natural_arr(0 TO c_nof_points-1);
  SIGNAL index_flip_transpose_N_P_arr       : t_natural_arr(0 TO c_nof_points-1);
  SIGNAL index_flip_arr                     : t_natural_arr(0 TO c_nof_points-1);
  SIGNAL index_flip_shift_arr               : t_natural_arr(0 TO c_nof_points-1);
  SIGNAL index_shift_flip_arr               : t_natural_arr(0 TO c_nof_points-1);
  SIGNAL bin_complex_arr                    : t_natural_arr(0 TO c_nof_points-1);
  SIGNAL bin_complex_flip_arr               : t_natural_arr(0 TO c_nof_points-1);  -- flip()
  SIGNAL bin_complex_flip_transpose_arr     : t_natural_arr(0 TO c_nof_points-1);
  SIGNAL bin_complex_reorder_arr            : t_natural_arr(0 TO c_nof_points-1);  -- fft_shift(flip())
  SIGNAL bin_complex_reorder_transpose_arr  : t_natural_arr(0 TO c_nof_points-1);
  SIGNAL bin_two_real_reorder_arr           : t_natural_arr(0 TO c_nof_points-1);  -- separate(flip())
  SIGNAL bin_two_real_reorder_transpose_arr : t_natural_arr(0 TO c_nof_points-1);

BEGIN

  p_bin : PROCESS
  BEGIN
    FOR I IN 0 TO c_nof_points-1 LOOP
      index_flip_arr(I)                    <= flip(I, c_w);
      index_transpose_P_N_arr(I)           <= transpose(I, c_wb_factor, c_nof_points/c_wb_factor);
      index_transpose_N_P_arr(I)           <= transpose(I, c_nof_points/c_wb_factor, c_wb_factor);
      index_transpose_N_P_flip_arr(I)      <= transpose(flip(I, c_w), c_nof_points/c_wb_factor, c_wb_factor);
      index_flip_transpose_N_P_arr(I)      <= flip(transpose(I, c_nof_points/c_wb_factor, c_wb_factor), c_w);
      index_flip_shift_arr(I)              <= flip(fft_shift(I, c_w), c_w);
      index_shift_flip_arr(I)              <= fft_shift(flip(I, c_w), c_w);
      --                                                                                                use_       use_      use_
      --                                                                                                index_flip fft_shift separate
      bin_complex_arr(I)                    <= fft_index_to_bin_frequency(c_wb_factor, c_nof_points, I, FALSE,     FALSE,    FALSE);
      bin_complex_flip_arr(I)               <= fft_index_to_bin_frequency(c_wb_factor, c_nof_points, I, TRUE,      FALSE,    FALSE);
      bin_complex_flip_transpose_arr(I)     <= fft_index_to_bin_frequency(c_wb_factor, c_nof_points, I, TRUE,      FALSE,    FALSE);
      bin_complex_reorder_arr(I)            <= fft_index_to_bin_frequency(c_wb_factor, c_nof_points, I, TRUE,      TRUE,     FALSE);
      bin_complex_reorder_transpose_arr(I)  <= fft_index_to_bin_frequency(c_wb_factor, c_nof_points, I, TRUE,      TRUE,     FALSE);
      bin_two_real_reorder_arr(I)           <= fft_index_to_bin_frequency(c_wb_factor, c_nof_points, I, TRUE,      FALSE,    TRUE);
      bin_two_real_reorder_transpose_arr(I) <= fft_index_to_bin_frequency(c_wb_factor, c_nof_points, I, TRUE,      FALSE,    TRUE);
    END LOOP;
    WAIT;
  END PROCESS;
   
END tb;

