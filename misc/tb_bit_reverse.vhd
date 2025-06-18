LIBRARY IEEE, STD, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE STD.TEXTIO.ALL;

ENTITY tb_bit_reverse is
    GENERIC(
        g_num_bits  : NATURAL := 8;
        g_async     : BOOLEAN := FALSE;
        g_in_val    : INTEGER := 170
    );
    PORT(
		o_rst		   : OUT STD_LOGIC;
		o_clk		   : OUT STD_LOGIC;
		o_tb_end	   : OUT STD_LOGIC;
		o_test_msg	   : OUT STRING(1 to 80);
		o_test_pass	   : OUT BOOLEAN := True
	);
END tb_bit_reverse;

ARCHITECTURE rtl of tb_bit_reverse is

    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk          : STD_LOGIC := '0';
    SIGNAL ce           : STD_LOGIC := '0';
    SIGNAL tb_end       : STD_LOGIC := '0';
    SIGNAL s_in_val     : STD_LOGIC_VECTOR(g_num_bits - 1 DOWNTO 0);
    SIGNAL s_out_val    : STD_LOGIC_VECTOR(g_num_bits - 1 DOWNTO 0);
    SIGNAL s_rev_vector : STD_LOGIC_VECTOR(g_num_bits - 1 DOWNTO 0);

begin
    
    clk         <= NOT clk OR tb_end AFTER clk_period / 2;
    o_rst       <= NOT ce;
    o_clk       <= clk;
    o_tb_end    <= tb_end;

    s_rev_vector <= func_slv_reverse(s_in_val);

    p_stimuli : PROCESS
        VARIABLE v_test_msg : STRING(1 to o_test_msg'length) := (OTHERS => '.');
        VARIABLE v_test_pass : BOOLEAN;
    BEGIN
        WAIT UNTIL falling_edge(clk);
        s_in_val <= STD_LOGIC_VECTOR(to_signed(g_in_val, g_num_bits));
        ce <= '1';
        if NOT g_async THEN
            WAIT for clk_period;
            WAIT UNTIL rising_edge(clk);
        end if;
        v_test_pass := s_out_val = s_rev_vector;
        IF NOT v_test_pass THEN
           v_test_msg := pad("wrong RTL result for re_out, expected: " & to_hstring(s_rev_vector) & " but got: " & to_hstring(s_out_val), o_test_msg'length, '.');
           o_test_msg <= v_test_msg;
           report "Error: " & v_test_msg severity error;
        END IF; 
        o_test_pass <= v_test_pass;
        WAIT for clk_period;
        tb_end <= '1';
        WAIT;
    END PROCESS;

    -- DUT
    u_dut : ENTITY work.bit_reverse
    GENERIC MAP(
        g_async => g_async
    )
    PORT MAP(
        clk => clk,
        ce => ce,
        in_val => s_in_val,
        out_val => s_out_val
    );
end rtl;