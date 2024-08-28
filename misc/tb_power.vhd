LIBRARY IEEE, STD, common_pkg_lib, casper_adder_lib, casper_multiplier_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE STD.TEXTIO.ALL;

ENTITY tb_power is
    GENERIC(
        g_bit_width_in : NATURAL := 8;
        g_add_latency  : NATURAL := 2;
        g_mult_latency : NATURAL := 3;
        g_use_dsp      : STRING  := "NO";

        g_value_re     : NATURAL := 9;
        g_value_im     : NATURAL := 3
    );
    PORT(
		o_rst		   : OUT STD_LOGIC;
		o_clk		   : OUT STD_LOGIC;
		o_tb_end	   : OUT STD_LOGIC;
		o_test_msg	   : OUT STRING(1 to 80);
		o_test_pass	   : OUT BOOLEAN := True
	);
END tb_power;

ARCHITECTURE rtl of tb_power is

    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk                 : STD_LOGIC := '0';
    SIGNAL ce                  : STD_LOGIC := '0';
    SIGNAL tb_end              : STD_LOGIC := '0';

    SIGNAL s_din               : STD_LOGIC_VECTOR(2 * g_bit_width_in - 1 DOWNTO 0);
    SIGNAL s_din_re            : STD_LOGIC_VECTOR(g_bit_width_in - 1 DOWNTO 0);
    SIGNAL s_din_im            : STD_LOGIC_VECTOR(g_bit_width_in - 1 DOWNTO 0);
    SIGNAL s_dout              : STD_LOGIC_VECTOR(2 * g_bit_width_in + 1 - 1 DOWNTO 0);

    SIGNAL s_dout_golden       : STD_LOGIC_VECTOR(2 * g_bit_width_in + 1 - 1 DOWNTO 0);
begin
    
    clk         <= NOT clk OR tb_end AFTER clk_period / 2;
    o_rst       <= NOT ce;
    o_clk       <= clk;
    o_tb_end    <= tb_end;

    -------------------DUT instantiation-------------------
    power_inst : entity work.power
        generic map(
            g_bit_width_in => g_bit_width_in,
            g_add_latency  => g_add_latency,
            g_mult_latency => g_mult_latency,
            g_use_dsp      => g_use_dsp
        )
        port map(
            clk  => clk,
            ce   => ce,
            din  => s_din,
            dout => s_dout
        );
    
    -------------------Load vector with value-------------------
    s_din_re <= TO_UVEC(g_value_re, g_bit_width_in);
    s_din_im <= TO_UVEC(g_value_im, g_bit_width_in);
    s_din <= s_din_re & s_din_im;

    -------------------Golden model-------------------
    validate : process is
        variable v_re_square : integer := g_value_re * g_value_re;
        variable v_im_square : integer := g_value_im * g_value_im;
        variable v_power     : integer := v_re_square + v_im_square;
        VARIABLE v_test_pass : BOOLEAN := TRUE;
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    begin
        WAIT FOR clk_period;
        s_dout_golden <= TO_SVEC(v_power, 2 * g_bit_width_in + 1);
        ce <= '1';
        WAIT FOR clk_period * (g_add_latency + g_mult_latency);
        WAIT UNTIL rising_edge(clk);
        v_test_pass := s_dout = s_dout_golden;
        if not v_test_pass then
            -- v_test_msg := pad("Pulse extension failed. Expected: " & to_hstring(s_dout_golden) & " but got: " & to_hstring(s_dout), o_test_msg'length,'.');
            REPORT v_test_msg severity failure;
            o_test_msg <= v_test_msg;
            o_test_pass <= v_test_pass;
        end if;
        WAIT FOR clk_period;
        tb_end <= '1';
    end process validate;

end rtl;