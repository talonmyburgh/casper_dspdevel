-- A VHDL testbench for the CASPER window_delay block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
LIBRARY IEEE, STD, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE STD.TEXTIO.ALL;

ENTITY tb_window_delay is
    GENERIC(
        g_delay : NATURAL := 4
    );
    PORT(
        o_rst       : OUT STD_LOGIC;
        o_clk       : OUT STD_LOGIC;
        o_tb_end    : OUT STD_LOGIC;
        o_test_msg  : OUT STRING(1 to 80);
        o_test_pass : OUT BOOLEAN := True
    );
END tb_window_delay;

ARCHITECTURE rtl of tb_window_delay is

    CONSTANT clk_period : TIME := 10 ns;

    SIGNAL clk    : STD_LOGIC := '0';
    SIGNAL ce     : STD_LOGIC := '0';
    SIGNAL tb_end : STD_LOGIC := '0';

    SIGNAL s_din  : STD_LOGIC := '1';
    SIGNAL s_dout : STD_LOGIC := '0';
begin

    clk      <= NOT clk OR tb_end AFTER clk_period / 2;
    o_rst    <= NOT ce;
    o_clk    <= clk;
    o_tb_end <= tb_end;

    -------------------DUT instantiation-------------------
    window_delay_inst : entity work.window_delay
        generic map(
            g_delay => g_delay
        )
        port map(
            clk  => clk,
            ce   => ce,
            din  => s_din,
            dout => s_dout
        );

    -------------------Golden model-------------------
    validate : process is
        VARIABLE v_test_pass : BOOLEAN                        := TRUE;
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    begin
        ce <= '1';

        WAIT FOR clk_period * (g_delay);
        WAIT UNTIL rising_edge(clk);
        v_test_pass := s_dout = s_din;
        if not v_test_pass then
            v_test_msg  := pad("window_delay failed.", o_test_msg'length, '.');
            REPORT v_test_msg severity failure;
            o_test_msg  <= v_test_msg;
            o_test_pass <= v_test_pass;
        end if;
        tb_end      <= '1';
    end process validate;
end rtl;
