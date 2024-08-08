-- A VHDL testbench for the simple delay block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, common_slv_arr_pkg_lib, casper_delay_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;
USE STD.TEXTIO.ALL;

entity tb_bus_mux is
    generic (
        g_delay : NATURAL := 3;
        g_nof_inputs : NATURAL := 4;
        g_bit_width : NATURAL := 4
    );
    port (
        o_clk   : out std_logic;
        o_tb_end : out std_logic;
        o_test_msg : out STRING(1 to 80);
        o_test_pass : out BOOLEAN  
    );
end tb_bus_mux;

architecture rtl of tb_bus_mux is
    CONSTANT clk_period : TIME    := 10 ns;

    SIGNAL clk : std_logic := '0';
    SIGNAL ce : std_logic;
    SIGNAL tb_end  : STD_LOGIC := '0';

    SIGNAL s_sel   : std_logic_vector(ceil_log2(g_nof_inputs)-1 downto 0);
    SIGNAL s_idata  : t_slv_arr(
        0 to g_nof_inputs-1,
        g_bit_width-1 downto 0
    ) := (OTHERS => (OTHERS => 'Z'));
    SIGNAL s_odata, s_exp, s_exp_delayed : std_logic_vector(g_bit_width-1 downto 0);
begin
    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

    o_clk <= clk;
    o_tb_end <= tb_end;
    
    u_bus_mux : entity work.bus_mux
        generic map (
          g_delay => g_delay
        )
        port map (
          clk => clk,
          ce => ce,
          i_sel => s_sel,
          i_data => s_idata,
          o_data => s_odata
        );
    
    u_delay_exp : entity casper_delay_lib.delay_simple
        generic map (
          g_delay => g_delay
        )
        port map (
          clk => clk,
          ce => ce,
          i_data => s_exp,
          o_data => s_exp_delayed
        );

    p_stimuli : PROCESS
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
        VARIABLE v_test_pass : BOOLEAN := TRUE;
        VARIABLE v_count: UNSIGNED(g_bit_width-1 downto 0) := to_unsigned(0, g_bit_width);
        VARIABLE v_value : STD_LOGIC_VECTOR(g_bit_width-1 downto 0);
    BEGIN
        -- set inputs
        -- index 0 will be time-variant, `v_count`
        FOR channel IN s_idata'range(1) LOOP
            v_value := STD_LOGIC_VECTOR(TO_UNSIGNED(
                channel,
                g_bit_width
            ));
            slv_arr_set_variable(
                s_idata,
                channel,
                v_value
            );
        END LOOP;
        s_exp <= (OTHERS => '0');

        WAIT FOR clk_period;
        WAIT UNTIL falling_edge(clk);
        ce          <= '1';
        WAIT FOR clk_period;
        WAIT UNTIL rising_edge(clk);

        FOR i IN 0 to (2*g_nof_inputs) - 1 LOOP
            -- change s_sel and update s_exp
            s_sel  <= TO_SVEC(i mod g_nof_inputs, s_sel'LENGTH);
            IF i mod g_nof_inputs = 0 THEN
                s_exp <= STD_LOGIC_VECTOR(v_count);
            ELSE
                s_exp <= STD_LOGIC_VECTOR(TO_UNSIGNED(i mod g_nof_inputs, s_exp'LENGTH));
            END IF;
            
            FOR r IN 0 to 2 LOOP
                slv_arr_set_variable(
                    s_idata,
                    0,
                    STD_LOGIC_VECTOR(v_count)
                );
                -- s
                WAIT FOR clk_period;
                
                v_count := v_count + 1;
                IF i mod g_nof_inputs = 0 THEN
                    s_exp <= STD_LOGIC_VECTOR(v_count);
                END IF;
            END LOOP;
        END LOOP;

        WAIT for clk_period * 2;
        tb_end      <= '1';
        WAIT;
    END PROCESS;
        
    p_verify : PROCESS(clk)
        VARIABLE v_test_pass : BOOLEAN := TRUE;
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    BEGIN

        v_test_pass := s_odata = s_exp_delayed;
        if not v_test_pass then
            v_test_msg := pad("Mux failed. Expected: " & to_hstring(s_exp_delayed) & " but got: " & to_hstring(s_odata), o_test_msg'length, '.');
            REPORT v_test_msg severity failure;
        end if;
        o_test_msg <= v_test_msg;
        o_test_pass <= v_test_pass;
    END PROCESS;

end architecture;