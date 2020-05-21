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

LIBRARY IEEE, common_pkg_lib, dp_pkg_lib, dp_components_lib;
USE IEEE.std_logic_1164.all;
USE dp_pkg_lib.dp_stream_pkg.ALL;

-- Purpose:
--   Pipeline the source input
-- Description:
--   This dp_pipeline_ready provides a single clock cycle delay of the source
--   input (i.e. siso). It does this by first going from RL = g_in_latency -->
--   0 and then to RL = g_out_latency. 
-- Data flow:
--   . out RL >  in RL                : incr(out RL - in RL)
--   . out RL <= in RL AND out RL = 0 : incr(1) --> adapt(out RL)
--   . out RL <= in RL AND out RL > 0 : adapt(0) --> incr(out RL)
-- Remark:
-- . The g_in_latency may be 0, but for g_in_latency=0 the sosi.ready acts
--   as an acknowledge and that could simply also be registered by the user.

ENTITY dp_pipeline_ready IS
  GENERIC (
    g_in_latency   : NATURAL := 1;  -- >= 0
    g_out_latency  : NATURAL := 1   -- >= 0
  );
  PORT (
    rst          : IN  STD_LOGIC;
    clk          : IN  STD_LOGIC;
    -- ST sink
    snk_out      : OUT t_dp_siso;
    snk_in       : IN  t_dp_sosi;
    -- ST source
    src_in       : IN  t_dp_siso;
    src_out      : OUT t_dp_sosi
  );
END dp_pipeline_ready;


ARCHITECTURE str OF dp_pipeline_ready IS

  SIGNAL internal_siso  : t_dp_siso;
  SIGNAL internal_sosi  : t_dp_sosi;
 
BEGIN

  gen_out_incr_rl : IF g_out_latency>g_in_latency GENERATE
    -- Register siso by incrementing the input RL first
    u_incr : ENTITY dp_components_lib.dp_latency_increase
    GENERIC MAP (
      g_in_latency   => g_in_latency,
      g_incr_latency => g_out_latency-g_in_latency
    )
    PORT MAP (
      rst          => rst,
      clk          => clk,
      -- ST sink
      snk_out      => snk_out,
      snk_in       => snk_in,
      -- ST source
      src_in       => src_in,
      src_out      => src_out
    );
  END GENERATE;
  
  gen_out_rl_0 : IF g_out_latency<=g_in_latency AND g_out_latency=0 GENERATE
    -- Register siso by incrementing the input RL first
    u_incr : ENTITY dp_components_lib.dp_latency_increase
    GENERIC MAP (
      g_in_latency   => g_in_latency,
      g_incr_latency => 1
    )
    PORT MAP (
      rst          => rst,
      clk          => clk,
      -- ST sink
      snk_out      => snk_out,
      snk_in       => snk_in,
      -- ST source
      src_in       => internal_siso,
      src_out      => internal_sosi
    );

    -- Input RL --> 0
    u_adapt : ENTITY dp_components_lib.dp_latency_adapter
    GENERIC MAP (
      g_in_latency   => g_in_latency+1,
      g_out_latency  => g_out_latency
    )
    PORT MAP (
      rst          => rst,
      clk          => clk,
      -- ST sink
      snk_out      => internal_siso,
      snk_in       => internal_sosi,
      -- ST source
      src_in       => src_in,
      src_out      => src_out
    );
  END GENERATE;
  
  gen_out_rl : IF g_out_latency<=g_in_latency AND g_out_latency>0 GENERATE
    -- First adapt the input RL --> 0
    u_adapt : ENTITY dp_components_lib.dp_latency_adapter
    GENERIC MAP (
      g_in_latency   => g_in_latency,
      g_out_latency  => 0
    )
    PORT MAP (
      rst          => rst,
      clk          => clk,
      -- ST sink
      snk_out      => snk_out,
      snk_in       => snk_in,
      -- ST source
      src_in       => internal_siso,
      src_out      => internal_sosi
    );

    -- Register siso by incrementing the internal RL = 0 --> the output RL
    u_incr : ENTITY dp_components_lib.dp_latency_increase
    GENERIC MAP (
      g_in_latency   => 0,
      g_incr_latency => g_out_latency
    )
    PORT MAP (
      rst          => rst,
      clk          => clk,
      -- ST sink
      snk_out      => internal_siso,
      snk_in       => internal_sosi,
      -- ST source
      src_in       => src_in,
      src_out      => src_out
    );
  END GENERATE;
    
END str;
