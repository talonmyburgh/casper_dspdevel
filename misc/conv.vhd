-- A VHDL implementation of the CASPER conv block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

entity conv is
    generic (
        g_din_width : integer := 8
    );
    port(
        clk  : in  std_logic;
        ce   : in  std_logic;
        din  : in  std_logic_vector(g_din_width - 1 DOWNTO 0);
        dout : out std_logic_vector
    );
end entity conv;

architecture behavioural of conv is

    signal s_nosignbit : std_logic_vector(g_din_width - 2 downto 0) := (others => '0');
    signal s_dout : std_logic_vector(g_din_width - 1 DOWNTO 0) := (others => '0');
    signal msb : std_logic := '0';
    signal not_msb : std_logic := '0';

begin
    -- Assign the MSB
    msb <= din(g_din_width-1);
    not_msb <= not msb;
    -- Assign the rest of the bits excluding the MSB
    s_nosignbit <= din(g_din_width - 2 downto 0);
    -- Concat
    s_dout <= not_msb & s_nosignbit;
    dout <= s_dout;

end architecture behavioural;