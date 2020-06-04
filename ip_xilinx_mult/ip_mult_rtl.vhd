--! @file
--! @brief RTL Multiplier

--! IEEE library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Purpose:
--!   - RTL multiplier. This will not necessarily be mapped to DSP elements.

--! @dot 
--! digraph ip_mult_rtl {
--!	rankdir="LR";
--! node [shape=box, fontname=Helvetica, fontsize=12,color="black"];
--! ip_mult_rtl;
--! node [shape=plaintext];
--! a;
--! b;
--! clk;
--! rst;
--! ce;
--! p;
--! clk -> ip_mult_rtl;
--! ce -> ip_mult_rtl;
--! a -> ip_mult_rtl;
--! b -> ip_mult_rtl;
--! rst -> ip_mult_rtl;
--! ip_mult_rtl -> p;
--!}
--! @enddot
 
entity ip_mult_rtl is
	generic(AWIDTH : natural := 16; --! Bitwidth of A input
	        BWIDTH : natural := 16);--! Bitwidth of B input
	port(
		a   : in  std_logic_vector(AWIDTH-1 downto 0); --! Input A (width = AWIDTH)
		b   : in  std_logic_vector(BWIDTH-1 downto 0);--! Input B (width = BWIDTH)
		clk : in  std_logic; --! Input clock
		rst : in  std_logic; --! Reset signal
		ce  : in  std_logic; --! Clock enable
		p   : out std_logic_vector(AWIDTH+BWIDTH -1 downto 0) --! Output signal
	);
end entity;
architecture ip_mult_infer_rtl of ip_mult_rtl is
	signal a1 : signed(AWIDTH-1 downto 0);
	signal b1 : signed(BWIDTH-1 downto 0);
	signal p1 : signed(AWIDTH+BWIDTH-1 downto 0);
begin
	p1 <= a1 * b1;
	process(clk) is
	begin
		if clk'event and clk = '1' then
			if rst = '1' then
				a1 <= (others => '0');
				b1 <= (others => '0');
				p  <= (others => '0');
			elsif ce = '1' then
				a1 <= signed(a);
				b1 <= signed(b);
				p  <= std_logic_vector(p1);
			end if;
		end if;
	end process;
end architecture;
