LIBRARY IEEE, STD, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.all;
USE IEEE.numeric_std.ALL;
USE STD.TEXTIO.ALL;

ENTITY tb_complex_addsub is
    GENERIC(
        g_a           : NATURAL := 119;
        g_b           : NATURAL := 85;
        g_bit_width   : NATURAL := 4;
        g_add_latency : INTEGER := 4
    );
    PORT(
        o_rst       : OUT STD_LOGIC;
        o_clk       : OUT STD_LOGIC;
        o_tb_end    : OUT STD_LOGIC;
        o_test_msg  : OUT STRING(1 to 80);
        o_test_pass : OUT BOOLEAN := True
    );
END tb_complex_addsub;

architecture RTL of tb_complex_addsub is

    CONSTANT clk_period : TIME := 10 ns;

    SIGNAL clk    : STD_LOGIC := '0';
    SIGNAL ce     : STD_LOGIC := '0';
    SIGNAL tb_end : STD_LOGIC := '0';

    SIGNAL s_a              : std_logic_vector(2 * g_bit_width - 1 downto 0);
    SIGNAL s_b              : std_logic_vector(2 * g_bit_width - 1 downto 0);
    SIGNAL s_a_plus_b_re    : INTEGER;
    SIGNAL s_a_plus_b_im    : INTEGER;
    SIGNAL s_a_minus_b_re   : INTEGER;
    SIGNAL s_a_minus_b_im   : INTEGER;
    SIGNAL s_a_plus_b_dout  : std_logic_vector(2 * g_bit_width - 1 downto 0);
    SIGNAL s_a_minus_b_dout : std_logic_vector(2 * g_bit_width - 1 downto 0);
    SIGNAL s_a_plus_b_gold  : std_logic_vector(2 * g_bit_width - 1 downto 0);
    SIGNAL s_a_minus_b_gold : std_logic_vector(2 * g_bit_width - 1 downto 0);

begin
    ce <= '1';
    s_a              <= std_logic_vector(to_signed(g_a, 2 * g_bit_width));
    s_b              <= std_logic_vector(to_signed(g_b, 2 * g_bit_width));
    s_a_plus_b_re    <= (TO_SINT(s_a(2 * g_bit_width - 1 DOWNTO g_bit_width)) + TO_SINT(s_b(2 * g_bit_width - 1 DOWNTO g_bit_width))) / 2;
    s_a_plus_b_im    <= (TO_SINT(s_a(g_bit_width - 1 DOWNTO 0)) + TO_SINT(s_b(g_bit_width - 1 DOWNTO 0))) / 2;
    s_a_minus_b_re   <= (TO_SINT(s_a(2 * g_bit_width - 1 DOWNTO g_bit_width)) - TO_SINT(s_b(2 * g_bit_width - 1 DOWNTO g_bit_width))) / 2;
    s_a_minus_b_im   <= (TO_SINT(s_a(g_bit_width - 1 DOWNTO 0)) - TO_SINT(s_b(g_bit_width - 1 DOWNTO 0))) / 2;
    s_a_plus_b_gold  <= TO_SVEC(s_a_plus_b_re, g_bit_width) & TO_SVEC(s_a_plus_b_im, g_bit_width);
    s_a_minus_b_gold <= TO_SVEC(s_a_minus_b_re, g_bit_width) & TO_SVEC(s_a_minus_b_im, g_bit_width);

    clk      <= NOT clk OR tb_end AFTER clk_period / 2;
    o_rst    <= not ce;
    o_clk    <= clk;
    o_tb_end <= tb_end;

    p_verify : PROCESS
        VARIABLE v_test_msg     : STRING(1 to o_test_msg'length) := (OTHERS => '.');
        VARIABLE v_test_pass_re : BOOLEAN                        := True;
        VARIABLE v_test_pass_im : BOOLEAN                        := True;
        VARIABLE v_test_pass    : BOOLEAN                        := True;
    BEGIN
        WAIT FOR (2*g_add_latency) * clk_period;
        WAIT UNTIL rising_edge(clk);
        v_test_pass_re := s_a_plus_b_gold = s_a_plus_b_dout;
        v_test_pass_im := s_a_minus_b_gold = s_a_minus_b_dout;
        v_test_pass    := v_test_pass_re and v_test_pass_im;
        if not v_test_pass_re then
            v_test_msg := pad("Complex_addsub failed.", o_test_msg'length, '.');
            REPORT v_test_msg severity failure;
        end if;
        tb_end <= '1';
    END PROCESS;

    complex_addsub_inst : entity work.complex_addsub
        generic map(
            g_bit_width   => g_bit_width,
            g_add_latency => g_add_latency
        )
        port map(
            clk       => clk,
            ce        => ce,
            a         => s_a,
            b         => s_b,
            a_plus_b  => s_a_plus_b_dout,
            a_minus_b => s_a_minus_b_dout
        );

end architecture RTL;
