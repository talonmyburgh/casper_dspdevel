-------------------------------------------------------------------------------
--
-- Copyright (C) 2017
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- JIVE (Joint Institute for VLBI in Europe) <http://www.jive.nl/>
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

LIBRARY IEEE, common_pkg_lib, common_components_lib, dp_pkg_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;

-- Author: Eric Kooistra, 17 nov 2017
-- Purpose:
--   Restore global BSN.
-- Description:
--   The input global BSN is active at the sync. In between sync the other BSN
--   BSN at the sop may count a local BSN that restarted at 0 for every sync.
--   This dp_bsn_restore_global takes the BSN at the sync and starts counting
--   from there for every sop, so in this way it restores the global BSN count
--   for the blocks in between syncs.
--   The increment for each restored BSN is 1. The assumption is that the
--   number of blocks between syncs equals the difference in global BSN values
--   between syncs. In this way the restored BSN counts without gaps or
--   duplicates.
-- Remarks:

ENTITY dp_bsn_restore_global IS
  GENERIC (
    g_bsn_w    : NATURAL := c_dp_stream_bsn_w;
    g_pipeline : NATURAL := 1  -- 0 for wires, > 0 for registers
  );
  PORT (
    rst          : IN  STD_LOGIC;
    clk          : IN  STD_LOGIC;
    -- ST sink
    snk_out      : OUT t_dp_siso;
    snk_in       : IN  t_dp_sosi;
    -- ST source
    src_in       : IN  t_dp_siso := c_dp_siso_rdy;
    src_out      : OUT t_dp_sosi
  );
END dp_bsn_restore_global;


ARCHITECTURE str OF dp_bsn_restore_global IS

  SIGNAL blk_sync          : STD_LOGIC;
  SIGNAL bsn_at_sync       : STD_LOGIC_VECTOR(g_bsn_w-1 DOWNTO 0);
  SIGNAL nxt_bsn_at_sync   : STD_LOGIC_VECTOR(g_bsn_w-1 DOWNTO 0);
  SIGNAL bsn_restored      : STD_LOGIC_VECTOR(g_bsn_w-1 DOWNTO 0);
  SIGNAL snk_in_restored   : t_dp_sosi;
  
BEGIN

  -- keep BSN at sync
  p_clk : PROCESS(clk, rst)
  BEGIN
    IF rst='1' THEN
      bsn_at_sync <= (OTHERS=>'0');
    ELSIF rising_edge(clk) THEN
      bsn_at_sync <= nxt_bsn_at_sync;
    END IF;
  END PROCESS;
  
  -- Store global BSN at sync
  nxt_bsn_at_sync <= snk_in.bsn(g_bsn_w-1 DOWNTO 0) WHEN snk_in.sync='1' ELSE bsn_at_sync;
  
  -- Create block sync from snk_in.sync, this blk_sync is active during entire first sop-eop block of sync interval
  u_common_switch : ENTITY common_components_lib.common_switch
  GENERIC MAP (
    g_rst_level    => '0',    -- Defines the output level at reset.
    g_priority_lo  => FALSE,  -- When TRUE then input switch_low has priority, else switch_high. Don't care when switch_high and switch_low are pulses that do not occur simultaneously.
    g_or_high      => TRUE,   -- When TRUE and priority hi then the registered switch_level is OR-ed with the input switch_high to get out_level, else out_level is the registered switch_level
    g_and_low      => FALSE   -- When TRUE and priority lo then the registered switch_level is AND-ed with the input switch_low to get out_level, else out_level is the registered switch_level
  )
  PORT MAP (
    rst         => rst,
    clk         => clk,
    switch_high => snk_in.sync,   -- A pulse on switch_high makes the out_level go high
    switch_low  => snk_in.eop,    -- A pulse on switch_low makes the out_level go low
    out_level   => blk_sync
  );
  
  -- Use stored global BSN at sync and add local BSN to restore the global BSN for every next sop
  bsn_restored <= snk_in.bsn WHEN blk_sync='1' ELSE ADD_UVEC(bsn_at_sync, snk_in.bsn, g_bsn_w);  
  
  snk_in_restored <= func_dp_stream_bsn_set(snk_in, bsn_restored);
  
  -- Add pipeline to ensure timing closure for the restored BSN summation
  u_pipeline : ENTITY work.dp_pipeline
  GENERIC MAP (
    g_pipeline => g_pipeline  -- 0 for wires, > 0 for registers
  )
  PORT MAP (
    rst         => rst,
    clk         => clk,
    -- ST sink
    snk_out     => snk_out,
    snk_in      => snk_in_restored,
    -- ST source
    src_in      => src_in,
    src_out     => src_out
  );
  
END str;
