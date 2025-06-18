-- A VHDL implementation of the CASPER complex_convert.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, casper_delay_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;

entity complex_convert is
    generic(
        g_bit_width_in  : NATURAL := 8;
        g_bit_width_out : NATURAL := 8;
        g_quantization  : STRING  := "ROUND";
        g_clip          : BOOLEAN := FALSE;
        g_latency       : NATURAL := 2
    );
    port(
        clk  : in  std_logic;
        ce   : in  std_logic;
        din  : in  std_logic_vector(2*g_bit_width_in - 1 downto 0);
        dout : out std_logic_vector(2*g_bit_width_out - 1 downto 0) := (others => '0')
    );
end entity complex_convert;

architecture behavioural of complex_convert is

    constant c_round_style : t_rounding_mode := stringround_to_enum_round(g_quantization);
    constant c_bit_round   : NATURAL         := g_bit_width_in - g_bit_width_out;

    signal s_re       : std_logic_vector(g_bit_width_in - 1 downto 0)  := (others => '0');
    signal s_im       : std_logic_vector(g_bit_width_in - 1 downto 0)  := (others => '0');
    signal s_re_delay : std_logic_vector(g_bit_width_in - 1 downto 0)  := (others => '0');
    signal s_im_delay : std_logic_vector(g_bit_width_in - 1 downto 0)  := (others => '0');
    signal s_re_round : std_logic_vector(g_bit_width_out - 1 downto 0) := (others => '0');
    signal s_im_round : std_logic_vector(g_bit_width_out - 1 downto 0) := (others => '0');

begin

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

    gen_lat : if g_latency > 0 generate
        re_delay_simple_inst : entity casper_delay_lib.delay_simple
            generic map(
                g_delay => g_latency
            )
            port map(
                clk    => clk,
                ce     => ce,
                i_data => s_re,
                o_data => s_re_delay
            );

        im_delay_simple_inst : entity casper_delay_lib.delay_simple
            generic map(
                g_delay => g_latency
            )
            port map(
                clk    => clk,
                ce     => ce,
                i_data => s_im,
                o_data => s_im_delay
            );
    end generate gen_lat;

    gen_comb : if g_latency = 0 generate
        s_re_delay <= s_re;
        s_im_delay <= s_im;
    end generate gen_comb;

    s_re_round <= s_round(s_re_delay, c_bit_round, g_clip, c_round_style);
    s_im_round <= s_round(s_im_delay, c_bit_round, g_clip, c_round_style);

    ri_to_c_inst : entity work.ri_to_c
        generic map(
            g_async => TRUE
        )
        port map(
            clk   => clk,
            ce    => ce,
            re_in => s_re_round,
            im_in => s_im_round,
            c_out => dout
        );

end architecture behavioural;
