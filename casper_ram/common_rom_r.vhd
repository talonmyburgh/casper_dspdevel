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

LIBRARY IEEE, common_pkg_lib, common_components_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE work.common_ram_pkg.ALL;

ENTITY common_rom_r IS
	GENERIC(
		g_ram            : t_c_mem := c_mem_ram;
		g_init_file      : STRING  := "UNUSED";
		g_ram_primitive  : STRING  := "auto"
	);
	PORT(
		clk    : IN  STD_LOGIC;
		clken  : IN  STD_LOGIC                                  := '1';
		adr    : IN  STD_LOGIC_VECTOR(g_ram.adr_w - 1 DOWNTO 0) := (OTHERS => '0');
		rd_en  : IN  STD_LOGIC                                  := '1';
		rd_dat : OUT STD_LOGIC_VECTOR(g_ram.dat_w - 1 DOWNTO 0);
		rd_val : OUT STD_LOGIC
	);
END common_rom_r;

ARCHITECTURE str OF common_rom_r IS

BEGIN

	-- Single port
	u_cr_cr : ENTITY work.common_rom_r_r
	GENERIC MAP(
		g_ram => g_ram,
		g_init_file => g_init_file,
		g_true_dual_port => FALSE,
		g_ram_primitive => g_ram_primitive
	)
	PORT MAP(
		clk => clk,
		clken => clken,
		adr_a => adr,
		adr_b => (others =>'0'),
		rd_en_a => rd_en,
		rd_en_b => '0',
		rd_dat_a => rd_dat,
		rd_dat_b => open,
		rd_val_a => rd_val,
		rd_val_b => open	
		);
END str;
