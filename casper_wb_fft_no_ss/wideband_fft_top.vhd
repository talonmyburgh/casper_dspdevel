library ieee, dp_pkg_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use dp_pkg_lib.dp_stream_pkg.ALL;
use work.fft_pkg.all;

--Purpose: A Simulink necessary wrapper for the fft_wide_unit. Serves to expose all signals and generics individually.

entity wideband_fft_top is
	port(
		clk : in std_logic;
		clken : in std_logic;
		rst : in std_logic;
		in_sync : in std_logic;
		in_bsn : in STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);
		in_data : in STD_LOGIC_VECTOR(c_dp_stream_data_w-1 DOWNTO 0);
		in_re : in STD_LOGIC_VECTOR(c_dp_stream_dsp_data_w-1 DOWNTO 0);
		in_im : in STD_LOGIC_VECTOR(c_dp_stream_dsp_data_w-1 DOWNTO 0);
		in_valid : in std_logic;
		in_sop : in std_logic;
		in_eop : in std_logic;
		in_empty : STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);
		in_channel : STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);
		in_err : STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0)
	);
end entity wideband_fft_top;

architecture RTL of wideband_fft_top is
	
begin

end architecture RTL;
