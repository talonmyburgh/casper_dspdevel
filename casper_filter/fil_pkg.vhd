library ieee, common_pkg_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;

package fil_pkg is

--UPDATED BY MATLAB CODE GENERATION FOR SLV ARRAYS/INTERFACES:
CONSTANT in_dat_w : natural := 8;
CONSTANT out_dat_w : natural := 10;
CONSTANT coef_dat_w : natural :=12;
type t_coefs_init_param is array (0 to 8 -1) of string(0 to 127-1);
constant c_coefs_init_param : t_coefs_init_param := ("ff1,fd6,fc0,fae,fa0,f97,f91,f8e,f8e,f91,f95,f9b,fa2,faa,fb3,fbc,fc5,fce,fd6,fdd,fe4,feb,ff0,ff4,ff8,ffb,ffd,fff,000,000,000,000", "7ff,7f6,7e5,7cb,7a8,77d,74a,710,6d0,689,63d,5ed,598,540,4e6,48b,42e,3d2,377,31d,2c5,270,21e,1d0,186,141,101,0c6,091,060,036,010", "010,034,05e,08e,0c2,0fc,13c,180,1c9,216,267,2bb,312,36c,3c7,423,47f,4db,535,58d,5e2,633,67f,6c7,708,743,777,7a3,7c6,7e2,7f4,7fe", "000,000,000,000,fff,ffe,ffc,ff9,ff6,ff2,fed,fe7,fe0,fd9,fd1,fc8,fc0,fb7,faf,fa7,f9f,f99,f95,f92,f92,f95,f9a,fa3,fb0,fc1,fd7,ff1", "fe3,fca,fb6,fa7,f9b,f94,f8f,f8e,f8f,f93,f98,f9e,fa6,faf,fb7,fc0,fc9,fd2,fda,fe1,fe8,fed,ff2,ff6,ffa,ffc,ffe,fff,000,000,000,000", "7fc,7ef,7d9,7ba,793,765,72e,6f1,6ad,664,615,5c3,56c,513,4b9,45d,400,3a4,349,2f0,29a,246,1f6,1ab,163,121,0e3,0ab,078,04a,022,000", "021,049,075,0a7,0df,11b,15d,1a4,1ef,23e,291,2e6,33f,399,3f5,451,4ad,508,561,5b8,60b,65a,6a4,6e8,726,75e,78e,7b5,7d5,7ec,7fa,7ff", "000,000,000,000,ffe,ffd,ffb,ff8,ff4,fef,fea,fe4,fdd,fd5,fcd,fc4,fbb,fb3,fab,fa3,f9c,f97,f94,f92,f93,f97,f9e,fa9,fb8,fcc,fe4,000");
--For coef init by files
CONSTANT c_coefs_file : string := "UNUSED";

--UPDATED THROUGH THE MATLAB CONFIG FOR FFT OPERATION:
CONSTANT wb_factor: natural :=2;
CONSTANT nof_taps : natural :=4; 
CONSTANT nof_chan : natural := 0;
CONSTANT nof_bands : natural := 256;
CONSTANT nof_streams : natural := 1;
CONSTANT backoff_w : natural := 0;

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

constant c_fil_ppf : t_fil_ppf := (wb_factor, nof_chan, nof_bands, nof_taps, nof_streams, backoff_w, in_dat_w, out_dat_w, coef_dat_w);
TYPE t_slv_arr_in is array (INTEGER range <>) of STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);
TYPE t_slv_arr_out is array (INTEGER range <>) of STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0);
TYPE t_slv_arr_coef is array (INTEGER range <>) of STD_LOGIC_VECTOR(coef_dat_w -1 DOWNTO 0);

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
requant_remove_lsb : natural;  -- = 1
requant_remove_msb : natural;  -- = 0
end record;

constant c_fil_ppf_pipeline : t_fil_ppf_pipeline := (1, 1, 1, 1, 1, 1, 0);

end package fil_pkg;
package body fil_pkg is
end fil_pkg;
