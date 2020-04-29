library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ip_mult_infer_rtl is
	generic(AWIDTH : natural := 16;
	        BWIDTH : natural := 16);
	port(
		a   : in  std_logic_vector(AWIDTH-1 downto 0);
		b   : in  std_logic_vector(BWIDTH-1 downto 0);
		clk : in  std_logic;
		rst : in  std_logic;
		ce  : in  std_logic;
		p   : out std_logic_vector(AWIDTH+BWIDTH -1 downto 0)
	);
end entity;
architecture ip_mult_infer_rtl of ip_mult_infer_rtl is
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
