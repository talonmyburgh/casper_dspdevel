-- A VHDL testbench for the CASPER stopwatch block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
LIBRARY IEEE, STD, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE STD.TEXTIO.ALL;

ENTITY tb_stopwatch is
    GENERIC(
        g_num_clocks : NATURAL := 8
    );
    PORT(
        o_rst       : OUT STD_LOGIC;
        o_clk       : OUT STD_LOGIC;
        o_tb_end    : OUT STD_LOGIC;
        o_test_msg  : OUT STRING(1 to 80);
        o_test_pass : OUT BOOLEAN := True
    );
END tb_stopwatch;

ARCHITECTURE rtl of tb_stopwatch is

    CONSTANT clk_period : TIME := 10 ns;

    SIGNAL clk    : STD_LOGIC := '0';
    SIGNAL ce     : STD_LOGIC := '0';
    SIGNAL tb_end : STD_LOGIC := '0';

    SIGNAL s_stop         : STD_LOGIC := '1';
    SIGNAL s_start        : STD_LOGIC := '0';
    SIGNAL s_reset        : STD_LOGIC := '1';
    SIGNAL s_count        : STD_LOGIC_VECTOR(32 - 1 DOWNTO 0);
    SIGNAL s_count_golden : STD_LOGIC_VECTOR(32 - 1 DOWNTO 0):=(others => '0');
begin

    clk      <= NOT clk OR tb_end AFTER clk_period / 2;
    o_rst    <= NOT ce;
    o_clk    <= clk;
    o_tb_end <= tb_end;

    -------------------DUT instantiation-------------------
    stopwatch_inst : entity work.stopwatch
        port map(
            clk   => clk,
            ce    => ce,
            stop  => s_stop,
            start => s_start,
            reset => s_reset,
            count => s_count
        );

    -------------------Golden model-------------------
    s_count_golden <= TO_UVEC(g_num_clocks-1, 32);
    validate : process is
        VARIABLE v_test_pass : BOOLEAN                        := TRUE;
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    begin
        ce             <= '1';
        WAIT FOR clk_period;
        s_stop         <= '0';
        s_start        <= '1';
        s_reset        <= '0';
        WAIT FOR clk_period * g_num_clocks;
        s_stop         <= '1';
        s_start        <= '0';
        WAIT UNTIL rising_edge(clk);
        v_test_pass    := s_count = s_count_golden;
        if not v_test_pass then
            v_test_msg  := pad("Stopwatch failed. Expected: " & to_hstring(s_count_golden) & " but got: " & to_hstring(s_count), o_test_msg'length, '.');
            REPORT v_test_msg severity failure;
            o_test_msg  <= v_test_msg;
            o_test_pass <= v_test_pass;
        end if;
        WAIT FOR 5 * clk_period;
        v_test_pass    := s_count = s_count_golden;
        if not v_test_pass then
            v_test_msg  := pad("Stopwatch failed. Expected: " & to_hstring(s_count_golden) & " but got: " & to_hstring(s_count), o_test_msg'length, '.');
            REPORT v_test_msg severity failure;
            o_test_msg  <= v_test_msg;
            o_test_pass <= v_test_pass;
        end if;
        tb_end         <= '1';
    end process validate;

end rtl;
