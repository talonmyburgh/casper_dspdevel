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

-- Purpose: Add flow XON-XOFF control by flushing frames
-- Description:
-- . The in_siso.ready = out_siso.ready so passed on unchanged, to support
--   detailed output to input flow control per cycle. The in_siso.xon is
--   always '1', because the out_siso.xon is taken care of in this
--   dp_xonoff.vhd by flushing any in_sosi data when out_siso.xon = '0'.
--
-- . When g_bypass=TRUE then the in and out are wired and the component is void.
-- . When g_bypass=FALSE then:
--     The output is ON when flush='0'.
--     The output is OFF when flush='1'.
--     The transition from OFF to ON occurs after an in_sosi.eop so between frames
--     The transition from ON to OFF occurs after an in_sosi.eop so between frames
--     Thanks to frm_busy it is also possible to switch between frames, so it
--     is not necessary that first an eop occurs, before the xon can change. 
--     The possibility to switch xon at an eop is needed to be able to switch
--     xon in case there are no gaps between the frames.
-- . The primary control is via out_siso.xon, however there is an option to override
--   the out_siso.xon control and force the output to off by using force_xoff.
-- Remark:
-- . The output controls are not registered.
-- . The xon timing is not cycle critical therefor register flush to ease
--   timing closure
-- . Originally based on rad_frame_onoff from LOFAR RSP firmware

LIBRARY IEEE, dp_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;

ENTITY dp_xonoff IS
  GENERIC (
    g_bypass : BOOLEAN := FALSE
  );
  PORT (
    rst           : IN  STD_LOGIC;
    clk           : IN  STD_LOGIC;
    -- Frame in
    in_siso       : OUT t_dp_siso;
    in_sosi       : IN  t_dp_sosi;
    -- Frame out
    out_siso      : IN  t_dp_siso;  -- flush control via out_siso.xon
    out_sosi      : OUT t_dp_sosi;
    -- Optional override to force XOFF ('1' = enable override)
    force_xoff    : IN  STD_LOGIC := '0'
  );
END dp_xonoff;


ARCHITECTURE rtl OF dp_xonoff IS

  SIGNAL frm_busy     : STD_LOGIC;
  SIGNAL frm_busy_reg : STD_LOGIC;
  
  SIGNAL flush      : STD_LOGIC;
  SIGNAL nxt_flush  : STD_LOGIC;
  
  SIGNAL out_en     : STD_LOGIC;
  SIGNAL nxt_out_en : STD_LOGIC;
  
BEGIN

  gen_bypass : IF g_bypass=TRUE GENERATE
    in_siso  <= out_siso;
    out_sosi <= in_sosi;
  END GENERATE;
  
  no_bypass : IF g_bypass=FALSE GENERATE
    in_siso.ready <= out_siso.ready;  -- pass on ready for detailed flow control per cycle
    in_siso.xon <= '1';               -- upstream can remain on, because flush will handle out_siso.xon
    nxt_flush <= NOT out_siso.xon OR force_xoff; -- use xon for flow control at frame level
  
    p_clk: PROCESS(clk, rst)
    BEGIN
      IF rst='1' THEN
        frm_busy_reg <= '0';
        flush        <= '0';
        out_en       <= '1';
      ELSIF rising_edge(clk) THEN
        frm_busy_reg <= frm_busy;
        flush        <= nxt_flush;     -- pipeline register flush to ease timing closure
        out_en       <= nxt_out_en;    -- state register out_en because it can only change between frames
      END IF;
    END PROCESS;

    -- Detect in_sosi frame busy, frm_busy is '1' from sop including sop, until eop excluding eop
    p_frm_busy : PROCESS(in_sosi, in_sosi, frm_busy_reg)
    BEGIN
      frm_busy <= frm_busy_reg;
      IF in_sosi.sop='1' THEN
        frm_busy <= '1';
      ELSIF in_sosi.eop='1' THEN
        frm_busy <= '0';
      END IF;
    END PROCESS;

    p_out_en : PROCESS(flush, out_en, frm_busy)
    BEGIN
      nxt_out_en <= out_en;
      IF frm_busy='0' THEN
        IF flush='1' THEN
          nxt_out_en <= '0';
        ELSE
          nxt_out_en <= '1';
        END IF;
      END IF;    
    END PROCESS;
    
    p_out_sosi : PROCESS(in_sosi, out_en)
    BEGIN
      -- Pass on sosi data via wires
      out_sosi       <= in_sosi;
      
      -- XON/XOFF flow control via sosi control
      out_sosi.sync  <= in_sosi.sync  AND out_en;
      out_sosi.valid <= in_sosi.valid AND out_en;
      out_sosi.sop   <= in_sosi.sop   AND out_en;
      out_sosi.eop   <= in_sosi.eop   AND out_en;
    END PROCESS;
  END GENERATE;
  
END ARCHITECTURE;
