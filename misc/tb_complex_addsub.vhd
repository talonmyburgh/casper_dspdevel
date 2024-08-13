LIBRARY IEEE, STD, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.all;
USE IEEE.numeric_std.ALL;
USE STD.TEXTIO.ALL;

ENTITY tb_complex_addsub is
    GENERIC(
        g_a : NATURAL := 8;
        g_b : NATURAL := 8;
        g_a_plus_b : NATURAL := 8;
        g_a_minus_b : NATURAL := 8;
        g_bit_width : NATURAL := 8;
        g_add_latency : INTEGER := 4
    );
    PORT(
		o_rst		   : OUT STD_LOGIC;
		o_clk		   : OUT STD_LOGIC;
		o_tb_end	   : OUT STD_LOGIC;
		o_test_msg	   : OUT STRING(1 to 80);
		o_test_pass	   : OUT BOOLEAN := True
	);
END tb_complex_addsub;

architecture RTL of tb_complex_addsub is

    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk          : STD_LOGIC := '0';
    SIGNAL ce           : STD_LOGIC := '0';
    SIGNAL tb_end       : STD_LOGIC := '0';

    SIGNAL s_a : std_logic_vector(2*g_bit_width - 1 downto 0);
    SIGNAL s_b : std_logic_vector(2*g_bit_width - 1 downto 0);
    SIGNAL s_a_plus_b : std_logic_vector(2*g_bit_width - 1 downto 0);
    SIGNAL s_a_minus_b : std_logic_vector(2*g_bit_width - 1 downto 0);
    SIGNAL s_a_plus_b_gold : std_logic_vector(2*g_bit_width - 1 downto 0);
    SIGNAL s_a_minus_b_gold : std_logic_vector(2*g_bit_width - 1 downto 0);

begin

    s_a <= std_logic_vector(to_signed(g_a, 2*g_bit_width));
    s_b <= std_logic_vector(to_signed(g_b, 2*g_bit_width));
    s_a_plus_b_gold <= std_logic_vector(to_signed(g_a_plus_b, 2*g_bit_width));
    s_a_minus_b_gold <= std_logic_vector(to_signed(g_a_minus_b, 2*g_bit_width));

    clk   <= NOT clk OR tb_end AFTER clk_period / 2;
    o_rst <= not ce;
    o_clk <= clk;
    o_tb_end <= tb_end;

    p_verify : PROCESS(clk)
    VARIABLE v_test_msg : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    VARIABLE v_test_pass_re : BOOLEAN := True;
    VARIABLE v_test_pass_im : BOOLEAN := True;
    VARIABLE v_test_pass : BOOLEAN := True;
    VARIABLE v_cnt : INTEGER := 0;
    BEGIN
        if rising_edge(clk) THEN
            if v_cnt = 0 then
                ce <= '1';
            end if;
            if v_cnt = g_add_latency then
                v_test_pass_re := s_a_plus_b_gold = s_a_plus_b;
                v_test_pass_im := s_a_minus_b_gold = s_a_minus_b;
                v_test_pass := v_test_pass_re and v_test_pass_im;
--                if not v_test_pass then
--                    -- v_test_msg := pad("Pulse extension failed. Expected: " & std_logic'image(s_pulse_exp) & " but got: " & std_logic'image(s_pulse_out), o_test_msg'length,'.');
--                    REPORT "Pulse extension failed. Expected: " severity failure;--" & std_logic'image(s_pulse_exp) & " but got: " & std_logic'image(s_pulse_out) severity failure;
--                end if;
--                tb_end <= '0';
--                ce <= '0';
            end if; 
            v_cnt := v_cnt + 1;
        end if;
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
            a_plus_b  => s_a_plus_b,
            a_minus_b => s_a_minus_b
        );
    
    
end architecture RTL;
