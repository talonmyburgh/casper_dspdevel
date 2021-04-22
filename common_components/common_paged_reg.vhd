-------------------------------------------------------------------------------
--
-- Copyright (C) 2009
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-------------------------------------------------------------------------------

-- Purpose: Multi page register
-- Description:
--   The input wr_dat is written to the first data page. The output out_dat is
--   read from the last data page. The wr_en vector determines when the data
--   page is passed on to the next data page.
-- Remarks:

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

ENTITY common_paged_reg IS
  GENERIC (
    g_data_w     : NATURAL := 8;
    g_nof_pages  : NATURAL := 2   -- >= 0
  );
  PORT (
    rst          : IN  STD_LOGIC := '0';
    clk          : IN  STD_LOGIC;
    wr_en        : IN  STD_LOGIC_VECTOR(g_nof_pages-1 DOWNTO 0);
    wr_dat       : IN  STD_LOGIC_VECTOR(g_data_w-1 DOWNTO 0);
    out_dat      : OUT STD_LOGIC_VECTOR(g_data_w-1 DOWNTO 0)
  );
END common_paged_reg;


ARCHITECTURE str OF common_paged_reg IS

  TYPE t_data IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(out_dat'RANGE);
  
  SIGNAL reg_dat  : t_data(g_nof_pages DOWNTO 0) := (OTHERS=>(OTHERS=>'0'));
  
BEGIN

  -- Wire input to first page and last page to output
  reg_dat(g_nof_pages) <= wr_dat;
  out_dat              <= reg_dat(0);
  
  -- Shift the intermediate data pages when enabled
  gen_pages : FOR I IN g_nof_pages-1 DOWNTO 0 GENERATE
    u_page : ENTITY work.common_pipeline
    GENERIC MAP (
      g_in_dat_w  => g_data_w,
      g_out_dat_w => g_data_w
    )
    PORT MAP (
      rst     => rst,
      clk     => clk,
      in_en   => wr_en(I),
      in_dat  => reg_dat(I+1),
      out_dat => reg_dat(I)
    );
  END GENERATE;
  
END str;
