-- A VHDL implementation of the CASPER concat block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

entity concat is
    generic(
        g_num_inputs : NATURAL := 2;
        g_async : BOOLEAN := TRUE
    );
    port (
        clk : IN std_logic;
        ce :  IN std_logic;
        in_val1 : IN std_logic_vector;
        in_val2 : IN std_logic_vector;
        out_val : OUT std_logic_vector
    );
end concat;

architecture rtl of concat is

    signal s_in_val1 : STD_LOGIC_VECTOR(in_val1'RANGE);
    signal s_in_val2 : STD_LOGIC_VECTOR(in_val2'RANGE);
    signal s_out_val : STD_LOGIC_VECTOR(in_val1'LENGTH + in_val2'LENGTH - 1 DOWNTO 0);

begin

gen_async : IF g_async GENERATE
    s_out_val <= in_val1 & in_val2;
end GENERATE;

gen_sync : IF not g_async GENERATE 
    sync_cat : process(clk,ce)
    BEGIN
     s_in_val1 <= in_val1;
     s_in_val2 <= in_val2;
     if rising_edge(clk) and ce='1' then
       s_out_val <= s_in_val1 & s_in_val2;
      end if;
    END PROCESS;
end GENERATE;

out_val <= s_out_val;
end architecture;