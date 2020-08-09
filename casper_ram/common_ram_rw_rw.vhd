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

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE work.common_ram_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

ENTITY common_ram_rw_rw IS
	GENERIC(
		g_technology     : NATURAL := 0;
		g_ram            : t_c_mem := c_mem_ram;
		g_init_file      : STRING  := "UNUSED";
		g_true_dual_port : BOOLEAN := TRUE;
		g_ram_primitive  : STRING  := "auto"
	);
	PORT(
		rst      : IN  STD_LOGIC                                  := '0';
		clk      : IN  STD_LOGIC;
		clken    : IN  STD_LOGIC                                  := '1';
		wr_en_a  : IN  STD_LOGIC                                  := '0';
		wr_en_b  : IN  STD_LOGIC                                  := '0';
		wr_dat_a : IN  STD_LOGIC_VECTOR(g_ram.dat_w - 1 DOWNTO 0) := (OTHERS => '0');
		wr_dat_b : IN  STD_LOGIC_VECTOR(g_ram.dat_w - 1 DOWNTO 0) := (OTHERS => '0');
		adr_a    : IN  STD_LOGIC_VECTOR(g_ram.adr_w - 1 DOWNTO 0) := (OTHERS => '0');
		adr_b    : IN  STD_LOGIC_VECTOR(g_ram.adr_w - 1 DOWNTO 0) := (OTHERS => '0');
		rd_en_a  : IN  STD_LOGIC                                  := '1';
		rd_en_b  : IN  STD_LOGIC                                  := '1';
		rd_dat_a : OUT STD_LOGIC_VECTOR(g_ram.dat_w - 1 DOWNTO 0);
		rd_dat_b : OUT STD_LOGIC_VECTOR(g_ram.dat_w - 1 DOWNTO 0);
		rd_val_a : OUT STD_LOGIC;
		rd_val_b : OUT STD_LOGIC
	);
END common_ram_rw_rw;

ARCHITECTURE str OF common_ram_rw_rw IS

BEGIN

	-- Use only one clock domain

	u_crw_crw : ENTITY work.common_ram_crw_crw
		GENERIC MAP(
			g_technology     => g_technology,
			g_ram            => g_ram,
			g_init_file      => g_init_file,
			g_true_dual_port => g_true_dual_port,
			g_ram_primitive  => g_ram_primitive
		)
		PORT MAP(
			rst_a    => rst,
			rst_b    => rst,
			clk_a    => clk,
			clk_b    => clk,
			clken_a  => clken,
			clken_b  => clken,
			wr_en_a  => wr_en_a,
			wr_en_b  => wr_en_b,
			wr_dat_a => wr_dat_a,
			wr_dat_b => wr_dat_b,
			adr_a    => adr_a,
			adr_b    => adr_b,
			rd_en_a  => rd_en_a,
			rd_en_b  => rd_en_b,
			rd_dat_a => rd_dat_a,
			rd_dat_b => rd_dat_b,
			rd_val_a => rd_val_a,
			rd_val_b => rd_val_b
		);

END str;
