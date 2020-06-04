--! @file
--! @brief Simple dual port symmetric ram

--! IEEE library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! True dual port symmetric ram:
--! 	+Port A is a write/read port
--! 	+Port B is a wrtie/read port

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
--! weB;
--! addrA;
--! addrB;
--! qB;
--! qA;
--! clkA -> PortA;
--! clkB -> PortB;
--! enA -> PortA;
--! enB -> PortB;
--! weA -> PortA;
--! weB -> PortB;
--! addrA -> PortA;
--! addrB -> PortB;
--! PortA -> qA;
--! PortB -> qB;
--! subgraph sdp_ram {
--! {rank=same PortA PortB}
--! PortA -> PortB [color=grey arrowhead=none];
--!}
--!}
--! @enddot

entity ip_tdp_ram_infer is
	generic(
		addressWidth : natural := 8;--! Address width dictates RAM size
		dataWidth    : natural := 8--! Width of data to be stored/fetched
	);
	port(
		addressA, addressB : in  std_logic_vector(addressWidth - 1 downto 0); --! Write/Read address for port A and B
		clockA, clockB     : in  std_logic; --! Clock input for port A and B
		dataA, dataB       : in  std_logic_vector(dataWidth - 1 downto 0); --! Write data for port A and B
		enA, enB   : in  std_logic := '1'; --! Enable signals for Port A and B
		weA, weB       : in  std_logic := '0'; --! Write enable signals for Port A and B
		qA, qB             : out std_logic_vector(dataWidth - 1 downto 0) --! Output signals from Port A and B
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
			if (enA = '1') then
				readA <= ram(to_integer(unsigned(addressA)));
				if (weA = '1') then
					ram(to_integer(unsigned(addressA))) <= dataA;
				end if;
				regA  <= readA;
			end if;
		end if;
		if rising_edge(clockB) then
			if (enB = '1') then
				readB <= ram(to_integer(unsigned(addressB)));
				if (weB = '1') then
					ram(to_integer(unsigned(addressB))) <= dataB;
				end if;
				regB  <= readB;
			end if;
		end if;
	end process;

end rtl;

