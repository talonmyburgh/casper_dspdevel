library ieee, common_pkg_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;

package fil_pkg is

--UPDATED BY MATLAB CODE GENERATION FOR SLV ARRAYS/INTERFACES:
CONSTANT c_fil_in_dat_w     : natural := 8;
CONSTANT c_fil_out_dat_w    : natural := 16;
CONSTANT c_fil_coef_dat_w   : natural := 16;
CONSTANT c_coefs_file       : string  := "C:/Users/mybur/Work/dspdevel_designs/casper_dspdevel/casper_wbpfb/data/hex/run_pfb_m_v2_pfir_coeff_fircls1_16taps_1024points_16b";

--UPDATED THROUGH THE MATLAB CONFIG FOR FFT OPERATION:
CONSTANT c_fil_wb_factor    : natural   := 4;
CONSTANT c_fil_nof_taps     : natural   := 16; 
CONSTANT c_fil_nof_chan     : natural   := 0;
CONSTANT c_fil_nof_bands    : natural   := 1024;
CONSTANT c_fil_nof_streams  : natural   := 1;
CONSTANT c_fil_backoff_w    : natural   := 0;

-- Parameters for the (wideband) poly phase filter. 
type t_fil_ppf is record
wb_factor      : natural; -- = 1, the wideband factor
nof_chan       : natural; -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan 
nof_bands      : natural; -- = 1024, the number of polyphase channels (= number of points of the FFT)
nof_taps       : natural; -- = 16, the number of FIR taps per subband
nof_streams    : natural; -- = 1, the number of streams that are served by the same coefficients.
backoff_w      : natural; -- = 0, number of bits for input backoff to avoid output overflow
in_dat_w       : natural; -- = 8, number of input bits per stream
out_dat_w      : natural; -- = 16, number of output bits per stream
coef_dat_w     : natural; -- = 16, data width of the FIR coefficients
end record;

constant c_fil_ppf : t_fil_ppf := (c_fil_wb_factor, c_fil_nof_chan, c_fil_nof_bands, c_fil_nof_taps, c_fil_nof_streams, c_fil_backoff_w, c_fil_in_dat_w, c_fil_out_dat_w, c_fil_coef_dat_w);
TYPE t_fil_slv_arr_in is array (INTEGER range <>) of STD_LOGIC_VECTOR(c_fil_in_dat_w-1 DOWNTO 0);
TYPE t_fil_slv_arr_out is array (INTEGER range <>) of STD_LOGIC_VECTOR(c_fil_out_dat_w-1 DOWNTO 0);
TYPE t_fil_slv_arr_coef is array (INTEGER range <>) of STD_LOGIC_VECTOR(c_fil_coef_dat_w -1 DOWNTO 0);

-- Record with the pipeline settings for the filter units. 
type t_fil_ppf_pipeline is record
-- generic for the taps and coefficients memory
mem_delay             : natural;  -- = 1
-- generics for the multiplier in in the filter unit
mult_input            : natural;  -- = 1
mult_product          : natural;  -- = 1
mult_output           : natural;  -- = 1                   
-- generics for the adder tree in in the filter unit
adder_stage           : natural;  -- = 1
-- generics for the requantizer in the filter unit
requant_remove_lsb    : natural;     -- = 1
requant_remove_msb    : natural;     -- = 0
end record;

constant c_fil_ppf_pipeline : t_fil_ppf_pipeline := (1, 1, 1, 1, 1, 1, 0);

end package fil_pkg;
package body fil_pkg is
end fil_pkg;
