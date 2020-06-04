--! @file
--! @brief Simple dual port symmetric ram

--! IEEE library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! Simple dual port symmetric ram:
--! 	+Port A is the write port
--! 	+Port B is the read port


--! @dot 
--! digraph ip_sdp_ram_infer {
--!	rankdir="LR";
--! node [shape=box, fontname=Helvetica, fontsize=12,color="black"];
--! PortA;
--! PortB;
--! node [shape=plaintext];
--! clkA;
--! clkB;
--! enA;
--! enB;
--! weA;
--! addrA;
--! addrB;
--! diA;
--! doB;
--! clkA -> PortA;
--! clkB -> PortB;
--! enA -> PortA;
--! enB -> PortB;
--! weA -> PortA;
--! addrA -> PortA;
--! addrB -> PortB;
--! diA -> PortA;
--! PortB -> doB;
--! subgraph sdp_ram {
--! {rank=same PortA PortB}
--! PortA -> PortB [color=grey arrowhead=none];
--!}
--!}
--! @enddot

entity ip_sdp_ram_infer is
	generic(
		addressWidth : natural; --! Address width dictates RAM size
		dataWidth    : natural --! Width of data to be stored/fetched
	);

	port(
		clkA  : in  std_logic; --! Clock input for port A
		clkB  : in  std_logic; --! Clock input for port B
		enA   : in  std_logic; --! Port A enable
		enB   : in  std_logic; --! Port B enable
		weA   : in  std_logic; --! Write enable for port A
		addrA : in  std_logic_vector(addressWidth - 1 downto 0); --! Write address (port A)
		addrB : in  std_logic_vector(addressWidth - 1 downto 0); --! Read address (port B)
		diA   : in  std_logic_vector(dataWidth - 1 downto 0); --! Write data (into port A)
		doB   : out std_logic_vector(dataWidth - 1 downto 0) --! Read data (from port B)
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
