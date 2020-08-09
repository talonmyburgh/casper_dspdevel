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

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE work.tech_memory_component_pkg.ALL;
--USE technology_lib.technology_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

-- Declare IP libraries to ensure default binding in simulation. The IP library clause is ignored by synthesis.
--LIBRARY ip_stratixiv_ram_lib;
--LIBRARY ip_arria10_ram_lib;
--LIBRARY ip_arria10_e3sge3_ram_lib;
--LIBRARY ip_arria10_e1sg_ram_lib;

ENTITY tech_memory_ram_crw_crw IS
	GENERIC(
		g_technology    : NATURAL := 0; --c_tech_select_default;
		g_adr_w         : NATURAL := 10;
		g_dat_w         : NATURAL := 18;
		g_nof_words     : NATURAL := 2**5;
		g_rd_latency    : NATURAL := 2; -- choose 1 or 2
		g_init_file     : STRING  := "UNUSED";
		g_ram_primitive : STRING  := "auto"
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
END tech_memory_ram_crw_crw;

ARCHITECTURE str OF tech_memory_ram_crw_crw IS

BEGIN
	gen_ip_xilinx : IF g_technology = 0 GENERATE
		u1 : ip_xpm_ram_crw_crw
			generic map(
				g_adr_w         => g_adr_w,
				g_dat_w         => g_dat_w,
				g_nof_words     => g_nof_words,
				g_rd_latency    => g_rd_latency,
				g_init_file     => g_init_file,
				g_ram_primitive => g_ram_primitive
			)
			port map(
				rst_a     => rst_a,
				rst_b     => rst_b,
				address_a => address_a,
				address_b => address_b,
				clock_a   => clock_a,
				clock_b   => clock_b,
				data_a    => data_a,
				data_b    => data_b,
				enable_a  => enable_a,
				enable_b  => enable_b,
				rden_a    => rden_a,
				rden_b    => rden_b,
				wren_a    => wren_a,
				wren_b    => wren_b,
				q_a       => q_a,
				q_b       => q_b
			);
	END GENERATE;

	--
	--	gen_ip_stratixiv : IF g_technology = 0 GENERATE
	--		u0 : ip_stratixiv_ram_crw_crw
	--			GENERIC MAP(g_adr_w, g_dat_w, g_nof_words, g_rd_latency, g_init_file)
	--			PORT MAP(address_a, address_b, clock_a, clock_b, data_a, data_b, enable_a, enable_b, rden_a, rden_b, wren_a, wren_b, q_a, q_b);
	--	END GENERATE;

	--  gen_ip_arria10 : IF g_technology=c_tech_arria10 GENERATE
	--    u0 : ip_arria10_ram_crw_crw
	--    GENERIC MAP (FALSE, g_adr_w, g_dat_w, g_nof_words, g_rd_latency, g_init_file)
	--    PORT MAP (address_a, address_b, clock_a, clock_b, data_a, data_b, wren_a, wren_b, q_a, q_b);
	--  END GENERATE;
	--  
	--  gen_ip_arria10_e3sge3 : IF g_technology=c_tech_arria10_e3sge3 GENERATE
	--    u0 : ip_arria10_e3sge3_ram_crw_crw
	--    GENERIC MAP (FALSE, g_adr_w, g_dat_w, g_nof_words, g_rd_latency, g_init_file)
	--    PORT MAP (address_a, address_b, clock_a, clock_b, data_a, data_b, wren_a, wren_b, q_a, q_b);
	--  END GENERATE;
	--  
	--  gen_ip_arria10_e1sg : IF g_technology=c_tech_arria10_e1sg GENERATE
	--    u0 : ip_arria10_e1sg_ram_crw_crw
	--    GENERIC MAP (FALSE, g_adr_w, g_dat_w, g_nof_words, g_rd_latency, g_init_file)
	--    PORT MAP (address_a, address_b, clock_a, clock_b, data_a, data_b, wren_a, wren_b, q_a, q_b);
	--  END GENERATE;

END ARCHITECTURE;
