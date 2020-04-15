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

LIBRARY ieee, common_pkg_lib;
USE IEEE.STD_LOGIC_1164.ALL;
--USE technology_lib.technology_pkg.ALL;
USE common_pkg_lib.common_pkg.ALL;

PACKAGE tech_fifo_component_pkg IS

	-----------------------------------------------------------------------------
	-- ip_stratixiv
	-----------------------------------------------------------------------------

	COMPONENT ip_stratixiv_fifo_sc IS
		GENERIC(
			g_use_eab   : STRING := "ON";
			g_dat_w     : NATURAL;
			g_nof_words : NATURAL
		);
		PORT(
			aclr  : IN  STD_LOGIC;
			clock : IN  STD_LOGIC;
			data  : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
			rdreq : IN  STD_LOGIC;
			wrreq : IN  STD_LOGIC;
			empty : OUT STD_LOGIC;
			full  : OUT STD_LOGIC;
			q     : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
			usedw : OUT STD_LOGIC_VECTOR(ceil_log2(g_nof_words) - 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT ip_stratixiv_fifo_dc IS
		GENERIC(
			g_dat_w     : NATURAL;
			g_nof_words : NATURAL
		);
		PORT(
			aclr    : IN  STD_LOGIC := '0';
			data    : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
			rdclk   : IN  STD_LOGIC;
			rdreq   : IN  STD_LOGIC;
			wrclk   : IN  STD_LOGIC;
			wrreq   : IN  STD_LOGIC;
			q       : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
			rdempty : OUT STD_LOGIC;
			rdusedw : OUT STD_LOGIC_VECTOR(ceil_log2(g_nof_words) - 1 DOWNTO 0);
			wrfull  : OUT STD_LOGIC;
			wrusedw : OUT STD_LOGIC_VECTOR(ceil_log2(g_nof_words) - 1 DOWNTO 0)
		);
	END COMPONENT;

	COMPONENT ip_stratixiv_fifo_dc_mixed_widths IS
		GENERIC(
			g_nof_words : NATURAL;      -- FIFO size in nof wr_dat words
			g_wrdat_w   : NATURAL;
			g_rddat_w   : NATURAL
		);
		PORT(
			aclr    : IN  STD_LOGIC := '0';
			data    : IN  STD_LOGIC_VECTOR(g_wrdat_w - 1 DOWNTO 0);
			rdclk   : IN  STD_LOGIC;
			rdreq   : IN  STD_LOGIC;
			wrclk   : IN  STD_LOGIC;
			wrreq   : IN  STD_LOGIC;
			q       : OUT STD_LOGIC_VECTOR(g_rddat_w - 1 DOWNTO 0);
			rdempty : OUT STD_LOGIC;
			rdusedw : OUT STD_LOGIC_VECTOR(ceil_log2(g_nof_words * g_wrdat_w / g_rddat_w) - 1 DOWNTO 0);
			wrfull  : OUT STD_LOGIC;
			wrusedw : OUT STD_LOGIC_VECTOR(ceil_log2(g_nof_words) - 1 DOWNTO 0)
		);
	END COMPONENT;

	--  -----------------------------------------------------------------------------
	--  -- ip_arria10
	--  -----------------------------------------------------------------------------
	--  
	--  COMPONENT ip_arria10_fifo_sc IS
	--  GENERIC (
	--    g_use_eab   : STRING := "ON";
	--    g_dat_w     : NATURAL := 20;
	--    g_nof_words : NATURAL := 1024
	--  );
	--  PORT (
	--    aclr    : IN STD_LOGIC ;
	--    clock   : IN STD_LOGIC ;
	--    data    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    rdreq   : IN STD_LOGIC ;
	--    wrreq   : IN STD_LOGIC ;
	--    empty   : OUT STD_LOGIC ;
	--    full    : OUT STD_LOGIC ;
	--    q       : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0) ;
	--    usedw   : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words)-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--
	--  COMPONENT ip_arria10_fifo_dc IS
	--  GENERIC (
	--    g_use_eab   : STRING := "ON";
	--    g_dat_w     : NATURAL := 20;
	--    g_nof_words : NATURAL := 1024
	--  );
	--  PORT (
	--    aclr    : IN STD_LOGIC  := '0';
	--    data    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    rdclk   : IN STD_LOGIC ;
	--    rdreq   : IN STD_LOGIC ;
	--    wrclk   : IN STD_LOGIC ;
	--    wrreq   : IN STD_LOGIC ;
	--    q       : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    rdempty : OUT STD_LOGIC ;
	--    rdusedw : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words)-1 DOWNTO 0);
	--    wrfull  : OUT STD_LOGIC ;
	--    wrusedw : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words)-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--  
	--  COMPONENT ip_arria10_fifo_dc_mixed_widths IS
	--  GENERIC (
	--    g_nof_words : NATURAL := 1024;  -- FIFO size in nof wr_dat words
	--    g_wrdat_w   : NATURAL := 20;
	--    g_rddat_w   : NATURAL := 10
	--  );
	--  PORT (
	--    aclr    : IN STD_LOGIC  := '0';
	--    data    : IN STD_LOGIC_VECTOR (g_wrdat_w-1 DOWNTO 0);
	--    rdclk   : IN STD_LOGIC ;
	--    rdreq   : IN STD_LOGIC ;
	--    wrclk   : IN STD_LOGIC ;
	--    wrreq   : IN STD_LOGIC ;
	--    q       : OUT STD_LOGIC_VECTOR (g_rddat_w-1 DOWNTO 0);
	--    rdempty : OUT STD_LOGIC ;
	--    rdusedw : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words*g_wrdat_w/g_rddat_w)-1 DOWNTO 0);
	--    wrfull  : OUT STD_LOGIC ;
	--    wrusedw : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words)-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--
	--  -----------------------------------------------------------------------------
	--  -- ip_arria10_e3sge3
	--  -----------------------------------------------------------------------------
	--  
	--  COMPONENT ip_arria10_e3sge3_fifo_sc IS
	--  GENERIC (
	--    g_use_eab   : STRING := "ON";
	--    g_dat_w     : NATURAL := 20;
	--    g_nof_words : NATURAL := 1024
	--  );
	--  PORT (
	--    aclr    : IN STD_LOGIC ;
	--    clock   : IN STD_LOGIC ;
	--    data    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    rdreq   : IN STD_LOGIC ;
	--    wrreq   : IN STD_LOGIC ;
	--    empty   : OUT STD_LOGIC ;
	--    full    : OUT STD_LOGIC ;
	--    q       : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0) ;
	--    usedw   : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words)-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--
	--  COMPONENT ip_arria10_e3sge3_fifo_dc IS
	--  GENERIC (
	--    g_use_eab   : STRING := "ON";
	--    g_dat_w     : NATURAL := 20;
	--    g_nof_words : NATURAL := 1024
	--  );
	--  PORT (
	--    aclr    : IN STD_LOGIC  := '0';
	--    data    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    rdclk   : IN STD_LOGIC ;
	--    rdreq   : IN STD_LOGIC ;
	--    wrclk   : IN STD_LOGIC ;
	--    wrreq   : IN STD_LOGIC ;
	--    q       : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    rdempty : OUT STD_LOGIC ;
	--    rdusedw : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words)-1 DOWNTO 0);
	--    wrfull  : OUT STD_LOGIC ;
	--    wrusedw : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words)-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--  
	--  COMPONENT ip_arria10_e3sge3_fifo_dc_mixed_widths IS
	--  GENERIC (
	--    g_nof_words : NATURAL := 1024;  -- FIFO size in nof wr_dat words
	--    g_wrdat_w   : NATURAL := 20;
	--    g_rddat_w   : NATURAL := 10
	--  );
	--  PORT (
	--    aclr    : IN STD_LOGIC  := '0';
	--    data    : IN STD_LOGIC_VECTOR (g_wrdat_w-1 DOWNTO 0);
	--    rdclk   : IN STD_LOGIC ;
	--    rdreq   : IN STD_LOGIC ;
	--    wrclk   : IN STD_LOGIC ;
	--    wrreq   : IN STD_LOGIC ;
	--    q       : OUT STD_LOGIC_VECTOR (g_rddat_w-1 DOWNTO 0);
	--    rdempty : OUT STD_LOGIC ;
	--    rdusedw : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words*g_wrdat_w/g_rddat_w)-1 DOWNTO 0);
	--    wrfull  : OUT STD_LOGIC ;
	--    wrusedw : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words)-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--  
	--  -----------------------------------------------------------------------------
	--  -- ip_arria10_e1sg
	--  -----------------------------------------------------------------------------
	--  
	--  COMPONENT ip_arria10_e1sg_fifo_sc IS
	--  GENERIC (
	--    g_use_eab   : STRING := "ON";
	--    g_dat_w     : NATURAL := 20;
	--    g_nof_words : NATURAL := 1024
	--  );
	--  PORT (
	--    aclr    : IN STD_LOGIC ;
	--    clock   : IN STD_LOGIC ;
	--    data    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    rdreq   : IN STD_LOGIC ;
	--    wrreq   : IN STD_LOGIC ;
	--    empty   : OUT STD_LOGIC ;
	--    full    : OUT STD_LOGIC ;
	--    q       : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0) ;
	--    usedw   : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words)-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--
	--  COMPONENT ip_arria10_e1sg_fifo_dc IS
	--  GENERIC (
	--    g_use_eab   : STRING := "ON";
	--    g_dat_w     : NATURAL := 20;
	--    g_nof_words : NATURAL := 1024
	--  );
	--  PORT (
	--    aclr    : IN STD_LOGIC  := '0';
	--    data    : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    rdclk   : IN STD_LOGIC ;
	--    rdreq   : IN STD_LOGIC ;
	--    wrclk   : IN STD_LOGIC ;
	--    wrreq   : IN STD_LOGIC ;
	--    q       : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
	--    rdempty : OUT STD_LOGIC ;
	--    rdusedw : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words)-1 DOWNTO 0);
	--    wrfull  : OUT STD_LOGIC ;
	--    wrusedw : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words)-1 DOWNTO 0)
	--  );
	--  END COMPONENT;
	--  
	--  COMPONENT ip_arria10_e1sg_fifo_dc_mixed_widths IS
	--  GENERIC (
	--    g_nof_words : NATURAL := 1024;  -- FIFO size in nof wr_dat words
	--    g_wrdat_w   : NATURAL := 20;
	--    g_rddat_w   : NATURAL := 10
	--  );
	--  PORT (
	--    aclr    : IN STD_LOGIC  := '0';
	--    data    : IN STD_LOGIC_VECTOR (g_wrdat_w-1 DOWNTO 0);
	--    rdclk   : IN STD_LOGIC ;
	--    rdreq   : IN STD_LOGIC ;
	--    wrclk   : IN STD_LOGIC ;
	--    wrreq   : IN STD_LOGIC ;
	--    q       : OUT STD_LOGIC_VECTOR (g_rddat_w-1 DOWNTO 0);
	--    rdempty : OUT STD_LOGIC ;
	--    rdusedw : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words*g_wrdat_w/g_rddat_w)-1 DOWNTO 0);
	--    wrfull  : OUT STD_LOGIC ;
	--    wrusedw : OUT STD_LOGIC_VECTOR (ceil_log2(g_nof_words)-1 DOWNTO 0)
	--  );
	--  END COMPONENT;

END tech_fifo_component_pkg;
