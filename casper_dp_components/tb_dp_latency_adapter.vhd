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

ENTITY tb_dp_latency_adapter IS
END tb_dp_latency_adapter;


ARCHITECTURE tb OF tb_dp_latency_adapter IS

  -- See tb_dp_pkg.vhd for explanation and run time
  
  SUBTYPE t_dut_range  IS INTEGER RANGE -1 to INTEGER'HIGH; 

  TYPE t_dut_natural_arr  IS ARRAY (t_dut_range RANGE <>) OF NATURAL;
  TYPE t_dut_data_arr     IS ARRAY (t_dut_range RANGE <>) OF STD_LOGIC_VECTOR(c_dp_data_w-1 DOWNTO 0);
  TYPE t_dut_logic_arr    IS ARRAY (t_dut_range RANGE <>) OF STD_LOGIC;  -- can not use STD_LOGIC_VECTOR because of integer range 
  
  -- TX ready latency to DUT chain
  CONSTANT c_tx_latency     : NATURAL := 3;
  CONSTANT c_tx_void        : NATURAL := sel_a_b(c_tx_latency, 1, 0);  -- used to avoid empty range VHDL warnings when c_tx_latency=0
  
  CONSTANT c_tx_offset_sop  : NATURAL := 3;
  CONSTANT c_tx_period_sop  : NATURAL := 7;              -- sop in data valid cycle 3,  10,  17, ...
  CONSTANT c_tx_offset_eop  : NATURAL := 5;              -- eop in data valid cycle   5,  12,  19, ...
  CONSTANT c_tx_period_eop  : NATURAL := c_tx_period_sop;
  CONSTANT c_tx_offset_sync : NATURAL := 3;                  -- sync in data valid cycle 3, 20, 37, ...
  CONSTANT c_tx_period_sync : NATURAL := 17;
  
  -- The TB supports using 1 or more dp_latency_adapter Devices Under Test in a chain. DUT 0 is the first DUT and it
  -- gets the tx_data from this test bench, which has index -1. Each next DUT gets its input from the previous DUT,
  -- hence the ready latency between DUTs should be the same.
  -- The output latency of the previous must equal the input latency of the next DUT, hence it is sufficient to define
  -- only the DUT output latencies.
  --CONSTANT c_dut_latency    : t_dut_natural_arr := (c_tx_latency, 3);  -- verify single dp_latency_adapter with only wires
  --CONSTANT c_dut_latency    : t_dut_natural_arr := (c_tx_latency, 4);  -- verify single dp_latency_adapter with latency increase
  --CONSTANT c_dut_latency    : t_dut_natural_arr := (c_tx_latency, 1);  -- verify single dp_latency_adapter with latency decrease
  CONSTANT c_dut_latency    : t_dut_natural_arr := (c_tx_latency, 1, 2, 0, 5, 5, 2, 1, 0, 7);
  
  -- The nof dut latencies in the c_dut_latency array automatically also defines the nof DUTs c_nof_dut.
  CONSTANT c_nof_dut        : NATURAL := c_dut_latency'HIGH+1;
  
  -- RX ready latency from DUT chain
  CONSTANT c_rx_latency     : NATURAL := c_dut_latency(c_nof_dut-1);
  
  CONSTANT c_verify_en_wait : NATURAL := 10+c_nof_dut*2;  -- wait some cycles before asserting verify enable
  
  CONSTANT c_empty_offset   : NATURAL := 1;
  CONSTANT c_channel_offset : NATURAL := 2;
  
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
  
  SIGNAL tx_data        : t_dp_data_arr(0 TO c_tx_latency + c_tx_void);
  SIGNAL tx_val         : STD_LOGIC_VECTOR(0 TO c_tx_latency + c_tx_void);
  
  SIGNAL in_ready       : STD_LOGIC;
  SIGNAL in_data        : STD_LOGIC_VECTOR(c_dp_data_w-1 DOWNTO 0);
  SIGNAL in_sync        : STD_LOGIC;
  SIGNAL in_val         : STD_LOGIC;
  SIGNAL in_sop         : STD_LOGIC;
  SIGNAL in_eop         : STD_LOGIC;
  
  -- DUT index -1 = in_data
  SIGNAL dut_ready      : t_dut_logic_arr(-1 TO c_nof_dut-1);  -- SISO
  SIGNAL dut_data       : t_dut_data_arr(-1 TO c_nof_dut-1);   -- SOSI
  SIGNAL dut_empty      : t_dut_data_arr(-1 TO c_nof_dut-1) := (OTHERS=>(OTHERS=>'0'));
  SIGNAL dut_channel    : t_dut_data_arr(-1 TO c_nof_dut-1) := (OTHERS=>(OTHERS=>'0'));
  SIGNAL dut_sync       : t_dut_logic_arr(-1 TO c_nof_dut-1);
  SIGNAL dut_val        : t_dut_logic_arr(-1 TO c_nof_dut-1);
  SIGNAL dut_sop        : t_dut_logic_arr(-1 TO c_nof_dut-1);
  SIGNAL dut_eop        : t_dut_logic_arr(-1 TO c_nof_dut-1);
  -- DUT index c_nof_dut-1 = out_data
  SIGNAL dut_siso       : t_dp_siso_arr(-1 TO c_nof_dut-1);
  SIGNAL dut_sosi       : t_dp_sosi_arr(-1 TO c_nof_dut-1) := (OTHERS=>c_dp_sosi_rst);
  
  SIGNAL out_ready      : STD_LOGIC;
  SIGNAL prev_out_ready : STD_LOGIC_VECTOR(0 TO c_rx_latency);
  SIGNAL out_data       : STD_LOGIC_VECTOR(c_dp_data_w-1 DOWNTO 0);
  SIGNAL out_empty      : STD_LOGIC_VECTOR(c_dp_data_w-1 DOWNTO 0);
  SIGNAL out_channel    : STD_LOGIC_VECTOR(c_dp_data_w-1 DOWNTO 0);
  SIGNAL out_sync       : STD_LOGIC;
  SIGNAL out_val        : STD_LOGIC;
  SIGNAL out_sop        : STD_LOGIC;
  SIGNAL out_eop        : STD_LOGIC;
  SIGNAL hold_out_sop   : STD_LOGIC;
  SIGNAL prev_out_data  : STD_LOGIC_VECTOR(out_data'RANGE);
  
  SIGNAL state          : t_dp_state_enum;
  
  SIGNAL verify_en      : STD_LOGIC;
  SIGNAL verify_done    : STD_LOGIC;
  
  SIGNAL exp_data       : STD_LOGIC_VECTOR(c_dp_data_w-1 DOWNTO 0) := TO_UVEC(19555, c_dp_data_w);
  
BEGIN

  -- Use intervals marked by sync to start a new test named by state.
  --
  -- Under all circumstances the out_data should not mis or duplicate a count
  -- while out_val is asserted as checked by p_verify.
  -- The throughput must remain 100%, with only some increase in latency. This
  -- can be checked manually by checking that cnt_val does not toggle when the
  -- out_ready is asserted continuously. E.g. check that the out_data value 
  -- is sufficiently high given the number of sync intervals that have passed.
  --
  -- Stimuli to verify the dp_latency_adapter DUT:
  --
  -- * Use various ready latency combinations in c_dut_latency:
  --   .     c_in_latency > c_out_latency = 0
  --   .     c_in_latency > c_out_latency > 0
  --   .     c_in_latency = c_out_latency = 0
  --   .     c_in_latency = c_out_latency > 0
  --   . 0 = c_in_latency < c_out_latency
  --   . 0 < c_in_latency < c_out_latency
  --
  -- * Manipulate the stimuli in:
  --   . p_cnt_en    : cnt_en not always active when in_ready is asserted
  --   . p_out_ready : out_ready not always active

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
  proc_dp_verify_data("out_data", c_rx_latency, clk, verify_en, out_ready, out_val, out_data, prev_out_data);
  proc_dp_verify_valid(c_rx_latency, clk, verify_en, out_ready, prev_out_ready, out_val);
  proc_dp_verify_ctrl(c_tx_offset_sync, c_tx_period_sync, "sync", clk, verify_en, out_data, out_val, out_sync);
  proc_dp_verify_ctrl(c_tx_offset_sop, c_tx_period_sop, "sop", clk, verify_en, out_data, out_val, out_sop);
  proc_dp_verify_ctrl(c_tx_offset_eop, c_tx_period_eop, "eop", clk, verify_en, out_data, out_val, out_eop);
  proc_dp_verify_sop_and_eop(c_rx_latency, FALSE, clk, out_val, out_val, out_sop, out_eop, hold_out_sop);  -- Verify that sop and eop come in pairs, no check on valid between eop and sop
  proc_dp_verify_other_sosi("empty", INCR_UVEC(out_data, c_empty_offset), clk, verify_en, out_empty);
  proc_dp_verify_other_sosi("channel", INCR_UVEC(out_data, c_channel_offset), clk, verify_en, out_channel);

  -- Check that the test has ran at all
  proc_dp_verify_value(e_equal, clk, verify_done, exp_data, out_data);
  
  ------------------------------------------------------------------------------
  -- Chain of 1 or more dp_latency_adapter DUTs
  --
  -- . Note this also models a series of streaming modules in a data path
  --
  ------------------------------------------------------------------------------
  
  -- Map the test bench tx counter data to the input of the chain
  in_ready        <= dut_ready(-1);
  dut_data(-1)    <=           in_data;
  dut_empty(-1)   <= INCR_UVEC(in_data, c_empty_offset);
  dut_channel(-1) <= INCR_UVEC(in_data, c_channel_offset);
  dut_sync(-1)    <= in_sync;
  dut_val(-1)     <= in_val;
  dut_sop(-1)     <= in_sop;
  dut_eop(-1)     <= in_eop;
  
  -- map sl, slv to record
  dut_ready(-1) <= dut_siso(-1).ready;                           -- SISO
  dut_sosi(-1).data(c_dp_data_w-1 DOWNTO 0) <= dut_data(-1);     -- SOSI
  dut_sosi(-1).empty                        <= dut_empty(-1)(c_dp_empty_w-1 DOWNTO 0);
  dut_sosi(-1).channel                      <= dut_channel(-1)(c_dp_channel_w-1 DOWNTO 0);
  dut_sosi(-1).sync                         <= dut_sync(-1);
  dut_sosi(-1).valid                        <= dut_val(-1);
  dut_sosi(-1).sop                          <= dut_sop(-1);
  dut_sosi(-1).eop                          <= dut_eop(-1);
    
  gen_chain : FOR I IN 0 TO c_nof_dut-1 GENERATE
    dut : ENTITY work.dp_latency_adapter
    GENERIC MAP (
      g_in_latency  => c_dut_latency(I-1),
      g_out_latency => c_dut_latency(I)
    )
    PORT MAP (
      rst       => rst,
      clk       => clk,
      -- ST sink
      snk_out   => dut_siso(I-1),
      snk_in    => dut_sosi(I-1),
      -- ST source
      src_in    => dut_siso(I),
      src_out   => dut_sosi(I)
    );
  END GENERATE;

  -- map record to sl, slv
  dut_siso(c_nof_dut-1).ready <= dut_ready(c_nof_dut-1);                                                      -- SISO
  dut_data(c_nof_dut-1)                               <= dut_sosi(c_nof_dut-1).data(c_dp_data_w-1 DOWNTO 0);  -- SOSI
  dut_empty(c_nof_dut-1)(c_dp_empty_w-1 DOWNTO 0)     <= dut_sosi(c_nof_dut-1).empty;
  dut_channel(c_nof_dut-1)(c_dp_channel_w-1 DOWNTO 0) <= dut_sosi(c_nof_dut-1).channel;
  dut_sync(c_nof_dut-1)                               <= dut_sosi(c_nof_dut-1).sync;
  dut_val(c_nof_dut-1)                                <= dut_sosi(c_nof_dut-1).valid;
  dut_sop(c_nof_dut-1)                                <= dut_sosi(c_nof_dut-1).sop;
  dut_eop(c_nof_dut-1)                                <= dut_sosi(c_nof_dut-1).eop;
  
  -- Map the output of the DUT chain to the test bench output data
  dut_ready(c_nof_dut-1) <= out_ready;
  out_data               <= dut_data(c_nof_dut-1);
  out_empty              <= dut_empty(c_nof_dut-1);
  out_channel            <= dut_channel(c_nof_dut-1);
  out_sync               <= dut_sync(c_nof_dut-1);
  out_val                <= dut_val(c_nof_dut-1);
  out_sop                <= dut_sop(c_nof_dut-1);
  out_eop                <= dut_eop(c_nof_dut-1);
    
END tb;
