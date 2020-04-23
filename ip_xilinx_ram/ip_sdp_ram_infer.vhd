-- Asymmetric port RAM
-- Read Wider than Write
-- asym_ram_sdp_read_wider.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ip_sdp_ram_infer is
	generic(
		addressWidth : natural;
		dataWidth    : natural
	);

	port(
		clkA  : in  std_logic;
		clkB  : in  std_logic;
		enA   : in  std_logic;
		enB   : in  std_logic;
		weA   : in  std_logic;
		addrA : in  std_logic_vector(addressWidth - 1 downto 0);
		addrB : in  std_logic_vector(addressWidth - 1 downto 0);
		diA   : in  std_logic_vector(dataWidth - 1 downto 0);
		doB   : out std_logic_vector(dataWidth - 1 downto 0)
	);

end ip_sdp_ram_infer;

architecture behavioral of ip_sdp_ram_infer is

	type ramType1 is array (2**addressWidth - 1 downto 0) of std_logic_vector(dataWidth - 1 downto 0);
	signal ram : ramType1 := (others => (others => '0'));

	signal readB : std_logic_vector(dataWidth - 1 downto 0) := (others => '0');
	signal regB  : std_logic_vector(dataWidth - 1 downto 0) := (others => '0');

begin

	doB <= regB;

	rw : process(clkA, clkB)
	begin
		if (rising_edge(clkA)) then
			if (enA = '1') then
				if (weA = '1') then
					ram(to_integer(unsigned(addrA))) <= diA;
				end if;
			end if;
		end if;
		if rising_edge(clkB) then
			if (enB = '1') then
				readB <= ram(to_integer(unsigned(addrB)));
			end if;
			regB <= readB;
		end if;
	end process rw;
end behavioral;
