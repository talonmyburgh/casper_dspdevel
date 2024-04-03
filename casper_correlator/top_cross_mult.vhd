library ieee, common_pkg_lib, casper_multiplier_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use common_pkg_lib.common_pkg.all;
use work.correlator_pkg.all;

entity cross_multiplier_top is
    generic(
        g_use_gauss        : BOOLEAN := FALSE;
        g_use_dsp          : BOOLEAN := TRUE;
        g_pipeline_input   : NATURAL := 1; --! 0 or 1
        g_pipeline_product : NATURAL := 1; --! 0 or 1
        g_pipeline_adder   : NATURAL := 1; --! 0 or 1
        g_pipeline_round   : NATURAL := 1; --! 0 or 1
        g_pipeline_output  : NATURAL := 0; --! >= 0
        ovflw_behav        : BOOLEAN := FALSE;
        quant_behav        : NATURAL := 0
    );
    port(
        clk  : in  std_logic;
        ce   : in  std_logic;
        sync_in : in std_logic;
        sync_out : out std_logic;
        din_0 : in STD_LOGIC_VECTOR((c_cross_mult_aggregation_per_stream * c_cross_mult_input_cbit_width) - 1 downto 0);
        din_1 : in STD_LOGIC_VECTOR((c_cross_mult_aggregation_per_stream * c_cross_mult_input_cbit_width) - 1 downto 0);
        dout_0 : out STD_LOGIC_VECTOR((c_cross_mult_aggregation_per_stream * c_cross_mult_output_cbit_width) - 1 downto 0);
        dout_1 : out STD_LOGIC_VECTOR((c_cross_mult_aggregation_per_stream * c_cross_mult_output_cbit_width) - 1 downto 0);
        dout_2 : out STD_LOGIC_VECTOR((c_cross_mult_aggregation_per_stream * c_cross_mult_output_cbit_width) - 1 downto 0)
    );

end entity cross_multiplier_top;

architecture RTL of cross_multiplier_top is

    SIGNAL s_din : s_cross_mult_din;
    SIGNAL s_dout : s_cross_mult_out;
begin

    u_cross_mult : entity work.cross_multiplier
    generic map (
     g_use_gauss => g_use_gauss,
     g_use_dsp => g_use_dsp,
     g_pipeline_input => g_pipeline_input,
     g_pipeline_product => g_pipeline_product,
     g_pipeline_adder => g_pipeline_adder,
     g_pipeline_round => g_pipeline_round,
     g_pipeline_output => g_pipeline_output,
     ovflw_behav => ovflw_behav,
     quant_behav => quant_behav
    )
    port map (
      clk => clk,
      ce => ce,
      sync_in => sync_in,
      sync_out => sync_out,
      din => s_din,
      dout => s_dout
    );

    s_din(0) <= din_0;
    s_din(1) <= din_1;
    dout_0 <= s_dout(0);
    dout_1 <= s_dout(1);
    dout_2 <= s_dout(2);

end architecture;