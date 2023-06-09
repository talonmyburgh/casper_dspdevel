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

-- Purpose:
-- Description:
--   Generates FFT testbenches (tb_rTwoSDF) for various g_in_dat_w and
--   g_nof_points. Note that twiddlePkg.vhd must be generated for the largest
--   value of g_nof_points used in this structure.

library ieee, common_pkg_lib;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use common_pkg_lib.common_pkg.all;
use work.rTwoSDFPkg.all;

entity tb_tb_rTwoSDF is
end entity tb_tb_rTwoSDF;

architecture tb of tb_tb_rTwoSDF is

    signal tb_end          : std_logic := '0'; -- declare tb_end to avoid 'No objects found' error on 'when -label tb_end'
    CONSTANT c_diff_margin : natural   := 1;

begin

    --  -- generics for tb
    --  g_use_uniNoise_file : boolean  := true;
    --  g_in_en             : natural  := 0;     -- 1 = always active, others = random control
    --  -- generics for rTwoSDF
    --  g_use_reorder       : boolean  := true;
    --  g_nof_points        : natural  := 1024;
    --  g_in_dat_w          : natural  := 8;   
    --  g_out_dat_w         : natural  := 14;   
    --  g_guard_w           : natural  := 2      -- guard bits are used to avoid overflow in single FFT stage.   

    u_act_impulse_16p_16i_16o : entity work.tb_rTwoSDF
        generic map(
            g_use_uniNoise_file => false,
            g_in_en             => 1,
            g_use_reorder       => true,
            g_nof_points        => 16,
            g_in_dat_w          => 16,
            g_out_dat_w         => 16,
            g_guard_w           => 2,
            g_diff_margin       => c_diff_margin,
            g_file_loc_prefix   => "../../../../../",
            g_twid_file_stem    => c_twid_file_stem
        );
--    u_act_noise_1024p_8i_14o : entity work.tb_rTwoSDF
--        generic map(
--            g_use_uniNoise_file => true,
--            g_in_en             => 1,
--            g_use_reorder       => true,
--            g_nof_points        => 1024,
--            g_in_dat_w          => 8,
--            g_out_dat_w         => 14,
--            g_guard_w           => 2,
--            g_diff_margin       => c_diff_margin,
--            g_file_loc_prefix   => "../../../../../",
--            g_twid_file_stem    => c_twid_file_stem
--        );
--    u_rnd_noise_1024p_8i_14o : entity work.tb_rTwoSDF
--        generic map(
--            g_use_uniNoise_file => true,
--            g_in_en             => 1,
--            g_use_reorder       => true,
--            g_nof_points        => 1024,
--            g_in_dat_w          => 8,
--            g_out_dat_w         => 14,
--            g_guard_w           => 2,
--            g_diff_margin       => c_diff_margin,
--            g_file_loc_prefix   => "../../../../../",
--            g_twid_file_stem    => c_twid_file_stem
--        );
--    u_rnd_noise_1024p_8i_14o_flipped : entity work.tb_rTwoSDF
--        generic map(
--            g_use_uniNoise_file => true,
--            g_in_en             => 0,
--            g_use_reorder       => false,
--            g_nof_points        => 1024,
--            g_in_dat_w          => 8,
--            g_out_dat_w         => 14,
--            g_guard_w           => 2,
--            g_diff_margin       => c_diff_margin,
--            g_file_loc_prefix   => "../../../../../",
--            g_twid_file_stem    => c_twid_file_stem
--        );

end tb;
