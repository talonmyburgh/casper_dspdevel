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

LIBRARY IEEE, common_pkg_lib;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.common_str_pkg.ALL;
USE work.mm_file_pkg.ALL;

PACKAGE mm_file_unb_pkg IS

  TYPE t_c_mmf_unb_sys IS RECORD
    nof_unb : NATURAL; -- Nof used UniBoard in our system [0..nof_unb-1]
    nof_fn  : NATURAL; -- Nof used FNs [0..nof_fn-1] per UniBoard
    nof_bn  : NATURAL; -- Nof used BNs [0..nof_fn-1] per UniBoard
  END RECORD;

  CONSTANT c_mmf_unb_nof_fn          : NATURAL := 4;
  CONSTANT c_mmf_unb_nof_bn          : NATURAL := 4;
  CONSTANT c_mmf_unb_nof_pn          : NATURAL := c_mmf_unb_nof_fn + c_mmf_unb_nof_bn;  -- = 8
  
  -- use fixed central directory to ease use of Python test case with Modelsim
  CONSTANT c_mmf_unb_file_path       : STRING := "$UNB/Software/python/sim/";
  
  -- create mmf file prefix that is unique per slave
  FUNCTION mmf_unb_file_prefix(sys: t_c_mmf_unb_sys; node: NATURAL) RETURN STRING;
  FUNCTION mmf_unb_file_prefix(             unb, node: NATURAL; node_type: STRING) RETURN STRING;  -- unb 0,1,..., node = 0:3 for FN or BN
  FUNCTION mmf_unb_file_prefix(             unb, node: NATURAL) RETURN STRING;  -- unb 0,1,..., node = 0:7, with 0:3 for FN and 4:7 for BN
  FUNCTION mmf_unb_file_prefix(tb,          unb, node: NATURAL) RETURN STRING;  -- idem, with extra index tb = 0,1,... for use with multi testbench
  FUNCTION mmf_unb_file_prefix(tb, subrack, unb, node: NATURAL) RETURN STRING;  -- idem, with extra index subrack =  0,1,... to support same local unb range per subrack

END mm_file_unb_pkg;

PACKAGE BODY mm_file_unb_pkg IS

  FUNCTION mmf_unb_file_prefix(sys: t_c_mmf_unb_sys; node: NATURAL) RETURN STRING IS
    -- This function is used to create files for node function instances that (can) run on
    -- an FN or a BN. One generate loop can be used for all node instances, no need to 
    -- use a separate FOR loop for the back nodes and the front nodes as this function
    -- determines the UniBoard index for you.
    VARIABLE v_nodes_per_board : NATURAL := sys.nof_fn + sys.nof_bn;
    VARIABLE v_board_index     : NATURAL := node/v_nodes_per_board;
    VARIABLE v_node_nr         : NATURAL := node REM v_nodes_per_board;
    VARIABLE v_node_type       : STRING(1 TO 2) := sel_a_b(v_node_nr>=sys.nof_fn, "BN", "FN");
    VARIABLE v_node_index      : NATURAL := sel_a_b(v_node_nr>=sys.nof_fn, v_node_nr-sys.nof_fn, v_node_nr);
  BEGIN
    RETURN mmf_slave_prefix(c_mmf_unb_file_path, "UNB", v_board_index, v_node_type, v_node_index);
  END;

  FUNCTION mmf_unb_file_prefix(unb, node: NATURAL; node_type: STRING) RETURN STRING IS
    -- Use this function and pass the UNB and node type BN 0:3 or node type FN 0:3 index.
  BEGIN
    RETURN mmf_slave_prefix(c_mmf_unb_file_path, "UNB", unb, node_type, node);
  END;

  FUNCTION mmf_unb_file_prefix(unb, node: NATURAL) RETURN STRING IS
    -- Use this function and pass the UNB and node 0:7 index.
    CONSTANT c_node_type       : STRING(1 TO 2) := sel_a_b(node>=c_mmf_unb_nof_fn, "BN", "FN");
    CONSTANT c_node_nr         : NATURAL := node MOD c_mmf_unb_nof_fn;  -- PN 0:3 --> FN 0:3, PN 4:7 --> BN 0:3
  BEGIN
    RETURN mmf_slave_prefix(c_mmf_unb_file_path, "UNB", unb, c_node_type, c_node_nr);
  END;
  
  FUNCTION mmf_unb_file_prefix(tb, unb, node: NATURAL) RETURN STRING IS
    -- Use this function and pass the UNB and node 0:7 index and a test bench index to allow file IO with multi tb.
    CONSTANT c_node_type       : STRING(1 TO 2) := sel_a_b(node>=c_mmf_unb_nof_fn, "BN", "FN");
    CONSTANT c_node_nr         : NATURAL := node MOD c_mmf_unb_nof_fn;  -- PN 0:3 --> FN 0:3, PN 4:7 --> BN 0:3
  BEGIN
    RETURN mmf_slave_prefix(c_mmf_unb_file_path, "TB", tb, "UNB", unb, c_node_type, c_node_nr);
  END;
  
  FUNCTION mmf_unb_file_prefix(tb, subrack, unb, node: NATURAL) RETURN STRING IS
    -- Use this function and pass the UNB and node 0:7 index and a test bench index to allow file IO with multi subrack and multi tb.
    CONSTANT c_node_type       : STRING(1 TO 2) := sel_a_b(node>=c_mmf_unb_nof_fn, "BN", "FN");
    CONSTANT c_node_nr         : NATURAL := node MOD c_mmf_unb_nof_fn;  -- PN 0:3 --> FN 0:3, PN 4:7 --> BN 0:3
  BEGIN
    RETURN mmf_slave_prefix(c_mmf_unb_file_path, "TB", tb, "SUBRACK", subrack, "UNB", unb, c_node_type, c_node_nr);
  END;
  
END mm_file_unb_pkg;

