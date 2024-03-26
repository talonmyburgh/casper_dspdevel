-- A VHDL testbench for the simple delay block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE STD.TEXTIO.ALL;

entity tb_delay_simple is
    generic (
        g_delay : NATURAL := 3;
        g_vec_w : NATURAL := 4
    );
    port (
        o_clk   : out std_logic;
        o_tb_end : out std_logic;
        o_test_msg : out STRING(1 to 80);
        o_test_pass : out BOOLEAN  
    );
end tb_delay_simple;

architecture rtl of tb_delay_simple is
    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk : std_logic := '0';
    SIGNAL ce : std_logic;
    SIGNAL tb_end  : STD_LOGIC := '0';

    SIGNAL s_in, s_out, s_exp : std_logic_vector(g_vec_w-1 downto 0);
begin
    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

    o_clk <= clk;
    o_tb_end <= tb_end;
    
    u_delay_simple : ENTITY work.delay_simple
        generic map (
            g_delay => g_delay
        )
        port map (
            clk => clk,
            ce => ce,
            i_data => s_in,
            o_data => s_out
        );

    p_stimuli : PROCESS
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
        VARIABLE v_test_pass : BOOLEAN := TRUE;
    BEGIN
        WAIT FOR clk_period;
        WAIT UNTIL falling_edge(clk);
        ce          <= '1';
        WAIT FOR clk_period;
        WAIT UNTIL rising_edge(clk);

        FOR value IN 0 to 5 LOOP
            s_in  <= TO_SVEC(value, s_in'LENGTH);
            WAIT FOR g_delay*clk_period;
            s_exp <= TO_SVEC(value, s_in'LENGTH);
            WAIT FOR clk_period;
        END LOOP;

        WAIT for clk_period * 2;
        tb_end      <= '1';
        WAIT;
    END PROCESS;
        
    p_verify : PROCESS(clk)
        VARIABLE v_test_pass : BOOLEAN := TRUE;
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    BEGIN
        v_test_pass := s_out = s_exp;
        if not v_test_pass then
            v_test_msg := pad("Delay failed. Expected: " & to_hstring(s_exp) & " but got: " & to_hstring(s_out), o_test_msg'length, '.');
            REPORT v_test_msg severity failure;
        end if;
        o_test_msg <= v_test_msg;
        o_test_pass <= v_test_pass;
    END PROCESS;

end architecture;