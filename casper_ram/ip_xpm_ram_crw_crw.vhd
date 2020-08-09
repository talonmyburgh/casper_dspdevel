----------------------------------------------------------------------------------
-- Engineer: Talon Myburgh
-- 
-- Create Date: 09.08.2020 14:26:58
-- Design Name: 
-- Module Name: ip_xpm_ram_crw_crw - Behavioral
----------------------------------------------------------------------------------
library IEEE, xpm, common_pkg_lib;
use IEEE.STD_LOGIC_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
use xpm.vcomponents.all;
use ieee.numeric_std.all;

ENTITY ip_xpm_ram_crw_crw IS
	GENERIC(
		g_adr_w         : NATURAL := 5;
		g_dat_w         : NATURAL := 8;
		g_nof_words     : NATURAL := 2**5;
		g_rd_latency    : NATURAL := 2; -- choose 1 or 2
		g_init_file     : STRING  := "UNUSED";
		g_ram_primitive : STRING  := "auto" --choose auto, distributed, block, ultra
	);
	PORT(
		rst_a     : IN  STD_LOGIC;
		rst_b     : IN  STD_LOGIC;
		address_a : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
		address_b : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
		clock_a   : IN  STD_LOGIC := '1';
		clock_b   : IN  STD_LOGIC;
		data_a    : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		data_b    : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		enable_a  : IN  STD_LOGIC := '1';
		enable_b  : IN  STD_LOGIC := '1';
		rden_a    : IN  STD_LOGIC := '1';
		rden_b    : IN  STD_LOGIC := '1';
		wren_a    : IN  STD_LOGIC := '0';
		wren_b    : IN  STD_LOGIC := '0';
		q_a       : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		q_b       : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0)
	);
END ip_xpm_ram_crw_crw;

architecture Behavioral of ip_xpm_ram_crw_crw is
	CONSTANT c_initfile : STRING  := sel_a_b(g_init_file = "UNUSED", "none", g_init_file);
	CONSTANT c_memsize  : NATURAL := g_nof_words * g_dat_w;

	SIGNAL sub_wire0 : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
	SIGNAL sub_wire1 : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
	SIGNAL we_a      : STD_LOGIC_VECTOR(0 DOWNTO 0) := (others => wren_a);
	SIGNAL we_b      : STD_LOGIC_VECTOR(0 DOWNTO 0) := (others => wren_b);

