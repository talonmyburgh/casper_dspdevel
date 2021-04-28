--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------

-- Purpose:
--   Multiplex frames from one or more input streams into one output stream.
-- Description:
--   The frames are marked by sop and eop. The input selection scheme depends
--   on g_mode:
--   0: Framed round-robin with fair chance.
--      Uses eop to select next input after the frame has been passed on or
--      select the next input when there is no frame coming in on the current
--      input, so it has had its chance.
--   1: Framed round-robin in forced order from each input.
--      Uses eop to select next output. Holds input selection until sop is
--      detected on that input. Results in ordered (low to high) but blocking
--      (on absence of sop) input selection.
--   2: Unframed external MM control input to select the output.
--      Three options have been considered for the flow control:
--      a) Use src_in for all inputs, data from the not selected inputs
--         will get lost. In case FIFOs are used they are only useful used for
--         the selected input.
--      b) Use c_dp_siso_rdy for unused inputs, this flushes them like with
--         option a) but possibly even faster in case the src_in.ready may get
--         inactive to apply backpressure.
--      c) Use c_dp_siso_hold for unused inputs, to stop them until they get
--         selected again.
--      Support only option a) because assume that the sel_ctrl is rather 
--      static and the data from the unused inputs can be ignored.
--   3: Framed external sel_ctrl input to select the output.
--      This scheme is identical to g_mode=0, but with xon='1' only for the 
--      selected input. The other not selected inputs have xon='0', so they
--      will stop getting input frames and the round-robin scheme of g_mode=0
--      will then automatically select only remaining active input.
--      The assumption is that the upstream input sources do stop their output
--      after they finished the current frame when xon='0'. If necessary
--      dp_xonoff could be used to add such frame flow control to an input
--      stream that does not yet support xon/xoff. But better use g_mode=4 
--      instead of g_mode=3, because the implementation of g_mode=4 is more
--      simple.
--   4) Framed external sel_ctrl input to select the output without ready.
--      This is preferred over g_mode=3 because it passes on the ready but
--      does not use it self. Not selected inputs have xon='0'. Only the
--      selected input has xon='1'. When sel_ctrl changes then briefly all
--      inputs get xon='0'. The new selected input only gets xon='1' when
--      the current selected input is idle or has become idle.
--       
--   The low part of the src_out.channel has c_sel_w = log2(g_nof_input) nof
--   bits and equals the input port number. The snk_in_arr().channel bits are
--   copied into the high part of the src_out.channel. Hence the total
--   effective output channel width becomes g_in_channel_w+c_sel_w when
--   g_use_in_channel=TRUE else c_sel_w.
--   If g_use_fifo=TRUE then the frames are buffered at the input, else the
--   connecting inputs need to take care of that.
-- Remark:
-- . Using g_nof_input=1 is transparent.
-- . Difference with dp_frame_scheduler is that dp_frame_scheduler does not
--   support back pressure via the ready signals.
-- . This dp_mux adds true_log2(nof ports) low bits to out_channel and the
--   dp_demux removes true_log2(nof ports) low bits from in_channel.
-- . For multiplexing time series frames or sample it can be applicable to
--   use g_append_channel_lo=FALSE in combination with g_mode=2.

LIBRARY IEEE, common_pkg_lib, dp_pkg_lib, dp_components_lib, casper_fifo_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

