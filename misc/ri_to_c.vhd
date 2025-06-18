-- A VHDL implementation of the CASPER ri_to_c block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

entity ri_to_c is
    generic(
        g_async : BOOLEAN := FALSE
    );
    port (
        clk : IN std_logic;
        ce :  IN std_logic;
        re_in : IN std_logic_vector;
        im_in : IN std_logic_vector;
        c_out : OUT std_logic_vector
    );
end ri_to_c;

architecture rtl of ri_to_c is

    signal s_c_out : STD_LOGIC_VECTOR(re_in'LENGTH + im_in'LENGTH - 1 DOWNTO 0);

begin

--------------------------------------------------------
-- Concatenation
--------------------------------------------------------
concat : ENTITY work.concat
GENERIC MAP(
    g_num_inputs => 2,
    g_async => g_async
)
PORT MAP(
    clk => clk,
    ce => ce,
    in_val1 => re_in,
    in_val2 => im_in,
    out_val => s_c_out
);

c_out <= s_c_out;
end architecture;