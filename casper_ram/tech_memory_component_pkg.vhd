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

LIBRARY IEEE, ip_xilinx_ram_lib;
USE IEEE.STD_LOGIC_1164.ALL;
--use ip_stratixiv_ram_lib.all;
use ip_xilinx_ram_lib.all;

PACKAGE tech_memory_component_pkg IS

-----------------------------------------------------------------------------
-- ip_xilinx
-----------------------------------------------------------------------------
component ip_sdp_ram_infer
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
end component ip_sdp_ram_infer;

component ip_tdp_ram_infer
	generic(
		addressWidth : natural;
		dataWidth    : natural
	);
	port(
		addressA, addressB : in  std_logic_vector(addressWidth - 1 downto 0);
		clockA, clockB     : in  std_logic;
		dataA, dataB       : in  std_logic_vector(dataWidth - 1 downto 0);
		enableA, enableB   : in  std_logic;
		wrenA, wrenB       : in  std_logic;
		qA, qB             : out std_logic_vector(dataWidth - 1 downto 0)
	);
end component ip_tdp_ram_infer;
 
-------------------------------------------------------------------------------
--  -- ip_stratixiv
-------------------------------------------------------------------------------
--  COMPONENT ip_stratixiv_ram_crw_crw IS
--  GENERIC (
--    g_adr_w      : NATURAL := 5;
--    g_dat_w      : NATURAL := 8;
--    g_nof_words  : NATURAL := 2**5;
--    g_rd_latency : NATURAL := 2;  -- choose 1 or 2
--    g_init_file  : STRING  := "UNUSED"
--  );
--  PORT (
--    address_a   : IN STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
--    address_b   : IN STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
--    clock_a   : IN STD_LOGIC  := '1';
--    clock_b   : IN STD_LOGIC ;
--    data_a    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
--    data_b    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
--    enable_a    : IN STD_LOGIC  := '1';
--    enable_b    : IN STD_LOGIC  := '1';
--    rden_a    : IN STD_LOGIC  := '1';
--    rden_b    : IN STD_LOGIC  := '1';
--    wren_a    : IN STD_LOGIC  := '0';
--    wren_b    : IN STD_LOGIC  := '0';
--    q_a   : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
--    q_b   : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0)
--  );
--  END COMPONENT;
--  
--  COMPONENT ip_stratixiv_ram_cr_cw IS
--  GENERIC (
--    g_adr_w      : NATURAL := 5;
--    g_dat_w      : NATURAL := 8;
--    g_nof_words  : NATURAL := 2**5;
--    g_rd_latency : NATURAL := 2;  -- choose 1 or 2
--    g_init_file  : STRING  := "UNUSED"
--  );
--  PORT (
--    data      : IN  STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
--    rdaddress : IN  STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
--    rdclock   : IN  STD_LOGIC ;
--    rdclocken : IN  STD_LOGIC  := '1';
--    wraddress : IN  STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
--    wrclock   : IN  STD_LOGIC  := '1';
--    wrclocken : IN  STD_LOGIC  := '1';
--    wren      : IN  STD_LOGIC  := '0';
--    q         : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0)
--  );
--  END COMPONENT;
--  
--  COMPONENT ip_stratixiv_ram_r_w IS
--  GENERIC (
--    g_adr_w     : NATURAL := 5;
--    g_dat_w     : NATURAL := 8;
--    g_nof_words : NATURAL := 2**5;
--    g_init_file : STRING  := "UNUSED"
--  );
--  PORT (
--    clock       : IN STD_LOGIC  := '1';
--    enable      : IN STD_LOGIC  := '1';
--    data        : IN STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);
--    rdaddress   : IN STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0);
--    wraddress   : IN STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0);
--    wren        : IN STD_LOGIC  := '0';
--    q           : OUT STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0)
--  );
--  END COMPONENT;
--  
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