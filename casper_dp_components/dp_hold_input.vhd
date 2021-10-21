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
USE IEEE.std_logic_1164.all;
USE dp_pkg_lib.dp_stream_pkg.ALL;

-- Purpose:
--   Hold the sink input
-- Description:
--   This dp_hold_input provides the necessary input logic to hold the input
--   data and control to easily register the source output. Compared to
--   dp_pipeling the dp_hold_input is the same except for the output register
--   stage. In this way dp_hold_input can be used in a more complicated stream
--   component where the output is not always the same as the input.
--   The snk_in.valid and hold_in.valid are never high at the same time.
--   If src_in.ready goes low while snk_in.valid is high then this snk_in.valid
--   is held in hold_in.valid and the corresponding snk_in.data will get held
--   in the external src_out_reg.data. When src_in.ready goes high again then
--   the held data becomes valid via src_out_reg.valid and hold_in.valid goes
--   low. Due to the RL=1 the next cycle the snk_in.valid from the sink may go
--   high. The next_src_out control signals are equal to pend_src_out AND
--   src_in.ready, so they can directly be assigned to src_out_reg.data if the
--   snk_in.data needs to be passed on.
--   The internal pend_src_out control signals are available outside, in
--   addition to the next_src_out control signals, to support external control
--   independent of src_in.ready. Use pend_scr_out instead of next_src_out
--   to avoid combinatorial loop when src_in.ready depends on next_src_out.
--   The pend_src_out signals are used to implement show ahead behaviour like
--   with RL=0, but for RL=1. The input can then be stopped based on the snk_in
--   data and later on continued again without losing this snk_in data, because
--   it was held as described above.
-- Remarks:
-- . Ready latency = 1
-- . Without flow control so when src_in.ready = '1' fixed, then dp_hold_input
--   becomes void because the dp_hold_ctrl output then remains '0'.

ENTITY dp_hold_input IS
  PORT (
    rst              : IN  STD_LOGIC;
    clk              : IN  STD_LOGIC;
    -- ST sink
    snk_out          : OUT t_dp_siso;
    snk_in           : IN  t_dp_sosi;
    -- ST source
    src_in           : IN  t_dp_siso;
    next_src_out     : OUT t_dp_sosi;
    pend_src_out     : OUT t_dp_sosi;  -- the SOSI data fields are the same as for next_src_out
    src_out_reg      : IN  t_dp_sosi   -- uses only the SOSI data fields
  );
END dp_hold_input;

ARCHITECTURE rtl OF dp_hold_input IS
  
  SIGNAL i_pend_src_out : t_dp_sosi;
  SIGNAL hold_in        : t_dp_sosi;  -- uses only the SOSI ctrl fields
  
BEGIN

  pend_src_out <= i_pend_src_out;

  -- SISO:
  snk_out <= src_in;  --  No change in ready latency, pass on xon frame level flow control
  
  -- SOSI:
  -- Take care of active snk_in.valid, snk_in.sync, snk_in.sop and snk_in.eop
  -- when src_in.ready went low. If hold_in.valid would not be used for
  -- pend_src_out.valid and next_src_out.valid, then the pipeline would still
  -- work, but the valid snk_in.data that came when src_in.ready went low,
  -- will then only get pushed out on the next valid snk_in.valid. Whereas
  -- hold_in.valid ensures that it will get pushed out as soon as src_in.ready
  -- goes high again. This is typically necessary in case of packetized data
  -- where the eop of one packet should not have to wait for the valid (sop)
  -- of a next packet to get pushed out.
  
  u_hold_val : ENTITY work.dp_hold_ctrl
  PORT MAP (
    rst      => rst,
    clk      => clk,
    ready    => src_in.ready,
    in_ctrl  => snk_in.valid,
    hld_ctrl => hold_in.valid
  );
  
  u_hold_sync : ENTITY work.dp_hold_ctrl
  PORT MAP (
    rst      => rst,
    clk      => clk,
    ready    => src_in.ready,
    in_ctrl  => snk_in.sync,
    hld_ctrl => hold_in.sync
  );
  
  u_hold_sop : ENTITY work.dp_hold_ctrl
  PORT MAP (
    rst      => rst,
    clk      => clk,
    ready    => src_in.ready,
    in_ctrl  => snk_in.sop,
    hld_ctrl => hold_in.sop
  );
  
  u_hold_eop : ENTITY work.dp_hold_ctrl
  PORT MAP (
    rst      => rst,
    clk      => clk,
    ready    => src_in.ready,
    in_ctrl  => snk_in.eop,
    hld_ctrl => hold_in.eop
  );
  
  p_pend_src_out : PROCESS(snk_in, src_out_reg, hold_in)
  BEGIN
    -- Pend data
    IF snk_in.valid='1' THEN
      i_pend_src_out <= snk_in;       -- Input data
    ELSE
      i_pend_src_out <= src_out_reg;  -- Hold data
    END IF;
    i_pend_src_out.valid <= snk_in.valid OR hold_in.valid;
    i_pend_src_out.sync  <= snk_in.sync  OR hold_in.sync;
    i_pend_src_out.sop   <= snk_in.sop   OR hold_in.sop;
    i_pend_src_out.eop   <= snk_in.eop   OR hold_in.eop;
  END PROCESS;
  
  p_next_src_out : PROCESS(i_pend_src_out, src_in)
  BEGIN
    -- Next data
    next_src_out       <= i_pend_src_out;
    -- Next control
    next_src_out.valid <= i_pend_src_out.valid AND src_in.ready;
    next_src_out.sync  <= i_pend_src_out.sync  AND src_in.ready;
    next_src_out.sop   <= i_pend_src_out.sop   AND src_in.ready;
    next_src_out.eop   <= i_pend_src_out.eop   AND src_in.ready;
  END PROCESS;
    
