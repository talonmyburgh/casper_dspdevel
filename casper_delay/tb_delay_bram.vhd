-- A VHDL testbench for delaybram.vhd.
-- @author: Mydon Solutions.

LIBRARY IEEE, std, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE STD.TEXTIO.ALL;

entity tb_delay_bram is
    generic (
        g_delay : NATURAL := 6;
        g_latency : NATURAL := 2;
        g_vec_w : NATURAL := 8
    );
    port (
        o_clk   : out std_logic;
        o_tb_end : out std_logic;
        o_test_msg : out STRING(1 to 80);
        o_test_pass : out BOOLEAN  
    );
end entity tb_delay_bram;

architecture rtl of tb_delay_bram is

    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk : std_logic := '0';
    SIGNAL ce : std_logic;
    SIGNAL en : std_logic;
    SIGNAL tb_end  : STD_LOGIC := '0';
    SIGNAL in_del_vec : std_logic_vector(g_vec_w -1 DOWNTO 0) := (others => '1');
    SIGNAL zeros : std_logic_vector(g_vec_w -1 DOWNTO 0) := (others => '0');
    SIGNAL out_del_vec : std_logic_vector(g_vec_w -1 DOWNTO 0);
    SIGNAL out_del_vec_async : std_logic_vector(g_vec_w -1 DOWNTO 0);

begin
    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

	o_clk <= clk;
	o_tb_end <= tb_end;

---------------------------------------------------------------------
-- Delay BRAM module
---------------------------------------------------------------------
delay_bram : ENTITY work.delay_bram
generic map(
    g_delay => g_delay
    )
    port map(
        clk => clk,
        ce => ce,
        din => in_del_vec,
        dout => out_del_vec
        );

---------------------------------------------------------------------
-- Delay BRAM async module
---------------------------------------------------------------------
    async_delay_bram : ENTITY work.delay_bram_async
    generic map(
        g_delay => g_delay
    )
    port map(
        clk => clk,
        ce => ce,
        en => en,
        din => in_del_vec,
        dout => out_del_vec_async
    );

---------------------------------------------------------------------
-- Stimulus process
---------------------------------------------------------------------
p_stimuli_verify : PROCESS
    VARIABLE v_test_msg : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    VARIABLE v_test_pass : BOOLEAN := True;
BEGIN
    WAIT for clk_period*2;
    ce <= '1';
    en <= '1';
    -- Check delay delays by the correct duration
    WAIT for clk_period * g_delay;
    WAIT UNTIL rising_edge(clk);
    v_test_pass := out_del_vec = in_del_vec;
    IF not v_test_pass THEN
        v_test_msg := pad("wrong RTL result for bram delay, expected: " & to_hstring(in_del_vec) & " but got: " & to_hstring(out_del_vec), o_test_msg'length, '.' );
        REPORT "ERROR: " & v_test_msg severity error;
    END IF;
    -- Check async delay delays by the correct duration
    v_test_pass := out_del_vec_async = in_del_vec;
    IF not v_test_pass THEN
        v_test_msg := pad("wrong RTL result for async bram delay, expected: " & to_hstring(in_del_vec) & " but got: " & to_hstring(out_del_vec_async), o_test_msg'length, '.' );
        REPORT "ERROR: " & v_test_msg severity error;
    END IF;
    -- Check asynchronous behaviour of async delay block resetting within on clk_period
    en <= '0';
    WAIT for clk_period;
    WAIT UNTIL rising_edge(clk);
    v_test_pass := out_del_vec_async = zeros;
    IF not v_test_pass THEN
        v_test_msg := pad("wrong RTL result for async bram delay, expected: " & to_hstring(zeros) & " but got: " & to_hstring(out_del_vec_async), o_test_msg'length, '.' );
        REPORT "ERROR: " & v_test_msg severity error;
    END IF;
    in_del_vec <= (others=>'0');
    o_test_msg <= v_test_msg;
    o_test_pass <= v_test_pass;
    tb_end <= '1';
    WAIT;
END PROCESS;

end architecture;