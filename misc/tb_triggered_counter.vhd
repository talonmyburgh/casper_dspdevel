-- A VHDL testbench for the CASPER triggered counter block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
LIBRARY IEEE, STD, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE STD.TEXTIO.ALL;

ENTITY tb_triggered_counter is
    GENERIC(
        g_run_length : NATURAL := 8
    );
    PORT(
        o_rst       : OUT STD_LOGIC;
        o_clk       : OUT STD_LOGIC;
        o_tb_end    : OUT STD_LOGIC;
        o_test_msg  : OUT STRING(1 to 80);
        o_test_pass : OUT BOOLEAN := True
    );
END tb_triggered_counter;

ARCHITECTURE rtl of tb_triggered_counter is

    CONSTANT clk_period       : TIME    := 10 ns;
    CONSTANT c_cnt_bit_widths : NATURAL := next_pow2(g_run_length) + 1;

    SIGNAL clk    : STD_LOGIC := '0';
    SIGNAL ce     : STD_LOGIC := '1';
    SIGNAL tb_end : STD_LOGIC := '0';

    SIGNAL s_trigger     : STD_LOGIC                                       := '0';
    SIGNAL s_valid       : STD_LOGIC                                       := '0';
    SIGNAL s_count       : std_logic_vector(c_cnt_bit_widths - 2 DOWNTO 0) := (others => '0');
    SIGNAL s_dout_golden : STD_LOGIC_VECTOR(c_cnt_bit_widths - 2 DOWNTO 0) := (others => '0');
begin

    clk      <= NOT clk OR tb_end AFTER clk_period / 2;
    o_rst    <= NOT ce;
    o_clk    <= clk;
    o_tb_end <= tb_end;

    -------------------DUT instantiation-------------------
    triggered_cntr_inst : entity work.triggered_cntr
        generic map(
            g_run_length => g_run_length
        )
        port map(
            clk   => clk,
            ce    => ce,
            trig  => s_trigger,
            count => s_count,
            valid => s_valid
        );

    -------------------Golden model-------------------
    validate : process is
        VARIABLE v_test_pass : BOOLEAN                        := TRUE;
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    begin
        WAIT FOR clk_period;
        ce          <= '1';
        s_trigger   <= '1';
        WAIT UNTIL falling_edge(s_valid);
        v_test_pass := s_count = s_dout_golden;
        if not v_test_pass then
            v_test_msg  := pad("Triggered counter failed. Expected: " & to_hstring(s_dout_golden) & " but got: " & to_hstring(s_count), o_test_msg'length, '.');
            REPORT v_test_msg severity failure;
            o_test_msg  <= v_test_msg;
            o_test_pass <= v_test_pass;
        end if;
        tb_end      <= '1';
    end process validate;

end rtl;
