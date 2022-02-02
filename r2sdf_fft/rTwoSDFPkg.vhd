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

Library ieee, common_pkg_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;

package rTwoSDFPkg is
	constant c_twid_file_stem : string := "D:/CASPERWORK/Development/casper_dspdevel/wrappers/simulink/twids/sdf_twiddle_coeffs_1024p_18b";

	-- Internal pipeline latencies and Z^(-1) pipeline settings for a stage in the rTwoSDF FFT
	-- Also used for other preallele and wideband FFT implementations (fft_lib)
	type t_fft_pipeline is record
		-- generics for rTwoSDFStage
		stage_lat     : natural;        -- = 1
		weight_lat    : natural;        -- = 1
		mul_lat       : natural;        -- = 3+1
		-- generics for rTwoBFStage
		bf_lat        : natural;        -- = 1
		-- generics for rTwoBF
		bf_use_zdly   : natural;        -- = 1
		bf_in_a_zdly  : natural;        -- = 0
		bf_out_d_zdly : natural;        -- = 0
	end record;
	constant c_fft_pipeline : t_fft_pipeline := (1, 1, 4, 1, 1, 0, 0);

end package rTwoSDFPkg;

package body rTwoSDFPkg IS
end rTwoSDFPkg;
