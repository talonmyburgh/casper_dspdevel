-- A VHDL testbench for delaybram.vhd.
-- @author: Mydon Solutions.

LIBRARY IEEE, std, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE STD.TEXTIO.ALL;

entity tb_addr_bram_vacc is
    generic (
        g_vector_length : NATURAL := 10;
        g_bit_w_out     : NATURAL := 10;
        g_bit_w         : NATURAL := 8
    );
    port (
        o_clk   : out std_logic;
        o_tb_end : out std_logic;
        o_test_msg : out STRING(1 to 80);
        o_test_pass : out BOOLEAN  
    );
end entity tb_addr_bram_vacc;

architecture rtl of tb_addr_bram_vacc is

    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk : std_logic := '0';
    SIGNAL ce : std_logic;
    SIGNAL tb_end  : STD_LOGIC := '0';
    SIGNAL new_acc : std_logic;
    SIGNAL din : std_logic_vector(g_bit_w - 1 DOWNTO 0);
    SIGNAL addr : std_logic_vector(ceil_log2(g_vector_length) - 1 DOWNTO 0);
    SIGNAL we : std_logic;
    SIGNAL dout : std_logic_vector(g_bit_w_out - 1 DOWNTO 0);
    

begin
    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

	o_clk <= clk;
	o_tb_end <= tb_end;

---------------------------------------------------------------------
-- addr BRAM vacc module
---------------------------------------------------------------------
delay_bram : ENTITY work.addr_bram_vacc
generic map(
        g_vector_length => g_vector_length,
        g_bit_w         => g_bit_w_out
    )
    port map(
        clk => clk,
        ce => ce,
        new_acc => new_acc,
        din => din,
        addr => addr,
        we => we,
        dout => dout
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
    -- Check delay delays by the correct duration
    new_acc <= '1';
    din <= (others => '1');
    WAIT FOR clk_period *40;
    WAIT;
    
    
END PROCESS;

end architecture;