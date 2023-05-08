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

LIBRARY ieee, technology_lib, ip_xpm_ram_lib;
USE ieee.std_logic_1164.all;
USE work.tech_memory_component_pkg.ALL;
USE technology_lib.technology_select_pkg.all;

--USE technology_lib.technology_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

-- Declare IP libraries to ensure default binding in simulation. The IP library clause is ignored by synthesis.
--LIBRARY ip_stratixiv_ram_lib;
--LIBRARY ip_arria10_ram_lib;
--LIBRARY ip_arria10_e3sge3_ram_lib;
--LIBRARY ip_arria10_e1sg_ram_lib;

ENTITY tech_memory_rom_r_r IS
	GENERIC(
		g_adr_a_w       : NATURAL := 10;
		g_adr_b_w       : NATURAL := 10;
		g_dat_w         : NATURAL := 22;
		g_nof_words     : NATURAL := 2**5;
		g_rd_latency    : NATURAL := 2; -- choose 1 or 2
		g_init_file     : STRING  := "UNUSED";
		g_ram_primitive : STRING  := "auto"
	);
	PORT(
		address_a : IN  STD_LOGIC_VECTOR(g_adr_a_w - 1 DOWNTO 0);
		address_b : IN  STD_LOGIC_VECTOR(g_adr_b_w - 1 DOWNTO 0);
		clock     : IN  STD_LOGIC;
		clocken   : IN  STD_LOGIC := '1';
		q_a         : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		q_B         : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0)
	);
END tech_memory_rom_r_r;

ARCHITECTURE str OF tech_memory_rom_r_r IS

BEGIN

	gen_ip_xilinx : IF (c_tech_select_default = c_tech_xpm or c_tech_select_default=c_tech_versal) GENERATE
		u1 : ip_xpm_rom_r_r
		GENERIC MAP (
			g_adr_a_w         => g_adr_a_w,
			g_adr_b_w         => g_adr_b_w,
			g_dat_w           => g_dat_w,
			g_nof_words       => g_nof_words,
			g_rd_latency      => g_rd_latency,
			g_init_file       => g_init_file,
			g_ram_primitive   => g_ram_primitive
		)
		PORT MAP (
			address_a => address_a,
			address_b => address_b,
			clock   => clock,
			clocken => clocken,
			q_a         => q_a,
			q_b         => q_b
		);
	else generate
		assert FALSE report "No rom Generated" severity failure;
	END GENERATE;
    
	--	gen_ip_stratixiv : IF g_technology = 0 GENERATE
	--		u0 : ip_stratixiv_rom_cr_cr
	--			GENERIC MAP(g_adr_w, g_dat_w, g_nof_words, g_rd_latency, g_init_file)
	--			PORT MAP(data, rdaddress, rdclock, rdclocken, wraddress, wrclock, wrclocken, wren, q);
	--	END GENERATE;

	--  gen_ip_arria10 : IF g_technology=c_tech_arria10 GENERATE
	--    u0 : ip_arria10_rom_cr_cr
	--    GENERIC MAP (FALSE, g_adr_w, g_dat_w, g_nof_words, g_rd_latency, g_init_file)
	--    PORT MAP (data, rdaddress, rdclock, wraddress, wrclock, wren, q);
	--  END GENERATE;
	--  
	--  gen_ip_arria10_e3sge3 : IF g_technology=c_tech_arria10_e3sge3 GENERATE
	--    u0 : ip_arria10_e3sge3_rom_cr_cr
	--    GENERIC MAP (FALSE, g_adr_w, g_dat_w, g_nof_words, g_rd_latency, g_init_file)
	--    PORT MAP (data, rdaddress, rdclock, wraddress, wrclock, wren, q);
	--  END GENERATE;
	--  
	--  gen_ip_arria10_e1sg : IF g_technology=c_tech_arria10_e1sg GENERATE
	--    u0 : ip_arria10_e1sg_rom_cr_cr
	--    GENERIC MAP (FALSE, g_adr_w, g_dat_w, g_nof_words, g_rd_latency, g_init_file)
	--    PORT MAP (data, rdaddress, rdclock, wraddress, wrclock, wren, q);
	--  END GENERATE;

END ARCHITECTURE;
