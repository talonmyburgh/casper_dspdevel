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

-- Purpose: Scope component to show the arrayed DP SOSI data at the SCLK
--          sample rate
-- Description:
--   The SCLK rate is g_wideband_factor faster than the DCLK rate. The input
--   is one wideband stream that is carried by an array of g_wideband_factor
--   sosi streams at the DCLK rate. The output is a single sosi integer stream
--   at the SCLK rate.
-- Remark:
-- . Only for simulation.
-- . When g_use_sclk=TRUE then the input SCLK is used. Else the SCLK is derived
--   from the DCLK so that it does not have to be applied via an input. This
--   eases the use of this scope within a design.
-- . In this dp_wideband_wb_arr_scope the input is only one wideband stream
--   and the input sosi array has size g_wideband_factor, so the wideband
--   data is carried via the sosi array dimension.
--   In dp_wideband_sp_arr_scope the input is one or more wideband streams
--   and the input sosi array has size g_nof_streams, so there the wideband
--   data is carried by g_wideband_factor concatenated symbols in the data
--   field or in the (re, im) fields.


LIBRARY IEEE, common_pkg_lib, dp_pkg_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;

ENTITY dp_wideband_wb_arr_scope IS
  GENERIC (
    g_sim                 : BOOLEAN := FALSE;
    g_use_sclk            : BOOLEAN := TRUE;
    g_wideband_factor     : NATURAL := 4;        -- Wideband rate factor = 4 for dp_clk processing frequency is 200 MHz frequency and SCLK sample frequency Fs is 800 MHz
    g_wideband_big_endian : BOOLEAN := FALSE;    -- When true wb_sosi_arr[3:0] = sample[t0,t1,t2,t3], else when false : wb_sosi_arr[3:0] = sample[t3,t2,t1,t0]
    g_dat_w               : NATURAL := 8         -- Actual width of the data field or of the re field, im field
  );
  PORT (
    -- Digital processing clk
    DCLK         : IN STD_LOGIC := '0';
    
    -- Sampling clk, for simulation only
    SCLK         : IN STD_LOGIC := '0';   -- SCLK rate = g_wideband_factor * DCLK rate
    
    -- Streaming input samples for one stream
    wb_sosi_arr  : IN t_dp_sosi_arr(g_wideband_factor-1 DOWNTO 0);   -- = [3:0] = Signal Path time samples [t3,t2,t1,t0]
    
    -- Scope output samples for one stream
    scope_sosi   : OUT t_dp_sosi_integer
  );
END dp_wideband_wb_arr_scope;


ARCHITECTURE beh OF dp_wideband_wb_arr_scope IS

  SIGNAL SCLKi        : STD_LOGIC;  -- sampling clk, for simulation only
  SIGNAL sample_cnt   : NATURAL RANGE 0 TO g_wideband_factor-1 := 0;
  SIGNAL st_sosi      : t_dp_sosi;
  
BEGIN

  sim_only : IF g_sim=TRUE GENERATE
    use_sclk : IF g_use_sclk=TRUE GENERATE
      SCLKi <= SCLK;  -- no worry about the delta cycle delay from SCLK to SCLKi
    END GENERATE;
    gen_sclk : IF g_use_sclk=FALSE GENERATE
      proc_common_dclk_generate_sclk(g_wideband_factor, DCLK, SCLKi);
    END GENERATE;
  
    -- View wb_sosi_arr at the sample rate using st_sosi
    p_st_sosi : PROCESS(SCLKi)
    BEGIN
      IF rising_edge(SCLKi) THEN
        IF g_wideband_big_endian=TRUE THEN
          st_sosi <= wb_sosi_arr(g_wideband_factor-1-sample_cnt);
        ELSE
          st_sosi <= wb_sosi_arr(sample_cnt);
        END IF;
        sample_cnt <= 0;
        IF wb_sosi_arr(0).valid='1' AND sample_cnt < g_wideband_factor-1 THEN  -- all wb_sosi_arr().valid are the same, so use (0)
          sample_cnt <= sample_cnt + 1;
        END IF;
      END IF;
    END PROCESS;
      
    -- Map sosi to SLV of actual g_dat_w to allow observation in Wave Window in analogue format
    scope_sosi <= func_dp_stream_slv_to_integer(st_sosi, g_dat_w);
  END GENERATE;
  
END beh;
