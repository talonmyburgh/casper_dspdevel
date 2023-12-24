library ieee, common_pkg_lib;
use IEEE.std_logic_1164.all;
-- use common_pkg_lib.common_pkg.all;

package pfb_fir_pkg is

    --UPDATED BY MATLAB CODE
    CONSTANT c_pfb_fir_din_w      : natural := 8;
    CONSTANT c_pfb_fir_dout_w     : natural := 23;
    CONSTANT c_pfb_fir_coef_w     : natural := 16;
    CONSTANT c_pfb_fir_coefs_file : string  := "../../../../../data/hex/run_pfir_coeff_m_incrementing_8taps_64points_16b";

    --UPDATED THROUGH THE MATLAB CONFIG
    CONSTANT c_pfb_fir_wb_factor : natural := 4;
    CONSTANT c_pfb_fir_n_taps    : natural := 8;
    CONSTANT c_pfb_fir_n_chans   : natural := 0;
    CONSTANT c_pfb_fir_n_bins    : natural := 64;
    CONSTANT c_pfb_fir_n_streams : natural := 1;
    CONSTANT c_pfb_fir_padding   : natural := 0;

    CONSTANT c_pfb_fir_mem_latency  : natural := 1;
    CONSTANT c_pfb_fir_mult_latency : natural := 1;
    CONSTANT c_pfb_fir_add_latency  : natural := 1;
    CONSTANT c_pfb_fir_conv_latency : natural := 1;
    
    type t_pfb_fir_pipeline is record
        mem_latency  : natural;         -- = 2, latency through taps and coeff lookup
        mult_latency : natural;         -- = 3, multiplier latency
        add_latency  : natural;         -- = 1, adder latency
        conv_latency : natural;         -- = 1, type conversion latency
    end record;
    
    constant c_pfb_fir_pipeline : t_pfb_fir_pipeline := (c_pfb_fir_mem_latency, c_pfb_fir_mult_latency,
                                                         c_pfb_fir_add_latency, c_pfb_fir_conv_latency);

    -- Parameters for the (wideband) poly phase filter. 
    type t_pfb_fir is record
        wb_factor    : natural;         -- = 1, the wideband factor
        n_chans      : natural;         -- = 0, number of time multiplexed input signals
        n_bins       : natural;         -- = 1024, the number of polyphase channels (= number of FFT bins)
        n_taps       : natural;         -- = 16, the number of FIR taps per subband
        n_streams    : natural;         -- = 1, the number of streams that are served by the same coefficients.
        din_w        : natural;         -- = 8, number of input bits per stream
        dout_w       : natural;         -- = 16, number of output bits per stream
        coef_w       : natural;         -- = 16, data width of the FIR coefficients
        padding      : natural;         -- = 0, padding added to prevent overflow
    end record;

    constant c_pfb_fir : t_pfb_fir := (c_pfb_fir_wb_factor, c_pfb_fir_n_chans, c_pfb_fir_n_bins,
                                       c_pfb_fir_n_taps, c_pfb_fir_n_streams, c_pfb_fir_din_w, c_pfb_fir_dout_w,
                                       c_pfb_fir_coef_w, c_pfb_fir_padding);

    TYPE t_pfb_fir_array_in is array (INTEGER range <>) of STD_LOGIC_VECTOR(c_pfb_fir_din_w - 1 DOWNTO 0);
    TYPE t_pfb_fir_array_out is array (INTEGER range <>) of STD_LOGIC_VECTOR(c_pfb_fir_dout_w - 1 DOWNTO 0);

end package pfb_fir_pkg;
package body pfb_fir_pkg is
end pfb_fir_pkg;
