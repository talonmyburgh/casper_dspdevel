library ieee, common_pkg_lib, casper_multiplier_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use common_pkg_lib.common_pkg.all;

entity cmult is
    generic(
        g_use_ip           : BOOLEAN := FALSE; -- Use IP component when TRUE, else rtl component when FALSE
        g_a_bw             : NATURAL := 18;
        g_b_bw             : NATURAL := 18;
        g_ab_bw            : NATURAL := 36;
        g_conjugate_b      : BOOLEAN := FALSE;
        g_use_gauss        : BOOLEAN := FALSE; --! Use 4DSP variant or 3DSP variant
        g_use_dsp          : BOOLEAN := TRUE;
        g_round_method     : NATURAL := 1;
        g_ovflw_method     : BOOLEAN := FALSE;
        g_pipeline_input   : NATURAL := 1; --! 0 or 1
        g_pipeline_product : NATURAL := 0; --! 0 or 1
        g_pipeline_adder   : NATURAL := 1; --! 0 or 1
        g_pipeline_round   : NATURAL := 1; --! 0 or 1
        g_pipeline_output  : NATURAL := 0 --! >= 0
    );
    port(
        clk     : in  std_logic;
        ce      : in  std_logic;
        rst     : in  std_logic;
        in_a    : in  std_logic_vector(2 * g_a_bw - 1 downto 0);
        in_b    : in  std_logic_vector(2 * g_b_bw - 1 downto 0);
        in_val  : in  std_logic := '1';
        out_ab  : out std_logic_vector(2 * g_ab_bw - 1 downto 0);
        out_val : out std_logic
    );
end entity cmult;

architecture Behaviour of cmult is

    constant round_mode    : t_rounding_mode := t_rounding_mode'val(g_round_method);
    constant c_prod_w      : NATURAL         := g_a_bw + g_b_bw + 1;
    constant c_a_complex_w : NATURAL         := g_a_bw * 2;
    constant c_b_complex_w : NATURAL         := g_b_bw * 2;
    constant c_use_variant : STRING          := sel_a_b(g_use_gauss, "3DSP", "4DSP");
    constant c_use_dsp     : STRING          := sel_a_b(g_use_dsp, "YES", "NO");

    signal s_in_a_re : std_logic_vector(g_a_bw - 1 DOWNTO 0);
    signal s_in_a_im : std_logic_vector(g_a_bw - 1 DOWNTO 0);
    signal s_in_b_re : std_logic_vector(g_b_bw - 1 DOWNTO 0);
    signal s_in_b_im : std_logic_vector(g_b_bw - 1 DOWNTO 0);

    signal s_out_ab_re : std_logic_vector(c_prod_w - 1 DOWNTO 0);
    signal s_out_ab_im : std_logic_vector(c_prod_w - 1 DOWNTO 0);
    signal s_round_re  : std_logic_vector(g_ab_bw - 1 DOWNTO 0);
    signal s_round_im  : std_logic_vector(g_ab_bw - 1 DOWNTO 0);

begin
    ------------------------------------------------------
    -- Split A and B into separate re/im parts
    ------------------------------------------------------
    s_in_a_re <= in_a(c_a_complex_w - 1 DOWNTO g_a_bw);
    s_in_a_im <= in_a(g_a_bw - 1 DOWNTO 0);
    s_in_b_re <= in_b(c_b_complex_w - 1 DOWNTO g_b_bw);
    s_in_b_im <= in_b(g_b_bw - 1 DOWNTO 0);

    ------------------------------------------------------
    -- Feed into common_complex_mult
    ------------------------------------------------------
    common_complex_mult_inst : entity casper_multiplier_lib.common_complex_mult
        generic map(
            g_use_ip           => g_use_ip,
            g_use_variant      => c_use_variant,
            g_use_dsp          => c_use_dsp,
            g_in_a_w           => g_a_bw,
            g_in_b_w           => g_b_bw,
            g_out_p_w          => c_prod_w,
            g_conjugate_b      => g_conjugate_b,
            g_pipeline_input   => g_pipeline_input,
            g_pipeline_product => g_pipeline_product,
            g_pipeline_adder   => g_pipeline_adder,
            g_pipeline_output  => g_pipeline_output
        )
        port map(
            rst     => rst,
            clk     => clk,
            clken   => ce,
            in_ar   => s_in_a_re,
            in_ai   => s_in_a_im,
            in_br   => s_in_b_re,
            in_bi   => s_in_b_im,
            in_val  => in_val,
            out_pr  => s_out_ab_re,
            out_pi  => s_out_ab_im,
            out_val => out_val
        );

    ------------------------------------------------------------------------------
    -- Round cmult output output
    ------------------------------------------------------------------------------

    gen_resize : if g_ab_bw >= c_prod_w GENERATE
        gen_comb_resize : if g_pipeline_round = 0 generate
            s_round_re <= RESIZE_SVEC(s_out_ab_re, g_ab_bw);
            s_round_im <= RESIZE_SVEC(s_out_ab_im, g_ab_bw);
        end generate;
        gen_reg_resize : if g_pipeline_round = 1 generate
            s_round_re <= RESIZE_SVEC(s_out_ab_re, g_ab_bw) when rising_edge(clk);
            s_round_im <= RESIZE_SVEC(s_out_ab_im, g_ab_bw) when rising_edge(clk);
        end generate;
    END GENERATE;

    gen_round : if g_ab_bw < c_prod_w GENERATE
        gen_comb_round : if g_pipeline_round = 0 generate
            s_round_re <= s_round(vec => s_out_ab_re, n => c_prod_w - g_ab_bw, clip => g_ovflw_method, round_style => round_mode);
            s_round_im <= s_round(vec => s_out_ab_im, n => c_prod_w - g_ab_bw, clip => g_ovflw_method, round_style => round_mode);
        end generate;
        gen_reg_round : if g_pipeline_round = 1 generate
            s_round_re <= s_round(vec => s_out_ab_re, n => c_prod_w - g_ab_bw, clip => g_ovflw_method, round_style => round_mode) when rising_edge(clk);
            s_round_im <= s_round(vec => s_out_ab_im, n => c_prod_w - g_ab_bw, clip => g_ovflw_method, round_style => round_mode) when rising_edge(clk);
        end generate;
    END GENERATE;

    out_ab(2 * g_ab_bw - 1 DOWNTO 0) <= s_round_re(g_ab_bw - 1 DOWNTO 0) & s_round_im(g_ab_bw - 1 DOWNTO 0);
end architecture Behaviour;

