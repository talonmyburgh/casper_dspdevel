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

LIBRARY IEEE, common_pkg_lib, dp_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;

-- Purpose:
--   Typically used in dp_latency_adapter.
-- Description:
--   Increase the output ready latency by g_incr_latency compared to the input
--   ready latency g_in_latency. Hence the output latency becomes g_in_latency
--   + g_incr_latency.
-- Remark:
-- . The SOSI data stream signals (i.e. data, empty, channel, err) are passed
--   on as wires.
-- . The out_sync, out_val, out_sop and out_eop are internally AND with the
--   delayed src_in.ready, this is only truely necessary if the input ready
--   latency is 0, but it does not harm to do it also when the input ready
--   latency > 0. However to easy achieving P&R timing it is better to not have
--   unnessary logic in the combinatorial path of out_sync, out_val, out_sop
--   and out_eop, therefore the AND with reg_val is only generated when
--   g_in_latency=0.

ENTITY dp_latency_increase IS
  GENERIC (
    g_in_latency   : NATURAL := 0;  -- >= 0
    g_incr_latency : NATURAL := 2   -- >= 0
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
END dp_latency_increase;


ARCHITECTURE rtl OF dp_latency_increase IS

  CONSTANT c_out_latency : NATURAL := g_in_latency + g_incr_latency;
  
  SIGNAL reg_ready : STD_LOGIC_VECTOR(c_out_latency DOWNTO 0);
  SIGNAL reg_val   : STD_LOGIC;
  
  SIGNAL i_snk_out : t_dp_siso := c_dp_siso_rdy;
  
BEGIN

  -- Use i_snk_out with defaults to force unused snk_out bits and fields to '0'
  snk_out <= i_snk_out;

  -- Support wires only for g_incr_latency=0
  no_latency : IF g_incr_latency=0 GENERATE
    i_snk_out <= src_in;  -- SISO
    src_out   <= snk_in;  -- SOSI
  END GENERATE no_latency;
  
  gen_latency : IF g_incr_latency>0 GENERATE
    -- SISO
    reg_ready(0) <= src_in.ready;  -- use reg_ready(0) to combinatorially store src_in.ready
    p_clk : PROCESS(rst, clk)
    BEGIN
      IF rst='1' THEN
        reg_ready(c_out_latency DOWNTO 1) <= (OTHERS=>'0');
      ELSIF rising_edge(clk) THEN
        reg_ready(c_out_latency DOWNTO 1) <= reg_ready(c_out_latency-1 DOWNTO 0);
      END IF;
    END PROCESS;
    
    i_snk_out.xon   <= src_in.xon;                 -- Pass on frame level flow control
    i_snk_out.ready <= reg_ready(g_incr_latency);  -- Adjust ready latency
    
    -- SOSI
    gen_out : IF g_in_latency/=0 GENERATE
      src_out <= snk_in;
    END GENERATE;
    gen_zero_out : IF g_in_latency=0 GENERATE
      reg_val <= reg_ready(c_out_latency);
    
      p_src_out : PROCESS(snk_in, reg_val)
      BEGIN
        src_out       <= snk_in;
        src_out.sync  <= snk_in.sync  AND reg_val;
        src_out.valid <= snk_in.valid AND reg_val;
        src_out.sop   <= snk_in.sop   AND reg_val;
        src_out.eop   <= snk_in.eop   AND reg_val;
      END PROCESS;
    END GENERATE;
  END GENERATE gen_latency;
  
END rtl;
