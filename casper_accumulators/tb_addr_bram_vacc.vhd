-- A VHDL testbench for addr_bram_vacc.vhd.
-- @author: Mydon Solutions.

LIBRARY IEEE, std, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE STD.TEXTIO.ALL;

entity tb_addr_bram_vacc is
    generic (
        g_vector_length : NATURAL := 8;
        g_bit_w_out     : NATURAL := 8;
        g_bit_w         : NATURAL := 8;
        g_values        : t_integer_arr := (-1, 4, 10, -2, 3, 0, -15, 0)
    );
    port (
        o_clk   : out std_logic;
        o_tb_end : out std_logic;
        o_test_msg : out STRING(1 to 80);
        o_test_pass : out BOOLEAN := True 
    );
end entity tb_addr_bram_vacc;

architecture rtl of tb_addr_bram_vacc is

    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk : STD_LOGIC := '0';
    SIGNAL ce : STD_LOGIC;
    SIGNAL tb_end  : STD_LOGIC := '0';
    SIGNAL new_acc : STD_LOGIC := '0';
    SIGNAL din : std_logic_vector(g_bit_w - 1 DOWNTO 0) := (others=>'0');
    SIGNAL addr : std_logic_vector(ceil_log2(g_vector_length) - 1 DOWNTO 0);
    SIGNAL we : STD_LOGIC;
    SIGNAL dout : std_logic_vector(g_bit_w_out - 1 DOWNTO 0);
    SIGNAL test_spike : STD_LOGIC:='0';

begin
    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

	o_clk <= clk;
	o_tb_end <= tb_end;

    ---------------------------------------------------------------------
    -- Stimulus process
    ---------------------------------------------------------------------
    p_stimuli_verify : PROCESS
        VARIABLE v_test_msg : STRING(1 to o_test_msg'length) := (OTHERS => '.');
        VARIABLE v_test_vector : STD_LOGIC_VECTOR(g_bit_w -1 DOWNTO 0);
        VARIABLE v_test_pass : BOOLEAN := True;
    BEGIN
        WAIT UNTIL rising_edge(clk);
        ce <= '1';
        new_acc <= '1';
        WAIT FOR clk_period*(g_vector_length+2);
        FOR I in 0 to g_vector_length - 1 LOOP
            WAIT FOR clk_period;
            v_test_vector := TO_SVEC(g_values(g_values'LOW + I), g_bit_w);
            v_test_pass := v_test_pass or (dout = v_test_vector);
            IF NOT v_test_pass THEN
                v_test_msg := pad("1wrong RTL result for dout, expected: " & to_hstring(v_test_vector) & " but got: " & to_hstring(dout), o_test_msg'length, '.');
                o_test_msg <= v_test_msg;
                report "Error: " & v_test_msg severity error;
            END IF;
        END LOOP;
        WAIT FOR clk_period*(g_vector_length)*5;
        FOR I in 0 to g_vector_length - 1 LOOP
            WAIT FOR clk_period;
            v_test_vector := TO_SVEC(g_values(g_values'LOW + I)*7, g_bit_w);
            v_test_pass := v_test_pass or (dout = v_test_vector);
            IF NOT v_test_pass THEN
                v_test_msg := pad("2wrong RTL result for dout, expected: " & to_hstring(v_test_vector) & " but got: " & to_hstring(dout), o_test_msg'length, '.');
                o_test_msg <= v_test_msg;
                report "Error: " & v_test_msg severity error;
            END IF;
        END LOOP;
        new_acc <= '0';
        WAIT FOR clk_period*(g_vector_length - 1);
        -- reload the vector
        new_acc <= '1';
        WAIT FOR clk_period*(g_vector_length+1);
        WAIT UNTIL rising_edge(clk);
        v_test_vector := TO_SVEC(g_values(g_values'LOW), g_bit_w);
        v_test_pass := v_test_pass or (dout = v_test_vector);
        IF NOT v_test_pass THEN
            v_test_msg := pad("3wrong RTL result for dout, expected: " & to_hstring(v_test_vector) & " but got: " & to_hstring(dout), o_test_msg'length, '.');
            o_test_msg <= v_test_msg;
            report "Error: " & v_test_msg severity error;
        END IF;
        o_test_msg <= v_test_msg;
        o_test_pass <= v_test_pass;
        tb_end <= '1';
    WAIT;
    
    END PROCESS;

    -- Process to unroll values into din
    p_unroll_nat_array : PROCESS(clk, ce)
        VARIABLE I : INTEGER := 0;
    BEGIN
        IF rising_edge(clk) and ce = '1' THEN
            din <= TO_SVEC(g_values(g_values'LOW + I), g_bit_w);
            IF I = g_vector_length -1 THEN
                I := 0;
            ELSE
                I := I + 1;
            END IF;
        END IF;
    END PROCESS;
    ---------------------------------------------------------------------
    -- addr BRAM vacc module
    ---------------------------------------------------------------------
    addr_bram_vacc : ENTITY work.addr_bram_vacc
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

end architecture;