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
 
LIBRARY IEEE, dp_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE dp_pkg_lib.tb_dp_pkg.ALL;


-- > as 2
-- > run -all --> OK

ENTITY tb_tb_dp_pipeline_ready IS
END tb_tb_dp_pipeline_ready;


ARCHITECTURE tb OF tb_tb_dp_pipeline_ready IS

  CONSTANT c_nof_repeat : NATURAL := 50;
  SIGNAL tb_end : STD_LOGIC := '0';  -- declare tb_end to avoid 'No objects found' error on 'when -label tb_end'
  
BEGIN

  --                                                               in_en,    src_in.ready, in_latency, out_latency, nof repeat,
  -- Random flow control for different RL
  u_rnd_rnd_0_0    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_random, e_random,     0,          0,           c_nof_repeat);
  u_rnd_rnd_1_0    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_random, e_random,     1,          0,           c_nof_repeat);
  u_rnd_rnd_0_1    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_random, e_random,     0,          1,           c_nof_repeat);
  u_rnd_rnd_2_0    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_random, e_random,     2,          0,           c_nof_repeat);
  u_rnd_rnd_0_2    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_random, e_random,     0,          2,           c_nof_repeat);
  u_rnd_rnd_2_1    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_random, e_random,     2,          1,           c_nof_repeat);
  u_rnd_rnd_1_2    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_random, e_random,     1,          2,           c_nof_repeat);
  u_rnd_rnd_2_2    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_random, e_random,     2,          2,           c_nof_repeat);
  
  -- Other flow control for fixed RL
  u_act_act_1_1    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_active, e_active,     1,          1,           c_nof_repeat);
  u_act_rnd_1_1    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_active, e_random,     1,          1,           c_nof_repeat);
  u_act_pls_1_1    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_active, e_pulse,      1,          1,           c_nof_repeat);
                                                                                      
  u_rnd_act_1_1    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_random, e_active,     1,          1,           c_nof_repeat);
  u_rnd_rnd_1_1    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_random, e_random,     1,          1,           c_nof_repeat);
  u_rnd_pls_1_1    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_random, e_pulse,      1,          1,           c_nof_repeat);
                                                                                      
  u_pls_act_1_1    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_pulse,  e_active,     1,          1,           c_nof_repeat);
  u_pls_rnd_1_1    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_pulse,  e_random,     1,          1,           c_nof_repeat);
  u_pls_pls_1_1    : ENTITY work.tb_dp_pipeline_ready GENERIC MAP (e_pulse,  e_pulse,      1,          1,           c_nof_repeat);
  
END tb;
