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
USE common_pkg_lib.common_lfsr_sequences_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;

PACKAGE tb_dp_pkg IS

	------------------------------------------------------------------------------
	-- Purpose:
	--
	-- Test bench package for applying stimuli to a streaming data path. The
	-- input is counter data, the output is verified and an error is reported
	-- if a counter value is missing or duplicate.
	--
	-- Description:
	--
	-- The test is divided into intervals marked by sync to start a new subtest
	-- named by state. New subtests can be added by adding an extra sync interval
	-- and state name to this package. In each subtest the streaming interface
	-- DUT can be verified for different situations by manipulating:
	-- . cnt_en    : cnt_en not always active when in_ready is asserted
	-- . out_ready : out_ready not always active
	--
	-- Remarks:
	-- . See e.g. tb_dp_pipeline.vhd for how to use the procedures.
	-- . To run all stimuli in Modelsim do:
	--   > as 10
	--   > run 400 us
	------------------------------------------------------------------------------

	CONSTANT clk_period         : TIME    := 10 ns; -- 100 MHz
	CONSTANT c_dp_sync_interval : NATURAL := 3000;
	CONSTANT c_dp_test_interval : NATURAL := 100;
	CONSTANT c_dp_nof_toggle    : NATURAL := 40;
	CONSTANT c_dp_nof_both      : NATURAL := 50;

	-- The test bench uses other field widths than the standard t_dp_sosi record field widths, the assumptions are:
	-- . c_dp_data_w < c_dp_stream_data_w
	-- . c_dp_data_w > c_dp_stream_empty_w
	-- . c_dp_data_w > c_dp_stream_channel_w
	-- . c_dp_data_w > c_dp_stream_error_w
	CONSTANT c_dp_data_w         : NATURAL := c_word_w; -- =32, choose wide enough to avoid out_data wrap around issue for p_verify
	CONSTANT c_dp_bsn_w          : NATURAL := c_dp_data_w; -- c_dp_stream_bsn_w;
	CONSTANT c_dp_empty_w        : NATURAL := c_dp_stream_empty_w;
	CONSTANT c_dp_channel_w      : NATURAL := c_dp_stream_channel_w;
	CONSTANT c_dp_channel_user_w : NATURAL := c_dp_stream_channel_w / 2; -- support some bits for mux input user streams channel widths
	CONSTANT c_dp_channel_mux_w  : NATURAL := (c_dp_stream_channel_w + 1) / 2; -- support rest bits for the nof input ports of a mux
	CONSTANT c_dp_error_w        : NATURAL := c_dp_stream_error_w;

	TYPE t_dp_data_arr IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(c_dp_data_w - 1 DOWNTO 0);

	-- The state name tells what kind of test is done in the sync interval
	TYPE t_dp_state_enum IS (
		s_idle,
		s_both_active,
		s_pull_down_out_ready,
		s_pull_down_cnt_en,
		s_toggle_out_ready,
		s_toggle_cnt_en,
		s_toggle_both,
		s_pulse_cnt_en,
		s_chirp_out_ready,
		s_random,
		s_done
	);

	TYPE t_dp_value_enum IS (
		e_equal,
		e_at_least
	);

	-- always active, random or pulse flow control
	TYPE t_dp_flow_control_enum IS (
		e_active,
		e_random,
		e_pulse
	);

	TYPE t_dp_flow_control_enum_arr IS ARRAY (NATURAL RANGE <>) OF t_dp_flow_control_enum;

	CONSTANT c_dp_flow_control_enum_arr : t_dp_flow_control_enum_arr := (e_active, e_random, e_pulse); -- array all possible values that can be iterated over

	------------------------------------------------------------------------------
	-- Stream source functions
	------------------------------------------------------------------------------

	-- Block data generator with feedforward throttle control
	-- !!! old style: sync before sop
	-- !!! used by tb_dp_packetizing, do not use for new DP components
	PROCEDURE proc_dp_gen_block_data(CONSTANT c_nof_block_per_sync : IN NATURAL;
	                                 CONSTANT c_block_size         : IN NATURAL;
	                                 CONSTANT c_gap_size           : IN NATURAL;
	                                 CONSTANT c_throttle_num       : IN NATURAL;
	                                 CONSTANT c_throttle_den       : IN NATURAL;
	                                 SIGNAL rst                    : IN STD_LOGIC;
	                                 SIGNAL clk                    : IN STD_LOGIC;
	                                 SIGNAL sync_nr                : INOUT NATURAL;
	                                 SIGNAL block_nr               : INOUT NATURAL;
	                                 SIGNAL cnt_sync               : OUT STD_LOGIC;
	                                 SIGNAL cnt_val                : OUT STD_LOGIC;
	                                 SIGNAL cnt_dat                : INOUT STD_LOGIC_VECTOR);

	-- Block data generator with ready flow control and symbols counter
	PROCEDURE proc_dp_gen_block_data(CONSTANT c_ready_latency  : IN NATURAL; -- 0, 1 are supported by proc_dp_stream_ready_latency()
	                                 CONSTANT c_use_data       : IN BOOLEAN; -- when TRUE use data field, else use re, im fields, and keep unused fields at 'X'
	                                 CONSTANT c_data_w         : IN NATURAL; -- data width for the data, re and im fields
	                                 CONSTANT c_symbol_w       : IN NATURAL; -- c_data_w/c_symbol_w must be an integer
	                                 CONSTANT c_symbol_init    : IN NATURAL; -- init counter for symbols in data field
	                                 CONSTANT c_symbol_re_init : IN NATURAL; -- init counter for symbols in re field
	                                 CONSTANT c_symbol_im_init : IN NATURAL; -- init counter for symbols in im field
	                                 CONSTANT c_nof_symbols    : IN NATURAL; -- nof symbols per frame for the data, re and im fields
	                                 CONSTANT c_channel        : IN NATURAL; -- channel field
	                                 CONSTANT c_error          : IN NATURAL; -- error field
	                                 CONSTANT c_sync           : IN STD_LOGIC; -- when '1' issue sync pulse during this block
	                                 CONSTANT c_bsn            : IN STD_LOGIC_VECTOR; -- bsn field
	                                 SIGNAL clk                : IN STD_LOGIC;
	                                 SIGNAL in_en              : IN STD_LOGIC; -- when '0' then no valid output even when src_in is ready
	                                 SIGNAL src_in             : IN t_dp_siso;
	                                 SIGNAL src_out            : OUT t_dp_sosi);

	PROCEDURE proc_dp_gen_block_data(CONSTANT c_data_w      : IN NATURAL; -- data width for the data field
	                                 CONSTANT c_symbol_init : IN NATURAL; -- init counter for the data in the data field
	                                 CONSTANT c_nof_symbols : IN NATURAL; -- nof symbols per frame for the data fields
	                                 CONSTANT c_channel     : IN NATURAL; -- channel field
	                                 CONSTANT c_error       : IN NATURAL; -- error field
	                                 CONSTANT c_sync        : IN STD_LOGIC; -- when '1' issue sync pulse during this block
	                                 CONSTANT c_bsn         : IN STD_LOGIC_VECTOR; -- bsn field
	                                 SIGNAL clk             : IN STD_LOGIC;
	                                 SIGNAL in_en           : IN STD_LOGIC; -- when '0' then no valid output even when src_in is ready
	                                 SIGNAL src_in          : IN t_dp_siso;
	                                 SIGNAL src_out         : OUT t_dp_sosi);

	-- Handle stream ready signal, only support RL=0 or 1.
	PROCEDURE proc_dp_stream_ready_latency(CONSTANT c_latency : IN NATURAL;
	                                       SIGNAL clk         : IN STD_LOGIC;
	                                       SIGNAL ready       : IN STD_LOGIC;
	                                       SIGNAL in_en       : IN STD_LOGIC; -- when '1' then active output when ready
	                                       CONSTANT c_sync    : IN STD_LOGIC;
	                                       CONSTANT c_valid   : IN STD_LOGIC;
	                                       CONSTANT c_sop     : IN STD_LOGIC;
	                                       CONSTANT c_eop     : IN STD_LOGIC;
	                                       SIGNAL out_sync    : OUT STD_LOGIC;
	                                       SIGNAL out_valid   : OUT STD_LOGIC;
	                                       SIGNAL out_sop     : OUT STD_LOGIC;
	                                       SIGNAL out_eop     : OUT STD_LOGIC);

	-- Initialize the data per symbol
	FUNCTION func_dp_data_init(c_data_w, c_symbol_w, init : NATURAL) RETURN STD_LOGIC_VECTOR;

	-- Increment the data per symbol
	FUNCTION func_dp_data_incr(c_data_w, c_symbol_w : NATURAL; data : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;

	-- Generate a counter data with valid
	PROCEDURE proc_dp_gen_data(CONSTANT c_ready_latency : IN NATURAL; -- 0, 1 are supported by proc_dp_stream_ready_latency()
	                           CONSTANT c_data_w        : IN NATURAL;
	                           CONSTANT c_data_init     : IN NATURAL;
	                           SIGNAL rst               : IN STD_LOGIC;
	                           SIGNAL clk               : IN STD_LOGIC;
	                           SIGNAL in_en             : IN STD_LOGIC; -- when '0' then no valid output even when src_in is ready
	                           SIGNAL src_in            : IN t_dp_siso;
	                           SIGNAL src_out           : OUT t_dp_sosi);

	-- As above but with counter max
	PROCEDURE proc_dp_gen_data(CONSTANT c_ready_latency : IN NATURAL;
	                           CONSTANT c_data_w        : IN NATURAL;
	                           CONSTANT c_data_init     : IN NATURAL;
	                           CONSTANT c_data_max      : IN NATURAL;
	                           SIGNAL rst               : IN STD_LOGIC;
	                           SIGNAL clk               : IN STD_LOGIC;
	                           SIGNAL in_en             : IN STD_LOGIC;
	                           SIGNAL src_in            : IN t_dp_siso;
	                           SIGNAL src_out           : OUT t_dp_sosi);

	-- Generate a frame with symbols counter
	PROCEDURE proc_dp_gen_frame(CONSTANT c_ready_latency : IN NATURAL; -- 0, 1 are supported by proc_dp_stream_ready_latency()
	                            CONSTANT c_data_w        : IN NATURAL;
	                            CONSTANT c_symbol_w      : IN NATURAL; -- c_data_w/c_symbol_w must be an integer
	                            CONSTANT c_symbol_init   : IN NATURAL;
	                            CONSTANT c_nof_symbols   : IN NATURAL;
	                            CONSTANT c_bsn           : IN NATURAL;
	                            CONSTANT c_sync          : IN STD_LOGIC;
	                            SIGNAL clk               : IN STD_LOGIC;
	                            SIGNAL in_en             : IN STD_LOGIC; -- when '0' then no valid output even when src_in is ready
	                            SIGNAL src_in            : IN t_dp_siso;
	                            SIGNAL src_out           : OUT t_dp_sosi);

	-- Input data counter
	PROCEDURE proc_dp_cnt_dat(SIGNAL rst     : IN STD_LOGIC;
	                          SIGNAL clk     : IN STD_LOGIC;
	                          SIGNAL in_en   : IN STD_LOGIC;
	                          SIGNAL cnt_dat : INOUT STD_LOGIC_VECTOR);

	PROCEDURE proc_dp_cnt_dat(SIGNAL rst     : IN STD_LOGIC;
	                          SIGNAL clk     : IN STD_LOGIC;
	                          SIGNAL in_en   : IN STD_LOGIC;
	                          SIGNAL cnt_val : INOUT STD_LOGIC;
	                          SIGNAL cnt_dat : INOUT STD_LOGIC_VECTOR);

	-- Transmit data
	PROCEDURE proc_dp_tx_data(CONSTANT c_ready_latency : IN NATURAL;
	                          SIGNAL rst               : IN STD_LOGIC;
	                          SIGNAL clk               : IN STD_LOGIC;
	                          SIGNAL cnt_val           : IN STD_LOGIC;
	                          SIGNAL cnt_dat           : IN STD_LOGIC_VECTOR;
	                          SIGNAL tx_data           : INOUT t_dp_data_arr;
	                          SIGNAL tx_val            : INOUT STD_LOGIC_VECTOR;
	                          SIGNAL out_data          : OUT STD_LOGIC_VECTOR;
	                          SIGNAL out_val           : OUT STD_LOGIC);

	-- Transmit data control (use for sop, eop)
	PROCEDURE proc_dp_tx_ctrl(CONSTANT c_offset : IN NATURAL;
	                          CONSTANT c_period : IN NATURAL;
	                          SIGNAL data       : IN STD_LOGIC_VECTOR;
	                          SIGNAL valid      : IN STD_LOGIC;
	                          SIGNAL ctrl       : OUT STD_LOGIC);

	-- Define sync interval
	PROCEDURE proc_dp_sync_interval(SIGNAL clk  : IN STD_LOGIC;
	                                SIGNAL sync : OUT STD_LOGIC);

	-- Stimuli for cnt_en
	PROCEDURE proc_dp_count_en(SIGNAL rst    : IN STD_LOGIC;
	                           SIGNAL clk    : IN STD_LOGIC;
	                           SIGNAL sync   : IN STD_LOGIC;
	                           SIGNAL lfsr   : INOUT STD_LOGIC_VECTOR;
	                           SIGNAL state  : OUT t_dp_state_enum;
	                           SIGNAL done   : OUT STD_LOGIC;
	                           SIGNAL tb_end : OUT STD_LOGIC;
	                           SIGNAL cnt_en : OUT STD_LOGIC);

	------------------------------------------------------------------------------
	-- Stream sink functions
	------------------------------------------------------------------------------

	-- Stimuli for out_ready
	PROCEDURE proc_dp_out_ready(SIGNAL rst       : IN STD_LOGIC;
	                            SIGNAL clk       : IN STD_LOGIC;
	                            SIGNAL sync      : IN STD_LOGIC;
	                            SIGNAL lfsr      : INOUT STD_LOGIC_VECTOR;
	                            SIGNAL out_ready : OUT STD_LOGIC);

	-- DUT output verify enable
	PROCEDURE proc_dp_verify_en(CONSTANT c_delay : IN NATURAL;
	                            SIGNAL rst       : IN STD_LOGIC;
	                            SIGNAL clk       : IN STD_LOGIC;
	                            SIGNAL sync      : IN STD_LOGIC;
	                            SIGNAL verify_en : OUT STD_LOGIC);

	PROCEDURE proc_dp_verify_en(CONSTANT c_continuous : IN BOOLEAN;
	                            SIGNAL clk            : IN STD_LOGIC;
	                            SIGNAL valid          : IN STD_LOGIC;
	                            SIGNAL sop            : IN STD_LOGIC;
	                            SIGNAL eop            : IN STD_LOGIC;
	                            SIGNAL verify_en      : OUT STD_LOGIC);

	-- Run and verify for some cycles
	PROCEDURE proc_dp_verify_run_some_cycles(CONSTANT nof_pre_clk    : IN NATURAL;
	                                         CONSTANT nof_verify_clk : IN NATURAL;
	                                         CONSTANT nof_post_clk   : IN NATURAL;
	                                         SIGNAL clk              : IN STD_LOGIC;
	                                         SIGNAL verify_en        : OUT STD_LOGIC);

	-- Verify the expected value
	PROCEDURE proc_dp_verify_value(CONSTANT c_str : IN STRING;
	                               CONSTANT mode  : IN t_dp_value_enum;
	                               SIGNAL clk     : IN STD_LOGIC;
	                               SIGNAL en      : IN STD_LOGIC;
	                               SIGNAL exp     : IN STD_LOGIC_VECTOR;
	                               SIGNAL res     : IN STD_LOGIC_VECTOR);

	PROCEDURE proc_dp_verify_value(CONSTANT mode : IN t_dp_value_enum;
	                               SIGNAL clk    : IN STD_LOGIC;
	                               SIGNAL en     : IN STD_LOGIC;
	                               SIGNAL exp    : IN STD_LOGIC_VECTOR;
	                               SIGNAL res    : IN STD_LOGIC_VECTOR);

	PROCEDURE proc_dp_verify_value(CONSTANT c_str : IN STRING;
	                               SIGNAL clk     : IN STD_LOGIC;
	                               SIGNAL en      : IN STD_LOGIC;
	                               SIGNAL exp     : IN STD_LOGIC;
	                               SIGNAL res     : IN STD_LOGIC);

	-- Verify output global and local BSN
	-- . incrementing or replicated global BSN
	-- . incrementing local BSN that starts at 1
	PROCEDURE proc_dp_verify_bsn(CONSTANT c_use_local_bsn             : IN BOOLEAN; -- use local BSN or only use global BSN
	                             CONSTANT c_global_bsn_increment      : IN POSITIVE; -- increment per global BSN
	                             CONSTANT c_nof_replicated_global_bsn : IN POSITIVE; -- number of replicated global BSN
	                             CONSTANT c_block_per_sync            : IN POSITIVE; -- of sop/eop blocks per sync interval
	                             SIGNAL clk                           : IN STD_LOGIC;
	                             SIGNAL out_sync                      : IN STD_LOGIC;
	                             SIGNAL out_sop                       : IN STD_LOGIC;
	                             SIGNAL out_bsn                       : IN STD_LOGIC_VECTOR;
	                             SIGNAL verify_en                     : INOUT STD_LOGIC; -- initialize '0', becomes '1' when bsn verification starts
	                             SIGNAL cnt_replicated_global_bsn     : INOUT NATURAL;
	                             SIGNAL prev_out_bsn_global           : INOUT STD_LOGIC_VECTOR;
	                             SIGNAL prev_out_bsn_local            : INOUT STD_LOGIC_VECTOR);

	-- Verify incrementing data
	-- . wrap at c_out_data_max when >0, else no wrap when c_out_data_max=0
	-- . default increment by +1, but also allow an increment by +c_out_data_gap
	PROCEDURE proc_dp_verify_data(CONSTANT c_str           : IN STRING;
	                              CONSTANT c_ready_latency : IN NATURAL;
	                              CONSTANT c_out_data_max  : IN UNSIGNED;
	                              CONSTANT c_out_data_gap  : IN UNSIGNED;
	                              SIGNAL clk               : IN STD_LOGIC;
	                              SIGNAL verify_en         : IN STD_LOGIC;
	                              SIGNAL out_ready         : IN STD_LOGIC;
	                              SIGNAL out_val           : IN STD_LOGIC;
	                              SIGNAL out_data          : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data     : INOUT STD_LOGIC_VECTOR);

	-- Verify the DUT incrementing output data that wraps in range 0 ... c_out_data_max
	PROCEDURE proc_dp_verify_data(CONSTANT c_str           : IN STRING;
	                              CONSTANT c_ready_latency : IN NATURAL;
	                              CONSTANT c_out_data_max  : IN UNSIGNED;
	                              SIGNAL clk               : IN STD_LOGIC;
	                              SIGNAL verify_en         : IN STD_LOGIC;
	                              SIGNAL out_ready         : IN STD_LOGIC;
	                              SIGNAL out_val           : IN STD_LOGIC;
	                              SIGNAL out_data          : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data     : INOUT STD_LOGIC_VECTOR);

	-- Verify the DUT incrementing output data, fixed increment +1
	PROCEDURE proc_dp_verify_data(CONSTANT c_str           : IN STRING;
	                              CONSTANT c_ready_latency : IN NATURAL;
	                              SIGNAL clk               : IN STD_LOGIC;
	                              SIGNAL verify_en         : IN STD_LOGIC;
	                              SIGNAL out_ready         : IN STD_LOGIC;
	                              SIGNAL out_val           : IN STD_LOGIC; -- by using sop or eop proc_dp_verify_data() can also be used to verify other SOSI fields like bsn, error, channel, empty
	                              SIGNAL out_data          : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data     : INOUT STD_LOGIC_VECTOR);

	-- Verify incrementing data with RL > 0 or no flow control, support wrap at maximum and increment gap
	PROCEDURE proc_dp_verify_data(CONSTANT c_str          : IN STRING;
	                              CONSTANT c_out_data_max : IN UNSIGNED;
	                              CONSTANT c_out_data_gap : IN UNSIGNED;
	                              SIGNAL clk              : IN STD_LOGIC;
	                              SIGNAL verify_en        : IN STD_LOGIC;
	                              SIGNAL out_val          : IN STD_LOGIC;
	                              SIGNAL out_data         : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data    : INOUT STD_LOGIC_VECTOR);

	PROCEDURE proc_dp_verify_data(CONSTANT c_str          : IN STRING;
	                              CONSTANT c_out_data_max : IN NATURAL;
	                              CONSTANT c_out_data_gap : IN NATURAL;
	                              SIGNAL clk              : IN STD_LOGIC;
	                              SIGNAL verify_en        : IN STD_LOGIC;
	                              SIGNAL out_val          : IN STD_LOGIC;
	                              SIGNAL out_data         : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data    : INOUT STD_LOGIC_VECTOR);

	PROCEDURE proc_dp_verify_data(CONSTANT c_str          : IN STRING;
	                              CONSTANT c_out_data_max : IN NATURAL;
	                              SIGNAL clk              : IN STD_LOGIC;
	                              SIGNAL verify_en        : IN STD_LOGIC;
	                              SIGNAL out_val          : IN STD_LOGIC;
	                              SIGNAL out_data         : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data    : INOUT STD_LOGIC_VECTOR);

	-- Verify incrementing data with RL > 0 or no flow control, fixed increment +1
	PROCEDURE proc_dp_verify_data(CONSTANT c_str       : IN STRING;
	                              SIGNAL clk           : IN STD_LOGIC;
	                              SIGNAL verify_en     : IN STD_LOGIC;
	                              SIGNAL out_val       : IN STD_LOGIC;
	                              SIGNAL out_data      : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data : INOUT STD_LOGIC_VECTOR);

	-- Verify the DUT output symbols
	PROCEDURE proc_dp_verify_symbols(CONSTANT c_ready_latency : IN NATURAL;
	                                 CONSTANT c_data_w        : IN NATURAL;
	                                 CONSTANT c_symbol_w      : IN NATURAL;
	                                 SIGNAL clk               : IN STD_LOGIC;
	                                 SIGNAL verify_en         : IN STD_LOGIC;
	                                 SIGNAL out_ready         : IN STD_LOGIC;
	                                 SIGNAL out_val           : IN STD_LOGIC;
	                                 SIGNAL out_eop           : IN STD_LOGIC;
	                                 SIGNAL out_data          : IN STD_LOGIC_VECTOR;
	                                 SIGNAL out_empty         : IN STD_LOGIC_VECTOR;
	                                 SIGNAL prev_out_data     : INOUT STD_LOGIC_VECTOR);

	-- Verify the DUT output data with empty
	PROCEDURE proc_dp_verify_data_empty(CONSTANT c_ready_latency : IN NATURAL;
	                                    CONSTANT c_last_word     : IN NATURAL;
	                                    SIGNAL clk               : IN STD_LOGIC;
	                                    SIGNAL verify_en         : IN STD_LOGIC;
	                                    SIGNAL out_ready         : IN STD_LOGIC;
	                                    SIGNAL out_val           : IN STD_LOGIC;
	                                    SIGNAL out_eop           : IN STD_LOGIC;
	                                    SIGNAL out_eop_1         : INOUT STD_LOGIC;
	                                    SIGNAL out_eop_2         : INOUT STD_LOGIC;
	                                    SIGNAL out_data          : IN STD_LOGIC_VECTOR;
	                                    SIGNAL out_data_1        : INOUT STD_LOGIC_VECTOR;
	                                    SIGNAL out_data_2        : INOUT STD_LOGIC_VECTOR;
	                                    SIGNAL out_data_3        : INOUT STD_LOGIC_VECTOR;
	                                    SIGNAL out_empty         : IN STD_LOGIC_VECTOR;
	                                    SIGNAL out_empty_1       : INOUT STD_LOGIC_VECTOR);

	PROCEDURE proc_dp_verify_other_sosi(CONSTANT c_str      : IN STRING;
	                                    CONSTANT c_exp_data : IN STD_LOGIC_VECTOR;
	                                    SIGNAL clk          : IN STD_LOGIC;
	                                    SIGNAL verify_en    : IN STD_LOGIC;
	                                    SIGNAL res_data     : IN STD_LOGIC_VECTOR);

	PROCEDURE proc_dp_verify_valid(CONSTANT c_ready_latency : IN NATURAL;
	                               SIGNAL clk               : IN STD_LOGIC;
	                               SIGNAL verify_en         : IN STD_LOGIC;
	                               SIGNAL out_ready         : IN STD_LOGIC;
	                               SIGNAL prev_out_ready    : INOUT STD_LOGIC_VECTOR;
	                               SIGNAL out_val           : IN STD_LOGIC);

	PROCEDURE proc_dp_verify_valid(SIGNAL clk            : IN STD_LOGIC;
	                               SIGNAL verify_en      : IN STD_LOGIC;
	                               SIGNAL out_ready      : IN STD_LOGIC;
	                               SIGNAL prev_out_ready : INOUT STD_LOGIC;
	                               SIGNAL out_val        : IN STD_LOGIC);

	-- Verify the DUT output sync
	PROCEDURE proc_dp_verify_sync(CONSTANT c_sync_period : IN NATURAL;
	                              CONSTANT c_sync_offset : IN NATURAL;
	                              SIGNAL clk             : IN STD_LOGIC;
	                              SIGNAL verify_en       : IN STD_LOGIC;
	                              SIGNAL sync            : IN STD_LOGIC;
	                              SIGNAL sop             : IN STD_LOGIC;
	                              SIGNAL bsn             : IN STD_LOGIC_VECTOR);

	-- Verify the DUT output sop and eop
	PROCEDURE proc_dp_verify_sop_and_eop(CONSTANT c_ready_latency : IN NATURAL;
	                                     CONSTANT c_verify_valid  : IN BOOLEAN;
	                                     SIGNAL clk               : IN STD_LOGIC;
	                                     SIGNAL out_ready         : IN STD_LOGIC;
	                                     SIGNAL out_val           : IN STD_LOGIC;
	                                     SIGNAL out_sop           : IN STD_LOGIC;
	                                     SIGNAL out_eop           : IN STD_LOGIC;
	                                     SIGNAL hold_sop          : INOUT STD_LOGIC);

	PROCEDURE proc_dp_verify_sop_and_eop(CONSTANT c_ready_latency : IN NATURAL;
	                                     SIGNAL clk               : IN STD_LOGIC;
	                                     SIGNAL out_ready         : IN STD_LOGIC;
	                                     SIGNAL out_val           : IN STD_LOGIC;
	                                     SIGNAL out_sop           : IN STD_LOGIC;
	                                     SIGNAL out_eop           : IN STD_LOGIC;
	                                     SIGNAL hold_sop          : INOUT STD_LOGIC);

	PROCEDURE proc_dp_verify_sop_and_eop(SIGNAL clk      : IN STD_LOGIC;
	                                     SIGNAL out_val  : IN STD_LOGIC;
	                                     SIGNAL out_sop  : IN STD_LOGIC;
	                                     SIGNAL out_eop  : IN STD_LOGIC;
	                                     SIGNAL hold_sop : INOUT STD_LOGIC);

	PROCEDURE proc_dp_verify_block_size(CONSTANT c_ready_latency : IN NATURAL;
	                                    SIGNAL alt_size          : IN NATURAL; -- alternative size (eg. use exp_size'last_value)
	                                    SIGNAL exp_size          : IN NATURAL; -- expected size
	                                    SIGNAL clk               : IN STD_LOGIC;
	                                    SIGNAL out_ready         : IN STD_LOGIC;
	                                    SIGNAL out_val           : IN STD_LOGIC;
	                                    SIGNAL out_sop           : IN STD_LOGIC;
	                                    SIGNAL out_eop           : IN STD_LOGIC;
	                                    SIGNAL cnt_size          : INOUT NATURAL);

	PROCEDURE proc_dp_verify_block_size(CONSTANT c_ready_latency : IN NATURAL;
	                                    SIGNAL exp_size          : IN NATURAL; -- expected size
	                                    SIGNAL clk               : IN STD_LOGIC;
	                                    SIGNAL out_ready         : IN STD_LOGIC;
	                                    SIGNAL out_val           : IN STD_LOGIC;
	                                    SIGNAL out_sop           : IN STD_LOGIC;
	                                    SIGNAL out_eop           : IN STD_LOGIC;
	                                    SIGNAL cnt_size          : INOUT NATURAL);

	PROCEDURE proc_dp_verify_block_size(SIGNAL alt_size : IN NATURAL; -- alternative size (eg. use exp_size'last_value)
	                                    SIGNAL exp_size : IN NATURAL; -- expected size
	                                    SIGNAL clk      : IN STD_LOGIC;
	                                    SIGNAL out_val  : IN STD_LOGIC;
	                                    SIGNAL out_sop  : IN STD_LOGIC;
	                                    SIGNAL out_eop  : IN STD_LOGIC;
	                                    SIGNAL cnt_size : INOUT NATURAL);

	PROCEDURE proc_dp_verify_block_size(SIGNAL exp_size : IN NATURAL; -- expected size
	                                    SIGNAL clk      : IN STD_LOGIC;
	                                    SIGNAL out_val  : IN STD_LOGIC;
	                                    SIGNAL out_sop  : IN STD_LOGIC;
	                                    SIGNAL out_eop  : IN STD_LOGIC;
	                                    SIGNAL cnt_size : INOUT NATURAL);

	-- Verify the DUT output invalid between frames
	PROCEDURE proc_dp_verify_gap_invalid(SIGNAL clk     : IN STD_LOGIC;
	                                     SIGNAL in_val  : IN STD_LOGIC;
	                                     SIGNAL in_sop  : IN STD_LOGIC;
	                                     SIGNAL in_eop  : IN STD_LOGIC;
	                                     SIGNAL out_gap : INOUT STD_LOGIC); -- declare initial gap signal = '1'

	-- Verify the DUT output control (use for sop, eop)
	PROCEDURE proc_dp_verify_ctrl(CONSTANT c_offset : IN NATURAL;
	                              CONSTANT c_period : IN NATURAL;
	                              CONSTANT c_str    : IN STRING;
	                              SIGNAL clk        : IN STD_LOGIC;
	                              SIGNAL verify_en  : IN STD_LOGIC;
	                              SIGNAL data       : IN STD_LOGIC_VECTOR;
	                              SIGNAL valid      : IN STD_LOGIC;
	                              SIGNAL ctrl       : IN STD_LOGIC);

	-- Wait for stream valid
	PROCEDURE proc_dp_stream_valid(SIGNAL clk      : IN STD_LOGIC;
	                               SIGNAL in_valid : IN STD_LOGIC);

	-- Wait for stream valid AND sop
	PROCEDURE proc_dp_stream_valid_sop(SIGNAL clk      : IN STD_LOGIC;
	                                   SIGNAL in_valid : IN STD_LOGIC;
	                                   SIGNAL in_sop   : IN STD_LOGIC);

	-- Wait for stream valid AND eop
	PROCEDURE proc_dp_stream_valid_eop(SIGNAL clk      : IN STD_LOGIC;
	                                   SIGNAL in_valid : IN STD_LOGIC;
	                                   SIGNAL in_eop   : IN STD_LOGIC);

END tb_dp_pkg;

PACKAGE BODY tb_dp_pkg IS

	------------------------------------------------------------------------------
	-- PROCEDURE: Block data generator with feedforward throttle control
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_gen_block_data(CONSTANT c_nof_block_per_sync : IN NATURAL;
	                                 CONSTANT c_block_size         : IN NATURAL;
	                                 CONSTANT c_gap_size           : IN NATURAL;
	                                 CONSTANT c_throttle_num       : IN NATURAL;
	                                 CONSTANT c_throttle_den       : IN NATURAL;
	                                 SIGNAL rst                    : IN STD_LOGIC;
	                                 SIGNAL clk                    : IN STD_LOGIC;
	                                 SIGNAL sync_nr                : INOUT NATURAL;
	                                 SIGNAL block_nr               : INOUT NATURAL;
	                                 SIGNAL cnt_sync               : OUT STD_LOGIC;
	                                 SIGNAL cnt_val                : OUT STD_LOGIC;
	                                 SIGNAL cnt_dat                : INOUT STD_LOGIC_VECTOR) IS
		CONSTANT c_start_delay : NATURAL := 10;
		VARIABLE v_throttle    : NATURAL;
	BEGIN
		sync_nr  <= 0;
		block_nr <= 0;

		cnt_sync <= '0';
		cnt_val  <= '0';
		cnt_dat  <= (cnt_dat'RANGE => '1'); -- -1, so first valid cnt_dat starts at 0

		-- allow some clock cycles before start after rst release
		WAIT UNTIL rst = '0';
		FOR I IN 0 TO c_start_delay - 1 LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- output first sync
		cnt_sync <= '1';
		WAIT UNTIL rising_edge(clk);
		cnt_sync <= '0';
		FOR I IN 1 TO c_gap_size - 1 LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		WHILE TRUE LOOP
			-- output block
			IF c_throttle_num >= c_throttle_den THEN
				-- no need to throttle, so cnt_val active during whole data block
				FOR I IN 0 TO c_block_size - 1 LOOP
					cnt_val <= '1';
					cnt_dat <= INCR_UVEC(cnt_dat, 1);
					WAIT UNTIL rising_edge(clk);
				END LOOP;
			ELSE
				-- throttle cnt_val, so c_throttle_num active cnt_val cycles per c_throttle_den cycles
				FOR I IN 0 TO c_block_size / c_throttle_num - 1 LOOP
					FOR J IN 0 TO c_throttle_num - 1 LOOP
						cnt_val <= '1';
						cnt_dat <= INCR_UVEC(cnt_dat, 1);
						WAIT UNTIL rising_edge(clk);
					END LOOP;
					FOR J IN 0 TO c_throttle_den - c_throttle_num - 1 LOOP
						cnt_val <= '0';
						WAIT UNTIL rising_edge(clk);
					END LOOP;
				END LOOP;
			END IF;
			cnt_val  <= '0';
			-- output sync for next block at first sample of gap
			IF block_nr > 0 AND ((block_nr + 1) MOD c_nof_block_per_sync) = 0 THEN
				cnt_sync <= '1';
				sync_nr  <= sync_nr + 1;
			END IF;
			WAIT UNTIL rising_edge(clk);
			-- output rest of the gap
			cnt_sync <= '0';
			FOR I IN 1 TO c_gap_size - 1 LOOP
				WAIT UNTIL rising_edge(clk);
			END LOOP;
			-- next block
			block_nr <= block_nr + 1;
		END LOOP;
	END proc_dp_gen_block_data;

	------------------------------------------------------------------------------
	-- PROCEDURE: Block data generator with ready flow control and symbols counter
	-- . dependent on in_en and src_in.ready
	-- . optional sync pulse at end of frame 
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_gen_block_data(CONSTANT c_ready_latency  : IN NATURAL; -- 0, 1 are supported by proc_dp_stream_ready_latency()
	                                 CONSTANT c_use_data       : IN BOOLEAN; -- when TRUE use data field, else use re, im fields, and keep unused fields at 'X'
	                                 CONSTANT c_data_w         : IN NATURAL; -- data width for the data, re and im fields
	                                 CONSTANT c_symbol_w       : IN NATURAL; -- c_data_w/c_symbol_w must be an integer
	                                 CONSTANT c_symbol_init    : IN NATURAL; -- init counter for symbols in data field
	                                 CONSTANT c_symbol_re_init : IN NATURAL; -- init counter for symbols in re field
	                                 CONSTANT c_symbol_im_init : IN NATURAL; -- init counter for symbols in im field
	                                 CONSTANT c_nof_symbols    : IN NATURAL; -- nof symbols per frame for the data, re and im fields
	                                 CONSTANT c_channel        : IN NATURAL; -- channel field
	                                 CONSTANT c_error          : IN NATURAL; -- error field
	                                 CONSTANT c_sync           : IN STD_LOGIC; -- when '1' issue sync pulse during this block
	                                 CONSTANT c_bsn            : IN STD_LOGIC_VECTOR; -- bsn field
	                                 SIGNAL clk                : IN STD_LOGIC;
	                                 SIGNAL in_en              : IN STD_LOGIC; -- when '0' then no valid output even when src_in is ready
	                                 SIGNAL src_in             : IN t_dp_siso;
	                                 SIGNAL src_out            : OUT t_dp_sosi) IS
		CONSTANT c_nof_symbols_per_data : NATURAL                                 := c_data_w / c_symbol_w;
		CONSTANT c_div                  : NATURAL                                 := c_nof_symbols / c_nof_symbols_per_data;
		CONSTANT c_mod                  : NATURAL                                 := c_nof_symbols MOD c_nof_symbols_per_data;
		CONSTANT c_empty                : NATURAL                                 := sel_a_b(c_mod, c_nof_symbols_per_data - c_mod, 0);
		CONSTANT c_nof_data             : NATURAL                                 := sel_a_b(c_mod, 1, 0) + c_div;
		VARIABLE v_data                 : STD_LOGIC_VECTOR(c_data_w - 1 DOWNTO 0) := func_dp_data_init(c_data_w, c_symbol_w, c_symbol_init);
		VARIABLE v_re                   : STD_LOGIC_VECTOR(c_data_w - 1 DOWNTO 0) := func_dp_data_init(c_data_w, c_symbol_w, c_symbol_re_init);
		VARIABLE v_im                   : STD_LOGIC_VECTOR(c_data_w - 1 DOWNTO 0) := func_dp_data_init(c_data_w, c_symbol_w, c_symbol_im_init);
	BEGIN
		src_out <= c_dp_sosi_rst;
		IF src_in.xon = '1' THEN
			-- Generate this block
			src_out.bsn     <= RESIZE_DP_BSN(c_bsn);
			src_out.empty   <= TO_DP_EMPTY(c_empty);
			src_out.channel <= TO_DP_CHANNEL(c_channel);
			src_out.err     <= TO_DP_ERROR(c_error);
			IF c_use_data = TRUE THEN
				src_out.data <= RESIZE_DP_DATA(v_data);
			END IF;
			IF c_use_data = FALSE THEN
				src_out.re <= RESIZE_DP_DSP_DATA(v_re);
			END IF;
			IF c_use_data = FALSE THEN
				src_out.im <= RESIZE_DP_DSP_DATA(v_im);
			END IF;
			IF c_nof_data > 1 THEN
				-- . sop
				proc_dp_stream_ready_latency(c_ready_latency, clk, src_in.ready, in_en, c_sync, '1', '1', '0', src_out.sync, src_out.valid, src_out.sop, src_out.eop);
				-- . valid
				FOR I IN 1 TO c_nof_data - 2 LOOP
					v_data := func_dp_data_incr(c_data_w, c_symbol_w, v_data);
					v_re   := func_dp_data_incr(c_data_w, c_symbol_w, v_re);
					v_im   := func_dp_data_incr(c_data_w, c_symbol_w, v_im);
					IF c_use_data = TRUE THEN
						src_out.data <= RESIZE_DP_DATA(v_data);
					END IF;
					IF c_use_data = FALSE THEN
						src_out.re <= RESIZE_DP_DSP_DATA(v_re);
					END IF;
					IF c_use_data = FALSE THEN
						src_out.im <= RESIZE_DP_DSP_DATA(v_im);
					END IF;
					proc_dp_stream_ready_latency(c_ready_latency, clk, src_in.ready, in_en, '0', '1', '0', '0', src_out.sync, src_out.valid, src_out.sop, src_out.eop);
				END LOOP;

				-- . eop
				v_data := func_dp_data_incr(c_data_w, c_symbol_w, v_data);
				v_re   := func_dp_data_incr(c_data_w, c_symbol_w, v_re);
				v_im   := func_dp_data_incr(c_data_w, c_symbol_w, v_im);
				IF c_use_data = TRUE THEN
					src_out.data <= RESIZE_DP_DATA(v_data);
				END IF;
				IF c_use_data = FALSE THEN
					src_out.re <= RESIZE_DP_DSP_DATA(v_re);
				END IF;
				IF c_use_data = FALSE THEN
					src_out.im <= RESIZE_DP_DSP_DATA(v_im);
				END IF;
				proc_dp_stream_ready_latency(c_ready_latency, clk, src_in.ready, in_en, '0', '1', '0', '1', src_out.sync, src_out.valid, src_out.sop, src_out.eop);
			ELSE
				-- . sop and eop, frame has only one word
				proc_dp_stream_ready_latency(c_ready_latency, clk, src_in.ready, in_en, c_sync, '1', '1', '1', src_out.sync, src_out.valid, src_out.sop, src_out.eop);
			END IF;
		ELSE
			-- Skip this block
			proc_common_wait_some_cycles(clk, c_nof_data);
		END IF;
	END proc_dp_gen_block_data;

	PROCEDURE proc_dp_gen_block_data(CONSTANT c_data_w      : IN NATURAL; -- data width for the data field
	                                 CONSTANT c_symbol_init : IN NATURAL; -- init counter for the data in the data field
	                                 CONSTANT c_nof_symbols : IN NATURAL; -- nof symbols per frame for the data fields
	                                 CONSTANT c_channel     : IN NATURAL; -- channel field
	                                 CONSTANT c_error       : IN NATURAL; -- error field
	                                 CONSTANT c_sync        : IN STD_LOGIC; -- when '1' issue sync pulse during this block
	                                 CONSTANT c_bsn         : IN STD_LOGIC_VECTOR; -- bsn field
	                                 SIGNAL clk             : IN STD_LOGIC;
	                                 SIGNAL in_en           : IN STD_LOGIC; -- when '0' then no valid output even when src_in is ready
	                                 SIGNAL src_in          : IN t_dp_siso;
	                                 SIGNAL src_out         : OUT t_dp_sosi) IS
	BEGIN
		proc_dp_gen_block_data(1, TRUE, c_data_w, c_data_w, c_symbol_init, 0, 0, c_nof_symbols, c_channel, c_error, c_sync, c_bsn, clk, in_en, src_in, src_out);
	END proc_dp_gen_block_data;

	------------------------------------------------------------------------------
	-- PROCEDURE: Handle stream ready signal
	-- . output active when src_in is ready and in_en='1'
	-- . only support RL=0 or 1, support for RL>1 requires keeping previous ready information in a STD_LOGIC_VECTOR(RL-1 DOWNTO 0).
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_stream_ready_latency(CONSTANT c_latency : IN NATURAL;
	                                       SIGNAL clk         : IN STD_LOGIC;
	                                       SIGNAL ready       : IN STD_LOGIC;
	                                       SIGNAL in_en       : IN STD_LOGIC;
	                                       CONSTANT c_sync    : IN STD_LOGIC;
	                                       CONSTANT c_valid   : IN STD_LOGIC;
	                                       CONSTANT c_sop     : IN STD_LOGIC;
	                                       CONSTANT c_eop     : IN STD_LOGIC;
	                                       SIGNAL out_sync    : OUT STD_LOGIC;
	                                       SIGNAL out_valid   : OUT STD_LOGIC;
	                                       SIGNAL out_sop     : OUT STD_LOGIC;
	                                       SIGNAL out_eop     : OUT STD_LOGIC) IS
	BEGIN
		-- Default no output
		out_sync  <= '0';
		out_valid <= '0';
		out_sop   <= '0';
		out_eop   <= '0';

		-- Skip cycles until in_en='1'
		WHILE in_en = '0' LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- Active output when ready
		-- . RL = 0
		IF c_latency = 0 THEN
			-- show the available output until acknowledge
			out_sync  <= c_sync;
			out_valid <= c_valid;
			out_sop   <= c_sop;
			out_eop   <= c_eop;
			WAIT UNTIL rising_edge(clk);
			WHILE ready /= '1' LOOP
				WAIT UNTIL rising_edge(clk);
			END LOOP;
			-- ready has acknowledged the valid output
		END IF;

		-- . RL = 1
		IF c_latency = 1 THEN
			-- no valid output until request
			WHILE ready /= '1' LOOP
				WAIT UNTIL rising_edge(clk);
			END LOOP;
			-- ready has requested this valid output
			out_sync  <= c_sync;
			out_valid <= c_valid;
			out_sop   <= c_sop;
			out_eop   <= c_eop;
			WAIT UNTIL rising_edge(clk);
		END IF;

		-- Return with no active output
		out_sync  <= '0';
		out_valid <= '0';
		out_sop   <= '0';
		out_eop   <= '0';
	END proc_dp_stream_ready_latency;

	------------------------------------------------------------------------------
	-- FUNCTION: Initialize the data per symbol
	-- . use big endian
	-- . if c_data_w=32, c_symbol_w=8, init=3 then return 0x03040506
	------------------------------------------------------------------------------
	FUNCTION func_dp_data_init(c_data_w, c_symbol_w, init : NATURAL) RETURN STD_LOGIC_VECTOR IS
		CONSTANT c_nof_symbols_per_data : NATURAL := c_data_w / c_symbol_w;
		VARIABLE v_data                 : STD_LOGIC_VECTOR(c_data_w - 1 DOWNTO 0);
		VARIABLE v_sym                  : STD_LOGIC_VECTOR(c_symbol_w - 1 DOWNTO 0);
	BEGIN
		v_data := (OTHERS => '0');
		v_sym  := TO_UVEC(init, c_symbol_w);
		FOR I IN c_nof_symbols_per_data - 1 DOWNTO 0 LOOP
			v_data((I + 1) * c_symbol_w - 1 DOWNTO I * c_symbol_w) := v_sym;
			v_sym                                                  := INCR_UVEC(v_sym, 1);
		END LOOP;
		RETURN v_data;
	END func_dp_data_init;

	------------------------------------------------------------------------------
	-- FUNCTION: Increment the data per symbol
	-- . use big endian
	-- . if c_data_w=32, c_symbol_w=8 then 0x00010203 returns 0x04050607
	-- . the actual data'LENGTH must be >= c_data_w, unused bits become 0
	-- . c_data_w/c_symbol_w must be an integer
	------------------------------------------------------------------------------
	FUNCTION func_dp_data_incr(c_data_w, c_symbol_w : NATURAL; data : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
		CONSTANT c_nof_symbols_per_data : NATURAL := c_data_w / c_symbol_w;
		VARIABLE v_data                 : STD_LOGIC_VECTOR(data'LENGTH - 1 DOWNTO 0);
		VARIABLE v_sym                  : STD_LOGIC_VECTOR(c_symbol_w - 1 DOWNTO 0);
	BEGIN
		v_data := (OTHERS => '0');
		v_sym  := data(c_symbol_w - 1 DOWNTO 0);
		FOR I IN c_nof_symbols_per_data - 1 DOWNTO 0 LOOP
			v_sym                                                  := INCR_UVEC(v_sym, 1);
			v_data((I + 1) * c_symbol_w - 1 DOWNTO I * c_symbol_w) := v_sym;
		END LOOP;
		RETURN v_data;
	END func_dp_data_incr;

	------------------------------------------------------------------------------
	-- PROCEDURE: Generate counter data with valid
	-- . Output counter data dependent on in_en and src_in.ready
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_gen_data(CONSTANT c_ready_latency : IN NATURAL; -- 0, 1 are supported by proc_dp_stream_ready_latency()
	                           CONSTANT c_data_w        : IN NATURAL;
	                           CONSTANT c_data_init     : IN NATURAL;
	                           SIGNAL rst               : IN STD_LOGIC;
	                           SIGNAL clk               : IN STD_LOGIC;
	                           SIGNAL in_en             : IN STD_LOGIC; -- when '0' then no valid output even when src_in is ready
	                           SIGNAL src_in            : IN t_dp_siso;
	                           SIGNAL src_out           : OUT t_dp_sosi) IS
		VARIABLE v_data : STD_LOGIC_VECTOR(c_data_w - 1 DOWNTO 0) := TO_UVEC(c_data_init, c_data_w);
	BEGIN
		src_out      <= c_dp_sosi_rst;
		src_out.data <= RESIZE_DP_DATA(v_data);
		IF rst = '0' THEN
			WAIT UNTIL rising_edge(clk);
			WHILE TRUE LOOP
				src_out.data <= RESIZE_DP_DATA(v_data);
				proc_dp_stream_ready_latency(c_ready_latency, clk, src_in.ready, in_en, '0', '1', '0', '0', src_out.sync, src_out.valid, src_out.sop, src_out.eop);
				v_data       := INCR_UVEC(v_data, 1);
			END LOOP;
		END IF;
	END proc_dp_gen_data;

	------------------------------------------------------------------------------
	-- PROCEDURE: Generate counter data with valid
	-- . Output counter data dependent on in_en and src_in.ready
	-- . with maximum count value
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_gen_data(CONSTANT c_ready_latency : IN NATURAL;
	                           CONSTANT c_data_w        : IN NATURAL;
	                           CONSTANT c_data_init     : IN NATURAL;
	                           CONSTANT c_data_max      : IN NATURAL;
	                           SIGNAL rst               : IN STD_LOGIC;
	                           SIGNAL clk               : IN STD_LOGIC;
	                           SIGNAL in_en             : IN STD_LOGIC; -- when '0' then no valid output even when src_in is ready
	                           SIGNAL src_in            : IN t_dp_siso;
	                           SIGNAL src_out           : OUT t_dp_sosi) IS
		VARIABLE v_cnt : STD_LOGIC_VECTOR(c_data_w - 1 DOWNTO 0) := TO_UVEC(c_data_init, c_data_w);
	BEGIN
		src_out      <= c_dp_sosi_rst;
		src_out.data <= RESIZE_DP_DATA(v_cnt);
		IF rst = '0' THEN
			WAIT UNTIL rising_edge(clk);
			WHILE TRUE LOOP
				src_out.data <= RESIZE_DP_DATA(v_cnt);
				proc_dp_stream_ready_latency(c_ready_latency, clk, src_in.ready, in_en, '0', '1', '0', '0', src_out.sync, src_out.valid, src_out.sop, src_out.eop);
				IF TO_UINT(v_cnt) = c_data_max THEN
					v_cnt := TO_UVEC(c_data_init, c_data_w);
				ELSE
					v_cnt := INCR_UVEC(v_cnt, 1);
				END IF;
			END LOOP;
		END IF;
	END proc_dp_gen_data;

	------------------------------------------------------------------------------
	-- PROCEDURE: Generate a frame with symbols counter
	-- . dependent on in_en and src_in.ready
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_gen_frame(CONSTANT c_ready_latency : IN NATURAL; -- 0, 1 are supported by proc_dp_stream_ready_latency()
	                            CONSTANT c_data_w        : IN NATURAL;
	                            CONSTANT c_symbol_w      : IN NATURAL; -- c_data_w/c_symbol_w must be an integer
	                            CONSTANT c_symbol_init   : IN NATURAL;
	                            CONSTANT c_nof_symbols   : IN NATURAL;
	                            CONSTANT c_bsn           : IN NATURAL;
	                            CONSTANT c_sync          : IN STD_LOGIC;
	                            SIGNAL clk               : IN STD_LOGIC;
	                            SIGNAL in_en             : IN STD_LOGIC; -- when '0' then no valid output even when src_in is ready
	                            SIGNAL src_in            : IN t_dp_siso;
	                            SIGNAL src_out           : OUT t_dp_sosi) IS
		CONSTANT c_nof_symbols_per_data : NATURAL                                 := c_data_w / c_symbol_w;
		CONSTANT c_div                  : NATURAL                                 := c_nof_symbols / c_nof_symbols_per_data;
		CONSTANT c_mod                  : NATURAL                                 := c_nof_symbols MOD c_nof_symbols_per_data;
		CONSTANT c_empty                : NATURAL                                 := sel_a_b(c_mod, c_nof_symbols_per_data - c_mod, 0);
		CONSTANT c_nof_data             : NATURAL                                 := sel_a_b(c_mod, 1, 0) + c_div;
		VARIABLE v_data                 : STD_LOGIC_VECTOR(c_data_w - 1 DOWNTO 0) := func_dp_data_init(c_data_w, c_symbol_w, c_symbol_init);
	BEGIN
		src_out       <= c_dp_sosi_rst;
		src_out.bsn   <= TO_DP_BSN(c_bsn);
		src_out.empty <= TO_DP_EMPTY(c_empty);
		src_out.data  <= RESIZE_DP_DATA(v_data);
		IF c_nof_data > 1 THEN
			-- . sop
			proc_dp_stream_ready_latency(c_ready_latency, clk, src_in.ready, in_en, c_sync, '1', '1', '0', src_out.sync, src_out.valid, src_out.sop, src_out.eop);
			-- . valid
			FOR I IN 1 TO c_nof_data - 2 LOOP
				v_data       := func_dp_data_incr(c_data_w, c_symbol_w, v_data);
				src_out.data <= RESIZE_DP_DATA(v_data);
				proc_dp_stream_ready_latency(c_ready_latency, clk, src_in.ready, in_en, '0', '1', '0', '0', src_out.sync, src_out.valid, src_out.sop, src_out.eop);
			END LOOP;
			-- . eop
			v_data       := func_dp_data_incr(c_data_w, c_symbol_w, v_data);
			src_out.data <= RESIZE_DP_DATA(v_data);
			proc_dp_stream_ready_latency(c_ready_latency, clk, src_in.ready, in_en, '0', '1', '0', '1', src_out.sync, src_out.valid, src_out.sop, src_out.eop);
		ELSE
			-- . sop and eop, frame has only one word
			proc_dp_stream_ready_latency(c_ready_latency, clk, src_in.ready, in_en, c_sync, '1', '1', '1', src_out.sync, src_out.valid, src_out.sop, src_out.eop);
		END IF;
		src_out.sync  <= '0';
		src_out.valid <= '0';
		src_out.sop   <= '0';
		src_out.eop   <= '0';
	END proc_dp_gen_frame;

	------------------------------------------------------------------------------
	-- PROCEDURE: Input data counter
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_cnt_dat(SIGNAL rst     : IN STD_LOGIC;
	                          SIGNAL clk     : IN STD_LOGIC;
	                          SIGNAL in_en   : IN STD_LOGIC;
	                          SIGNAL cnt_dat : INOUT STD_LOGIC_VECTOR) IS
	BEGIN
		IF rst = '1' THEN
			cnt_dat <= (cnt_dat'RANGE => '0');
		ELSIF rising_edge(clk) THEN
			IF in_en = '1' THEN
				cnt_dat <= STD_LOGIC_VECTOR(UNSIGNED(cnt_dat) + 1);
			END IF;
		END IF;
	END proc_dp_cnt_dat;

	PROCEDURE proc_dp_cnt_dat(SIGNAL rst     : IN STD_LOGIC;
	                          SIGNAL clk     : IN STD_LOGIC;
	                          SIGNAL in_en   : IN STD_LOGIC;
	                          SIGNAL cnt_val : INOUT STD_LOGIC;
	                          SIGNAL cnt_dat : INOUT STD_LOGIC_VECTOR) IS
	BEGIN
		IF rst = '1' THEN
			cnt_val <= '0';
			cnt_dat <= (cnt_dat'RANGE => '0');
		ELSIF rising_edge(clk) THEN
			cnt_val <= '0';
			IF in_en = '1' THEN
				cnt_val <= '1';
				cnt_dat <= STD_LOGIC_VECTOR(UNSIGNED(cnt_dat) + 1);
			END IF;
		END IF;
	END proc_dp_cnt_dat;

	------------------------------------------------------------------------------
	-- PROCEDURE: Transmit data
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_tx_data(CONSTANT c_ready_latency : IN NATURAL;
	                          SIGNAL rst               : IN STD_LOGIC;
	                          SIGNAL clk               : IN STD_LOGIC;
	                          SIGNAL cnt_val           : IN STD_LOGIC;
	                          SIGNAL cnt_dat           : IN STD_LOGIC_VECTOR;
	                          SIGNAL tx_data           : INOUT t_dp_data_arr;
	                          SIGNAL tx_val            : INOUT STD_LOGIC_VECTOR;
	                          SIGNAL out_data          : OUT STD_LOGIC_VECTOR;
	                          SIGNAL out_val           : OUT STD_LOGIC) IS
		CONSTANT c_void : NATURAL := sel_a_b(c_ready_latency, 1, 0); -- used to avoid empty range VHDL warnings when c_ready_latency=0
	BEGIN
		-- TX data array for output ready latency [c_ready_latency], index [0] for zero latency combinatorial
		tx_data(0) <= cnt_dat;
		tx_val(0)  <= cnt_val;

		IF rst = '1' THEN
			tx_data(1 TO c_ready_latency + c_void) <= (1 TO c_ready_latency + c_void => (OTHERS => '0'));
			tx_val(1 TO c_ready_latency + c_void)  <= (1 TO c_ready_latency + c_void => '0');
		ELSIF rising_edge(clk) THEN
			tx_data(1 TO c_ready_latency + c_void) <= tx_data(0 TO c_ready_latency + c_void - 1);
			tx_val(1 TO c_ready_latency + c_void)  <= tx_val(0 TO c_ready_latency + c_void - 1);
		END IF;

		out_data <= tx_data(c_ready_latency);
		out_val  <= tx_val(c_ready_latency);
	END proc_dp_tx_data;

	------------------------------------------------------------------------------
	-- PROCEDURE: Transmit data control (use for sop, eop)
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_tx_ctrl(CONSTANT c_offset : IN NATURAL;
	                          CONSTANT c_period : IN NATURAL;
	                          SIGNAL data       : IN STD_LOGIC_VECTOR;
	                          SIGNAL valid      : IN STD_LOGIC;
	                          SIGNAL ctrl       : OUT STD_LOGIC) IS
		VARIABLE v_data : INTEGER;
	BEGIN
		v_data := TO_UINT(data);
		ctrl   <= '0';
		IF valid = '1' AND ((v_data - c_offset) MOD c_period) = 0 THEN
			ctrl <= '1';
		END IF;
	END proc_dp_tx_ctrl;

	------------------------------------------------------------------------------
	-- PROCEDURE: Define test sync interval
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_sync_interval(SIGNAL clk  : IN STD_LOGIC;
	                                SIGNAL sync : OUT STD_LOGIC) IS
	BEGIN
		sync <= '0';
		FOR I IN 1 TO c_dp_sync_interval - 1 LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;
		sync <= '1';
		WAIT UNTIL rising_edge(clk);
	END proc_dp_sync_interval;

	------------------------------------------------------------------------------
	-- PROCEDURE: Stimuli for cnt_en
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_count_en(SIGNAL rst    : IN STD_LOGIC;
	                           SIGNAL clk    : IN STD_LOGIC;
	                           SIGNAL sync   : IN STD_LOGIC;
	                           SIGNAL lfsr   : INOUT STD_LOGIC_VECTOR;
	                           SIGNAL state  : OUT t_dp_state_enum;
	                           SIGNAL done   : OUT STD_LOGIC;
	                           SIGNAL tb_end : OUT STD_LOGIC;
	                           SIGNAL cnt_en : OUT STD_LOGIC) IS
	BEGIN
		-- The counter operates at zero latency
		state  <= s_idle;
		done   <= '0';
		tb_end <= '0';
		cnt_en <= '0';
		WAIT UNTIL rst = '0';
		WAIT UNTIL rising_edge(clk);
		-- The cnt_val may be asserted for every active in_ready, but als support
		-- cnt_val not asserted for every asserted in_ready.

		----------------------------------------------------------------------------
		-- Interval 1
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		state  <= s_both_active;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 2
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		state  <= s_pull_down_out_ready;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 3
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		state  <= s_pull_down_cnt_en;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 1 cycle
		cnt_en <= '0';
		WAIT UNTIL rising_edge(clk);
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 2 cycle
		cnt_en <= '0';
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 3 cycle
		cnt_en <= '0';
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 4 cycle
		cnt_en <= '0';
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 5 cycle
		cnt_en <= '0';
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 6 cycle
		cnt_en <= '0';
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 7 cycle
		cnt_en <= '0';
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 4
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		state  <= s_toggle_out_ready;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 5
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		state  <= s_toggle_cnt_en;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 1-1 toggle
		cnt_en <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '0';
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '1';
		END LOOP;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 1-2 toggle
		cnt_en <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '0';
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '1';
		END LOOP;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 2-1 toggle
		cnt_en <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '0';
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '1';
		END LOOP;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 2-2 toggle
		cnt_en <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '0';
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '1';
		END LOOP;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 1-3 toggle
		cnt_en <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '0';
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '1';
		END LOOP;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 3-1 toggle
		cnt_en <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '0';
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '1';
		END LOOP;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 2-3 toggle
		cnt_en <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '0';
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '1';
		END LOOP;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 3-2 toggle
		cnt_en <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '0';
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			cnt_en <= '1';
		END LOOP;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 6
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		state  <= s_toggle_both;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		FOR I IN 1 TO c_dp_nof_both LOOP
			cnt_en <= '0';
			FOR J IN 1 TO I LOOP
				WAIT UNTIL rising_edge(clk);
			END LOOP;
			cnt_en <= '1';
			FOR J IN I TO c_dp_nof_both LOOP
				WAIT UNTIL rising_edge(clk);
			END LOOP;
		END LOOP;
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 7
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		state <= s_pulse_cnt_en;
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		FOR I IN 1 TO 15 LOOP
			FOR J IN 1 TO 15 LOOP
				cnt_en <= '0';
				FOR K IN 1 TO I LOOP
					WAIT UNTIL rising_edge(clk);
				END LOOP;
				cnt_en <= '1';
				WAIT UNTIL rising_edge(clk);
			END LOOP;
			FOR J IN 1 TO 20 LOOP
				WAIT UNTIL rising_edge(clk);
			END LOOP;
		END LOOP;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 8
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		state  <= s_chirp_out_ready;
		cnt_en <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 9
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		state  <= s_random;
		cnt_en <= '1';

		FOR I IN 0 TO c_dp_sync_interval - c_dp_test_interval LOOP
			lfsr   <= func_common_random(lfsr);
			cnt_en <= lfsr(lfsr'HIGH);
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Done
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		state  <= s_done;
		WAIT UNTIL rising_edge(clk);
		cnt_en <= '0';

		-- pulse done
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;
		done <= '1';
		WAIT UNTIL rising_edge(clk);
		done <= '0';

		----------------------------------------------------------------------------
		-- Testbench end
		----------------------------------------------------------------------------
		-- set tb_end
		WAIT UNTIL sync = '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;
		tb_end <= '1';
		WAIT;
	END proc_dp_count_en;

	------------------------------------------------------------------------------
	-- PROCEDURE: Stimuli for out_ready
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_out_ready(SIGNAL rst       : IN STD_LOGIC;
	                            SIGNAL clk       : IN STD_LOGIC;
	                            SIGNAL sync      : IN STD_LOGIC;
	                            SIGNAL lfsr      : INOUT STD_LOGIC_VECTOR;
	                            SIGNAL out_ready : OUT STD_LOGIC) IS
	BEGIN
		out_ready <= '0';
		WAIT UNTIL rst = '0';
		WAIT UNTIL rising_edge(clk);

		----------------------------------------------------------------------------
		-- Interval 1 : Assert both cnt_en and out_ready
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 2 : Make out_ready low for 1 or more cycles
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 1 cycle
		out_ready <= '0';
		WAIT UNTIL rising_edge(clk);
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 2 cycle
		out_ready <= '0';
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 3 cycle
		out_ready <= '0';
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 4 cycle
		out_ready <= '0';
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 5 cycle
		out_ready <= '0';
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 6 cycle
		out_ready <= '0';
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 7 cycle
		out_ready <= '0';
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		WAIT UNTIL rising_edge(clk);
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 3
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 4 : Toggle out_ready for 1 or more cycles
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 1-1 toggle
		out_ready <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			out_ready <= '0';
			WAIT UNTIL rising_edge(clk);
			out_ready <= '1';
		END LOOP;
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 1-2 toggle
		out_ready <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			out_ready <= '0';
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			out_ready <= '1';
		END LOOP;
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 2-1 toggle
		out_ready <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			out_ready <= '0';
			WAIT UNTIL rising_edge(clk);
			out_ready <= '1';
		END LOOP;
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 2-2 toggle
		out_ready <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			out_ready <= '0';
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			out_ready <= '1';
		END LOOP;
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 1-3 toggle
		out_ready <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			out_ready <= '0';
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			out_ready <= '1';
		END LOOP;
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 3-1 toggle
		out_ready <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			out_ready <= '0';
			WAIT UNTIL rising_edge(clk);
			out_ready <= '1';
		END LOOP;
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 2-3 toggle
		out_ready <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			out_ready <= '0';
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			out_ready <= '1';
		END LOOP;
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . 3-2 toggle
		out_ready <= '0';
		FOR I IN 1 TO c_dp_nof_toggle LOOP
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			out_ready <= '0';
			WAIT UNTIL rising_edge(clk);
			WAIT UNTIL rising_edge(clk);
			out_ready <= '1';
		END LOOP;
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 5
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 6
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		FOR I IN 1 TO c_dp_nof_both LOOP
			out_ready <= '0';
			FOR J IN I TO c_dp_nof_both LOOP
				WAIT UNTIL rising_edge(clk);
			END LOOP;
			out_ready <= '1';
			FOR J IN 1 TO I LOOP
				WAIT UNTIL rising_edge(clk);
			END LOOP;
		END LOOP;
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 7
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 8 : Chirp out_ready
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		-- . slow toggle
		out_ready <= '0';
		FOR I IN 0 TO c_dp_nof_toggle LOOP
			out_ready <= '0';
			FOR J IN 0 TO I LOOP
				WAIT UNTIL rising_edge(clk);
			END LOOP;
			out_ready <= '1';
			FOR J IN 0 TO I LOOP
				WAIT UNTIL rising_edge(clk);
			END LOOP;
		END LOOP;
		out_ready <= '1';
		FOR I IN 0 TO c_dp_test_interval LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Interval 9 : Random
		----------------------------------------------------------------------------
		WAIT UNTIL sync = '1';
		out_ready <= '1';

		FOR I IN 0 TO c_dp_sync_interval - c_dp_test_interval LOOP
			lfsr      <= func_common_random(lfsr);
			out_ready <= lfsr(lfsr'HIGH);
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		----------------------------------------------------------------------------
		-- Done
		----------------------------------------------------------------------------
		WAIT;
	END proc_dp_out_ready;

	------------------------------------------------------------------------------
	-- PROCEDURE: DUT output verify enable
	------------------------------------------------------------------------------

	-- Fixed delay until verify_en active
	PROCEDURE proc_dp_verify_en(CONSTANT c_delay : IN NATURAL;
	                            SIGNAL rst       : IN STD_LOGIC;
	                            SIGNAL clk       : IN STD_LOGIC;
	                            SIGNAL sync      : IN STD_LOGIC;
	                            SIGNAL verify_en : OUT STD_LOGIC) IS
	BEGIN
		verify_en <= '0';
		WAIT UNTIL rst = '0';
		WAIT UNTIL rising_edge(clk);

		WAIT UNTIL sync = '1';
		-- Use c_delay delay before enabling the p_verify.
		FOR I IN 0 TO c_delay LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;

		verify_en <= '1';
		WAIT;
	END proc_dp_verify_en;

	-- Dynamicly depend on first valid data to make verify_en active
	PROCEDURE proc_dp_verify_en(CONSTANT c_continuous : IN BOOLEAN;
	                            SIGNAL clk            : IN STD_LOGIC;
	                            SIGNAL valid          : IN STD_LOGIC;
	                            SIGNAL sop            : IN STD_LOGIC;
	                            SIGNAL eop            : IN STD_LOGIC;
	                            SIGNAL verify_en      : OUT STD_LOGIC) IS
	BEGIN
		IF rising_edge(clk) THEN
			IF c_continuous = TRUE THEN
				-- Verify across frames (so enable data verify after the first data has been output)
				IF valid = '1' THEN
					verify_en <= '1';
				END IF;
			ELSE
				-- Verify only per frame (so re-enable data verify after the every sop)
				IF eop = '1' THEN
					verify_en <= '0';
				ELSIF sop = '1' THEN
					verify_en <= '1';
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_en;

	-- Run and verify for some cycles
	PROCEDURE proc_dp_verify_run_some_cycles(CONSTANT nof_pre_clk    : IN NATURAL;
	                                         CONSTANT nof_verify_clk : IN NATURAL;
	                                         CONSTANT nof_post_clk   : IN NATURAL;
	                                         SIGNAL clk              : IN STD_LOGIC;
	                                         SIGNAL verify_en        : OUT STD_LOGIC) IS
	BEGIN
		proc_common_wait_some_cycles(clk, nof_pre_clk);
		verify_en <= '1';
		proc_common_wait_some_cycles(clk, nof_verify_clk);
		verify_en <= '0';
		proc_common_wait_some_cycles(clk, nof_post_clk);
	END proc_dp_verify_run_some_cycles;

	------------------------------------------------------------------------------
	-- PROCEDURE: Verify the expected value
	------------------------------------------------------------------------------
	--  e.g. to check that a test has ran at all
	PROCEDURE proc_dp_verify_value(CONSTANT c_str : IN STRING;
	                               CONSTANT mode  : IN t_dp_value_enum;
	                               SIGNAL clk     : IN STD_LOGIC;
	                               SIGNAL en      : IN STD_LOGIC;
	                               SIGNAL exp     : IN STD_LOGIC_VECTOR;
	                               SIGNAL res     : IN STD_LOGIC_VECTOR) IS
	BEGIN
		IF rising_edge(clk) THEN
			IF en = '1' THEN
				IF mode = e_equal AND UNSIGNED(res) /= UNSIGNED(exp) THEN
					REPORT "DP : Wrong " & c_str & " result value" SEVERITY ERROR;
				END IF;
				IF mode = e_at_least AND UNSIGNED(res) < UNSIGNED(exp) THEN
					REPORT "DP : Wrong " & c_str & " result value too small" SEVERITY ERROR;
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_value;

	PROCEDURE proc_dp_verify_value(CONSTANT mode : IN t_dp_value_enum;
	                               SIGNAL clk    : IN STD_LOGIC;
	                               SIGNAL en     : IN STD_LOGIC;
	                               SIGNAL exp    : IN STD_LOGIC_VECTOR;
	                               SIGNAL res    : IN STD_LOGIC_VECTOR) IS
	BEGIN
		proc_dp_verify_value("", mode, clk, en, exp, res);
	END proc_dp_verify_value;

	PROCEDURE proc_dp_verify_value(CONSTANT c_str : IN STRING;
	                               SIGNAL clk     : IN STD_LOGIC;
	                               SIGNAL en      : IN STD_LOGIC;
	                               SIGNAL exp     : IN STD_LOGIC;
	                               SIGNAL res     : IN STD_LOGIC) IS
	BEGIN
		IF rising_edge(clk) THEN
			IF en = '1' THEN
				IF res /= exp THEN
					REPORT "DP : Wrong " & c_str & " result value" SEVERITY ERROR;
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_value;

	------------------------------------------------------------------------------
	-- PROCEDURE: Verify output global and local BSN
	------------------------------------------------------------------------------
	-- Verify BSN:
	-- . incrementing or replicated global BSN
	-- . incrementing local BSN that starts at 1
	--
	--               _              _              _              _             
	--  sync      __| |____________| |____________| |____________| |____________
	--               _    _    _    _    _    _    _    _    _    _    _    _
	--   sop      __| |__| |__| |__| |__| |__| |__| |__| |__| |__| |__| |__| |__  c_block_per_sync = 3
	--
	-- c_use_local_bsn = FALSE:
	--                                                                            c_nof_replicated_global_bsn = 1
	--        bsn    3    4    5    6    7    8    9    10   11   12   13   14    c_global_bsn_increment = 1
	--        bsn    3    5    7    9   11   13   15    17   19   21   22   23    c_global_bsn_increment = 2
	--
	-- c_use_local_bsn = TRUE:
	--
	-- global bsn    3              4              5               6              c_global_bsn_increment = 1, c_nof_replicated_global_bsn = 1
	-- global bsn    3              6              9              12              c_global_bsn_increment = 3, c_nof_replicated_global_bsn = 1
	-- global bsn    3              3              9               9              c_global_bsn_increment = 6, c_nof_replicated_global_bsn = 2
	--  local bsn    -    1    2    -    1    2    -    1    2     -    1    2    range 1:c_block_per_sync-1
	--        
	-- The verify_en should initially be set to '0' and gets enabled when
	-- sufficient BSN history is available to do the verification.
	--
	PROCEDURE proc_dp_verify_bsn(CONSTANT c_use_local_bsn             : IN BOOLEAN; -- use local BSN or only use global BSN
	                             CONSTANT c_global_bsn_increment      : IN POSITIVE; -- increment per global BSN
	                             CONSTANT c_nof_replicated_global_bsn : IN POSITIVE; -- number of replicated global BSN
	                             CONSTANT c_block_per_sync            : IN POSITIVE; -- of sop/eop blocks per sync interval
	                             SIGNAL clk                           : IN STD_LOGIC;
	                             SIGNAL out_sync                      : IN STD_LOGIC;
	                             SIGNAL out_sop                       : IN STD_LOGIC;
	                             SIGNAL out_bsn                       : IN STD_LOGIC_VECTOR;
	                             SIGNAL verify_en                     : INOUT STD_LOGIC; -- initialize '0', becomes '1' when bsn verification starts
	                             SIGNAL cnt_replicated_global_bsn     : INOUT NATURAL;
	                             SIGNAL prev_out_bsn_global           : INOUT STD_LOGIC_VECTOR;
	                             SIGNAL prev_out_bsn_local            : INOUT STD_LOGIC_VECTOR) IS
	BEGIN
		IF rising_edge(clk) THEN
			-- out_sop must be active, because only then out_bsn will differ from the previous out_bsn
			IF out_sop = '1' THEN
				IF c_use_local_bsn = FALSE THEN
					------------------------------------------------------------------
					-- Only use global BSN
					------------------------------------------------------------------
					prev_out_bsn_global <= out_bsn;
					-- verify
					IF out_sync = '1' THEN
						verify_en <= '1';
					END IF;
					IF verify_en = '1' THEN
						ASSERT UNSIGNED(out_bsn) = UNSIGNED(prev_out_bsn_global) + c_global_bsn_increment REPORT "DP : Wrong BSN increment" SEVERITY ERROR;
					END IF;
				ELSE
					------------------------------------------------------------------
					-- Use global and local BSN
					------------------------------------------------------------------
					IF out_sync = '1' THEN
						prev_out_bsn_global <= out_bsn;
						IF UNSIGNED(out_bsn) /= UNSIGNED(prev_out_bsn_global) THEN
							verify_en                 <= '1'; -- wait until after last replicated global bsn
							cnt_replicated_global_bsn <= 0;
						ELSE
							cnt_replicated_global_bsn <= cnt_replicated_global_bsn + 1;
						END IF;
						prev_out_bsn_local  <= TO_UVEC(0, prev_out_bsn_global'LENGTH);
					ELSE
						prev_out_bsn_local <= out_bsn;
					END IF;
					-- verify
					IF verify_en = '1' THEN
						IF out_sync = '1' THEN
							IF UNSIGNED(out_bsn) /= UNSIGNED(prev_out_bsn_global) THEN
								ASSERT cnt_replicated_global_bsn = c_nof_replicated_global_bsn - 1 REPORT "DP : Wrong number of replicated global BSN" SEVERITY ERROR;
								ASSERT UNSIGNED(out_bsn) = UNSIGNED(prev_out_bsn_global) + c_global_bsn_increment REPORT "DP : Wrong global BSN increment" SEVERITY ERROR;
							ELSE
								ASSERT UNSIGNED(out_bsn) = UNSIGNED(prev_out_bsn_global) REPORT "DP : Wrong replicated global BSN" SEVERITY ERROR;
							END IF;
							ASSERT UNSIGNED(prev_out_bsn_local) = c_block_per_sync - 1 REPORT "DP : Wrong last local BSN in sync interval" SEVERITY ERROR;
						ELSE
							ASSERT UNSIGNED(out_bsn) = UNSIGNED(prev_out_bsn_local) + 1 REPORT "DP : Wrong local BSN increment" SEVERITY ERROR;
						END IF;
					END IF;
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_bsn;

	------------------------------------------------------------------------------
	-- PROCEDURE: Verify the DUT output data
	------------------------------------------------------------------------------

	-- Verify incrementing data
	-- . wrap at c_out_data_max when >0, else no wrap when c_out_data_max=0
	-- . default increment by 1, but also allow an increment by c_out_data_gap
	PROCEDURE proc_dp_verify_data(CONSTANT c_str           : IN STRING;
	                              CONSTANT c_ready_latency : IN NATURAL;
	                              CONSTANT c_out_data_max  : IN UNSIGNED;
	                              CONSTANT c_out_data_gap  : IN UNSIGNED;
	                              SIGNAL clk               : IN STD_LOGIC;
	                              SIGNAL verify_en         : IN STD_LOGIC;
	                              SIGNAL out_ready         : IN STD_LOGIC; -- only needed when c_ready_latency = 0
	                              SIGNAL out_val           : IN STD_LOGIC;
	                              SIGNAL out_data          : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data     : INOUT STD_LOGIC_VECTOR) IS
	BEGIN
		IF rising_edge(clk) THEN
			-- out_val must be active, because only the out_data will it differ from the previous out_data
			IF out_val = '1' THEN
				-- for ready_latency > 0 out_val indicates new data
				-- for ready_latency = 0 out_val only indicates new data when it is confirmed by out_ready
				IF c_ready_latency /= 0 OR (c_ready_latency = 0 AND out_ready = '1') THEN
					IF c_out_data_max = 0 THEN
						prev_out_data <= out_data; -- no wrap detection
					ELSIF UNSIGNED(out_data) < c_out_data_max THEN
						prev_out_data <= out_data; -- no wrap
					ELSE
						prev_out_data <= TO_SVEC(-1, prev_out_data'LENGTH); -- do wrap
					END IF;
					IF verify_en = '1' THEN
						IF UNSIGNED(out_data) /= UNSIGNED(prev_out_data) + 1 AND -- check increment +1
							UNSIGNED(out_data) /= UNSIGNED(prev_out_data) + c_out_data_gap AND -- increment +c_out_data_gap
							UNSIGNED(out_data) /= UNSIGNED(prev_out_data) + c_out_data_gap - c_out_data_max THEN -- increment +c_out_data_gap wrapped
							REPORT "DP : Wrong out_data " & c_str & " count" SEVERITY ERROR;
						END IF;
					END IF;
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_data;

	-- Verify incrementing data that wraps in range 0 ... c_out_data_max
	PROCEDURE proc_dp_verify_data(CONSTANT c_str           : IN STRING;
	                              CONSTANT c_ready_latency : IN NATURAL;
	                              CONSTANT c_out_data_max  : IN UNSIGNED;
	                              SIGNAL clk               : IN STD_LOGIC;
	                              SIGNAL verify_en         : IN STD_LOGIC;
	                              SIGNAL out_ready         : IN STD_LOGIC;
	                              SIGNAL out_val           : IN STD_LOGIC;
	                              SIGNAL out_data          : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data     : INOUT STD_LOGIC_VECTOR) IS
	BEGIN
		proc_dp_verify_data(c_str, c_ready_latency, c_out_data_max, TO_UNSIGNED(1, 1), clk, verify_en, out_ready, out_val, out_data, prev_out_data);
	END proc_dp_verify_data;

	-- Verify incrementing data
	PROCEDURE proc_dp_verify_data(CONSTANT c_str           : IN STRING;
	                              CONSTANT c_ready_latency : IN NATURAL;
	                              SIGNAL clk               : IN STD_LOGIC;
	                              SIGNAL verify_en         : IN STD_LOGIC;
	                              SIGNAL out_ready         : IN STD_LOGIC;
	                              SIGNAL out_val           : IN STD_LOGIC;
	                              SIGNAL out_data          : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data     : INOUT STD_LOGIC_VECTOR) IS
	BEGIN
		proc_dp_verify_data(c_str, c_ready_latency, TO_UNSIGNED(0, 1), TO_UNSIGNED(1, 1), clk, verify_en, out_ready, out_val, out_data, prev_out_data);
	END proc_dp_verify_data;

	-- Verify incrementing data with RL > 0 or no flow control
	PROCEDURE proc_dp_verify_data(CONSTANT c_str          : IN STRING;
	                              CONSTANT c_out_data_max : IN UNSIGNED;
	                              CONSTANT c_out_data_gap : IN UNSIGNED;
	                              SIGNAL clk              : IN STD_LOGIC;
	                              SIGNAL verify_en        : IN STD_LOGIC;
	                              SIGNAL out_val          : IN STD_LOGIC;
	                              SIGNAL out_data         : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data    : INOUT STD_LOGIC_VECTOR) IS
	BEGIN
		-- Use out_val as void signal to pass on to unused out_ready, because a signal input can not connect a constant or variable
		proc_dp_verify_data(c_str, 1, c_out_data_max, c_out_data_gap, clk, verify_en, out_val, out_val, out_data, prev_out_data);
	END proc_dp_verify_data;

	PROCEDURE proc_dp_verify_data(CONSTANT c_str          : IN STRING;
	                              CONSTANT c_out_data_max : IN NATURAL;
	                              CONSTANT c_out_data_gap : IN NATURAL;
	                              SIGNAL clk              : IN STD_LOGIC;
	                              SIGNAL verify_en        : IN STD_LOGIC;
	                              SIGNAL out_val          : IN STD_LOGIC;
	                              SIGNAL out_data         : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data    : INOUT STD_LOGIC_VECTOR) IS
		CONSTANT c_data_w : NATURAL := out_data'LENGTH;
	BEGIN
		proc_dp_verify_data(c_str, TO_UNSIGNED(c_out_data_max, c_data_w), TO_UNSIGNED(c_out_data_gap, c_data_w), clk, verify_en, out_val, out_data, prev_out_data);
	END proc_dp_verify_data;

	PROCEDURE proc_dp_verify_data(CONSTANT c_str          : IN STRING;
	                              CONSTANT c_out_data_max : IN NATURAL;
	                              SIGNAL clk              : IN STD_LOGIC;
	                              SIGNAL verify_en        : IN STD_LOGIC;
	                              SIGNAL out_val          : IN STD_LOGIC;
	                              SIGNAL out_data         : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data    : INOUT STD_LOGIC_VECTOR) IS
		CONSTANT c_data_w : NATURAL := out_data'LENGTH;
	BEGIN
		proc_dp_verify_data(c_str, TO_UNSIGNED(c_out_data_max, c_data_w), TO_UNSIGNED(1, 1), clk, verify_en, out_val, out_data, prev_out_data);
	END proc_dp_verify_data;

	PROCEDURE proc_dp_verify_data(CONSTANT c_str       : IN STRING;
	                              SIGNAL clk           : IN STD_LOGIC;
	                              SIGNAL verify_en     : IN STD_LOGIC;
	                              SIGNAL out_val       : IN STD_LOGIC;
	                              SIGNAL out_data      : IN STD_LOGIC_VECTOR;
	                              SIGNAL prev_out_data : INOUT STD_LOGIC_VECTOR) IS
	BEGIN
		-- Use out_val as void signal to pass on to unused out_ready, because a signal input can not connect a constant or variable
		proc_dp_verify_data(c_str, 1, TO_UNSIGNED(0, 1), TO_UNSIGNED(1, 1), clk, verify_en, out_val, out_val, out_data, prev_out_data);
	END proc_dp_verify_data;

	------------------------------------------------------------------------------
	-- PROCEDURE: Verify incrementing symbols in data
	-- . for c_data_w = c_symbol_w proc_dp_verify_symbols() = proc_dp_verify_data()
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_verify_symbols(CONSTANT c_ready_latency : IN NATURAL;
	                                 CONSTANT c_data_w        : IN NATURAL;
	                                 CONSTANT c_symbol_w      : IN NATURAL;
	                                 SIGNAL clk               : IN STD_LOGIC;
	                                 SIGNAL verify_en         : IN STD_LOGIC;
	                                 SIGNAL out_ready         : IN STD_LOGIC;
	                                 SIGNAL out_val           : IN STD_LOGIC;
	                                 SIGNAL out_eop           : IN STD_LOGIC;
	                                 SIGNAL out_data          : IN STD_LOGIC_VECTOR;
	                                 SIGNAL out_empty         : IN STD_LOGIC_VECTOR;
	                                 SIGNAL prev_out_data     : INOUT STD_LOGIC_VECTOR) IS
		CONSTANT c_nof_symbols_per_data : NATURAL := c_data_w / c_symbol_w; -- must be an integer
		CONSTANT c_empty_w              : NATURAL := ceil_log2(c_nof_symbols_per_data);
		VARIABLE v_data                 : STD_LOGIC_VECTOR(c_data_w - 1 DOWNTO 0);
		VARIABLE v_symbol               : STD_LOGIC_VECTOR(c_symbol_w - 1 DOWNTO 0);
		VARIABLE v_empty                : NATURAL;
	BEGIN
		IF rising_edge(clk) THEN
			-- out_val must be active, because only the out_data will it differ from the previous out_data
			IF out_val = '1' THEN
				-- for ready_latency > 0 out_val indicates new data
				-- for ready_latency = 0 out_val only indicates new data when it is confirmed by out_ready
				IF c_ready_latency /= 0 OR (c_ready_latency = 0 AND out_ready = '1') THEN
					prev_out_data <= out_data;
					IF verify_en = '1' THEN
						v_data := prev_out_data(c_data_w - 1 DOWNTO 0);
						FOR I IN 0 TO c_nof_symbols_per_data - 1 LOOP
							v_data((I + 1) * c_symbol_w - 1 DOWNTO I * c_symbol_w) := INCR_UVEC(v_data((I + 1) * c_symbol_w - 1 DOWNTO I * c_symbol_w), c_nof_symbols_per_data); -- increment each symbol
						END LOOP;
						IF out_eop = '0' THEN
							IF UNSIGNED(out_data) /= UNSIGNED(v_data) THEN
								REPORT "DP : Wrong out_data symbols count" SEVERITY ERROR;
							END IF;
						ELSE
							v_empty := TO_UINT(out_empty(c_empty_w - 1 DOWNTO 0));
							IF UNSIGNED(out_data(c_data_w - 1 DOWNTO v_empty * c_symbol_w)) /= UNSIGNED(v_data(c_data_w - 1 DOWNTO v_empty * c_symbol_w)) THEN
								REPORT "DP : Wrong out_data symbols count at eop" SEVERITY ERROR;
							END IF;
							IF v_empty > 0 THEN
								-- adjust prev_out_data for potentially undefined empty symbols in out_data
								v_symbol      := v_data((v_empty + 1) * c_symbol_w - 1 DOWNTO v_empty * c_symbol_w); -- last valid symbol
								FOR I IN 0 TO c_nof_symbols_per_data - 1 LOOP
									v_data((I + 1) * c_symbol_w - 1 DOWNTO I * c_symbol_w) := v_symbol; -- put the last valid symbol at the end of the v_data
									v_symbol                                               := INCR_UVEC(v_symbol, -1); -- decrement each symbol towards the beginning of v_data
								END LOOP;
								prev_out_data <= v_data;
							END IF;
						END IF;
					END IF;
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_symbols;

	------------------------------------------------------------------------------
	-- PROCEDURE: Verify the DUT output data with empty
	-- . account for stream empty
	-- . support last word replace (e.g. by a CRC instead of the count, or use
	--   c_last_word=out_data for no replace)
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_verify_data_empty(CONSTANT c_ready_latency : IN NATURAL;
	                                    CONSTANT c_last_word     : IN NATURAL;
	                                    SIGNAL clk               : IN STD_LOGIC;
	                                    SIGNAL verify_en         : IN STD_LOGIC;
	                                    SIGNAL out_ready         : IN STD_LOGIC;
	                                    SIGNAL out_val           : IN STD_LOGIC;
	                                    SIGNAL out_eop           : IN STD_LOGIC;
	                                    SIGNAL out_eop_1         : INOUT STD_LOGIC;
	                                    SIGNAL out_eop_2         : INOUT STD_LOGIC;
	                                    SIGNAL out_data          : IN STD_LOGIC_VECTOR;
	                                    SIGNAL out_data_1        : INOUT STD_LOGIC_VECTOR;
	                                    SIGNAL out_data_2        : INOUT STD_LOGIC_VECTOR;
	                                    SIGNAL out_data_3        : INOUT STD_LOGIC_VECTOR;
	                                    SIGNAL out_empty         : IN STD_LOGIC_VECTOR;
	                                    SIGNAL out_empty_1       : INOUT STD_LOGIC_VECTOR) IS
		VARIABLE v_last_word  : STD_LOGIC_VECTOR(out_data'HIGH DOWNTO 0);
		VARIABLE v_ref_data   : STD_LOGIC_VECTOR(out_data'HIGH DOWNTO 0);
		VARIABLE v_empty_data : STD_LOGIC_VECTOR(out_data'HIGH DOWNTO 0);
	BEGIN
		IF rising_edge(clk) THEN
			-- out_val must be active, because only then out_data will differ from the previous out_data
			IF out_val = '1' THEN
				-- for ready_latency > 0 out_val indicates new data
				-- for ready_latency = 0 out_val only indicates new data when it is confirmed by out_ready
				IF c_ready_latency /= 0 OR (c_ready_latency = 0 AND out_ready = '1') THEN
					-- default expected data
					out_data_1  <= out_data;
					out_data_2  <= out_data_1;
					out_data_3  <= out_data_2;
					out_empty_1 <= out_empty;
					out_eop_1   <= out_eop;
					out_eop_2   <= out_eop_1;
					IF verify_en = '1' THEN
						-- assume sufficient valid cycles between eop and sop, so no need to check for out_sop with regard to eop empty
						IF out_eop = '0' AND out_eop_1 = '0' AND out_eop_2 = '0' THEN
							-- verify out_data from eop-n to eop-2 and from eop+1 to eop+n, n>2
							v_ref_data := INCR_UVEC(out_data_2, 1);
							IF UNSIGNED(out_data_1) /= UNSIGNED(v_ref_data) THEN
								REPORT "DP : Wrong out_data count" SEVERITY ERROR;
							END IF;
						ELSE
							-- the empty and crc replace affect data at eop_1 and eop, so need to check data from eop-2 to eop-1 to eop to eop+1
							v_last_word := TO_UVEC(c_last_word, out_data'LENGTH);
							IF out_eop = '1' THEN
								-- verify out_data at eop
								CASE TO_INTEGER(UNSIGNED(out_empty)) IS
									WHEN 0      => v_empty_data := v_last_word;
									WHEN 1      => v_empty_data := v_last_word(3 * c_byte_w - 1 DOWNTO 0) & c_slv0(1 * c_byte_w - 1 DOWNTO 0);
									WHEN 2      => v_empty_data := v_last_word(2 * c_byte_w - 1 DOWNTO 0) & c_slv0(2 * c_byte_w - 1 DOWNTO 0);
									WHEN 3      => v_empty_data := v_last_word(1 * c_byte_w - 1 DOWNTO 0) & c_slv0(3 * c_byte_w - 1 DOWNTO 0);
									WHEN OTHERS => NULL;
								END CASE;
								IF UNSIGNED(out_data) /= UNSIGNED(v_empty_data) THEN
									REPORT "DP : Wrong out_data count at eop" SEVERITY ERROR;
								END IF;
							ELSIF out_eop_1 = '1' THEN
								-- verify out_data from eop-2 to eop-1
								v_ref_data := INCR_UVEC(out_data_3, 1);
								CASE TO_INTEGER(UNSIGNED(out_empty_1)) IS
									WHEN 0      => v_empty_data := v_ref_data;
									WHEN 1      => v_empty_data := v_ref_data(4 * c_byte_w - 1 DOWNTO 1 * c_byte_w) & v_last_word(4 * c_byte_w - 1 DOWNTO 3 * c_byte_w);
									WHEN 2      => v_empty_data := v_ref_data(4 * c_byte_w - 1 DOWNTO 2 * c_byte_w) & v_last_word(4 * c_byte_w - 1 DOWNTO 2 * c_byte_w);
									WHEN 3      => v_empty_data := v_ref_data(4 * c_byte_w - 1 DOWNTO 3 * c_byte_w) & v_last_word(4 * c_byte_w - 1 DOWNTO 1 * c_byte_w);
									WHEN OTHERS => NULL;
								END CASE;
								IF UNSIGNED(out_data_2) /= UNSIGNED(v_empty_data) THEN
									REPORT "DP : Wrong out_data count at eop-1" SEVERITY ERROR;
								END IF;
								-- verify out_data from eop-2 to eop+1
								v_ref_data := INCR_UVEC(out_data_3, 3);
								IF UNSIGNED(out_data) /= UNSIGNED(v_ref_data) THEN
									REPORT "DP : Wrong out_data count at eop+1" SEVERITY ERROR;
								END IF;
							END IF;
						END IF;
					END IF;
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_data_empty;

	------------------------------------------------------------------------------
	-- PROCEDURE: Verify the DUT output other SOSI data
	-- . Suited to verify the empty, error, channel fields assuming that these
	--   are treated in the same way in parallel to the SOSI data.
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_verify_other_sosi(CONSTANT c_str      : IN STRING;
	                                    CONSTANT c_exp_data : IN STD_LOGIC_VECTOR; -- use constant to support assignment via FUNCTION return value
	                                    SIGNAL clk          : IN STD_LOGIC;
	                                    SIGNAL verify_en    : IN STD_LOGIC;
	                                    SIGNAL res_data     : IN STD_LOGIC_VECTOR) IS
	BEGIN
		IF rising_edge(clk) THEN
			IF verify_en = '1' THEN
				IF c_str = "bsn" THEN
					IF UNSIGNED(c_exp_data(c_dp_bsn_w - 1 DOWNTO 0)) /= UNSIGNED(res_data(c_dp_bsn_w - 1 DOWNTO 0)) THEN
						REPORT "DP : Wrong sosi.bsn value" SEVERITY ERROR;
					END IF;
				ELSIF c_str = "empty" THEN
					IF UNSIGNED(c_exp_data(c_dp_empty_w - 1 DOWNTO 0)) /= UNSIGNED(res_data(c_dp_empty_w - 1 DOWNTO 0)) THEN
						REPORT "DP : Wrong sosi.empty value" SEVERITY ERROR;
					END IF;
				ELSIF c_str = "channel" THEN
					IF UNSIGNED(c_exp_data(c_dp_channel_user_w - 1 DOWNTO 0)) /= UNSIGNED(res_data(c_dp_channel_user_w - 1 DOWNTO 0)) THEN
						REPORT "DP : Wrong sosi.channel value" SEVERITY ERROR;
					END IF;
				ELSIF c_str = "error" THEN
					IF UNSIGNED(c_exp_data(c_dp_error_w - 1 DOWNTO 0)) /= UNSIGNED(res_data(c_dp_error_w - 1 DOWNTO 0)) THEN
						REPORT "DP : Wrong sosi.error value" SEVERITY ERROR;
					END IF;
				ELSE
					REPORT "proc_dp_verify_other_sosi : Unknown sosi." & c_str & "field" SEVERITY FAILURE;
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_other_sosi;

	------------------------------------------------------------------------------
	-- PROCEDURE: Verify the DUT output valid
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_verify_valid(CONSTANT c_ready_latency : IN NATURAL;
	                               SIGNAL clk               : IN STD_LOGIC;
	                               SIGNAL verify_en         : IN STD_LOGIC;
	                               SIGNAL out_ready         : IN STD_LOGIC;
	                               SIGNAL prev_out_ready    : INOUT STD_LOGIC_VECTOR;
	                               SIGNAL out_val           : IN STD_LOGIC) IS
	BEGIN
		IF rising_edge(clk) THEN
			-- for ready_latency > 0 out_val may only be asserted after out_ready
			-- for ready_latency = 0 out_val may always be asserted
			prev_out_ready <= (prev_out_ready'RANGE => '0');
			IF c_ready_latency /= 0 THEN
				IF c_ready_latency = 1 THEN
					prev_out_ready(0) <= out_ready;
				ELSE
					prev_out_ready <= out_ready & prev_out_ready(0 TO c_ready_latency - 1);
				END IF;
				IF verify_en = '1' AND out_val = '1' THEN
					IF prev_out_ready(c_ready_latency - 1) /= '1' THEN
						REPORT "DP : Wrong ready latency between out_ready and out_val" SEVERITY ERROR;
					END IF;
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_valid;

	PROCEDURE proc_dp_verify_valid(SIGNAL clk            : IN STD_LOGIC;
	                               SIGNAL verify_en      : IN STD_LOGIC;
	                               SIGNAL out_ready      : IN STD_LOGIC;
	                               SIGNAL prev_out_ready : INOUT STD_LOGIC;
	                               SIGNAL out_val        : IN STD_LOGIC) IS
	BEGIN
		-- Can not reuse:
		--   proc_dp_verify_valid(1, clk, verify_en, out_ready, prev_out_ready, out_val);
		-- because prev_out_ready needs to map from STD_LOGIC to STD_LOGIC_VECTOR. Therefore copy paste code for RL=1:
		IF rising_edge(clk) THEN
			-- for ready_latency = 1 out_val may only be asserted after out_ready
			prev_out_ready <= out_ready;
			IF verify_en = '1' AND out_val = '1' THEN
				IF prev_out_ready /= '1' THEN
					REPORT "DP : Wrong ready latency between out_ready and out_val" SEVERITY ERROR;
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_valid;

	------------------------------------------------------------------------------
	-- PROCEDURE: Verify the DUT output sync
	-- . sync is defined such that it can only be active at sop
	-- . assume that the sync occures priodically at bsn MOD c_sync_period = c_sync_offset
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_verify_sync(CONSTANT c_sync_period : IN NATURAL; -- BSN sync period
	                              CONSTANT c_sync_offset : IN NATURAL; -- BSN sync offset
	                              SIGNAL clk             : IN STD_LOGIC;
	                              SIGNAL verify_en       : IN STD_LOGIC;
	                              SIGNAL sync            : IN STD_LOGIC;
	                              SIGNAL sop             : IN STD_LOGIC;
	                              SIGNAL bsn             : IN STD_LOGIC_VECTOR) IS
		CONSTANT c_bsn_w         : NATURAL := sel_a_b(bsn'LENGTH > 31, 31, bsn'LENGTH); -- use maximally 31 bit of BSN slv to allow calculations with integers
		VARIABLE v_expected_sync : BOOLEAN;
	BEGIN
		IF rising_edge(clk) THEN
			IF verify_en = '1' THEN
				v_expected_sync := (TO_UINT(bsn(c_bsn_w - 1 DOWNTO 0)) - c_sync_offset) MOD c_sync_period = 0;
				-- Check for unexpected sync
				IF sync = '1' THEN
					ASSERT v_expected_sync = TRUE
					REPORT "Error: Unexpected sync at BSN" SEVERITY ERROR;
					ASSERT sop = '1'
					REPORT "Error: Unexpected sync at inactive sop" SEVERITY ERROR;
				END IF;
				-- Check for missing sync
				IF sop = '1' AND v_expected_sync = TRUE THEN
					ASSERT sync = '1'
					REPORT "Error: Missing sync" SEVERITY ERROR;
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_sync;

	------------------------------------------------------------------------------
	-- PROCEDURE: Verify the DUT output sop and eop
	------------------------------------------------------------------------------
	-- sop and eop in pairs, valid during packet and invalid between packets
	PROCEDURE proc_dp_verify_sop_and_eop(CONSTANT c_ready_latency : IN NATURAL;
	                                     CONSTANT c_verify_valid  : IN BOOLEAN;
	                                     SIGNAL clk               : IN STD_LOGIC;
	                                     SIGNAL out_ready         : IN STD_LOGIC;
	                                     SIGNAL out_val           : IN STD_LOGIC;
	                                     SIGNAL out_sop           : IN STD_LOGIC;
	                                     SIGNAL out_eop           : IN STD_LOGIC;
	                                     SIGNAL hold_sop          : INOUT STD_LOGIC) IS
	BEGIN
		IF rising_edge(clk) THEN
			IF out_val = '0' THEN
				IF out_sop = '1' THEN
					REPORT "DP : Wrong active sop during invalid" SEVERITY ERROR;
				END IF;
				IF out_eop = '1' THEN
					REPORT "DP : Wrong active eop during invalid" SEVERITY ERROR;
				END IF;
			ELSE
				-- for ready_latency > 0 out_val indicates new data
				-- for ready_latency = 0 out_val only indicates new data when it is confirmed by out_ready
				IF c_ready_latency /= 0 OR (c_ready_latency = 0 AND out_ready = '1') THEN
					IF out_sop = '1' THEN
						hold_sop <= '1';
						IF hold_sop = '1' THEN
							REPORT "DP : Unexpected sop without eop" SEVERITY ERROR;
						END IF;
					END IF;
					IF out_eop = '1' THEN
						hold_sop <= '0';
						IF hold_sop = '0' AND out_sop = '0' THEN
							REPORT "DP : Unexpected eop without sop" SEVERITY ERROR;
						END IF;
					END IF;
					-- out_val='1'
					IF c_verify_valid = TRUE AND out_sop = '0' AND hold_sop = '0' THEN
						REPORT "DP : Unexpected valid in gap between eop and sop" SEVERITY ERROR;
					END IF;
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_sop_and_eop;

	PROCEDURE proc_dp_verify_sop_and_eop(CONSTANT c_ready_latency : IN NATURAL;
	                                     SIGNAL clk               : IN STD_LOGIC;
	                                     SIGNAL out_ready         : IN STD_LOGIC;
	                                     SIGNAL out_val           : IN STD_LOGIC;
	                                     SIGNAL out_sop           : IN STD_LOGIC;
	                                     SIGNAL out_eop           : IN STD_LOGIC;
	                                     SIGNAL hold_sop          : INOUT STD_LOGIC) IS
	BEGIN
		proc_dp_verify_sop_and_eop(c_ready_latency, TRUE, clk, out_ready, out_val, out_sop, out_eop, hold_sop);
	END proc_dp_verify_sop_and_eop;

	PROCEDURE proc_dp_verify_sop_and_eop(SIGNAL clk      : IN STD_LOGIC;
	                                     SIGNAL out_val  : IN STD_LOGIC;
	                                     SIGNAL out_sop  : IN STD_LOGIC;
	                                     SIGNAL out_eop  : IN STD_LOGIC;
	                                     SIGNAL hold_sop : INOUT STD_LOGIC) IS
	BEGIN
		-- Use out_val as void signal to pass on to unused out_ready, because a signal input can not connect a constant or variable
		proc_dp_verify_sop_and_eop(1, TRUE, clk, out_val, out_val, out_sop, out_eop, hold_sop);
	END proc_dp_verify_sop_and_eop;

	PROCEDURE proc_dp_verify_block_size(CONSTANT c_ready_latency : IN NATURAL;
	                                    SIGNAL alt_size          : IN NATURAL; -- alternative size
	                                    SIGNAL exp_size          : IN NATURAL; -- expected size 
	                                    SIGNAL clk               : IN STD_LOGIC;
	                                    SIGNAL out_ready         : IN STD_LOGIC;
	                                    SIGNAL out_val           : IN STD_LOGIC;
	                                    SIGNAL out_sop           : IN STD_LOGIC;
	                                    SIGNAL out_eop           : IN STD_LOGIC;
	                                    SIGNAL cnt_size          : INOUT NATURAL) IS
	BEGIN
		IF rising_edge(clk) THEN
			IF out_val = '1' THEN
				-- for ready_latency > 0 out_val indicates new data
				-- for ready_latency = 0 out_val only indicates new data when it is confirmed by out_ready
				IF c_ready_latency /= 0 OR (c_ready_latency = 0 AND out_ready = '1') THEN
					IF out_sop = '1' THEN
						cnt_size <= 1;
					ELSIF out_eop = '1' THEN
						cnt_size <= 0;
						IF cnt_size /= alt_size - 1 AND cnt_size /= exp_size - 1 THEN
							REPORT "DP : Unexpected block size" SEVERITY ERROR;
						END IF;
					ELSE
						cnt_size <= cnt_size + 1;
					END IF;
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_block_size;

	PROCEDURE proc_dp_verify_block_size(CONSTANT c_ready_latency : IN NATURAL;
	                                    SIGNAL exp_size          : IN NATURAL;
	                                    SIGNAL clk               : IN STD_LOGIC;
	                                    SIGNAL out_ready         : IN STD_LOGIC;
	                                    SIGNAL out_val           : IN STD_LOGIC;
	                                    SIGNAL out_sop           : IN STD_LOGIC;
	                                    SIGNAL out_eop           : IN STD_LOGIC;
	                                    SIGNAL cnt_size          : INOUT NATURAL) IS
	BEGIN
		proc_dp_verify_block_size(c_ready_latency, exp_size, exp_size, clk, out_ready, out_val, out_sop, out_eop, cnt_size);
	END proc_dp_verify_block_size;

	PROCEDURE proc_dp_verify_block_size(SIGNAL alt_size : IN NATURAL; -- alternative size
	                                    SIGNAL exp_size : IN NATURAL; -- expected size   
	                                    SIGNAL clk      : IN STD_LOGIC;
	                                    SIGNAL out_val  : IN STD_LOGIC;
	                                    SIGNAL out_sop  : IN STD_LOGIC;
	                                    SIGNAL out_eop  : IN STD_LOGIC;
	                                    SIGNAL cnt_size : INOUT NATURAL) IS
	BEGIN
		-- Use out_val as void signal to pass on to unused out_ready, because a signal input can not connect a constant or variable
		proc_dp_verify_block_size(1, alt_size, exp_size, clk, out_val, out_val, out_sop, out_eop, cnt_size);
	END proc_dp_verify_block_size;

	PROCEDURE proc_dp_verify_block_size(SIGNAL exp_size : IN NATURAL;
	                                    SIGNAL clk      : IN STD_LOGIC;
	                                    SIGNAL out_val  : IN STD_LOGIC;
	                                    SIGNAL out_sop  : IN STD_LOGIC;
	                                    SIGNAL out_eop  : IN STD_LOGIC;
	                                    SIGNAL cnt_size : INOUT NATURAL) IS
	BEGIN
		-- Use out_val as void signal to pass on to unused out_ready, because a signal input can not connect a constant or variable
		proc_dp_verify_block_size(1, exp_size, exp_size, clk, out_val, out_val, out_sop, out_eop, cnt_size);
	END proc_dp_verify_block_size;

	------------------------------------------------------------------------------
	-- PROCEDURE: Verify the DUT output invalid between frames
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_verify_gap_invalid(SIGNAL clk     : IN STD_LOGIC;
	                                     SIGNAL in_val  : IN STD_LOGIC;
	                                     SIGNAL in_sop  : IN STD_LOGIC;
	                                     SIGNAL in_eop  : IN STD_LOGIC;
	                                     SIGNAL out_gap : INOUT STD_LOGIC) IS
	BEGIN
		IF rising_edge(clk) THEN
			IF in_eop = '1' THEN
				out_gap <= '1';
			ELSIF in_sop = '1' THEN
				out_gap <= '0';
			ELSIF in_val = '1' AND out_gap = '1' THEN
				REPORT "DP : Wrong valid in gap between eop and sop" SEVERITY ERROR;
			END IF;
		END IF;
	END proc_dp_verify_gap_invalid;

	------------------------------------------------------------------------------
	-- PROCEDURE: Verify the DUT output control (use for sop, eop)
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_verify_ctrl(CONSTANT c_offset : IN NATURAL;
	                              CONSTANT c_period : IN NATURAL;
	                              CONSTANT c_str    : IN STRING;
	                              SIGNAL clk        : IN STD_LOGIC;
	                              SIGNAL verify_en  : IN STD_LOGIC;
	                              SIGNAL data       : IN STD_LOGIC_VECTOR;
	                              SIGNAL valid      : IN STD_LOGIC;
	                              SIGNAL ctrl       : IN STD_LOGIC) IS
		VARIABLE v_data : INTEGER;
	BEGIN
		IF rising_edge(clk) THEN
			IF verify_en = '1' THEN
				v_data := TO_UINT(data);
				IF ((v_data - c_offset) MOD c_period) = 0 THEN
					IF valid = '1' AND ctrl /= '1' THEN
						REPORT "DP : Wrong data control, missing " & c_str SEVERITY ERROR;
					END IF;
				ELSE
					IF ctrl = '1' THEN
						REPORT "DP : Wrong data control, unexpected " & c_str SEVERITY ERROR;
					END IF;
				END IF;
			END IF;
		END IF;
	END proc_dp_verify_ctrl;

	------------------------------------------------------------------------------
	-- PROCEDURE: Wait for stream valid
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_stream_valid(SIGNAL clk      : IN STD_LOGIC;
	                               SIGNAL in_valid : IN STD_LOGIC) IS
	BEGIN
		WAIT UNTIL rising_edge(clk);
		WHILE in_valid /= '1' LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;
	END proc_dp_stream_valid;

	------------------------------------------------------------------------------
	-- PROCEDURE: Wait for stream valid AND sop
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_stream_valid_sop(SIGNAL clk      : IN STD_LOGIC;
	                                   SIGNAL in_valid : IN STD_LOGIC;
	                                   SIGNAL in_sop   : IN STD_LOGIC) IS
	BEGIN
		WAIT UNTIL rising_edge(clk);
		WHILE in_valid /= '1' AND in_sop /= '1' LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;
	END proc_dp_stream_valid_sop;

	------------------------------------------------------------------------------
	-- PROCEDURE: Wait for stream valid AND eop
	------------------------------------------------------------------------------
	PROCEDURE proc_dp_stream_valid_eop(SIGNAL clk      : IN STD_LOGIC;
	                                   SIGNAL in_valid : IN STD_LOGIC;
	                                   SIGNAL in_eop   : IN STD_LOGIC) IS
	BEGIN
		WAIT UNTIL rising_edge(clk);
		WHILE in_valid /= '1' AND in_eop /= '1' LOOP
			WAIT UNTIL rising_edge(clk);
		END LOOP;
	END proc_dp_stream_valid_eop;

END tb_dp_pkg;
