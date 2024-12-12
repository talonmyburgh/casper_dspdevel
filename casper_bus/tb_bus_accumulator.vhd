-- A VHDL implementation of the CASPER bus_accumulator block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, casper_delay_lib;
USE IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;
USE common_pkg_lib.common_pkg.all;

ENTITY tb_bus_accumulator is
  generic (
    g_bus_constituent_widths : t_nat_natural_arr := (6, 4, 8);
    g_bus_constituent_expansion_widths : t_nat_natural_arr := (8, 8, 8);
    g_accumulations_to_test : natural := 10
  );
  port (
    o_clk   : out std_logic;
    o_tb_end : out std_logic;
    o_test_msg : out STRING(1 to 80);
    o_test_pass : out BOOLEAN  
  );
end ENTITY;

architecture tb of tb_bus_accumulator is 
    CONSTANT clk_period : TIME    := 10 ns;
  
    SIGNAL clk : std_logic := '1';
    SIGNAL ce : std_logic := '1';
    SIGNAL tb_end  : STD_LOGIC := '0';

    CONSTANT c_nof_elements : natural := g_bus_constituent_widths'length;
    signal s_rst : std_logic_vector(c_nof_elements-1 downto 0);
    signal s_en : std_logic_vector(c_nof_elements-1 downto 0);

    signal s_din : std_logic_vector(func_sum(g_bus_constituent_widths)-1 downto 0);
    signal s_dout : std_logic_vector(func_sum(g_bus_constituent_expansion_widths)-1 downto 0);

    
    alias a_g_bus_constituent_widths : t_nat_natural_arr (0 to g_bus_constituent_widths'length-1) is g_bus_constituent_widths;
    alias a_g_bus_constituent_expansion_widths : t_nat_natural_arr (0 to g_bus_constituent_expansion_widths'length-1) is g_bus_constituent_expansion_widths;
BEGIN

    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

    o_clk <= clk;
    o_tb_end <= tb_end;

    u_dut : ENTITY work.bus_accumulator
    generic map (
        g_bus_constituent_widths => g_bus_constituent_widths,
        g_bus_constituent_expansion_widths => g_bus_constituent_expansion_widths
    )
    port map(
        clk => clk,
        ce => ce,

        rst => s_rst,
        en => s_en,

        -- misci => 
        -- misco => 

        din => s_din,
        dout => s_dout
    );

    p_stim: process
        variable v_din_index, v_dout_index: integer;
        VARIABLE v_test_pass : BOOLEAN := TRUE;
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    begin
        -- assign bus elements with values equal to index
        v_din_index := s_din'length;
        for I in a_g_bus_constituent_widths'range loop
            s_din(
                v_din_index-1 downto v_din_index-a_g_bus_constituent_widths(I)
            ) <= std_logic_vector(to_unsigned(I, a_g_bus_constituent_widths(I)));

            v_din_index := v_din_index - a_g_bus_constituent_widths(I); -- din'descending
        end loop;
        
        s_rst <= (others => '1');
        s_en <= (others => '0');

        wait until rising_edge(clk);
        
        for r in 1 to 3 loop
            -- test reset
            s_en <= (others => '1');
            s_rst <= (others => '1');
            wait for 3*clk_period;
            
            -- test accumulation
            s_rst <= (others => '0');
            wait for 1*clk_period;

            for t in 1 to g_accumulations_to_test loop
                wait for 1*clk_period;

                -- test each dout element
                v_dout_index := s_dout'length;
                for I in a_g_bus_constituent_expansion_widths'range loop
                    if t*I /= unsigned(s_dout(
                        v_dout_index-1 downto v_dout_index-a_g_bus_constituent_expansion_widths(I)
                    )) then
                        v_test_msg := pad("Accumulation #"& integer'image(t) &" failed at index "& integer'image(I) &". Expected: " & integer'image(I*t) &" but got: " & integer'image(to_integer(unsigned(s_dout(
                            v_dout_index-1 downto v_dout_index-a_g_bus_constituent_expansion_widths(I)
                        )))), o_test_msg'length, '.');
                        v_test_pass := FALSE;
                        REPORT v_test_msg severity failure;
                    end if;
                    o_test_msg <= v_test_msg;
                    o_test_pass <= v_test_pass;

                    v_dout_index := v_dout_index - a_g_bus_constituent_expansion_widths(I); -- dout'descending
                end loop;
            end loop;
        end loop;

        tb_end <= '1';
        wait;
    end process;
    

end architecture;