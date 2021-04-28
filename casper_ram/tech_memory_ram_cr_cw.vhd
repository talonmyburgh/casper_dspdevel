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

LIBRARY ieee, technology_lib;
USE ieee.std_logic_1164.all;
USE work.tech_memory_component_pkg.ALL;
USE technology_lib.technology_select_pkg.ALL;

-- Declare IP libraries to ensure default binding in simulation. The IP library clause is ignored by synthesis.
--LIBRARY ip_stratixiv_ram_lib;
--LIBRARY ip_arria10_ram_lib;
--LIBRARY ip_arria10_e3sge3_ram_lib;
--LIBRARY ip_arria10_e1sg_ram_lib;

ENTITY tech_memory_ram_cr_cw IS
	GENERIC(
		g_adr_w         : NATURAL := 10;
		g_dat_w         : NATURAL := 22;
		g_nof_words     : NATURAL := 2**5;
		g_rd_latency    : NATURAL := 2; -- choose 1 or 2
		g_init_file     : STRING  := "UNUSED";
		g_ram_primitive : STRING  := "auto"
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
END tech_memory_ram_cr_cw;

ARCHITECTURE str OF tech_memory_ram_cr_cw IS

BEGIN

	gen_ip_xpm : IF c_tech_select_default = c_tech_xpm GENERATE  -- Xilinx
		u1 : ip_xpm_ram_cr_cw
			generic map(
				g_adr_w         => g_adr_w,
				g_dat_w         => g_dat_w,
				g_nof_words     => g_nof_words,
				g_rd_latency    => g_rd_latency,
				g_init_file     => g_init_file,
				g_ram_primitive => g_ram_primitive
			)
			port map(
				data      => data,
				rdaddress => rdaddress,
				rdclock   => rdclock,
				rdclocken => rdclocken,
				wraddress => wraddress,
				wrclock   => wrclock,
				wrclocken => wrclocken,
				wren      => wren,
				q         => q
			);
	END GENERATE;

	gen_ip_stratixiv : IF c_tech_select_default = c_tech_stratixiv GENERATE  -- Intel Altera on UniBoard1
		u0 : ip_stratixiv_ram_cr_cw
			GENERIC MAP(g_adr_w, g_dat_w, g_nof_words, g_rd_latency, g_init_file)
			PORT MAP(data, rdaddress, rdclock, rdclocken, wraddress, wrclock, wrclocken, wren, q);
	END GENERATE;

END ARCHITECTURE;
