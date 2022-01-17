library ieee, common_pkg_lib, casper_ram_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.all;

entity rTwoWeights is
	generic(
		g_stage          : natural := 4; -- The stage number of the pft
		g_lat            : natural := 1; -- latency 0 or 1
		g_twiddle_offset : natural := 0; -- The twiddle offset: 0 for normal FFT. Other than 0 in wideband FFT
		g_coef_file	     : string  := "UNUSED";
		g_ram_primitive  : string  := "auto";
		g_stage_offset   : natural := 0 -- The Stage offset: 0 for normal FFT. Other than 0 in wideband FFT
	);
	port(
		clk       : in  std_logic;
		in_wAdr   : in  std_logic_vector;
		weight_re : out std_logic_vector;
		weight_im : out std_logic_vector
	);
end;

architecture rtl of rTwoWeights is

	constant c_virtual_stage : integer := g_stage + g_stage_offset; -- Virtual stage based on the real stage and the stage_offset.
	constant c_nof_shifts    : integer := -1 * g_stage_offset; -- Shift factor when fft is used in wfft configuration  

	signal nxt_weight_re  : std_logic_vector;
	signal nxt_weight_im  : std_logic_vector;
	signal wAdr_shift     : std_logic_vector(c_virtual_stage - 1 downto 1);
	signal wAdr_unshift   : std_logic_vector(c_virtual_stage - 1 downto 1);
	signal wAdr_tw_offset : integer := 0;

    begin

        wAdr_unshift   <= RESIZE_UVEC(in_wAdr, wAdr_unshift'length);
        wAdr_shift     <= SHIFT_UVEC(wAdr_unshift, c_nof_shifts) when in_wAdr'length > 0 else (others => '0');
        wAdr_tw_offset <= TO_UINT(wAdr_shift) + g_twiddle_offset when in_wAdr'length > 0 else g_twiddle_offset;

        -- Instantiate a BRAM for the coefficients
		coef_mem : entity casper_ram_lib.common_ram_rw_rw
			generic map(
				g_ram => c_mem_ram,
				g_init_file => g_coef_file,
				g_true_dual_port => TRUE, 
				g_ram_primitive => g_ram_primitive
			)
			port map(

			);


end rtl;