END rtl;

LIBRARY IEEE, wb_fft_lib, wpfb_lib;
USE IEEE.std_logic_1164.all;
USE wb_fft_lib.fft_gnrcs_intrfcs_pkg.ALL;
USE wpfb_lib.wbpfb_gnrcs_intrfcs_pkg.ALL;

ENTITY dp_hold_input_fft_out IS
  PORT (
    rst              : IN  STD_LOGIC;
    clk              : IN  STD_LOGIC;
    -- ST sink
    snk_out          : OUT t_dp_siso;
    snk_in           : IN  t_fft_sosi_out;
    -- ST source
    src_in           : IN  t_dp_siso;
    next_src_out     : OUT t_fft_sosi_out;
    pend_src_out     : OUT t_fft_sosi_out;  -- the SOSI data fields are the same as for next_src_out
    src_out_reg      : IN  t_fft_sosi_out   -- uses only the SOSI data fields
  );
END dp_hold_input_fft_out;

ARCHITECTURE rtl OF dp_hold_input_fft_out IS
  
  SIGNAL i_pend_src_out : t_fft_sosi_out;
  SIGNAL hold_in        : t_fft_sosi_out;  -- uses only the SOSI ctrl fields
  
BEGIN

  pend_src_out <= i_pend_src_out;

  -- SISO:
  snk_out <= src_in;  --  No change in ready latency, pass on xon frame level flow control
  
  -- SOSI:
  -- Take care of active snk_in.valid, snk_in.sync, snk_in.sop and snk_in.eop
  -- when src_in.ready went low. If hold_in.valid would not be used for
  -- pend_src_out.valid and next_src_out.valid, then the pipeline would still
  -- work, but the valid snk_in.data that came when src_in.ready went low,
  -- will then only get pushed out on the next valid snk_in.valid. Whereas
  -- hold_in.valid ensures that it will get pushed out as soon as src_in.ready
  -- goes high again. This is typically necessary in case of packetized data
  -- where the eop of one packet should not have to wait for the valid (sop)
  -- of a next packet to get pushed out.
  
  u_hold_val : ENTITY work.dp_hold_ctrl
  PORT MAP (
    rst      => rst,
    clk      => clk,
    ready    => src_in.ready,
    in_ctrl  => snk_in.valid,
    hld_ctrl => hold_in.valid
  );
  
  u_hold_sync : ENTITY work.dp_hold_ctrl
  PORT MAP (
    rst      => rst,
    clk      => clk,
    ready    => src_in.ready,
    in_ctrl  => snk_in.sync,
    hld_ctrl => hold_in.sync
  );
  
  u_hold_sop : ENTITY work.dp_hold_ctrl
  PORT MAP (
    rst      => rst,
    clk      => clk,
    ready    => src_in.ready,
    in_ctrl  => snk_in.sop,
    hld_ctrl => hold_in.sop
  );
  
  u_hold_eop : ENTITY work.dp_hold_ctrl
  PORT MAP (
    rst      => rst,
    clk      => clk,
    ready    => src_in.ready,
    in_ctrl  => snk_in.eop,
    hld_ctrl => hold_in.eop
  );
  
  p_pend_src_out : PROCESS(snk_in, src_out_reg, hold_in)
  BEGIN
    -- Pend data
    IF snk_in.valid='1' THEN
      i_pend_src_out <= snk_in;       -- Input data
    ELSE
      i_pend_src_out <= src_out_reg;  -- Hold data
    END IF;
    i_pend_src_out.valid <= snk_in.valid OR hold_in.valid;
    i_pend_src_out.sync  <= snk_in.sync  OR hold_in.sync;
    i_pend_src_out.sop   <= snk_in.sop   OR hold_in.sop;
    i_pend_src_out.eop   <= snk_in.eop   OR hold_in.eop;
  END PROCESS;
  
  p_next_src_out : PROCESS(i_pend_src_out, src_in)
  BEGIN
    -- Next data
    next_src_out       <= i_pend_src_out;
    -- Next control
    next_src_out.valid <= i_pend_src_out.valid AND src_in.ready;
    next_src_out.sync  <= i_pend_src_out.sync  AND src_in.ready;
    next_src_out.sop   <= i_pend_src_out.sop   AND src_in.ready;
    next_src_out.eop   <= i_pend_src_out.eop   AND src_in.ready;
  END PROCESS;
    
END rtl;

