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
 
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

-- > as 3
-- > run -all --> OK

ENTITY tb_tb_dp_pipeline IS
END tb_tb_dp_pipeline;


ARCHITECTURE tb OF tb_tb_dp_pipeline IS
  SIGNAL tb_end : STD_LOGIC := '0';  -- declare tb_end to avoid 'No objects found' error on 'when -label tb_end'
BEGIN

  u_p0 : ENTITY work.tb_dp_pipeline GENERIC MAP (0);
  u_p1 : ENTITY work.tb_dp_pipeline GENERIC MAP (1);
  u_p2 : ENTITY work.tb_dp_pipeline GENERIC MAP (2);
  u_p7 : ENTITY work.tb_dp_pipeline GENERIC MAP (7);

END tb;
