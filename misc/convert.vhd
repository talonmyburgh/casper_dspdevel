-- A VHDL implementation of the CASPER convert block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
LIBRARY IEEE, common_pkg_lib, casper_adder_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
use common_pkg_lib.common_pkg.all;

entity convert is
    generic(
        g_bin_point_in  : NATURAL := 8;
        g_out_bitwidth  : NATURAL := 8;
        g_bin_point_out : NATURAL := 8;
        g_quantization  : STRING  := "ROUND";
        g_latency       : NATURAL := 2
    );
    port(
        clk  : IN  std_logic;
        ce   : IN  std_logic;
        din  : IN  std_logic_vector;
        dout : OUT std_logic_vector(g_out_bitwidth - 1 DOWNTO 0)
    );
end convert;

architecture rtl of convert is

    CONSTANT c_in_bitwidth     : NATURAL         := din'LENGTH;
    CONSTANT c_chop            : NATURAL         := g_bin_point_in - g_bin_point_out;
    CONSTANT c_round_style     : t_rounding_mode := stringround_to_enum_round(g_quantization);
    CONSTANT c_almost_half     : NATURAL         := sel_a_b(c_round_style = TRUNCATE, 0, pow2(c_chop) - 1);
    CONSTANT c_pipeline_input  : NATURAL         := ceil_div(g_latency, 2);
    CONSTANT c_pipeline_output : NATURAL         := g_latency - c_pipeline_input;

    SIGNAL s_bit_slice : std_logic := '0';
    SIGNAL s_lo        : std_logic := '0';
    SIGNAL s_concat    : std_logic_vector(c_in_bitwidth DOWNTO 0);
    SIGNAL s_add_a     : std_logic_vector(c_in_bitwidth DOWNTO 0);
    SIGNAL s_add_b     : std_logic_vector(c_in_bitwidth DOWNTO 0);
    SIGNAL s_addition  : std_logic_vector(g_out_bitwidth - 1 DOWNTO 0);
begin
    s_bit_slice <= din(c_chop);
    s_lo        <= s_bit_slice nor '1';
    s_concat    <= din & s_lo;
    s_add_a     <= s_concat;
    s_add_b     <= TO_UVEC(c_almost_half, c_in_bitwidth + 1);
    dout        <= s_addition;

    common_add_sub_inst : entity casper_adder_lib.common_add_sub
        generic map(
            g_direction       => "ADD",
            g_pipeline_input  => c_pipeline_input,
            g_pipeline_output => c_pipeline_output,
            g_in_dat_w        => c_in_bitwidth + 1,
            g_out_dat_w       => g_out_bitwidth
        )
        port map(
            clk    => clk,
            clken  => ce,
            in_a   => s_add_a,
            in_b   => s_add_b,
            result => s_addition
        );
end architecture;
