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

LIBRARY IEEE, common_pkg_lib, common_components_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.common_lfsr_sequences_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;

-- Purpose: Test bench for common_multiplexer.vhd and common_demultiplexer.vhd
-- Usage:
-- > as 6
-- > run -all
--   The tb p_verify self-checks the output by using first a 1->g_nof_streams
--   demultiplexer and then a g_nof_streams->1 multiplexer. Both the use the
--   same output and input selection so that the expected output data is again
--   the same as the input stimuli data.
-- Remark:

ENTITY tb_common_multiplexer IS
  GENERIC (
    g_pipeline_demux_in  : NATURAL := 1;
    g_pipeline_demux_out : NATURAL := 1;
    g_nof_streams        : NATURAL := 3;
    g_pipeline_mux_in    : NATURAL := 1;
    g_pipeline_mux_out   : NATURAL := 1;
    g_dat_w              : NATURAL := 8;
    g_random_in_val      : BOOLEAN := FALSE;
    g_test_nof_cycles    : NATURAL := 500
  );
	PORT(
		o_rst		   : OUT STD_LOGIC;
		o_clk		   : OUT STD_LOGIC;
		o_tb_end	 : OUT STD_LOGIC;
		o_test_msg : OUT STRING(1 to 120);
		o_test_pass: OUT BOOLEAN
	);
END tb_common_multiplexer;

