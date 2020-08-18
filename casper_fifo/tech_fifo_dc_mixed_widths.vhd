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

LIBRARY ieee, common_pkg_lib;
USE ieee.std_logic_1164.all;
USE work.tech_fifo_component_pkg.ALL;
USE common_pkg_lib.common_pkg.ALL;

--USE technology_lib.technology_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

-- Declare IP libraries to ensure default binding in simulation. The IP library clause is ignored by synthesis.
--LIBRARY ip_stratixiv_fifo_lib;
--LIBRARY ip_arria10_fifo_lib;
--LIBRARY ip_arria10_e3sge3_fifo_lib;
--LIBRARY ip_arria10_e1sg_fifo_lib;

ENTITY tech_fifo_dc_mixed_widths IS
	GENERIC(
		g_technology     : NATURAL := 0; --c_tech_select_default;
		g_nof_words      : NATURAL := 16; -- FIFO size in nof wr_dat words
		g_wrdat_w        : NATURAL := 12;
		g_rddat_w        : NATURAL := 10;
		g_fifo_primitive : STRING  := "auto"
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
END tech_fifo_dc_mixed_widths;

ARCHITECTURE str OF tech_fifo_dc_mixed_widths IS

BEGIN
	gen_ip_xilinx : IF g_technology = 0 GENERATE
		u0 : component ip_xilinx_fifo_dc_mixed_widths
			generic map(
				g_nof_words      => g_nof_words,
				g_wrdat_w        => g_wrdat_w,
				g_rddat_w        => g_rddat_w,
				g_fifo_primitive => g_fifo_primitive
			)
			port map(
				aclr    => aclr,
				data    => data,
				rdclk   => rdclk,
				rdreq   => rdreq,
				wrclk   => wrclk,
				wrreq   => wrreq,
				q       => q,
				rdempty => rdempty,
				rdusedw => rdusedw,
				wrfull  => wrfull,
				wrusedw => wrusedw
			);
	END GENERATE;

	gen_ip_stratixiv : IF g_technology = 1 GENERATE
		u0 : ip_stratixiv_fifo_dc_mixed_widths
			GENERIC MAP(g_nof_words, g_wrdat_w, g_rddat_w)
			PORT MAP(aclr, data, rdclk, rdreq, wrclk, wrreq, q, rdempty, rdusedw, wrfull, wrusedw);
	END GENERATE;

	--  gen_ip_arria10 : IF g_technology=c_tech_arria10 GENERATE
	--    u0 : ip_arria10_fifo_dc_mixed_widths
	--    GENERIC MAP (g_nof_words, g_wrdat_w, g_rddat_w)
	--    PORT MAP (aclr, data, rdclk, rdreq, wrclk, wrreq, q, rdempty, rdusedw, wrfull, wrusedw);
	--  END GENERATE;
	--
	--  gen_ip_arria10_e3sge3 : IF g_technology=c_tech_arria10_e3sge3 GENERATE
	--    u0 : ip_arria10_e3sge3_fifo_dc_mixed_widths
	--    GENERIC MAP (g_nof_words, g_wrdat_w, g_rddat_w)
	--    PORT MAP (aclr, data, rdclk, rdreq, wrclk, wrreq, q, rdempty, rdusedw, wrfull, wrusedw);
	--  END GENERATE;
	--  
	--  gen_ip_arria10_e1sg : IF g_technology=c_tech_arria10_e1sg GENERATE
	--    u0 : ip_arria10_e1sg_fifo_dc_mixed_widths
	--    GENERIC MAP (g_nof_words, g_wrdat_w, g_rddat_w)
	--    PORT MAP (aclr, data, rdclk, rdreq, wrclk, wrreq, q, rdempty, rdusedw, wrfull, wrusedw);
	--  END GENERATE;

END ARCHITECTURE;
