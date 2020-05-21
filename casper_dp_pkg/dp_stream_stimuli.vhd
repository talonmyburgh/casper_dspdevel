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

-- Purpose:
-- . The dp_stream_stimuli generates as stream of packets with counter data.
-- Description:
--
-- Remark:
-- . The stimuli empty = 0 because the data in proc_dp_gen_block_data() is
--   generated with one symbol per data (because symbol_w = data_w).
--
-- Usage:
-- . See tb_dp_example_no_dut for usage example
--

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.common_lfsr_sequences_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;
USE work.dp_stream_pkg.ALL;
USE work.tb_dp_pkg.ALL;


ENTITY dp_stream_stimuli IS
  GENERIC (
    g_instance_nr    : NATURAL := 0;
    -- flow control
    g_random_w       : NATURAL := 15;                       -- use different random width for stimuli and for verify to have different random sequences
    g_pulse_active   : NATURAL := 1;
    g_pulse_period   : NATURAL := 2;
    g_flow_control   : t_dp_flow_control_enum := e_active;  -- always active, random or pulse flow control
    -- initializations
    g_sync_period    : NATURAL := 10;
    g_sync_offset    : NATURAL := 0;
    g_data_init      : NATURAL := 0;    -- choose some easy to recognize and unique value, data will increment at every valid
    g_bsn_init       : STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0) := TO_DP_BSN(0);  -- X"0877665544332211", bsn will increment at every sop
    g_err_init       : NATURAL := 247;  -- choose some easy to recognize and unique value
    g_err_incr       : NATURAL := 1;    -- when 0 keep fixed at init value, when 1 increment at every sop
    g_channel_init   : NATURAL := 5;    -- choose some easy to recognize and unique value
    g_channel_incr   : NATURAL := 1;    -- when 0 keep fixed at init value, when 1 increment at every sop
    -- specific
    g_in_dat_w       : NATURAL := 32;
    g_nof_repeat     : NATURAL := 5;
    g_pkt_len        : NATURAL := 16;
    g_pkt_gap        : NATURAL := 4;
    g_wait_last_evt  : NATURAL := 100   -- number of clk cycles to wait with last_snk_in_evt after finishing the stimuli
  );
  PORT (
    rst               : IN  STD_LOGIC;
    clk               : IN  STD_LOGIC;
  
    -- Generate stimuli
    src_in            : IN  t_dp_siso := c_dp_siso_rdy;
    src_out           : OUT t_dp_sosi;

    -- End of stimuli
    last_snk_in       : OUT t_dp_sosi;   -- expected verify_snk_in after end of stimuli 
    last_snk_in_evt   : OUT STD_LOGIC;   -- trigger verify to verify the last_snk_in 
    tb_end            : OUT STD_LOGIC    -- signal end of tb as far as this dp_stream_stimuli is concerned
  );
END dp_stream_stimuli;


ARCHITECTURE str OF dp_stream_stimuli IS
  
  SIGNAL random          : STD_LOGIC_VECTOR(g_random_w-1 DOWNTO 0) := TO_UVEC(g_instance_nr, g_random_w);  -- use different initialization to have different random sequences per stream
  SIGNAL pulse           : STD_LOGIC;
  SIGNAL pulse_en        : STD_LOGIC := '1';
  
  SIGNAL stimuli_en      : STD_LOGIC := '1';
  SIGNAL src_out_data    : STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
  SIGNAL i_src_out       : t_dp_sosi;
  