ENTITY dp_mux IS
  GENERIC (
    -- MUX
    g_mode              : NATURAL := 0;
    g_nof_input         : NATURAL := 2;                   -- >= 1
    g_append_channel_lo : BOOLEAN := TRUE;
    g_sel_ctrl_invert   : BOOLEAN := FALSE;  -- Use default FALSE when stream array IO are indexed (0 TO g_nof_input-1), else use TRUE when indexed (g_nof_input-1 DOWNTO 0)
    -- Input FIFO
    g_use_fifo          : BOOLEAN := FALSE;
    g_bsn_w             : NATURAL := 16;
    g_data_w            : NATURAL := 16;
    g_empty_w           : NATURAL := 1;
    g_in_channel_w      : NATURAL := 1;
    g_error_w           : NATURAL := 1;
    g_use_bsn           : BOOLEAN := FALSE;
    g_use_empty         : BOOLEAN := FALSE;
    g_use_in_channel    : BOOLEAN := FALSE;
    g_use_error         : BOOLEAN := FALSE;
    g_use_sync          : BOOLEAN := FALSE;
    g_fifo_af_margin    : NATURAL := 4;  -- Nof words below max (full) at which fifo is considered almost full
    g_fifo_size         : t_natural_arr := array_init(1024, 2);  -- must match g_nof_input, even when g_use_fifo=FALSE
    g_fifo_fill         : t_natural_arr := array_init(   0, 2)   -- must match g_nof_input, even when g_use_fifo=FALSE
  ); 
  PORT (
    rst         : IN  STD_LOGIC;
    clk         : IN  STD_LOGIC;
    -- Control
    sel_ctrl    : IN  NATURAL RANGE 0 TO g_nof_input-1 := 0;  -- used by g_mode = 2, 3, 4
    -- ST sinks
    snk_out_arr : OUT t_dp_siso_arr(0 TO g_nof_input-1);
    snk_in_arr  : IN  t_dp_sosi_arr(0 TO g_nof_input-1);
    -- ST source
    src_in      : IN  t_dp_siso;
    src_out     : OUT t_dp_sosi
  );
END dp_mux;


