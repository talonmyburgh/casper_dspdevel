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

LIBRARY IEEE, common_pkg_lib, common_components_lib, casper_adder_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;


-- Purpose:
--   Accumulate input data to an accumulator that is stored externally. In this
--   way blocks of input samples (e.g. subband products) can be accumulated to
--   a set of external accumulators. At the in_load the accumulator input value
--   is ignored so that the accumulation restarts with the in_dat.
--
-- Description:
--   if in_load = '1' then
--     out_acc = in_dat + 0         -- restart accumulation
--   else
--     out_acc = in_dat + in_acc    -- accumulate
--
-- Remarks:
-- . in_val propagates to out_val after the pipeline latency but does not 
--   affect the sum

ENTITY st_acc IS
  GENERIC (
    g_dat_w            : NATURAL;
    g_acc_w            : NATURAL;  -- g_acc_w >= g_dat_w
    g_hold_load        : BOOLEAN := TRUE;
    g_pipeline_input   : NATURAL;  -- 0 no input registers, else register input after in_load
    g_pipeline_output  : NATURAL   -- pipeline for the adder
  );
  PORT (
    clk         : IN  STD_LOGIC;
    clken       : IN  STD_LOGIC := '1';
    in_load     : IN  STD_LOGIC;
    in_dat      : IN  STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);
    in_acc      : IN  STD_LOGIC_VECTOR(g_acc_w-1 DOWNTO 0);
    in_val      : IN  STD_LOGIC := '1';
    out_acc     : OUT STD_LOGIC_VECTOR(g_acc_w-1 DOWNTO 0);
    out_val     : OUT STD_LOGIC
  );
END st_acc;


ARCHITECTURE rtl OF st_acc IS
  
  CONSTANT c_pipeline  : NATURAL := g_pipeline_input + g_pipeline_output;
  
  -- Input signals
  SIGNAL hld_load        : STD_LOGIC := '0';
  SIGNAL nxt_hld_load    : STD_LOGIC;
  SIGNAL acc_clr        : STD_LOGIC;
  
  SIGNAL reg_dat        : STD_LOGIC_VECTOR(g_acc_w-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL nxt_reg_dat    : STD_LOGIC_VECTOR(g_acc_w-1 DOWNTO 0);
  SIGNAL reg_acc        : STD_LOGIC_VECTOR(g_acc_w-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL nxt_reg_acc    : STD_LOGIC_VECTOR(g_acc_w-1 DOWNTO 0);
  
  -- Pipeline control signals, map to slv to be able to use common_pipeline
  SIGNAL in_val_slv     : STD_LOGIC_VECTOR(0 DOWNTO 0);
  SIGNAL out_val_slv    : STD_LOGIC_VECTOR(0 DOWNTO 0);
  
BEGIN

  ASSERT NOT(g_acc_w < g_dat_w)
    REPORT "st_acc: output accumulator width must be >= input data width"
    SEVERITY FAILURE;
    
  ------------------------------------------------------------------------------
  -- Input load control
  ------------------------------------------------------------------------------
  
  p_clk : PROCESS(clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF clken='1' THEN
        hld_load <= nxt_hld_load;
      END IF;
    END IF;
  END PROCESS;
  
  nxt_hld_load <= in_load WHEN in_val='1' ELSE hld_load;

  -- Hold in_load to save power by avoiding unneccessary out_acc toggling when in_val goes low  
  -- . For g_pipeline_input>0 this is fine
  -- . For g_pipeline_input=0 this may cause difficulty in achieving timing closure for synthesis
  use_in_load : IF g_hold_load = FALSE GENERATE
    acc_clr <= in_load;  -- the in_load may already be extended during in_val
  END GENERATE;
  use_hld_load : IF g_hold_load = TRUE GENERATE
    acc_clr <= in_load OR (hld_load AND NOT in_val);
  END GENERATE;
  
  -- Do not use g_pipeline_input of u_adder, to allow registered acc clear if g_pipeline_input=1
  nxt_reg_dat <= RESIZE_SVEC(in_dat, g_acc_w);
  nxt_reg_acc <= in_acc WHEN acc_clr='0' ELSE (OTHERS=>'0');
  
  no_input_reg : IF g_pipeline_input=0 GENERATE
    reg_dat <= nxt_reg_dat;
    reg_acc <= nxt_reg_acc;
  END GENERATE;
  gen_input_reg : IF g_pipeline_input>0 GENERATE
    p_reg : PROCESS(clk)
    BEGIN
      IF rising_edge(clk) THEN
        IF clken='1' THEN
          reg_dat <= nxt_reg_dat;
          reg_acc <= nxt_reg_acc;
        END IF;
      END IF;
    END PROCESS;
  END GENERATE;
  
  
  ------------------------------------------------------------------------------
  -- Adder for the external accumulator
  ------------------------------------------------------------------------------
  
  u_adder : ENTITY casper_adder_lib.common_add_sub
  GENERIC MAP (
    g_direction       => "ADD",
    g_representation  => "SIGNED",  -- not relevant because g_out_dat_w = g_in_dat_w
    g_pipeline_input  => 0,
    g_pipeline_output => g_pipeline_output,
    g_in_dat_w        => g_acc_w,
    g_out_dat_w       => g_acc_w
  )
  PORT MAP (
    clk     => clk,
    clken   => clken,
    in_a    => reg_dat,
    in_b    => reg_acc,
    result  => out_acc
  );
  
  
  ------------------------------------------------------------------------------
  -- Parallel output control pipeline
  ------------------------------------------------------------------------------
  
  in_val_slv(0) <= in_val;
  out_val       <= out_val_slv(0);
    
  u_out_val : ENTITY common_components_lib.common_pipeline
  GENERIC MAP (
    g_representation => "UNSIGNED",
    g_pipeline       => c_pipeline,
    g_reset_value    => 0,
    g_in_dat_w       => 1,
    g_out_dat_w      => 1
  )
  PORT MAP (
    clk     => clk,
    clken   => clken,
    in_dat  => slv(in_val),
    out_dat => out_val_slv
  );
  
END rtl;
