Library ieee, common_pkg_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;

package rTwoSDFPkg is
	constant c_twid_file_stem : string := "../../../../../../r2sdf_fft/data/twids/sdf_twiddle_coeffs";

	-- Internal pipeline latencies and Z^(-1) pipeline settings for a stage in the rTwoSDF FFT
	-- Also used for other preallele and wideband FFT implementations (fft_lib)
	type t_fft_pipeline is record
		-- generics for rTwoSDFStage
		stage_lat     : natural;        -- = 1
		weight_lat    : natural;        -- = 2 -- this was changed from 1 to 2 for better timing on Ultrascale / Versal
		mul_lat       : natural;        -- = 5 -- This was changed from (3+1) to 5 for better timing on Ultrascale/Versal
		-- generics for rTwoBFStage
		bf_lat        : natural;        -- = 1
		-- generics for rTwoBF
		bf_use_zdly   : natural;        -- = 1
		bf_in_a_zdly  : natural;        -- = 0
		bf_out_d_zdly : natural;        -- = 0
		bf_dsp_dly	  : natural;        -- = 1
	end record;
	constant c_fft_pipeline : t_fft_pipeline := (1, 2, 5, 1, 1, 0, 0, 0);

end package rTwoSDFPkg;

package body rTwoSDFPkg IS
end rTwoSDFPkg;
