----------------------------------------------------------------------------------
-- Engineer: Talon Myburgh
-- 
-- Create Date: 09.08.2020 14:26:58
-- Design Name: 
-- Module Name: ip_xpm_ram_cr_cw - Behavioral
----------------------------------------------------------------------------------

library IEEE, xpm, common_pkg_lib;
use IEEE.STD_LOGIC_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
use xpm.vcomponents.all;
use ieee.numeric_std.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity ip_xpm_ram_cr_cw is
	GENERIC(
		g_adr_w         : NATURAL := 10;
		g_dat_w         : NATURAL := 22;
		g_nof_words     : NATURAL := 2**5;
		g_rd_latency    : NATURAL := 2; -- choose 1 or 2
		g_init_file     : STRING  := "UNUSED";
		g_ram_primitive : STRING  := "auto" --choose auto, distributed, block, ultra
	);
	PORT(
		data      : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		rdaddress : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
		rdclock   : IN  STD_LOGIC;
		rdclocken : IN  STD_LOGIC := '1';
		wraddress : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
		wrclock   : IN  STD_LOGIC := '1';
		wrclocken : IN  STD_LOGIC := '1';
		wren      : IN  STD_LOGIC := '0';
		q         : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0)
	);
end ip_xpm_ram_cr_cw;

architecture Behavioral of ip_xpm_ram_cr_cw is

	SIGNAL sub_wire0    : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
	CONSTANT c_initfile : STRING  := sel_a_b(g_init_file = "UNUSED", "none", g_init_file);
	CONSTANT c_memsize  : NATURAL := g_nof_words * g_dat_w;

	SIGNAL we_a : STD_LOGIC_VECTOR(0 DOWNTO 0);

begin
	we_a <= (others => wren);
	q    <= sub_wire0(g_dat_w - 1 DOWNTO 0);

	xpm_memory_sdpram_inst : xpm_memory_sdpram
		generic map(
			ADDR_WIDTH_A            => g_adr_w, -- DECIMAL
			ADDR_WIDTH_B            => g_adr_w, -- DECIMAL
			AUTO_SLEEP_TIME         => 0, -- DECIMAL
			BYTE_WRITE_WIDTH_A      => g_dat_w, -- DECIMAL
			CLOCKING_MODE           => "independant_clock", -- String
			ECC_MODE                => "no_ecc", -- String
			MEMORY_INIT_FILE        => c_initfile, -- String
			MEMORY_INIT_PARAM       => "0", -- String
			MEMORY_OPTIMIZATION     => "true", -- String
			MEMORY_PRIMITIVE        => g_ram_primitive, -- String
			MEMORY_SIZE             => c_memsize, -- DECIMAL
			MESSAGE_CONTROL         => 0, -- DECIMAL
			READ_DATA_WIDTH_B       => g_dat_w, -- DECIMAL
			READ_LATENCY_B          => g_rd_latency, -- DECIMAL
			READ_RESET_VALUE_B      => "0", -- String
			RST_MODE_A              => "SYNC", -- String
			RST_MODE_B              => "SYNC", -- String
			USE_EMBEDDED_CONSTRAINT => 0, --DECIMAL
			USE_MEM_INIT            => 1, --DECIMAL
			WAKEUP_TIME             => "disable_sleep", --String
			WRITE_DATA_WIDTH_A      => g_dat_w, --DECIMAL
			WRITE_MODE_B            => "read_first" --String
		)
		port map(
			dbiterrb       => open,     -- 1-bit output: Status signal to indicate double bit error occurrence
			-- on the data output of port B.
			doutb          => sub_wire0, -- READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
			sbiterrb       => open,     -- 1-bit output: Status signal to indicate single bit error occurrence
			-- on the data output of port B.
			addra          => wraddress, -- ADDR_WIDTH_A-bit input: Address for port A write operations.
			addrb          => rdaddress, -- ADDR_WIDTH_B-bit input: Address for port B read operations.
			clka           => wrclock,  -- 1-bit input: Clock signal for port A. Also clocks port B when
			-- parameter CLOCKING_MODE is "common_clock".
			clkb           => rdclock,  -- 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
			-- "independent_clock". Unused when parameter CLOCKING_MODE is
			-- "common_clock".
			dina           => data,     -- WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
			ena            => wrclocken, -- 1-bit input: Memory enable signal for port A. Must be high on clock
			-- cycles when write operations are initiated. Pipelined internally.
			enb            => rdclocken, -- 1-bit input: Memory enable signal for port B. Must be high on clock
			-- cycles when read operations are initiated. Pipelined internally.

			injectdbiterra => '0',      -- 1-bit input: Controls double bit error injection on input data when
			-- ECC enabled (Error injection capability is not available in
			-- "decode_only" mode).
			injectsbiterra => '0',      -- 1-bit input: Controls single bit error injection on input data when
			-- ECC enabled (Error injection capability is not available in
			-- "decode_only" mode).
			regceb         => '1',      -- 1-bit input: Clock Enable for the last register stage on the output
			-- data path.
			rstb           => '0',      -- 1-bit input: Reset signal for the final port B output register
			-- stage. Synchronously resets output port doutb to the value specified
			-- by parameter READ_RESET_VALUE_B.
			sleep          => '0',      --1-bit input: sleep signal to enable the dynamic power saving feature.
			wea            => we_a      --WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
			--for port A input data port dina. 1 bit wide when word-wide writes
			--are used. In byte-wide write configurations, each bit controls the
			-- writing one byte of dina to address addra. For example, to
			-- synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
			-- is 32, wea would be 4'b0010.
		);
		-- End of xpm_memory_sdpram_inst instantiation

end Behavioral;
