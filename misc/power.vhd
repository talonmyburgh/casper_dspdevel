-- A VHDL implementation of the CASPER power.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, casper_adder_lib, casper_multiplier_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;

entity power is
    generic(
        g_bit_width_in : NATURAL := 8;
        g_add_latency  : NATURAL := 2;
        g_mult_latency : NATURAL := 3;
        g_use_dsp      : STRING  := "YES"
    );
    port(
        clk  : in  std_logic;
        ce   : in  std_logic;
        din  : in  std_logic_vector(2 * g_bit_width_in - 1 downto 0);
        dout : out std_logic_vector(2 * g_bit_width_in + 1 - 1 downto 0) := (others => '0')
    );
end entity power;

architecture behavioural of power is
    constant c_prod_w               : NATURAL := 2 * g_bit_width_in;
    constant c_power_w              : NATURAL := c_prod_w + 1;
    constant c_mult_product_latency : NATURAL := sel_a_b(g_mult_latency > 0, 1, 0);
    constant c_mult_in_latency      : NATURAL := sel_a_b(g_mult_latency > 1, 1, 0);
    constant c_mult_out_latency     : NATURAL := g_mult_latency - c_mult_in_latency - c_mult_product_latency;

    constant c_add_in_latency  : NATURAL := sel_a_b(g_add_latency > 0, 1, 0);
    constant c_add_out_latency : NATURAL := g_add_latency - c_add_in_latency;

    signal s_re : std_logic_vector(g_bit_width_in - 1 downto 0) := (others => '0');
    signal s_im : std_logic_vector(g_bit_width_in - 1 downto 0) := (others => '0');

    signal s_re_square : std_logic_vector(c_prod_w - 1 downto 0) := (others => '0');
    signal s_im_square : std_logic_vector(c_prod_w - 1 downto 0) := (others => '0');

    signal s_power : std_logic_vector(c_power_w - 1 downto 0) := (others => '0');

begin

    ------------------Split into real and imaginary parts------------------
    c_to_ri_inst : entity work.c_to_ri
        generic map(
            g_async     => TRUE,
            g_bit_width => g_bit_width_in
        )
        port map(
            clk    => clk,
            ce     => ce,
            c_in   => din,
            re_out => s_re,
            im_out => s_im
        );

    ------------------Calculate the square of the separate part------------------
    re_square : entity casper_multiplier_lib.common_mult
        generic map(
            g_use_dsp          => g_use_dsp,
            g_in_a_w           => g_bit_width_in,
            g_in_b_w           => g_bit_width_in,
            g_out_p_w          => c_prod_w,
            g_pipeline_input   => c_mult_in_latency,
            g_pipeline_product => c_mult_product_latency,
            g_pipeline_output  => c_mult_out_latency
        )
        port map(
            rst     => '0',
            clk     => clk,
            clken   => ce,
            in_a    => s_re,
            in_b    => s_re,
            in_val  => '1',
            result  => s_re_square,
            out_val => open
        );

    im_square : entity casper_multiplier_lib.common_mult
        generic map(
            g_use_dsp          => g_use_dsp,
            g_in_a_w           => g_bit_width_in,
            g_in_b_w           => g_bit_width_in,
            g_out_p_w          => c_prod_w,
            g_pipeline_input   => c_mult_in_latency,
            g_pipeline_product => c_mult_product_latency,
            g_pipeline_output  => c_mult_out_latency
        )
        port map(
            rst     => '0',
            clk     => clk,
            clken   => ce,
            in_a    => s_im,
            in_b    => s_im,
            in_val  => '1',
            result  => s_im_square,
            out_val => open
        );

    ------------------Add the squares------------------
    power_adder : entity casper_adder_lib.common_add_sub
        generic map(
            g_pipeline_input  => c_add_in_latency,
            g_pipeline_output => c_add_out_latency,
            g_in_dat_w        => c_prod_w,
            g_out_dat_w       => c_power_w
        )
        port map(
            clk    => clk,
            clken  => ce,
            in_a   => s_re_square,
            in_b   => s_im_square,
            result => s_power
        );

    dout <= s_power;

end behavioural;
