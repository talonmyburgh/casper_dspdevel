-- A VHDL implementation of the CASPER complex_addsub.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE, casper_adder_lib, common_pkg_lib, casper_delay_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;

entity complex_addsub is
    generic(
        g_bit_width : NATURAL := 8;
        g_add_latency : NATURAL := 2
    );
    port(
        clk : in std_logic;
        ce  : in std_logic;
        a   : in std_logic_vector;
        b   : in std_logic_vector;
        a_plus_b : out std_logic_vector(2*g_bit_width - 1 DOWNTO 0);
        a_minus_b : out std_logic_vector(2*g_bit_width - 1 DOWNTO 0)
    );
end entity complex_addsub;

architecture behavioural of complex_addsub is

    signal s_inst1_re : std_logic_vector(g_bit_width - 1 downto 0);
    signal s_inst1_im : std_logic_vector(g_bit_width - 1 downto 0);
    signal s_inst2_re : std_logic_vector(g_bit_width - 1 downto 0);
    signal s_inst2_im : std_logic_vector(g_bit_width - 1 downto 0);

    signal s_addsub1 : std_logic_vector(g_bit_width downto 0);
    signal s_addsub2 : std_logic_vector(g_bit_width downto 0);
    signal s_addsub3 : std_logic_vector(g_bit_width downto 0);
    signal s_addsub4 : std_logic_vector(g_bit_width downto 0);

    signal s_scale1 : std_logic_vector(g_bit_width downto 0);    
    signal s_scale2 : std_logic_vector(g_bit_width downto 0);
    signal s_scale3 : std_logic_vector(g_bit_width downto 0);
    signal s_scale4 : std_logic_vector(g_bit_width downto 0);

    signal s_round1 : std_logic_vector(g_bit_width - 1 downto 0);    
    signal s_round2 : std_logic_vector(g_bit_width - 1 downto 0);
    signal s_round3 : std_logic_vector(g_bit_width - 1 downto 0);
    signal s_round4 : std_logic_vector(g_bit_width - 1 downto 0);
    
    signal s_round_buf1 : std_logic_vector(g_bit_width - 1 downto 0) := (others => '0');    
    signal s_round_buf2 : std_logic_vector(g_bit_width - 1 downto 0) := (others => '0');
    signal s_round_buf3 : std_logic_vector(g_bit_width - 1 downto 0) := (others => '0');
    signal s_round_buf4 : std_logic_vector(g_bit_width - 1 downto 0) := (others => '0');
    
    signal s_out1 : std_logic_vector(2*g_bit_width - 1 downto 0) := (others => '0');
    signal s_out2 : std_logic_vector(2*g_bit_width - 1 downto 0) := (others => '0');

    constant c_addsub_input_latency : integer := sel_a_b(g_add_latency > 1, 1, 0);
    constant c_addsub_output_latency : integer := sel_a_b(g_add_latency = 0, 0, g_add_latency - c_addsub_input_latency);
    constant c_round_style : t_rounding_mode := ROUND;
    

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
            re_out => s_inst1_re,
            im_out => s_inst1_im
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
            re_out => s_inst2_re,
            im_out => s_inst2_im
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
            clk     => clk,
            clken   => ce,
            in_a    => s_inst1_re,
            in_b    => s_inst2_re,
            result  => s_addsub1
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
            clk     => clk,
            clken   => ce,
            in_a    => s_inst2_re,
            in_b    => s_inst1_re,
            result  => s_addsub2
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
            clk     => clk,
            clken   => ce,
            in_a    => s_inst1_im,
            in_b    => s_inst2_im,
            result  => s_addsub3
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
            clk     => clk,
            clken   => ce,
            in_a    => s_inst1_im,
            in_b    => s_inst2_im,
            result  => s_addsub4
        );
    
    ----------------Scale the values by 0.5----------------
    s_scale1 <= std_logic_vector(signed(s_addsub1) / 2);
    s_scale2 <= std_logic_vector(signed(s_addsub2) / 2);
    s_scale3 <= std_logic_vector(signed(s_addsub3) / 2);
    s_scale4 <= std_logic_vector(signed(s_addsub4) / 2);

    ----------------Resize and Round the value to correct bit widths----------------
    s_round1 <= s_round(s_scale1, 1, FALSE, c_round_style);
    s_round1 <= s_round(s_scale1, 1, FALSE, c_round_style);
    s_round1 <= s_round(s_scale1, 1, FALSE, c_round_style);
    s_round1 <= s_round(s_scale1, 1, FALSE, c_round_style);

    ----------------Buffer the signals by g_add_latency----------------
    delay_simple_inst1 : entity casper_delay_lib.delay_simple
        generic map(
            g_delay          => g_add_latency
        )
        port map(
            clk    => clk,
            ce     => ce,
            i_data => s_round1,
            o_data => s_round_buf1
        );
    delay_simple_inst2 : entity casper_delay_lib.delay_simple
        generic map(
            g_delay          => g_add_latency
        )
        port map(
            clk    => clk,
            ce     => ce,
            i_data => s_round2,
            o_data => s_round_buf2
        );
    delay_simple_inst3 : entity casper_delay_lib.delay_simple
        generic map(
            g_delay          => g_add_latency
        )
        port map(
            clk    => clk,
            ce     => ce,
            i_data => s_round3,
            o_data => s_round_buf3
        );
    delay_simple_inst4 : entity casper_delay_lib.delay_simple
        generic map(
            g_delay          => g_add_latency
        )
        port map(
            clk    => clk,
            ce     => ce,
            i_data => s_round4,
            o_data => s_round_buf4
        );

    ----------------Real Imaginary to Complex Conversion----------------
    ri_to_c_inst1 : entity work.ri_to_c
        generic map(
            g_async => TRUE
        )
        port map(
            clk   => clk,
            ce    => ce,
            re_in => s_round_buf1,
            im_in => s_round_buf3,
            c_out => s_out1
        );

    ri_to_c_inst2 : entity work.ri_to_c
        generic map(
            g_async => TRUE
        )
        port map(
            clk   => clk,
            ce    => ce,
            re_in => s_round_buf4,
            im_in => s_round_buf2,
            c_out => s_out2
        );
    
    a_plus_b <= s_out1;
    a_minus_b <= s_out2;
    

end architecture behavioural;