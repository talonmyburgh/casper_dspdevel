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

LIBRARY ieee, common_pkg_lib, technology_lib;
USE ieee.std_logic_1164.all;
USE work.tech_fifo_component_pkg.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE technology_lib.technology_select_pkg.ALL;

-- Declare IP libraries to ensure default binding in simulation. The IP library clause is ignored by synthesis.
LIBRARY ip_xpm_fifo_lib;
LIBRARY ip_stratixiv_fifo_lib;

ENTITY tech_fifo_sc IS
	GENERIC(
		g_use_eab        : STRING  := "NO";
		g_dat_w          : NATURAL;
		g_nof_words      : NATURAL;
		g_fifo_primitive : STRING  := "auto"
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
END tech_fifo_sc;

ARCHITECTURE str OF tech_fifo_sc IS

BEGIN

	gen_ip_xpm : IF c_tech_select_default = c_tech_xpm GENERATE  -- Xilinx
		u1 : ip_xilinx_fifo_sc
			generic map(
				g_dat_w          => g_dat_w,
				g_nof_words      => g_nof_words,
				g_fifo_primitive => g_fifo_primitive
			)
			port map(
				aclr  => aclr,
				clock => clock,
				data  => data,
				rdreq => rdreq,
				wrreq => wrreq,
				empty => empty,
				full  => full,
				q     => q,
				usedw => usedw
			);
	END GENERATE;

	gen_ip_stratixiv : IF c_tech_select_default = c_tech_stratixiv or c_tech_select_default=c_test_agilex  GENERATE  -- Intel Altera on UniBoard1
		u0 : ip_stratixiv_fifo_sc
			GENERIC MAP(g_use_eab, g_dat_w, g_nof_words)
			PORT MAP(aclr, clock, data, rdreq, wrreq, empty, full, q, usedw);
	END GENERATE;

END ARCHITECTURE;
