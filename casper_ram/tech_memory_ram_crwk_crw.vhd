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
LIBRARY ip_xpm_ram_lib;
LIBRARY ip_stratixiv_ram_lib;

ENTITY tech_memory_ram_crwk_crw IS      -- support different port data widths and corresponding address ranges
	GENERIC(
		g_adr_a_w       : NATURAL := 11;
		g_dat_a_w       : NATURAL := 18;
		g_adr_b_w       : NATURAL := 11;
		g_dat_b_w       : NATURAL := 14;
		g_nof_words_a   : NATURAL := 2**5;
		g_nof_words_b   : NATURAL := 2**7;
		g_rd_latency    : NATURAL := 2; -- choose 1 or 2
		g_init_file     : STRING  := "UNUSED";
		g_ram_primitive : STRING  := "auto"
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
END tech_memory_ram_crwk_crw;

ARCHITECTURE str OF tech_memory_ram_crwk_crw IS
BEGIN

	gen_ip_xpm : IF (c_tech_select_default = c_tech_xpm or c_tech_select_default=c_tech_versal) GENERATE  -- Xilinx
		u1 : ip_xpm_ram_crwk_crw
			generic map(
				g_adr_a_w       => g_adr_a_w,
				g_dat_a_w       => g_dat_a_w,
				g_adr_b_w       => g_adr_b_w,
				g_dat_b_w       => g_dat_b_w,
				g_nof_words_a   => g_nof_words_a,
				g_nof_words_b   => g_nof_words_b,
				g_rd_latency    => g_rd_latency,
				g_init_file     => g_init_file,
				g_ram_primitive => g_ram_primitive
			)
			port map(
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

	gen_ip_stratixiv : IF c_tech_select_default = c_tech_stratixiv or c_tech_select_default = c_tech_agilex GENERATE  -- Intel Altera on UniBoard1
	    u0 : ip_stratixiv_ram_crwk_crw
	    GENERIC MAP (g_adr_a_w, g_dat_a_w, g_adr_b_w, g_dat_b_w, g_nof_words_a, g_nof_words_b, g_rd_latency, g_init_file)
	    PORT MAP (address_a, address_b, clock_a, clock_b, data_a, data_b, enable_a, enable_b, rden_a, rden_b, wren_a, wren_b, q_a, q_b);
	END GENERATE;

END ARCHITECTURE;
