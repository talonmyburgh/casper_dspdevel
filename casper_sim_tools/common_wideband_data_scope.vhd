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

-- Purpose: Scope component to show the concateneated DP in_data at the SCLK
--          sample rate in the Wave Window
-- Description: 
-- . See dp_wideband_sp_arr_scope (for g_nof_streams=1)
-- . The wideband in_data has g_wideband_factor nof samples per word. For
--   g_wideband_big_endian=TRUE sthe first sample is in the MS symbol.
-- Remark:
-- . Only for simulation.
-- . When g_use_sclk=TRUE then the input SCLK is used. Else the SCLK is derived
--   from the DCLK so that it does not have to be applied via an input. This
--   eases the use of this scope within a design.

LIBRARY IEEE, common_pkg_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

ENTITY common_wideband_data_scope IS
  GENERIC (
    g_sim                 : BOOLEAN := FALSE;
    g_use_sclk            : BOOLEAN := TRUE;
    g_wideband_factor     : NATURAL := 4;        -- Wideband rate factor = 4 for dp_clk processing frequency is 200 MHz frequency and SCLK sample frequency Fs is 800 MHz
    g_wideband_big_endian : BOOLEAN := TRUE;     -- When true in_data[3:0] = sample[t0,t1,t2,t3], else when false : in_data[3:0] = sample[t3,t2,t1,t0]
    g_dat_w               : NATURAL := 8         -- Actual width of the data samples
  );
  PORT (
    -- Digital processing clk
    DCLK      : IN STD_LOGIC := '0';
    
    -- Sampling clk, for simulation only
    SCLK      : IN STD_LOGIC := '0';   -- SCLK rate = g_wideband_factor * DCLK rate
        
    -- Streaming input data
    in_data   : IN STD_LOGIC_VECTOR(g_wideband_factor*g_dat_w-1 DOWNTO 0);
    in_val    : IN STD_LOGIC;
    
    -- Scope output samples
    out_dat   : OUT STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);
    out_int   : OUT INTEGER;
    out_val   : OUT STD_LOGIC
  );  
END common_wideband_data_scope;


ARCHITECTURE beh OF common_wideband_data_scope IS

  SIGNAL SCLKi       : STD_LOGIC;  -- sampling clk, for simulation only
  SIGNAL scope_cnt   : NATURAL;
  SIGNAL scope_dat   : STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);
  
BEGIN

  sim_only : IF g_sim=TRUE GENERATE
    use_sclk : IF g_use_sclk=TRUE GENERATE
      SCLKi <= SCLK;  -- no worry about the delta cycle delay from SCLK to SCLKi
    END GENERATE;
    gen_sclk : IF g_use_sclk=FALSE GENERATE
      proc_common_dclk_generate_sclk(g_wideband_factor, DCLK, SCLKi);
    END GENERATE;
  
    -- View in_data at the sample rate using out_dat 
    p_scope_dat : PROCESS(SCLKi)
      VARIABLE vI : NATURAL;
    BEGIN
      IF rising_edge(SCLKi) THEN
        IF g_wideband_big_endian=TRUE THEN
          vI := g_wideband_factor-1-scope_cnt;
        ELSE
          vI := scope_cnt;
        END IF;
        scope_cnt <= 0;
        IF in_val='1' AND scope_cnt < g_wideband_factor-1 THEN
          scope_cnt <= scope_cnt + 1;
        END IF;
        scope_dat <= in_data((vI+1)*g_dat_w-1 DOWNTO vI*g_dat_w);
        out_val <= in_val;
      END IF;
    END PROCESS;
    
    out_dat <= scope_dat;
    out_int <= TO_SINT(scope_dat);
  END GENERATE;
  
END beh;
