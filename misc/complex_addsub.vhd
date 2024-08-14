-- A VHDL implementation of the CASPER complex_addsub.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE, casper_adder_lib, common_pkg_lib, casper_delay_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;

entity complex_addsub is
    generic(
        g_bit_width   : NATURAL := 8;
        g_add_latency : NATURAL := 2
    );
    port(
        clk       : in  std_logic;
        ce        : in  std_logic;
        a         : in  std_logic_vector;
        b         : in  std_logic_vector;
        a_plus_b  : out std_logic_vector(2 * g_bit_width - 1 DOWNTO 0);
        a_minus_b : out std_logic_vector(2 * g_bit_width - 1 DOWNTO 0)
    );
end entity complex_addsub;

architecture behavioural of complex_addsub is

    signal s_a_re : std_logic_vector(g_bit_width - 1 downto 0) := (others => '0');
    signal s_a_im : std_logic_vector(g_bit_width - 1 downto 0) := (others => '0');
    signal s_b_re : std_logic_vector(g_bit_width - 1 downto 0) := (others => '0');
    signal s_b_im : std_logic_vector(g_bit_width - 1 downto 0) := (others => '0');

    signal s_add_re : std_logic_vector(g_bit_width downto 0);
    signal s_add_im : std_logic_vector(g_bit_width downto 0);
    signal s_sub_re : std_logic_vector(g_bit_width downto 0);
    signal s_sub_im : std_logic_vector(g_bit_width downto 0);

    signal s_round_add_re : std_logic_vector(g_bit_width - 1 downto 0);
    signal s_round_sub_re : std_logic_vector(g_bit_width - 1 downto 0);
    signal s_round_sub_im : std_logic_vector(g_bit_width - 1 downto 0);
    signal s_round_add_im : std_logic_vector(g_bit_width - 1 downto 0);

    signal s_round_buf_add_re : std_logic_vector(g_bit_width - 1 downto 0) := (others => '0');
    signal s_round_buf_sub_re : std_logic_vector(g_bit_width - 1 downto 0) := (others => '0');
    signal s_round_buf_sub_im : std_logic_vector(g_bit_width - 1 downto 0) := (others => '0');
    signal s_round_buf_add_im : std_logic_vector(g_bit_width - 1 downto 0) := (others => '0');

    signal s_out_a_plus_b  : std_logic_vector(2 * g_bit_width - 1 downto 0) := (others => '0');
    signal s_out_a_minus_b : std_logic_vector(2 * g_bit_width - 1 downto 0) := (others => '0');

    constant c_addsub_input_latency  : integer         := sel_a_b(g_add_latency > 1, 1, 0);
    constant c_addsub_output_latency : integer         := sel_a_b(g_add_latency = 0, 0, g_add_latency - c_addsub_input_latency);
    constant c_round_style           : t_rounding_mode := ROUND;

