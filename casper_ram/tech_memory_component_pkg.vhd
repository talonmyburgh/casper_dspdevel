-------------------------------------------------------------------------------
--
-- Copyright 2020
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--     http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-------------------------------------------------------------------------------

-- Purpose: IP components declarations for various devices that get wrapped by the tech components

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

PACKAGE tech_memory_component_pkg IS

	-----------------------------------------------------------------------------
	-- ip_stratixiv
	-----------------------------------------------------------------------------

	COMPONENT ip_stratixiv_ram_crwk_crw IS -- support different port data widths and corresponding address ranges
		GENERIC(
			g_adr_a_w     : NATURAL := 5;
			g_dat_a_w     : NATURAL := 32;
			g_adr_b_w     : NATURAL := 7;
			g_dat_b_w     : NATURAL := 8;
			g_nof_words_a : NATURAL := 2**5;
			g_nof_words_b : NATURAL := 2**7;
			g_rd_latency  : NATURAL := 2; -- choose 1 or 2
			g_init_file   : STRING  := "UNUSED"
		);
		PORT(
			address_a : IN  STD_LOGIC_VECTOR(g_adr_a_w - 1 DOWNTO 0);
			address_b : IN  STD_LOGIC_VECTOR(g_adr_b_w - 1 DOWNTO 0);
			clock_a   : IN  STD_LOGIC := '1';
			clock_b   : IN  STD_LOGIC;
			data_a    : IN  STD_LOGIC_VECTOR(g_dat_a_w - 1 DOWNTO 0);
			data_b    : IN  STD_LOGIC_VECTOR(g_dat_b_w - 1 DOWNTO 0);
			enable_a  : IN  STD_LOGIC := '1';
			enable_b  : IN  STD_LOGIC := '1';
			rden_a    : IN  STD_LOGIC := '1';
			rden_b    : IN  STD_LOGIC := '1';
			wren_a    : IN  STD_LOGIC := '0';
			wren_b    : IN  STD_LOGIC := '0';
			q_a       : OUT STD_LOGIC_VECTOR(g_dat_a_w - 1 DOWNTO 0);
			q_b       : OUT STD_LOGIC_VECTOR(g_dat_b_w - 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT ip_stratixiv_ram_crw_crw IS
		GENERIC(
			g_adr_w      : NATURAL := 5;
			g_dat_w      : NATURAL := 8;
			g_nof_words  : NATURAL := 2**5;
			g_rd_latency : NATURAL := 2; -- choose 1 or 2
			g_init_file  : STRING  := "UNUSED"
		);
		PORT(
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
	END COMPONENT;

	COMPONENT ip_stratixiv_ram_cr_cw IS
		GENERIC(
			g_adr_w      : NATURAL := 5;
			g_dat_w      : NATURAL := 8;
			g_nof_words  : NATURAL := 2**5;
			g_rd_latency : NATURAL := 2; -- choose 1 or 2
			g_init_file  : STRING  := "UNUSED"
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
	END COMPONENT;

	COMPONENT ip_stratixiv_ram_r_w IS
		GENERIC(
			g_adr_w     : NATURAL := 5;
			g_dat_w     : NATURAL := 8;
			g_nof_words : NATURAL := 2**5;
			g_init_file : STRING  := "UNUSED"
		);
		PORT(
			clock     : IN  STD_LOGIC := '1';
			enable    : IN  STD_LOGIC := '1';
			data      : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
			rdaddress : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
			wraddress : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
			wren      : IN  STD_LOGIC := '0';
			q         : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0)
		);
	END COMPONENT;

	--  COMPONENT ip_stratixiv_rom_r IS
	--  GENERIC (
	--    g_adr_w     : NATURAL := 5;
	--    g_dat_w     : NATURAL := 8;
	--    g_nof_words : NATURAL := 2**5;
	--    g_init_file : STRING  := "UNUSED"
	--  );
	--  PORT (
	--    address   : IN STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0);
	--    clock     : IN STD_LOGIC  := '1';
	--    clken     : IN STD_LOGIC  := '1';
	--    q         : OUT STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0)
	--  );
	--  END COMPONENT;

	-----------------------------------------------------------------------------
	-- ip_xilinx
	-----------------------------------------------------------------------------
	component ip_xpm_ram_cr_cw
		generic(
			g_adr_w         : NATURAL;
			g_dat_w         : NATURAL;
			g_nof_words     : NATURAL;
			g_rd_latency    : NATURAL;
			g_init_file     : STRING;
			g_ram_primitive : STRING
		);
		port(
			data      : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
			rdaddress : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
			rdclock   : IN  STD_LOGIC;
			rdclocken : IN  STD_LOGIC;
			wraddress : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
			wrclock   : IN  STD_LOGIC;
			wrclocken : IN  STD_LOGIC;
			wren      : IN  STD_LOGIC;
			q         : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0)
		);
	end component ip_xpm_ram_cr_cw;

	component ip_xpm_ram_crw_crw
		generic(
			g_adr_w         : NATURAL;
			g_dat_w         : NATURAL;
			g_nof_words     : NATURAL;
			g_rd_latency    : NATURAL;
			g_init_file     : STRING;
			g_ram_primitive : STRING
		);
		port(
			address_a : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
			address_b : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
			clock_a   : IN  STD_LOGIC;
			clock_b   : IN  STD_LOGIC;
			data_a    : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
			data_b    : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
			enable_a  : IN  STD_LOGIC;
			enable_b  : IN  STD_LOGIC;
			rden_a    : IN  STD_LOGIC;
			rden_b    : IN  STD_LOGIC;
			wren_a    : IN  STD_LOGIC;
			wren_b    : IN  STD_LOGIC;
			q_a       : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
			q_b       : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0)
		);
	end component ip_xpm_ram_crw_crw;

	component ip_xpm_ram_crwk_crw
		generic(
			g_adr_a_w       : NATURAL;
			g_dat_a_w       : NATURAL;
			g_adr_b_w       : NATURAL;
			g_dat_b_w       : NATURAL;
			g_nof_words_a   : NATURAL;
			g_nof_words_b   : NATURAL;
			g_rd_latency    : NATURAL;
			g_init_file     : STRING;
			g_ram_primitive : STRING
		);
		port(
			address_a : IN  STD_LOGIC_VECTOR(g_adr_a_w - 1 DOWNTO 0);
			address_b : IN  STD_LOGIC_VECTOR(g_adr_b_w - 1 DOWNTO 0);
			clock_a   : IN  STD_LOGIC;
			clock_b   : IN  STD_LOGIC;
			data_a    : IN  STD_LOGIC_VECTOR(g_dat_a_w - 1 DOWNTO 0);
			data_b    : IN  STD_LOGIC_VECTOR(g_dat_b_w - 1 DOWNTO 0);
			enable_a  : IN  STD_LOGIC;
			enable_b  : IN  STD_LOGIC;
			rden_a    : IN  STD_LOGIC;
			rden_b    : IN  STD_LOGIC;
			wren_a    : IN  STD_LOGIC;
			wren_b    : IN  STD_LOGIC;
			q_a       : OUT STD_LOGIC_VECTOR(g_dat_a_w - 1 DOWNTO 0);
			q_b       : OUT STD_LOGIC_VECTOR(g_dat_b_w - 1 DOWNTO 0)
		);
	end component ip_xpm_ram_crwk_crw;

	component ip_xpm_rom_cr is
		generic(
			g_adr_w         : NATURAL := 10;
			g_dat_w         : NATURAL := 22;
			g_nof_words     : NATURAL := 2**5;
			g_rd_latency    : NATURAL := 2; -- choose 1 or 2
			g_init_file     : STRING  := "UNUSED";
			g_ram_primitive : STRING  := "auto" --choose auto, distributed, block, ultra
		);
		port(
			rdaddress : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
			rdclock   : IN  STD_LOGIC;
			rdclocken : IN  STD_LOGIC := '1';
			q         : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0)
		);
	end component ip_xpm_rom_cr;

	-----------------------------------------------------------------------------
	-- ip_arria10
	-----------------------------------------------------------------------------

	--  COMPONENT ip_arria10_ram_crwk_crw IS
	--  GENERIC (
	--    g_adr_a_w     : NATURAL := 5;
	--    g_dat_a_w     : NATURAL := 32;
	--    g_adr_b_w     : NATURAL := 4;
	--    g_dat_b_w     : NATURAL := 64;
	--    g_nof_words_a : NATURAL := 2**5;
	--    g_nof_words_b : NATURAL := 2**4;
	--    g_rd_latency  : NATURAL := 1;     -- choose 1 or 2
	--    g_init_file   : STRING  := "UNUSED"
	--  );
	--  PORT
	--  (
	--    address_a : IN STD_LOGIC_VECTOR (g_adr_a_w-1 DOWNTO 0);
	--    address_b : IN STD_LOGIC_VECTOR (g_adr_b_w-1 DOWNTO 0);
	--    clk_a     : IN STD_LOGIC  := '1';
	--    clk_b     : IN STD_LOGIC ;
	--    data_a    : IN STD_LOGIC_VECTOR (g_dat_a_w-1 DOWNTO 0);
	--    data_b    : IN STD_LOGIC_VECTOR (g_dat_b_w-1 DOWNTO 0);
	--    wren_a    : IN STD_LOGIC  := '0';
	--    wren_b    : IN STD_LOGIC  := '0';
	--    q_a       : OUT STD_LOGIC_VECTOR (g_dat_a_w-1 DOWNTO 0);
	--    q_b       : OUT STD_LOGIC_VECTOR (g_dat_b_w-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--
	--  COMPONENT ip_arria10_ram_crw_crw IS
	--  GENERIC (
	--    g_inferred   : BOOLEAN := FALSE;
	--    g_adr_w      : NATURAL := 5;
	--    g_dat_w      : NATURAL := 8;
	--    g_nof_words  : NATURAL := 2**5;
	--    g_rd_latency : NATURAL := 1;  -- choose 1 or 2
	--    g_init_file  : STRING  := "UNUSED"
	--  );
	--  PORT
	--  (
	--    address_a : IN STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
	--    address_b : IN STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
	--    clk_a     : IN STD_LOGIC  := '1';
	--    clk_b     : IN STD_LOGIC ;
	--    data_a    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    data_b    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    wren_a    : IN STD_LOGIC  := '0';
	--    wren_b    : IN STD_LOGIC  := '0';
	--    q_a       : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    q_b       : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--  
	--  COMPONENT ip_arria10_ram_cr_cw IS
	--  GENERIC (
	--    g_inferred   : BOOLEAN := FALSE;
	--    g_adr_w      : NATURAL := 5;
	--    g_dat_w      : NATURAL := 8;
	--    g_nof_words  : NATURAL := 2**5;
	--    g_rd_latency : NATURAL := 1;  -- choose 1 or 2
	--    g_init_file  : STRING  := "UNUSED"
	--  );
	--  PORT
	--  (
	--    data      : IN  STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    rdaddress : IN  STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
	--    rdclk     : IN  STD_LOGIC ;
	--    wraddress : IN  STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
	--    wrclk     : IN  STD_LOGIC  := '1';
	--    wren      : IN  STD_LOGIC  := '0';
	--    q         : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--  
	--  COMPONENT ip_arria10_ram_r_w IS
	--  GENERIC (
	--    g_inferred   : BOOLEAN := FALSE;
	--    g_adr_w      : NATURAL := 5;
	--    g_dat_w      : NATURAL := 8;
	--    g_nof_words  : NATURAL := 2**5;
	--    g_rd_latency : NATURAL := 1;     -- choose 1 or 2
	--    g_init_file  : STRING  := "UNUSED"
	--  );
	--  PORT (
	--    clk         : IN STD_LOGIC  := '1';
	--    data        : IN STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0) := (OTHERS=>'0');
	--    rdaddress   : IN STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0) := (OTHERS=>'0');
	--    wraddress   : IN STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0) := (OTHERS=>'0');
	--    wren        : IN STD_LOGIC  := '0';
	--    q           : OUT STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--  
	--  -----------------------------------------------------------------------------
	--  -- ip_arria10_e3sge3
	--  -----------------------------------------------------------------------------
	--  
	--  COMPONENT ip_arria10_e3sge3_ram_crwk_crw IS
	--  GENERIC (
	--    g_adr_a_w     : NATURAL := 5;
	--    g_dat_a_w     : NATURAL := 32;
	--    g_adr_b_w     : NATURAL := 4;
	--    g_dat_b_w     : NATURAL := 64;
	--    g_nof_words_a : NATURAL := 2**5;
	--    g_nof_words_b : NATURAL := 2**4;
	--    g_rd_latency  : NATURAL := 1;     -- choose 1 or 2
	--    g_init_file   : STRING  := "UNUSED"
	--  );
	--  PORT
	--  (
	--    address_a : IN STD_LOGIC_VECTOR (g_adr_a_w-1 DOWNTO 0);
	--    address_b : IN STD_LOGIC_VECTOR (g_adr_b_w-1 DOWNTO 0);
	--    clk_a     : IN STD_LOGIC  := '1';
	--    clk_b     : IN STD_LOGIC ;
	--    data_a    : IN STD_LOGIC_VECTOR (g_dat_a_w-1 DOWNTO 0);
	--    data_b    : IN STD_LOGIC_VECTOR (g_dat_b_w-1 DOWNTO 0);
	--    wren_a    : IN STD_LOGIC  := '0';
	--    wren_b    : IN STD_LOGIC  := '0';
	--    q_a       : OUT STD_LOGIC_VECTOR (g_dat_a_w-1 DOWNTO 0);
	--    q_b       : OUT STD_LOGIC_VECTOR (g_dat_b_w-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--
	--  COMPONENT ip_arria10_e3sge3_ram_crw_crw IS
	--  GENERIC (
	--    g_inferred   : BOOLEAN := FALSE;
	--    g_adr_w      : NATURAL := 5;
	--    g_dat_w      : NATURAL := 8;
	--    g_nof_words  : NATURAL := 2**5;
	--    g_rd_latency : NATURAL := 1;  -- choose 1 or 2
	--    g_init_file  : STRING  := "UNUSED"
	--  );
	--  PORT
	--  (
	--    address_a : IN STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
	--    address_b : IN STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
	--    clk_a     : IN STD_LOGIC  := '1';
	--    clk_b     : IN STD_LOGIC ;
	--    data_a    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    data_b    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    wren_a    : IN STD_LOGIC  := '0';
	--    wren_b    : IN STD_LOGIC  := '0';
	--    q_a       : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    q_b       : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--  
	--  COMPONENT ip_arria10_e3sge3_ram_cr_cw IS
	--  GENERIC (
	--    g_inferred   : BOOLEAN := FALSE;
	--    g_adr_w      : NATURAL := 5;
	--    g_dat_w      : NATURAL := 8;
	--    g_nof_words  : NATURAL := 2**5;
	--    g_rd_latency : NATURAL := 1;  -- choose 1 or 2
	--    g_init_file  : STRING  := "UNUSED"
	--  );
	--  PORT
	--  (
	--    data      : IN  STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    rdaddress : IN  STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
	--    rdclk     : IN  STD_LOGIC ;
	--    wraddress : IN  STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
	--    wrclk     : IN  STD_LOGIC  := '1';
	--    wren      : IN  STD_LOGIC  := '0';
	--    q         : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--  
	--  COMPONENT ip_arria10_e3sge3_ram_r_w IS
	--  GENERIC (
	--    g_inferred   : BOOLEAN := FALSE;
	--    g_adr_w      : NATURAL := 5;
	--    g_dat_w      : NATURAL := 8;
	--    g_nof_words  : NATURAL := 2**5;
	--    g_rd_latency : NATURAL := 1;     -- choose 1 or 2
	--    g_init_file  : STRING  := "UNUSED"
	--  );
	--  PORT (
	--    clk         : IN STD_LOGIC  := '1';
	--    data        : IN STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0) := (OTHERS=>'0');
	--    rdaddress   : IN STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0) := (OTHERS=>'0');
	--    wraddress   : IN STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0) := (OTHERS=>'0');
	--    wren        : IN STD_LOGIC  := '0';
	--    q           : OUT STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--  
	--  -----------------------------------------------------------------------------
	--  -- ip_arria10_e1sg
	--  -----------------------------------------------------------------------------
	--  
	--  COMPONENT ip_arria10_e1sg_ram_crwk_crw IS
	--  GENERIC (
	--    g_adr_a_w     : NATURAL := 5;
	--    g_dat_a_w     : NATURAL := 32;
	--    g_adr_b_w     : NATURAL := 4;
	--    g_dat_b_w     : NATURAL := 64;
	--    g_nof_words_a : NATURAL := 2**5;
	--    g_nof_words_b : NATURAL := 2**4;
	--    g_rd_latency  : NATURAL := 1;     -- choose 1 or 2
	--    g_init_file   : STRING  := "UNUSED"
	--  );
	--  PORT
	--  (
	--    address_a : IN STD_LOGIC_VECTOR (g_adr_a_w-1 DOWNTO 0);
	--    address_b : IN STD_LOGIC_VECTOR (g_adr_b_w-1 DOWNTO 0);
	--    clk_a     : IN STD_LOGIC  := '1';
	--    clk_b     : IN STD_LOGIC ;
	--    data_a    : IN STD_LOGIC_VECTOR (g_dat_a_w-1 DOWNTO 0);
	--    data_b    : IN STD_LOGIC_VECTOR (g_dat_b_w-1 DOWNTO 0);
	--    wren_a    : IN STD_LOGIC  := '0';
	--    wren_b    : IN STD_LOGIC  := '0';
	--    q_a       : OUT STD_LOGIC_VECTOR (g_dat_a_w-1 DOWNTO 0);
	--    q_b       : OUT STD_LOGIC_VECTOR (g_dat_b_w-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--
	--  COMPONENT ip_arria10_e1sg_ram_crw_crw IS
	--  GENERIC (
	--    g_inferred   : BOOLEAN := FALSE;
	--    g_adr_w      : NATURAL := 5;
	--    g_dat_w      : NATURAL := 8;
	--    g_nof_words  : NATURAL := 2**5;
	--    g_rd_latency : NATURAL := 1;  -- choose 1 or 2
	--    g_init_file  : STRING  := "UNUSED"
	--  );
	--  PORT
	--  (
	--    address_a : IN STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
	--    address_b : IN STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
	--    clk_a     : IN STD_LOGIC  := '1';
	--    clk_b     : IN STD_LOGIC ;
	--    data_a    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    data_b    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    wren_a    : IN STD_LOGIC  := '0';
	--    wren_b    : IN STD_LOGIC  := '0';
	--    q_a       : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    q_b       : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--  
	--  COMPONENT ip_arria10_e1sg_ram_cr_cw IS
	--  GENERIC (
	--    g_inferred   : BOOLEAN := FALSE;
	--    g_adr_w      : NATURAL := 5;
	--    g_dat_w      : NATURAL := 8;
	--    g_nof_words  : NATURAL := 2**5;
	--    g_rd_latency : NATURAL := 1;  -- choose 1 or 2
	--    g_init_file  : STRING  := "UNUSED"
	--  );
	--  PORT
	--  (
	--    data      : IN  STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    rdaddress : IN  STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
	--    rdclk     : IN  STD_LOGIC ;
	--    wraddress : IN  STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
	--    wrclk     : IN  STD_LOGIC  := '1';
	--    wren      : IN  STD_LOGIC  := '0';
	--    q         : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--  
	--  COMPONENT ip_arria10_e1sg_ram_r_w IS
	--  GENERIC (
	--    g_inferred   : BOOLEAN := FALSE;
	--    g_adr_w      : NATURAL := 5;
	--    g_dat_w      : NATURAL := 8;
	--    g_nof_words  : NATURAL := 2**5;
	--    g_rd_latency : NATURAL := 1;     -- choose 1 or 2
	--    g_init_file  : STRING  := "UNUSED"
	--  );
	--  PORT (
	--    clk         : IN STD_LOGIC  := '1';
	--    data        : IN STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0) := (OTHERS=>'0');
	--    rdaddress   : IN STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0) := (OTHERS=>'0');
	--    wraddress   : IN STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0) := (OTHERS=>'0');
	--    wren        : IN STD_LOGIC  := '0';
	--    q           : OUT STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0)
	--  );
	--  END COMPONENT;

END tech_memory_component_pkg;
