----------------------------------------------------------------------------------
-- Engineer: Talon Myburgh
-- 
-- Create Date: 09.08.2020 14:26:58
-- Design Name: 
-- Module Name: ip_xpm_rom_r - Behavioral
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

entity ip_xpm_rom_r is
	GENERIC(
		g_adr_w         : NATURAL := 10;
		g_dat_w         : NATURAL := 22;
		g_nof_words     : NATURAL := 2**5;
		g_rd_latency    : NATURAL := 2; -- choose 1 or 2
		g_init_file     : STRING  := "UNUSED";
		g_ram_primitive : STRING  := "auto" --choose auto, distributed, block, ultra
	);
	PORT(
		address : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
		clock   : IN  STD_LOGIC;
		clocken : IN  STD_LOGIC := '1';
		q         : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0)
	);
end ip_xpm_rom_r;

architecture Behavioral of ip_xpm_rom_r is

	SIGNAL sub_wire0    : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
	CONSTANT c_initfile : STRING  := sel_a_b(g_init_file = "UNUSED", "none", g_init_file);
	-- CONSTANT c_memsize  : NATURAL := g_nof_words * g_dat_w;
	CONSTANT c_memsize  : NATURAL := 2**g_adr_w * g_dat_w;

begin
	assert 2**g_adr_w >= g_nof_words
	report "Address width "&natural'image(g_adr_w)&" does not cover the number of words " &natural'image(g_nof_words)
	severity failure;

	q    <= sub_wire0(g_dat_w - 1 DOWNTO 0);

	-- xpm_memory_sprom: Single Port ROM
	-- Xilinx Parameterized Macro, version 2019.2
	xpm_memory_sprom_inst : xpm_memory_sprom
	generic map (
		ADDR_WIDTH_A            => g_adr_w, -- DECIMAL
		AUTO_SLEEP_TIME         => 0, -- DECIMAL
		ECC_MODE                => "no_ecc", -- String
		MEMORY_INIT_FILE        => c_initfile, -- String
		MEMORY_INIT_PARAM       => "0", -- String
		MEMORY_OPTIMIZATION     => "true", -- String
		MEMORY_PRIMITIVE        => g_ram_primitive, -- String
		MEMORY_SIZE             => c_memsize, -- DECIMAL
		MESSAGE_CONTROL         => 0, -- DECIMAL
		READ_DATA_WIDTH_A       => g_dat_w, -- DECIMAL
		READ_LATENCY_A          => g_rd_latency, -- DECIMAL
		READ_RESET_VALUE_A      => "0", -- String
		RST_MODE_A              => "SYNC", -- String
		USE_MEM_INIT            => 1, --DECIMAL
		WAKEUP_TIME             => "disable_sleep" --String
	)
	port map (
		dbiterra => open, 			-- 1-bit output: Leave open.
		douta => sub_wire0,			-- READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
		sbiterra => open, 			-- 1-bit output: Leave open.
		addra => address, 		-- ADDR_WIDTH_A-bit input: Address for port A read operations.
		clka => clock, 				-- 1-bit input: Clock signal for port A.
		ena => clocken, 			-- 1-bit input: Memory enable signal for port A. Must be high on clock
														-- cycles when read operations are initiated. Pipelined internally.
		injectdbiterra => '0', 	-- 1-bit input: Do not change from the provided value.
		injectsbiterra => '0', 	-- 1-bit input: Do not change from the provided value.
		regcea => '1', 					-- 1-bit input: Do not change from the provided value.
		rsta => '0', 						-- 1-bit input: Reset signal for the final port A output register
														-- stage. Synchronously resets output port douta to the value specified
														-- by parameter READ_RESET_VALUE_A.
		sleep => '0' 						-- 1-bit input: sleep signal to enable the dynamic power saving feature.
	);
	-- End of xpm_memory_sprom_inst instantiation

end Behavioral;