begin

    ----------------Complex to Real Imaginary Conversion----------------
    c_to_ri_inst1 : entity work.c_to_ri
        generic map(
            g_async     => TRUE,
            g_bit_width => g_bit_width
        )
        port map(
            clk    => clk,
            ce     => ce,
            c_in   => a,
            re_out => s_a_re,
            im_out => s_a_im
        );

    c_to_ri_inst2 : entity work.c_to_ri
        generic map(
            g_async     => TRUE,
            g_bit_width => g_bit_width
        )
        port map(
            clk    => clk,
            ce     => ce,
            c_in   => b,
            re_out => s_b_re,
            im_out => s_b_im
        );

    ----------------Addition and Subtraction----------------
    common_add_sub_inst1 : entity casper_adder_lib.common_add_sub
        generic map(
            g_direction       => "ADD",
            g_representation  => "SIGNED",
            g_pipeline_input  => c_addsub_input_latency,
            g_pipeline_output => c_addsub_output_latency,
            g_in_dat_w        => g_bit_width,
            g_out_dat_w       => g_bit_width + 1
        )
        port map(
            clk    => clk,
            clken  => ce,
            in_a   => s_a_re,
            in_b   => s_b_re,
            result => s_add_re
        );
    common_add_sub_inst2 : entity casper_adder_lib.common_add_sub
        generic map(
            g_direction       => "SUB",
            g_representation  => "SIGNED",
            g_pipeline_input  => c_addsub_input_latency,
            g_pipeline_output => c_addsub_output_latency,
            g_in_dat_w        => g_bit_width,
            g_out_dat_w       => g_bit_width + 1
        )
        port map(
            clk    => clk,
            clken  => ce,
            in_a   => s_a_re,
            in_b   => s_b_re,
            result => s_sub_re
        );
    common_add_sub_inst3 : entity casper_adder_lib.common_add_sub
        generic map(
            g_direction       => "SUB",
            g_representation  => "SIGNED",
            g_pipeline_input  => c_addsub_input_latency,
            g_pipeline_output => c_addsub_output_latency,
            g_in_dat_w        => g_bit_width,
            g_out_dat_w       => g_bit_width + 1
        )
        port map(
            clk    => clk,
            clken  => ce,
            in_a   => s_a_im,
            in_b   => s_b_im,
            result => s_sub_im
        );
    common_add_sub_inst4 : entity casper_adder_lib.common_add_sub
        generic map(
            g_direction       => "ADD",
            g_representation  => "SIGNED",
            g_pipeline_input  => c_addsub_input_latency,
            g_pipeline_output => c_addsub_output_latency,
            g_in_dat_w        => g_bit_width,
            g_out_dat_w       => g_bit_width + 1
        )
        port map(
            clk    => clk,
            clken  => ce,
            in_a   => s_a_im,
            in_b   => s_b_im,
            result => s_add_im
        );

    ----------------Resize (scale by 0.5) and Round the value to correct bit widths----------------
    s_round_add_re <= s_round(s_add_re, 1, FALSE, c_round_style);
    s_round_sub_re <= s_round(s_sub_re, 1, FALSE, c_round_style);
    s_round_sub_im <= s_round(s_sub_im, 1, FALSE, c_round_style);
    s_round_add_im <= s_round(s_add_im, 1, FALSE, c_round_style);

    ----------------Buffer the signals by g_add_latency----------------
    gen_delays : if g_add_latency > 0 generate
        delay_simple_inst1 : entity casper_delay_lib.delay_simple
            generic map(
                g_delay => g_add_latency
            )
            port map(
                clk    => clk,
                ce     => ce,
                i_data => s_round_add_re,
                o_data => s_round_buf_add_re
            );
        delay_simple_inst2 : entity casper_delay_lib.delay_simple
            generic map(
                g_delay => g_add_latency
            )
            port map(
                clk    => clk,
                ce     => ce,
                i_data => s_round_sub_re,
                o_data => s_round_buf_sub_re
            );
        delay_simple_inst3 : entity casper_delay_lib.delay_simple
            generic map(
                g_delay => g_add_latency
            )
            port map(
                clk    => clk,
                ce     => ce,
                i_data => s_round_sub_im,
                o_data => s_round_buf_sub_im
            );
        delay_simple_inst4 : entity casper_delay_lib.delay_simple
            generic map(
                g_delay => g_add_latency
            )
            port map(
                clk    => clk,
                ce     => ce,
                i_data => s_round_add_im,
                o_data => s_round_buf_add_im
            );
    end generate gen_delays;

    gen_comb : if g_add_latency = 0 generate
        s_round_buf_add_re <= s_round_add_re;
        s_round_buf_sub_re <= s_round_sub_re;
        s_round_buf_sub_im <= s_round_sub_im;
        s_round_buf_add_im <= s_round_add_im;
    end generate gen_comb;

    ----------------Real Imaginary to Complex Conversion----------------
    ri_to_c_inst1 : entity work.ri_to_c
        generic map(
            g_async => TRUE
        )
        port map(
            clk   => clk,
            ce    => ce,
            re_in => s_round_buf_add_re,
            im_in => s_round_buf_add_im,
            c_out => s_out_a_plus_b
        );

    ri_to_c_inst2 : entity work.ri_to_c
        generic map(
            g_async => TRUE
        )
        port map(
            clk   => clk,
            ce    => ce,
            re_in => s_round_buf_sub_re,
            im_in => s_round_buf_sub_im,
            c_out => s_out_a_minus_b
        );

    a_plus_b  <= s_out_a_plus_b;
    a_minus_b <= s_out_a_minus_b;

end architecture behavioural;
