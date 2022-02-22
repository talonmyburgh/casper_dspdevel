Library ieee, common_pkg_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;

package rTwoSDFPkg is
	constant c_twid_file_stem : string := "D:/CASPERWORK/Development/casper_dspdevel/r2sdf_fft/data/twids/sdf_twiddle_coeffs";

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