ARCHITECTURE rtl OF dp_mux IS

  -- Convert unconstrained range (that starts at INTEGER'LEFT) to 0 TO g_nof_input-1 range
  CONSTANT c_fifo_fill  : t_natural_arr(0 TO g_nof_input-1) := g_fifo_fill;
  CONSTANT c_fifo_size  : t_natural_arr(0 TO g_nof_input-1) := g_fifo_size;
  
  -- The low part of src_out.channel is used to represent the input port and the high part of src_out.channel is copied from snk_in_arr().channel
  CONSTANT c_sel_w      : NATURAL := true_log2(g_nof_input);

  CONSTANT c_rl         : NATURAL := 1;
  SIGNAL tb_ready_reg   : STD_LOGIC_VECTOR(0 TO g_nof_input*(1+c_rl)-1);
  
  TYPE state_type IS (s_idle, s_output);
  
  SIGNAL state            : state_type;
  SIGNAL nxt_state        : state_type;

  SIGNAL i_snk_out_arr    : t_dp_siso_arr(0 TO g_nof_input-1);
  
  SIGNAL sel_ctrl_reg     : NATURAL RANGE 0 TO g_nof_input-1;
  SIGNAL nxt_sel_ctrl_reg : NATURAL;
  SIGNAL sel_ctrl_evt     : STD_LOGIC;
  SIGNAL nxt_sel_ctrl_evt : STD_LOGIC;  

  SIGNAL in_sel           : NATURAL RANGE 0 TO g_nof_input-1;  -- input port low part of src_out.channel
  SIGNAL nxt_in_sel       : NATURAL;
  SIGNAL next_sel         : NATURAL;
  
  SIGNAL rd_siso_arr      : t_dp_siso_arr(0 TO g_nof_input-1);
  SIGNAL rd_sosi_arr      : t_dp_sosi_arr(0 TO g_nof_input-1);
  SIGNAL rd_sosi_busy_arr : STD_LOGIC_VECTOR(0 TO g_nof_input-1);
    
  SIGNAL hold_src_in_arr  : t_dp_siso_arr(0 TO g_nof_input-1);
  SIGNAL next_src_out_arr : t_dp_sosi_arr(0 TO g_nof_input-1);
  SIGNAL pend_src_out_arr : t_dp_sosi_arr(0 TO g_nof_input-1);  -- SOSI control
  
  SIGNAL in_xon_arr       : STD_LOGIC_VECTOR(0 TO g_nof_input-1);
  SIGNAL nxt_in_xon_arr   : STD_LOGIC_VECTOR(0 TO g_nof_input-1);
  
  SIGNAL prev_src_in      : t_dp_siso;
  SIGNAL src_out_hi       : t_dp_sosi;  -- snk_in_arr().channel as high part of src_out.channel
  SIGNAL nxt_src_out_hi   : t_dp_sosi;
  SIGNAL channel_lo       : STD_LOGIC_VECTOR(c_sel_w-1 DOWNTO 0);
  SIGNAL nxt_channel_lo   : STD_LOGIC_VECTOR(c_sel_w-1 DOWNTO 0);
  
BEGIN

  snk_out_arr <= i_snk_out_arr;

  -- Monitor sink valid input and sink ready output
  proc_dp_siso_alert(clk, snk_in_arr, i_snk_out_arr, tb_ready_reg);

  p_src_out_wires : PROCESS(src_out_hi, channel_lo)
  BEGIN
    -- SOSI
    src_out <= src_out_hi;
    
    IF g_append_channel_lo=TRUE THEN
      -- The high part of src_out.channel copies the snk_in_arr().channel, the low part of src_out.channel is used to indicate the input port
      src_out.channel                     <= SHIFT_UVEC(src_out_hi.channel, -c_sel_w);
      src_out.channel(c_sel_w-1 DOWNTO 0) <= channel_lo;
    END IF;
  END PROCESS;
  
  p_clk: PROCESS(clk, rst)
  BEGIN
    IF rst='1' THEN
      sel_ctrl_reg <= 0;
      sel_ctrl_evt <= '0';
      in_xon_arr   <= (OTHERS=>'0');
      in_sel       <= 0;
      prev_src_in  <= c_dp_siso_rst;
      state        <= s_idle;
      src_out_hi   <= c_dp_sosi_rst;
      channel_lo   <= (OTHERS=>'0');
    ELSIF rising_edge(clk) THEN
      sel_ctrl_reg <= nxt_sel_ctrl_reg;
      sel_ctrl_evt <= nxt_sel_ctrl_evt;
      in_xon_arr   <= nxt_in_xon_arr;
      in_sel       <= nxt_in_sel;
      prev_src_in  <= src_in;
      state        <= nxt_state;
      src_out_hi   <= nxt_src_out_hi;
      channel_lo   <= nxt_channel_lo;
    END IF;
  END PROCESS;
  
  gen_input : FOR I IN 0 TO g_nof_input-1 GENERATE
    gen_fifo : IF g_use_fifo=TRUE GENERATE
      u_fill : ENTITY casper_fifo_lib.dp_fifo_fill
      GENERIC MAP (
        g_bsn_w          => g_bsn_w,
        g_data_w         => g_data_w,
        g_empty_w        => g_empty_w,
        g_channel_w      => g_in_channel_w,
        g_error_w        => g_error_w,
        g_use_bsn        => g_use_bsn,
        g_use_empty      => g_use_empty,
        g_use_channel    => g_use_in_channel,
        g_use_error      => g_use_error,
        g_use_sync       => g_use_sync,
        g_fifo_fill      => c_fifo_fill(I),
        g_fifo_size      => c_fifo_size(I),
        g_fifo_af_margin => g_fifo_af_margin,
        g_fifo_rl        => 1
      )
      PORT MAP (
        rst      => rst,
        clk      => clk,
        -- ST sink
        snk_out  => i_snk_out_arr(I),
        snk_in   => snk_in_arr(I),
        -- ST source
        src_in   => rd_siso_arr(I),
        src_out  => rd_sosi_arr(I)
      );
    END GENERATE;
    no_fifo : IF g_use_fifo=FALSE GENERATE
      i_snk_out_arr <= rd_siso_arr;
      rd_sosi_arr   <= snk_in_arr;
    END GENERATE;
    
    -- Hold the sink input to be able to register the source output
    u_hold : ENTITY dp_components_lib.dp_hold_input
    PORT MAP (
      rst          => rst,
      clk          => clk,
      -- ST sink
      snk_out      => OPEN,                 -- SISO ready
      snk_in       => rd_sosi_arr(I),       -- SOSI
      -- ST source
      src_in       => hold_src_in_arr(I),   -- SISO ready
      next_src_out => next_src_out_arr(I),  -- SOSI
      pend_src_out => pend_src_out_arr(I),
      src_out_reg  => src_out_hi
    );
  END GENERATE;
  
  -- Register and adjust external MM sel_ctrl for g_sel_ctrl_invert
  nxt_sel_ctrl_reg <= sel_ctrl WHEN g_sel_ctrl_invert=FALSE ELSE g_nof_input-1-sel_ctrl;
  
  -- Detect change in sel_ctrl
  nxt_sel_ctrl_evt <= '1' WHEN nxt_sel_ctrl_reg/=sel_ctrl_reg ELSE '0';
    
  -- The output register stage matches RL = 1 for src_in.ready
  nxt_src_out_hi <= next_src_out_arr(in_sel);  -- default output selected next_src_out_arr 
  nxt_channel_lo <= TO_UVEC(in_sel, c_sel_w);  -- pass on input index via channel low
  
  ------------------------------------------------------------------------------
  -- Unframed MM controlled input selection scheme
  ------------------------------------------------------------------------------
  
  gen_sel_ctrl_direct : IF g_mode=2 GENERATE
    hold_src_in_arr <= (OTHERS=>src_in);  -- pass src_in on to all inputs, only the selected input sosi gets used and the sosi from the other inputs will get lost
    rd_siso_arr     <= (OTHERS=>src_in);
    
    nxt_in_sel <= sel_ctrl_reg;  -- external MM control selects the input
  END GENERATE;
  
  ------------------------------------------------------------------------------
  -- Framed input selection schemes
  ------------------------------------------------------------------------------
  
  gen_sel_ctrl_framed : IF g_mode=4 GENERATE
    u_dp_frame_busy_arr : ENTITY work.dp_frame_busy_arr
    GENERIC MAP (
      g_nof_inputs => g_nof_input,
      g_pipeline   => 1   -- register snk_in_busy to ease timing closure
    )
    PORT MAP (
      rst             => rst,
      clk             => clk,
      snk_in_arr      => rd_sosi_arr,
      snk_in_busy_arr => rd_sosi_busy_arr
    );
    
    hold_src_in_arr <= (OTHERS=>c_dp_siso_rdy);  -- effectively bypass the dp_hold_input
    
    p_rd_siso_arr : PROCESS(src_in, in_xon_arr)
    BEGIN
      FOR I IN 0 TO g_nof_input-1 LOOP
        rd_siso_arr(I).ready <= src_in.ready;    -- default pass on src_in ready flow control to all inputs
        rd_siso_arr(I).xon   <= in_xon_arr(I);   -- use xon to enable one input and stop all other inputs
      END LOOP;
    END PROCESS;
    
    p_state : PROCESS(state, in_sel, rd_sosi_busy_arr, sel_ctrl_reg, sel_ctrl_evt)
    BEGIN
      nxt_state      <= state;
      nxt_in_sel     <= in_sel;
      nxt_in_xon_arr <= (OTHERS=>'0');  -- Default stop all inputs
      
      CASE state IS
        WHEN s_idle =>
          -- Wait until all inputs are inactive (due to xon='0') to ensure that the old input has finished its last frame and the new input has not started yet
          IF UNSIGNED(rd_sosi_busy_arr)=0 THEN
            nxt_in_sel <= sel_ctrl_reg;
            nxt_state <= s_output;
          END IF;
          
        WHEN OTHERS => -- s_output
          -- Enable only the selected input via xon='1'
          nxt_in_xon_arr(sel_ctrl_reg) <= '1';
          
          -- Detect if the input selection changes
          IF sel_ctrl_evt='1' THEN
            nxt_state <= s_idle;
          END IF;
      END CASE;
    END PROCESS;    
  END GENERATE;
  
  
  gen_framed : IF g_mode=0 OR g_mode=1 OR g_mode=3 GENERATE
    p_hold_src_in_arr : PROCESS(rd_siso_arr, pend_src_out_arr, in_sel, src_in)
    BEGIN
      hold_src_in_arr <= rd_siso_arr;       -- default ready for hold input when ready for sink input
      IF pend_src_out_arr(in_sel).eop='1' THEN
        hold_src_in_arr(in_sel) <= src_in;  -- also ready for hold input when the eop is there
      END IF;
    END PROCESS;
  
    next_sel <= in_sel+1 WHEN in_sel<g_nof_input-1 ELSE 0;
  
    p_state : PROCESS(state, in_sel, next_sel, pend_src_out_arr, src_in, prev_src_in, sel_ctrl_reg)
    BEGIN
      rd_siso_arr <= (OTHERS=>c_dp_siso_hold);  -- default not ready for input, but xon='1'
      
      nxt_in_sel <= in_sel;
      
      nxt_state <= state;
      
      CASE state IS
        WHEN s_idle =>
          -- Need to check pend_src_out_arr(in_sel).sop, which can be active if prev_src_in.ready was '1',
          -- because src_in.ready may be '0' and then next_src_out_arr(in_sel).sop is '0'
          IF pend_src_out_arr(in_sel).sop='1' THEN
            IF pend_src_out_arr(in_sel).eop='1' THEN
              rd_siso_arr <= (OTHERS=>c_dp_siso_hold);  -- the sop and the eop are there, it is a frame with only one data word, stop reading this input
              IF src_in.ready='1' THEN
                nxt_in_sel            <= next_sel;      -- the pend_src_out_arr(in_sel).eop will be output, so continue to next input.
                rd_siso_arr(next_sel) <= src_in;
              END IF;
            ELSE
              rd_siso_arr(in_sel) <= src_in;            -- the sop is there, so start outputting the frame from this input
              nxt_state <= s_output;
            END IF;
          ELSE
            CASE g_mode IS
              WHEN 0 | 3 =>
                -- Framed round-robin with fair chance per input
                IF prev_src_in.ready='0' THEN
                  rd_siso_arr(in_sel) <= src_in;        -- no sop, remain at current input to give it a chance
                ELSE
                  nxt_in_sel            <= next_sel;    -- no sop, select next input, because the current input has had a chance
                  rd_siso_arr(next_sel) <= src_in;
                END IF;
              WHEN OTHERS =>  -- = 1
                -- Framed round-robin in forced order from each input
                rd_siso_arr(in_sel) <= src_in;          -- no sop, remain at current input to wait for a frame     
            END CASE;
          END IF;
        WHEN OTHERS => -- s_output
          rd_siso_arr(in_sel) <= src_in;                -- output the rest of the selected input frame
          IF pend_src_out_arr(in_sel).eop='1' THEN
            rd_siso_arr <= (OTHERS=>c_dp_siso_hold);    -- the eop is there, stop reading this input
            IF src_in.ready='1' THEN
              nxt_in_sel            <= next_sel;        -- the pend_src_out_arr(in_sel).eop will be output, so continue to next input. 
              rd_siso_arr(next_sel) <= src_in;
              nxt_state <= s_idle;
            END IF;
          END IF;
      END CASE;
      
      -- Pass on frame level flow control
      FOR I IN 0 TO g_nof_input-1 LOOP
        rd_siso_arr(I).xon <= src_in.xon;
        
        IF g_mode=3 THEN
          -- Framed MM control select input via XON
          rd_siso_arr(I).xon <= '0';            -- force xon='0' for not selected inputs
          IF sel_ctrl_reg=I THEN
            rd_siso_arr(I).xon <= src_in.xon;   -- pass on frame level flow control for selected input
          END IF;
        END IF;
      END LOOP;
    END PROCESS;
    
  END GENERATE;
      
END rtl;
