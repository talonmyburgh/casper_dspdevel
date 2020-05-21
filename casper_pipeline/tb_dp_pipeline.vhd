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
USE dp_pkg_lib.tb_dp_pkg.ALL;

ENTITY tb_dp_pipeline IS
  GENERIC (
    g_pipeline : NATURAL := 5
  );
END tb_dp_pipeline;


ARCHITECTURE tb OF tb_dp_pipeline IS

  -- See tb_dp_pkg.vhd for explanation and run time

  -- DUT ready latency
  CONSTANT c_dut_latency    : NATURAL := 1;              -- fixed 1 for dp_pipeline
  CONSTANT c_tx_latency     : NATURAL := c_dut_latency;  -- TX ready latency of TB
  CONSTANT c_tx_void        : NATURAL := sel_a_b(c_tx_latency, 1, 0);  -- used to avoid empty range VHDL warnings when c_tx_latency=0
  CONSTANT c_tx_offset_sop  : NATURAL := 3;
  CONSTANT c_tx_period_sop  : NATURAL := 7;              -- sop in data valid cycle 3,  10,  17, ...
  CONSTANT c_tx_offset_eop  : NATURAL := 5;              -- eop in data valid cycle   5,  12,  19, ...
  CONSTANT c_tx_period_eop  : NATURAL := c_tx_period_sop;
  CONSTANT c_tx_offset_sync : NATURAL := 3;              -- sync in data valid cycle 3, 20, 37, ...
  CONSTANT c_tx_period_sync : NATURAL := 17;
  CONSTANT c_rx_latency     : NATURAL := c_dut_latency;  -- RX ready latency from DUT
  CONSTANT c_verify_en_wait : NATURAL := 4+g_pipeline;   -- wait some cycles before asserting verify enable
  
  CONSTANT c_random_w       : NATURAL := 19;
  
  SIGNAL tb_end         : STD_LOGIC := '0';
  SIGNAL clk            : STD_LOGIC := '0';
  SIGNAL rst            : STD_LOGIC;
  SIGNAL sync           : STD_LOGIC;
  SIGNAL lfsr1          : STD_LOGIC_VECTOR(c_random_w-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL lfsr2          : STD_LOGIC_VECTOR(c_random_w   DOWNTO 0) := (OTHERS=>'0');
  
  SIGNAL cnt_dat        : STD_LOGIC_VECTOR(c_dp_data_w-1 DOWNTO 0);
  SIGNAL cnt_val        : STD_LOGIC;
  SIGNAL cnt_en         : STD_LOGIC;
  
  SIGNAL tx_data        : t_dp_data_arr(0 TO c_tx_latency + c_tx_void)    := (OTHERS=>(OTHERS=>'0'));
  SIGNAL tx_val         : STD_LOGIC_VECTOR(0 TO c_tx_latency + c_tx_void) := (OTHERS=>'0');
  
  SIGNAL in_ready       : STD_LOGIC;
  SIGNAL in_data        : STD_LOGIC_VECTOR(c_dp_data_w-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL in_sync        : STD_LOGIC;
  SIGNAL in_val         : STD_LOGIC;
  SIGNAL in_sop         : STD_LOGIC;
  SIGNAL in_eop         : STD_LOGIC;
  
  SIGNAL in_siso        : t_dp_siso;
  SIGNAL in_sosi        : t_dp_sosi := c_dp_sosi_rst;
  SIGNAL out_siso       : t_dp_siso;
  SIGNAL out_sosi       : t_dp_sosi;
  
  SIGNAL out_ready      : STD_LOGIC;
  SIGNAL prev_out_ready : STD_LOGIC_VECTOR(0 TO c_rx_latency);
  SIGNAL out_data       : STD_LOGIC_VECTOR(c_dp_data_w-1 DOWNTO 0);
  SIGNAL out_sync       : STD_LOGIC;
  SIGNAL out_val        : STD_LOGIC;
  SIGNAL out_sop        : STD_LOGIC;
  SIGNAL out_eop        : STD_LOGIC;
  SIGNAL hold_out_sop   : STD_LOGIC;
  SIGNAL prev_out_data  : STD_LOGIC_VECTOR(out_data'RANGE);
    
  SIGNAL state          : t_dp_state_enum;
  
  SIGNAL verify_en      : STD_LOGIC;
  SIGNAL verify_done    : STD_LOGIC;
  
  SIGNAL exp_data       : STD_LOGIC_VECTOR(c_dp_data_w-1 DOWNTO 0) := TO_UVEC(sel_a_b(g_pipeline=0, 18953, 18952), c_dp_data_w);
  
BEGIN

  clk <= NOT clk OR tb_end AFTER clk_period/2;
  rst <= '1', '0' AFTER clk_period*7;
  
  -- Sync interval
  proc_dp_sync_interval(clk, sync);
  
  -- Input data
  cnt_val <= in_ready AND cnt_en;
  
  proc_dp_cnt_dat(rst, clk, cnt_val, cnt_dat);
  proc_dp_tx_data(c_tx_latency, rst, clk, cnt_val, cnt_dat, tx_data, tx_val, in_data, in_val);
  proc_dp_tx_ctrl(c_tx_offset_sync, c_tx_period_sync, in_data, in_val, in_sync);
  proc_dp_tx_ctrl(c_tx_offset_sop, c_tx_period_sop, in_data, in_val, in_sop);
  proc_dp_tx_ctrl(c_tx_offset_eop, c_tx_period_eop, in_data, in_val, in_eop);

  -- Stimuli control
  proc_dp_count_en(rst, clk, sync, lfsr1, state, verify_done, tb_end, cnt_en);
  proc_dp_out_ready(rst, clk, sync, lfsr2, out_ready);
  
  -- Output verify
  proc_dp_verify_en(c_verify_en_wait, rst, clk, sync, verify_en);
  proc_dp_verify_data("out_sosi.data", c_rx_latency, clk, verify_en, out_ready, out_val, out_data, prev_out_data);
  proc_dp_verify_valid(c_rx_latency, clk, verify_en, out_ready, prev_out_ready, out_val);
  proc_dp_verify_sop_and_eop(c_rx_latency, FALSE, clk, out_val, out_val, out_sop, out_eop, hold_out_sop);  -- Verify that sop and eop come in pairs, no check on valid between eop and sop
  proc_dp_verify_ctrl(c_tx_offset_sync, c_tx_period_sync, "sync", clk, verify_en, out_data, out_val, out_sync);
  proc_dp_verify_ctrl(c_tx_offset_sop, c_tx_period_sop, "sop", clk, verify_en, out_data, out_val, out_sop);
  proc_dp_verify_ctrl(c_tx_offset_eop, c_tx_period_eop, "eop", clk, verify_en, out_data, out_val, out_eop);
  
  -- Check that the test has ran at all
  proc_dp_verify_value(e_equal, clk, verify_done, exp_data, out_data);
  
  ------------------------------------------------------------------------------
  -- DUT dp_pipeline
  ------------------------------------------------------------------------------
  
  -- map sl, slv to record
  in_ready <= in_siso.ready;                        -- SISO
  in_sosi.data(c_dp_data_w-1 DOWNTO 0) <= in_data;  -- SOSI
  in_sosi.sync                         <= in_sync;
  in_sosi.valid                        <= in_val;
  in_sosi.sop                          <= in_sop;
  in_sosi.eop                          <= in_eop;
  
  out_siso.ready <= out_ready;                        -- SISO
  out_data <= out_sosi.data(c_dp_data_w-1 DOWNTO 0);  -- SOSI
  out_sync <= out_sosi.sync;
  out_val  <= out_sosi.valid;
  out_sop  <= out_sosi.sop;
  out_eop  <= out_sosi.eop;
  
  dut : ENTITY work.dp_pipeline
  GENERIC MAP (
    g_pipeline => g_pipeline
  )
  PORT MAP (
    rst         => rst,
    clk         => clk,
    snk_out     => in_siso,     -- OUT = request to upstream ST source
    snk_in      => in_sosi,
    src_in      => out_siso,    -- IN  = request from downstream ST sink
    src_out     => out_sosi
  );
  
END tb;
