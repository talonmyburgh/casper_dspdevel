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

-- Purpose: Verify dp_pipeline_ready for different RL
-- Description:
-- Usage:
-- > as 10
-- > run -all  -- signal tb_end will stop the simulation by stopping the clk
-- . The verify procedures check the correct output
  
LIBRARY IEEE, common_pkg_lib, dp_pkg_lib, dp_components_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.common_lfsr_sequences_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;
USE dp_pkg_lib.tb_dp_pkg.ALL;


ENTITY tb_dp_pipeline_ready IS
  GENERIC (
    g_in_en          : t_dp_flow_control_enum := e_random;  -- always active, random or pulse flow control
    g_out_ready      : t_dp_flow_control_enum := e_random;  -- always active, random or pulse flow control
    g_in_latency     : NATURAL := 1;  -- >= 0
    g_out_latency    : NATURAL := 0;  -- >= 0
    g_nof_repeat     : NATURAL := 50
  );
END tb_dp_pipeline_ready;


ARCHITECTURE tb OF tb_dp_pipeline_ready IS
  CONSTANT c_data_w          : NATURAL := 16;
  CONSTANT c_rl              : NATURAL := 1;
  CONSTANT c_data_init       : INTEGER := 0;
  CONSTANT c_frame_len_init  : NATURAL := 1;  -- >= 1
  CONSTANT c_pulse_active    : NATURAL := 1;
  CONSTANT c_pulse_period    : NATURAL := 7;
  CONSTANT c_sync_period     : NATURAL := 7;
  CONSTANT c_sync_offset     : NATURAL := 2;

  SIGNAL tb_end              : STD_LOGIC := '0';
  SIGNAL clk                 : STD_LOGIC := '1';
  SIGNAL rst                 : STD_LOGIC := '1';

  -- Flow control
  SIGNAL random_0            : STD_LOGIC_VECTOR(14 DOWNTO 0) := (OTHERS=>'0');  -- use different lengths to have different random sequences
  SIGNAL random_1            : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS=>'0');  -- use different lengths to have different random sequences
  SIGNAL pulse_0             : STD_LOGIC;
  SIGNAL pulse_1             : STD_LOGIC;
  SIGNAL pulse_en            : STD_LOGIC := '1';

  -- Stimuli
  SIGNAL in_en               : STD_LOGIC := '1';
  SIGNAL in_siso             : t_dp_siso;
  SIGNAL in_sosi             : t_dp_sosi;
  SIGNAL adapt_siso          : t_dp_siso;
  SIGNAL adapt_sosi          : t_dp_sosi;

  SIGNAL out_siso            : t_dp_siso := c_dp_siso_hold;  -- ready='0', xon='1'
  SIGNAL out_sosi            : t_dp_sosi;

  -- Verification
  SIGNAL verify_en           : STD_LOGIC := '0';
  SIGNAL verify_done         : STD_LOGIC := '0';
  SIGNAL count_eop           : NATURAL := 0;

  SIGNAL prev_out_ready      : STD_LOGIC_VECTOR(0 TO g_out_latency);
  SIGNAL prev_out_data       : STD_LOGIC_VECTOR(c_data_w-1 DOWNTO 0) := TO_SVEC(c_data_init-1, c_data_w);
  SIGNAL out_bsn             : STD_LOGIC_VECTOR(c_data_w-1 DOWNTO 0);
  SIGNAL out_data            : STD_LOGIC_VECTOR(c_data_w-1 DOWNTO 0);
  SIGNAL out_sync            : STD_LOGIC;
  SIGNAL out_val             : STD_LOGIC;
  SIGNAL out_sop             : STD_LOGIC;
  SIGNAL out_eop             : STD_LOGIC;
  SIGNAL hold_out_sop        : STD_LOGIC;
  SIGNAL expected_out_data   : STD_LOGIC_VECTOR(c_data_w-1 DOWNTO 0);

