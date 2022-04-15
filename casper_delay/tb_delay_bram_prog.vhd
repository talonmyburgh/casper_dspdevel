-- A VHDL testbench for delay_bram_prog.vhd.
-- @author: Mydon Solutions.

LIBRARY IEEE, std, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE STD.TEXTIO.ALL;

entity tb_delay_bram_prog is
    generic (
        g_max_delay : NATURAL := 7;
        g_ram_latency : NATURAL := 4;
        g_vec_w : NATURAL := 8
    );
    port (
        o_clk   : out std_logic;
        o_tb_end : out std_logic;
        o_test_msg : out STRING(1 to 80);
        o_test_pass : out BOOLEAN  
    );
end entity tb_delay_bram_prog;

architecture rtl of tb_delay_bram_prog is

    CONSTANT clk_period : TIME    := 10 ns;
    CONSTANT c_delay_one : NATURAL := 6;
    CONSTANT c_delay_two : NATURAL := 4;

    SIGNAL clk : std_logic := '0';
    SIGNAL ce : std_logic;
    SIGNAL tb_end  : STD_LOGIC := '0';
    SIGNAL in_del_vec : std_logic_vector(g_vec_w -1 DOWNTO 0) := (others => '1');
    SIGNAL out_del_vec : std_logic_vector(g_vec_w -1 DOWNTO 0);
    SIGNAL delay : std_logic_vector(g_max_delay - 1 DOWNTO 0);

begin
    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

	o_clk <= clk;
	o_tb_end <= tb_end;

---------------------------------------------------------------------
-- Delay BRAM prog module
---------------------------------------------------------------------
delay_bram : ENTITY work.delay_bram_prog
generic map(
    g_max_delay => g_max_delay,
    g_ram_latency => g_ram_latency
    )
    port map(
        clk => clk,
        ce => ce,
        din => in_del_vec,
        delay => delay,
        dout => out_del_vec
    );

---------------------------------------------------------------------
-- Stimulus process
---------------------------------------------------------------------
p_stimuli_verify : PROCESS
    VARIABLE v_test_msg : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    VARIABLE v_test_pass : BOOLEAN := True;
BEGIN
    WAIT for clk_period*2;
    ce <= '0';
    -- Check delay delays by the correct duration
    WAIT for clk_period * g_ram_latency;
    WAIT UNTIL rising_edge(clk);
    WAIT for clk_period *4;
    delay <= TO_SVEC(c_delay_one, g_max_delay);
    ce <= '1';
    WAIT for clk_period * c_delay_one;
    WAIT UNTIL rising_edge(clk);
    v_test_pass := out_del_vec = in_del_vec;
    IF not v_test_pass THEN
        v_test_msg := pad("wrong RTL result for dout, expected: " & to_hstring(in_del_vec) & " but got: " & to_hstring(out_del_vec), o_test_msg'length, '.' );
        REPORT "ERROR: " & v_test_msg severity error;
    END IF;
    delay <= TO_SVEC(c_delay_two,g_max_delay);
    WAIT for clk_period;
    in_del_vec <= (others => '0');
    WAIT for clk_period * c_delay_two;
    WAIT UNTIL rising_edge(clk);
    v_test_pass := out_del_vec = in_del_vec;
    IF not v_test_pass THEN
        v_test_msg := pad("wrong RTL result for dout, expected: " & to_hstring(in_del_vec) & " but got: " & to_hstring(out_del_vec), o_test_msg'length, '.' );
        REPORT "ERROR: " & v_test_msg severity error;
    END IF;
    o_test_msg <= v_test_msg;
    o_test_pass <= v_test_pass;
    tb_end <= '1';
    WAIT;
END PROCESS;

end architecture;