begin

	q_a <= sub_wire0(g_dat_w - 1 DOWNTO 0) when rden_a = '1' else (others => 'X');
	q_b <= sub_wire1(g_dat_w - 1 DOWNTO 0) when rden_b = '1' else (others => 'X');

	xpm_memory_tdpram_inst : xpm_memory_tdpram
		generic map(
			ADDR_WIDTH_A            => g_adr_w, -- DECIMAL
			ADDR_WIDTH_B            => g_adr_w, -- DECIMAL
			AUTO_SLEEP_TIME         => 0, -- DECIMAL
			BYTE_WRITE_WIDTH_A      => g_dat_w, -- DECIMAL
			BYTE_WRITE_WIDTH_B      => g_dat_w, -- DECIMAL
			CLOCKING_MODE           => "independant_clock", -- String
			ECC_MODE                => "no_ecc", -- String
			MEMORY_INIT_FILE        => c_initfile, -- String
			MEMORY_INIT_PARAM       => "0", -- String
			MEMORY_OPTIMIZATION     => "true", -- String
			MEMORY_PRIMITIVE        => g_ram_primitive, -- String
			MEMORY_SIZE             => c_memsize, -- DECIMAL
			MESSAGE_CONTROL         => 0, -- DECIMAL
			READ_DATA_WIDTH_A       => g_dat_w, -- DECIMAL
			READ_DATA_WIDTH_B       => g_dat_w, -- DECIMAL
			READ_LATENCY_A          => g_rd_latency - 1, -- DECIMAL
			READ_LATENCY_B          => g_rd_latency - 1, -- DECIMAL
			READ_RESET_VALUE_A      => "0", -- String
			READ_RESET_VALUE_B      => "0", -- String
			RST_MODE_A              => "SYNC", -- String
			RST_MODE_B              => "SYNC", -- String
			USE_EMBEDDED_CONSTRAINT => 0, --DECIMAL
			USE_MEM_INIT            => 1, --DECIMAL
			WAKEUP_TIME             => "disable_sleep", --STRING
			WRITE_DATA_WIDTH_A      => g_dat_w, --DECIMAL
			WRITE_DATA_WIDTH_B      => g_dat_w, --DECIMAL
			WRITE_MODE_A            => "no_change", --STRING
			WRITE_MODE_B            => "no_change" --STRING
		)
		port map(
			dbiterra       => open,     -- 1-bit output: Status signal to indicate double bit error occurrence
			-- on the data output of port A.
			dbiterrb       => open,     -- 1-bit output: Status signal to indicate double bit error occurrence
			-- on the data output of port A.
			douta          => sub_wire0, -- READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
			doutb          => sub_wire1, -- READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
			sbiterra       => open,     -- 1-bit output: Status signal to indicate single bit error occurrence
			-- on the data output of port A.
			sbiterrb       => open,     -- 1-bit output: Status signal to indicate single bit error occurrence
			-- on the data output of port B.
			addra          => address_a, -- ADDR_WIDTH_A-bit input: Address for port A write and read operations.
			addrb          => address_b, -- ADDR_WIDTH_B-bit input: Address for port B write and read operations.
			clka           => clock_a,  -- 1-bit input: Clock signal for port A. Also clocks port B when
			-- parameter CLOCKING_MODE is "common_clock".
			clkb           => clock_b,  -- 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
			-- "independent_clock". Unused when parameter CLOCKING_MODE is
			-- "common_clock".
			dina           => data_a,   --WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
			dinb           => data_b,   --WRITE_DATA_WIDTH_B-bit input: Data input for port B write operations.
			ena            => enable_a, --1-bit input: Memory enable signal for port A. Must be high on clock
			--cycles when read or write operations are initiated. Pipelined
			-- internally.
			enb            => enable_b, -- 1-bit input: Memory enable signal for port B. Must be high on clock
			-- cycles when read or write operations are initiated. Pipelined
			-- internally.
			injectdbiterra => '0',      -- 1-bit input: Controls double bit error injection on input data when
			-- ECC enabled (Error injection capability is not available in
			-- "decode_only" mode).
			injectdbiterrb => '0',      -- 1-bit input: Controls double bit error injection on input data when
			-- ECC enabled (Error injection capability is not available in
			-- "decode_only" mode).

			injectsbiterra => '0',      -- 1-bit input: Controls single bit error injection on input data when
			-- ECC enabled (Error injection capability is not available in
			-- "decode_only" mode).
			injectsbiterrb => '0',      -- 1-bit input: Controls single bit error injection on input data when
			-- ECC enabled (Error injection capability is not available in
			-- "decode_only" mode).
			regcea         => '1',      -- 1-bit input: Clock Enable for the last register stage on the output
			-- data path.
			regceb         => '1',      -- 1-bit input: Clock Enable for the last register stage on the output
			-- data path.
			rsta           => rst_a,      -- 1-bit input: Reset signal for the final port A output register
			-- stage. Synchronously resets output port douta to the value specified
			-- by parameter READ_RESET_VALUE_B.
			rstb           => rst_b,
			-- 1-bit input: Reset signal for the final port B output register
			-- stage. Synchronously resets output port doutb to the value specified
			-- by parameter READ_RESET_VALUE_B.
			sleep          => '0',      --1-bit input: sleep signal to enable the dynamic power saving feature.
			wea            => we_a,     --WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector
			--for port A input data port dina. 1 bit wide when word-wide writes
			--are used. In byte-wide write configurations, each bit controls the
			-- writing one byte of dina to address addra. For example, to
			-- synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A
			-- is 32, wea would be 4'b0010.
			web            => we_b
			-- WRITE_DATA_WIDTH_B/BYTE_WRITE_WIDTH_B-bit input: Write enable vector
			-- for port B input data port dinb. 1 bit wide when word-wide writes
			-- are used. In byte-wide write configurations, each bit controls the
			-- writing one byte of dinb to address addrb. For example, to
			-- synchronously write only bits [15-8] of dinb when WRITE_DATA_WIDTH_B
			-- is 32, web would be 4'b0010.
		);                              -- End of xpm_memory_tdpram_inst instantiation

end Behavioral;