ARCHITECTURE tb OF tb_common_multiplexer IS

  CONSTANT clk_period        : TIME := 10 ns;
  
  CONSTANT c_rl              : NATURAL := 1;
  CONSTANT c_init            : NATURAL := 0;
  
  -- DUT constants
  CONSTANT c_pipeline_demux  : NATURAL := g_pipeline_demux_in + g_pipeline_demux_out;
  CONSTANT c_pipeline_mux    : NATURAL := g_pipeline_mux_in   + g_pipeline_mux_out;
  CONSTANT c_pipeline_total  : NATURAL := c_pipeline_demux + c_pipeline_mux;
  
  CONSTANT c_sel_w           : NATURAL := ceil_log2(g_nof_streams);
  
  -- Stimuli
  SIGNAL tb_end             : STD_LOGIC := '0';
  SIGNAL rst                : STD_LOGIC;
  SIGNAL clk                : STD_LOGIC := '1';
  SIGNAL ready              : STD_LOGIC := '1';
  SIGNAL verify_en          : STD_LOGIC := '0';
  SIGNAL random_0           : STD_LOGIC_VECTOR(14 DOWNTO 0) := (OTHERS=>'0');  -- use different lengths to have different random sequences
  SIGNAL cnt_en             : STD_LOGIC := '1';
  
  -- DUT input
  SIGNAL in_dat             : STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL in_val             : STD_LOGIC;
  SIGNAL in_sel             : STD_LOGIC_VECTOR(c_sel_w-1 DOWNTO 0) := (OTHERS => '0');
  
  -- Demux-Mux interface
  SIGNAL demux_dat_vec      : STD_LOGIC_VECTOR(g_nof_streams*g_dat_w-1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL demux_val_vec      : STD_LOGIC_VECTOR(g_nof_streams        -1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL demux_val          : STD_LOGIC;
  SIGNAL demux_sel          : STD_LOGIC_VECTOR(c_sel_w-1 DOWNTO 0) := (OTHERS => '0');
  
  -- DUT output
  SIGNAL out_dat            : STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL out_val            : STD_LOGIC;
  
  -- Verify
  SIGNAL prev_out_dat       : STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL pipe_dat_vec       : STD_LOGIC_VECTOR(0 TO (c_pipeline_total+1)*g_dat_w-1) := (OTHERS => '0');
  SIGNAL pipe_val_vec       : STD_LOGIC_VECTOR(0 TO (c_pipeline_total+1)*1      -1) := (OTHERS => '0');
  
  -- Test out signals
  SIGNAL dat_test_pass : BOOLEAN := TRUE;
  SIGNAL dat_latency_test_pass : BOOLEAN := TRUE;
  SIGNAL val_latency_test_pass : BOOLEAN := TRUE;

  SIGNAL dat_test_msg : STRING(o_test_msg'range) := (OTHERS => '.');
  SIGNAL dat_latency_test_msg : STRING(o_test_msg'range) := (OTHERS => '.');
  SIGNAL val_latency_test_msg : STRING(o_test_msg'range) := (OTHERS => '.');
BEGIN

  ------------------------------------------------------------------------------
  -- Stimuli
  ------------------------------------------------------------------------------
  
  -- . tb
  clk <= NOT clk OR tb_end AFTER clk_period/2;
  rst <= '1', '0' AFTER 3*clk_period;
  tb_end <= '0', '1' AFTER g_test_nof_cycles*clk_period;

  o_clk <= clk;
  o_rst <= rst;
  o_tb_end <= tb_end;
  o_test_pass <= dat_test_pass and dat_latency_test_pass and val_latency_test_pass;
  o_test_msg <= sel_a_b(not dat_test_pass, dat_test_msg, sel_a_b(not dat_latency_test_pass, dat_latency_test_msg, val_latency_test_msg));
  
  -- . data
  random_0 <= func_common_random(random_0) WHEN rising_edge(clk);
  
  cnt_en <= '1' WHEN g_random_in_val=FALSE ELSE random_0(random_0'HIGH);

  proc_common_gen_data(c_rl, c_init, rst, clk, cnt_en, ready, in_dat, in_val);
  
  -- . selection
  in_sel <= INCR_UVEC(in_sel, 1) WHEN rising_edge(clk) AND TO_UINT(in_sel)<g_nof_streams-1 ELSE
            TO_UVEC(0, c_sel_w)  WHEN rising_edge(clk);  -- periodic selection over all demultiplexer output and multiplexer input streams

  -- . verification
  p_verify_en : PROCESS
  BEGIN
    proc_common_wait_until_high(clk, in_val);
    proc_common_wait_some_cycles(clk, c_pipeline_total);
    
    verify_en <= '1';
    WAIT;
  END PROCESS;
  
  ------------------------------------------------------------------------------
  -- DUT : 1 --> g_nof_streams --> 1
  ------------------------------------------------------------------------------
  
  -- . Demultiplex single input to output[in_sel]
  u_demux : ENTITY work.common_demultiplexer
  GENERIC MAP (
    g_pipeline_in   => g_pipeline_demux_in,
    g_pipeline_out  => g_pipeline_demux_out,
    g_nof_out       => g_nof_streams,
    g_dat_w         => g_dat_w
  )
  PORT MAP(
    rst         => rst,
    clk         => clk,
    
    in_dat      => in_dat,
    in_val      => in_val,

    out_sel     => in_sel,
    out_dat     => demux_dat_vec,
    out_val     => demux_val_vec
  );
  
  -- . pipeline in_sel to align demux_sel to demux_*_vec
  u_pipe_sel : ENTITY common_components_lib.common_pipeline
  GENERIC MAP (
    g_pipeline  => c_pipeline_demux,
    g_in_dat_w  => c_sel_w,
    g_out_dat_w => c_sel_w
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    in_dat  => in_sel,
    out_dat => demux_sel
  );
  
  demux_val <= demux_val_vec(TO_UINT(demux_sel));

  -- . Multiplex input[demux_sel] back to a single output
  u_mux : ENTITY work.common_multiplexer
  GENERIC MAP (
    g_pipeline_in   => g_pipeline_mux_in,  
    g_pipeline_out  => g_pipeline_mux_out,
    g_nof_in        => g_nof_streams,
    g_dat_w         => g_dat_w
  )
  PORT MAP (
    rst         => rst,
    clk         => clk,
    
    in_sel      => demux_sel,
    in_dat      => demux_dat_vec,
    in_val      => demux_val,

    out_dat     => out_dat,
    out_val     => out_val
  );     
                      
  
  ------------------------------------------------------------------------------
  -- Verification
  ------------------------------------------------------------------------------
  
  proc_common_verify_data(c_rl, clk, rst, verify_en, ready, out_val, out_dat, prev_out_dat, dat_test_msg, dat_test_pass);              -- verify out_dat assuming incrementing data
  proc_common_verify_latency("data",  c_pipeline_total, clk, verify_en, in_dat, pipe_dat_vec, out_dat, dat_latency_test_msg, dat_latency_test_pass);   -- verify out_dat using delayed input
  proc_common_verify_latency("valid", c_pipeline_total, clk, verify_en, in_val, pipe_val_vec, out_val, val_latency_test_msg, val_latency_test_pass);   -- verify out_val using delayed input
  
END tb;