BEGIN

  src_out <= i_src_out;
  
  ------------------------------------------------------------------------------
  -- STREAM CONTROL
  ------------------------------------------------------------------------------
  
  random <= func_common_random(random) WHEN rising_edge(clk);
  
  proc_common_gen_duty_pulse(g_pulse_active, g_pulse_period, '1', rst, clk, pulse_en, pulse);

  stimuli_en <= '1'                 WHEN g_flow_control=e_active ELSE
                random(random'HIGH) WHEN g_flow_control=e_random ELSE
                pulse               WHEN g_flow_control=e_pulse;
                       
  ------------------------------------------------------------------------------
  -- DATA GENERATION
  ------------------------------------------------------------------------------
  
  -- Generate data path input data
  p_stimuli_st : PROCESS
    VARIABLE v_sosi : t_dp_sosi := c_dp_sosi_rst;
    VARIABLE v_last : t_dp_sosi := c_dp_sosi_rst;
  BEGIN
    -- Initialisations
    last_snk_in <= c_dp_sosi_rst;
    last_snk_in_evt <= '0';
    tb_end <= '0';
    
    -- Adjust initial sosi field values by -1 to compensate for auto increment
    v_sosi.bsn     := INCR_UVEC(g_bsn_init,                    -1);
    v_sosi.channel := INCR_UVEC(TO_DP_CHANNEL(g_channel_init), -g_channel_incr);
    v_sosi.data    := INCR_UVEC(TO_DP_DATA(g_data_init),       -g_pkt_len);
    v_sosi.err     := INCR_UVEC(TO_DP_ERROR(g_err_init),       -g_err_incr);
    
    i_src_out <= c_dp_sosi_rst;
    proc_common_wait_until_low(clk, rst);
    proc_common_wait_some_cycles(clk, 5);

    -- Generate g_nof_repeat packets
    FOR I IN 0 TO g_nof_repeat-1 LOOP
      -- Auto increment v_sosi field values for this packet
      v_sosi.bsn     := INCR_UVEC(v_sosi.bsn, 1);
      v_sosi.sync    := sel_a_b((UNSIGNED(v_sosi.bsn) MOD g_sync_period) = g_sync_offset, '1', '0');  -- insert sync starting at BSN=g_sync_offset and with period g_sync_period
      v_sosi.channel := INCR_UVEC(v_sosi.channel, g_channel_incr);
      v_sosi.data    := INCR_UVEC(v_sosi.data, g_pkt_len);
      v_sosi.data    := RESIZE_DP_DATA(v_sosi.data(g_in_dat_w-1 DOWNTO 0));  -- wrap when >= 2**g_in_dat_w
      v_sosi.err     := INCR_UVEC(v_sosi.err, g_err_incr);
      
      -- Send packet
      proc_dp_gen_block_data(g_in_dat_w, TO_UINT(v_sosi.data), g_pkt_len, TO_UINT(v_sosi.channel), TO_UINT(v_sosi.err), v_sosi.sync, v_sosi.bsn, clk, stimuli_en, src_in, i_src_out);
      
      -- Insert optional gap between the packets
      proc_common_wait_some_cycles(clk, g_pkt_gap);
      
      -- Update v_last.sync
      IF v_sosi.sync='1' THEN v_last.sync := '1'; END IF;
    END LOOP;

    -- Update v_last control
    IF g_nof_repeat>0 THEN
      v_last.sop := '1';
      v_last.eop := '1';
      v_last.valid := '1';
    END IF;
    
    -- Determine and keep last expected sosi field values after end of stimuli
    -- . e_qual
    v_last.bsn     := STD_LOGIC_VECTOR( UNSIGNED(g_bsn_init) + g_nof_repeat-1);
    v_last.channel := TO_DP_CHANNEL(g_channel_init           + (g_nof_repeat-1)*g_channel_incr);
    v_last.err     := TO_DP_ERROR(g_err_init                 + (g_nof_repeat-1)*g_err_incr);
    -- . account for g_pkt_len
    v_last.data    := INCR_UVEC(v_sosi.data, g_pkt_len-1);
    v_last.data    := RESIZE_DP_DATA(v_last.data(g_in_dat_w-1 DOWNTO 0));  -- wrap when >= 2**g_in_dat_w
    last_snk_in <= v_last;
    
    -- Signal end of stimuli
    proc_common_wait_some_cycles(clk, g_wait_last_evt);  -- latency from stimuli to verify depends on the flow control, so wait sufficiently long for last packet to have passed through
    proc_common_gen_pulse(clk, last_snk_in_evt);
    proc_common_wait_some_cycles(clk, 50);
    tb_end <= '1';
    WAIT;
  END PROCESS;
    
  ------------------------------------------------------------------------------
  -- Auxiliary
  ------------------------------------------------------------------------------
  
  -- Map to slv to ease monitoring in wave window
  src_out_data <= i_src_out.data(g_in_dat_w-1 DOWNTO 0);
  
END str;
