-- A VHDL testbench for the CASPER freeze_cntr block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
LIBRARY IEEE, STD, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE STD.TEXTIO.ALL;

ENTITY tb_freeze_cntr is
    GENERIC(
        g_num_cntr_bits : NATURAL := 5
    );
    PORT(
        o_rst       : OUT STD_LOGIC;
        o_clk       : OUT STD_LOGIC;
        o_tb_end    : OUT STD_LOGIC;
        o_test_msg  : OUT STRING(1 to 80);
        o_test_pass : OUT BOOLEAN := True
    );
END tb_freeze_cntr;

ARCHITECTURE rtl of tb_freeze_cntr is

    CONSTANT clk_period : TIME := 10 ns;

    SIGNAL clk    : STD_LOGIC := '0';
    SIGNAL ce     : STD_LOGIC := '0';
    SIGNAL tb_end : STD_LOGIC := '0';

    SIGNAL s_en          : STD_LOGIC := '1';
    SIGNAL s_we          : STD_LOGIC := '0';
    SIGNAL s_done        : STD_LOGIC := '0';
    SIGNAL s_rst         : STD_LOGIC := '0';
    SIGNAL s_addr        : STD_LOGIC_VECTOR(g_num_cntr_bits - 1 DOWNTO 0);
    SIGNAL s_dout_golden : STD_LOGIC_VECTOR(g_num_cntr_bits - 1 DOWNTO 0);
begin

    clk      <= NOT clk OR tb_end AFTER clk_period / 2;
    o_rst    <= NOT ce;
    o_clk    <= clk;
    o_tb_end <= tb_end;

    -------------------DUT instantiation-------------------
    freeze_cntr_inst : entity work.freeze_cntr
        generic map(
            g_num_cntr_bits => g_num_cntr_bits
        )
        port map(
            clk  => clk,
            ce   => ce,
            en   => s_en,
            rst  => s_rst,
            addr => s_addr,
            we   => s_we,
            done => s_done
        );

    -------------------Load vector with value-------------------
    s_dout_golden <= TO_UVEC(2 ** g_num_cntr_bits - 1, g_num_cntr_bits);

    -------------------Golden model-------------------
    validate : process is
        VARIABLE v_test_pass : BOOLEAN                        := TRUE;
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    begin
        WAIT FOR clk_period;
        ce          <= '1';
        s_en        <= '1';
        s_rst       <= '0';
        WAIT UNTIL rising_edge(s_done);
        WAIT UNTIL rising_edge(clk);
        v_test_pass := s_addr = s_dout_golden;
        if not v_test_pass then
            v_test_msg  := pad("Freeze counter failed. Expected: " & to_hstring(s_dout_golden) & " but got: " & to_hstring(s_addr), o_test_msg'length, '.');
            REPORT v_test_msg severity failure;
            o_test_msg  <= v_test_msg;
            o_test_pass <= v_test_pass;
        end if;
        tb_end      <= '1';
    end process validate;

end rtl;
