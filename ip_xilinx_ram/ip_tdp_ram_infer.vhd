library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ip_tdp_ram_infer is
	generic(
		addressWidth : natural := 8;
		dataWidth    : natural := 8
	);
	port(
		addressA, addressB : in  std_logic_vector(addressWidth - 1 downto 0);
		clockA, clockB     : in  std_logic;
		dataA, dataB       : in  std_logic_vector(dataWidth - 1 downto 0);
		enableA, enableB   : in  std_logic := '1';
		wrenA, wrenB       : in  std_logic := '0';
		qA, qB             : out std_logic_vector(dataWidth - 1 downto 0)
	);
end ip_tdp_ram_infer;

architecture rtl of ip_tdp_ram_infer is
	type ramType1 is array (2**addressWidth - 1 downto 0) of std_logic_vector(dataWidth - 1 downto 0);
	signal ram : ramType1 := (others => (others => '0'));

	signal readA : std_logic_vector(dataWidth - 1 downto 0) := (others => '0');
	signal readB : std_logic_vector(dataWidth - 1 downto 0) := (others => '0');
	signal regA  : std_logic_vector(dataWidth - 1 downto 0) := (others => '0');
	signal regB  : std_logic_vector(dataWidth - 1 downto 0) := (others => '0');

begin

	qA <= regA;
	qB <= regB;

	process(clockA, clockB)
	begin
		if rising_edge(clockA) then
			if (enableA = '1') then
				readA <= ram(to_integer(unsigned(addressA)));
				if (wrenA = '1') then
					ram(to_integer(unsigned(addressA))) <= dataA;
				end if;
				regA  <= readA;
			end if;
		end if;
		if rising_edge(clockB) then
			if (enableB = '1') then
				readB <= ram(to_integer(unsigned(addressB)));
				if (wrenB = '1') then
					ram(to_integer(unsigned(addressB))) <= dataB;
				end if;
				regB  <= readB;
			end if;
		end if;
	end process;

end rtl;

