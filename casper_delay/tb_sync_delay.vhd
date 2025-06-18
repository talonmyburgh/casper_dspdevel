-- A VHDL testbench for delaybram.vhd.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE, std, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE STD.TEXTIO.ALL;

entity tb_sync_delay is
    generic(
        g_delay : NATURAL := 6
    );
    port(
        o_clk       : out std_logic;
        o_tb_end    : out std_logic;
        o_test_msg  : out STRING(1 to 80);
        o_test_pass : out BOOLEAN
    );
end entity tb_sync_delay;

architecture rtl of tb_sync_delay is

    CONSTANT clk_period : TIME := 10 ns;

    SIGNAL clk    : std_logic := '0';
    SIGNAL ce     : std_logic := '0';
    SIGNAL tb_end : STD_LOGIC := '0';
    SIGNAL s_din  : std_logic := '0';
    SIGNAL s_dout : std_logic := '0';

begin
    clk <= NOT clk OR tb_end AFTER clk_period / 2;

    o_clk    <= clk;
    o_tb_end <= tb_end;

    ---------------------------------------------------------------------
    -- Delay SYNC module
    ---------------------------------------------------------------------
    DUT : entity work.sync_delay
        generic map(
            g_delay => g_delay
        )
        port map(
            clk   => clk,
            ce    => ce,
            delay => "0000",
            din  => s_din,
            dout => s_dout
        );
    ---------------------------------------------------------------------
    -- Stimulus process
    ---------------------------------------------------------------------
    p_stimuli_verify : PROCESS
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
        VARIABLE v_test_pass : BOOLEAN                        := True;
    BEGIN
        s_din <= '1';
        WAIT for clk_period * 2;
        s_din <= '0';
        ce          <= '1';
        -- Check zero stays zero
        WAIT for clk_period * (g_delay + 2);
        WAIT UNTIL rising_edge(clk);
        v_test_pass := s_dout = s_din;
        IF not v_test_pass THEN
            v_test_msg := pad("wrong RTL result for bram delay, expected: " & std_logic'image(s_din) & " but got: " & std_logic'image(s_dout), o_test_msg'length, '.');
            REPORT "ERROR: " & v_test_msg severity error;
        END IF;
        -- Check pulse is delayed correctly
        wait for clk_period;
        s_din       <= '1';
        WAIT for clk_period * (g_delay);
        WAIT UNTIL rising_edge(clk);
        v_test_pass := s_dout = s_din;
        IF not v_test_pass THEN
            v_test_msg := pad("wrong RTL result for async bram delay, expected: " & std_logic'image(s_din) & " but got: " & std_logic'image(s_dout), o_test_msg'length, '.');
            REPORT "ERROR: " & v_test_msg severity error;
        END IF;
        -- Check ones stay ones after delay
        wait for clk_period * 5;
        WAIT UNTIL rising_edge(clk);
        v_test_pass := s_dout = s_din;
        IF not v_test_pass THEN
            v_test_msg := pad("wrong RTL result for async bram delay, expected: " & std_logic'image(s_din) & " but got: " & std_logic'image(s_dout), o_test_msg'length, '.');
            REPORT "ERROR: " & v_test_msg severity error;
        END IF;
        o_test_msg  <= v_test_msg;
        o_test_pass <= v_test_pass;
        tb_end      <= '1';
        WAIT;
    END PROCESS;

end architecture;