BEGIN

  clk <= (NOT clk) OR tb_end AFTER clk_period/2;
  rst <= '1', '0' AFTER clk_period*7;

  random_0 <= func_common_random(random_0) WHEN rising_edge(clk);
  random_1 <= func_common_random(random_1) WHEN rising_edge(clk);

  proc_common_gen_duty_pulse(c_pulse_active, c_pulse_period,   '1', rst, clk, pulse_en, pulse_0);
  proc_common_gen_duty_pulse(c_pulse_active, c_pulse_period+1, '1', rst, clk, pulse_en, pulse_1);


  ------------------------------------------------------------------------------
  -- STREAM CONTROL
  ------------------------------------------------------------------------------

  in_en          <= '1'                     WHEN g_in_en=e_active      ELSE
                    random_0(random_0'HIGH) WHEN g_in_en=e_random      ELSE
                    pulse_0                 WHEN g_in_en=e_pulse;

  out_siso.ready <= '1'                     WHEN g_out_ready=e_active  ELSE
                    random_1(random_1'HIGH) WHEN g_out_ready=e_random  ELSE
                    pulse_1                 WHEN g_out_ready=e_pulse;


  ------------------------------------------------------------------------------
  -- DATA GENERATION
  ------------------------------------------------------------------------------

  -- Generate data path input data
  p_stimuli : PROCESS
    VARIABLE v_data_init   : NATURAL;
    VARIABLE v_frame_len   : NATURAL;
    VARIABLE v_sync        : STD_LOGIC;
  BEGIN
    v_data_init := c_data_init;
    v_frame_len := c_frame_len_init;
    in_sosi <= c_dp_sosi_rst;
    proc_common_wait_until_low(clk, rst);
    proc_common_wait_some_cycles(clk, 5);

    -- Begin of stimuli
    FOR R IN 0 TO g_nof_repeat-1 LOOP
      v_sync := sel_a_b(R MOD c_sync_period = c_sync_offset, '1', '0');
      proc_dp_gen_block_data(c_rl, TRUE, c_data_w, c_data_w, v_data_init, 0, 0, v_frame_len, 0, 0, v_sync, TO_DP_BSN(R), clk, in_en, in_siso, in_sosi);
      --proc_common_wait_some_cycles(clk, 10);
      v_data_init := v_data_init + v_frame_len;
      v_frame_len := v_frame_len + 1;
    END LOOP;

    -- End of stimuli
    expected_out_data <= TO_UVEC(v_data_init-1, c_data_w);

    proc_common_wait_until_high(clk, verify_done);
    proc_common_wait_some_cycles(clk, 10);
    tb_end <= '1';
    WAIT;
  END PROCESS;
  
  -- proc_dp_gen_block_data() only supports RL=0 or 1, so use a latency adpater to support any g_in_latency
  u_input_adapt : ENTITY dp_components_lib.dp_latency_adapter
  GENERIC MAP (
    g_in_latency   => c_rl,
    g_out_latency  => g_in_latency
  )
  PORT MAP (
    rst          => rst,
    clk          => clk,
    -- ST sink
    snk_out      => in_siso,
    snk_in       => in_sosi,
    -- ST source
    src_in       => adapt_siso,
    src_out      => adapt_sosi 
  );


  ------------------------------------------------------------------------------
  -- DATA VERIFICATION
  ------------------------------------------------------------------------------


  -- Verification logistics
  verify_en <= '1'          WHEN rising_edge(clk) AND out_sosi.sop='1';          -- enable verify after first output sop
  count_eop <= count_eop+1  WHEN rising_edge(clk) AND out_sosi.eop='1' AND((g_out_latency>0) OR
                                                                           (g_out_latency=0 AND out_siso.ready='1'));  -- count number of output eop
  verify_done <= '1'        WHEN rising_edge(clk) AND count_eop = g_nof_repeat;  -- signal verify done after g_nof_repeat frames

  -- Actual verification of the output streams
  proc_dp_verify_data("out_sosi.data", g_out_latency, clk, verify_en, out_siso.ready, out_sosi.valid, out_data, prev_out_data);  -- Verify that the output is incrementing data, like the input stimuli
  proc_dp_verify_valid(g_out_latency, clk, verify_en, out_siso.ready, prev_out_ready, out_sosi.valid);                           -- Verify that the output valid fits with the output ready latency
  proc_dp_verify_sop_and_eop(g_out_latency, clk, out_siso.ready, out_sosi.valid, out_sosi.sop, out_sosi.eop, hold_out_sop);      -- Verify that sop and eop come in pairs
  proc_dp_verify_value(e_equal, clk, verify_done, expected_out_data, prev_out_data);                                             -- Verify that the stimuli have been applied at all
  proc_dp_verify_sync(c_sync_period, c_sync_offset, clk, verify_en, out_sosi.sync, out_sosi.sop, out_sosi.bsn);

  -- Monitoring
  out_bsn  <= out_sosi.bsn(c_data_w-1 DOWNTO 0);
  out_data <= out_sosi.data(c_data_w-1 DOWNTO 0);
  out_sync <= out_sosi.sync;
  out_val  <= out_sosi.valid;
  out_sop  <= out_sosi.sop;
  out_eop  <= out_sosi.eop;
  
  
  ------------------------------------------------------------------------------
  -- DUT dp_pipeline_ready
  ------------------------------------------------------------------------------

  pipeline : ENTITY work.dp_pipeline_ready
  GENERIC MAP (
    g_in_latency   => g_in_latency,
    g_out_latency  => g_out_latency
  )
  PORT MAP (
    rst          => rst,
    clk          => clk,
    -- ST sink
    snk_out      => adapt_siso,
    snk_in       => adapt_sosi,
    -- ST source
    src_in       => out_siso,
    src_out      => out_sosi
  );

    
END tb;
