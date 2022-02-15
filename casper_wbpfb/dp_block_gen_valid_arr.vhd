-------------------------------------------------------------------------------
--
-- Copyright (C) 2011
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-------------------------------------------------------------------------------

-- Purpose : Generate the sosi control for a block of data based on the
--           input valid
-- Description:
--   All input streams in the snk_in_arr must have the same sosi ctrl and info
--   fields, such that the valid from snk_in_arr(0) is sufficient. Only the
--   data, re, im in the snk_in_arr() differs. Therefore default connect snk_in
--   = snk_in_arr(0).
-- 
--   When enabled (enable='1') then a block of g_nof_data_per_block words is
--   output via src_out_arr under flow control by the input valid.
--
--   The input sync, sop and eop are ignored. For the output the sync, sop and 
--   eop are generated by counting the input valid and using
--   g_nof_data_per_block for the output sop and eop, and using
--   g_nof_blk_per_sync for the output sync.
--
--   The first active input valid starts the dp_block_gen_valid_arr. The first
--   output block will have an output sync and every g_nof_blk_per_sync there
--   is another output sync. Each output block is marked by output sop and
--   output eop. The output sop also marks the output BSN. The output BSN is
--   generated such that it increments for every block and that it restarts at
--   0 at every output sync.
--
--   Typically the size of g_nof_blk_per_sync*g_nof_data_per_block should match
--   the number of input valids in an input sync interval.
--
--   The local BSN restarts at 0 for every new output sync interval, but instead
--   of BSN = 0 the input BSN will be inserted at the first block in a new
--   output sync interval. If the first output BSN should remain 0 then simply
--   keep snk_in.bsn = 0.
--
--   g_nof_pages_bsn:
--   The input BSN is not available in snk_in_arr(0) if the upstream component
--   does not pass the BSN on. In that case the snk_in.sync and snk_in.bsn can
--   be connected to some further upstream interface that does have the proper
--   BSN. The input BSN is then buffered to align it with the local sync that is 
--   recreated for the output. This buffer is set via g_nof_pages_bsn. Typically
--   g_nof_pages_bsn = 1 is sufficient to align the BSN along some DSP,
--   components, because the latency in number of blocks of most DSP functions
--   is much less than a sync interval. For a corner turn that operates per sync
--   interval choosing g_nof_pages_bsn = 2 seems appropriate.
--
--   g_check_input_sync:
--   When g_check_input_sync=FALSE then the input sync is ignored and the first
--   input valid that occurs after when enable is active will start the local
--   sync. When g_check_input_sync=TRUE then the block output for a new sync
--   interval is only started if the input valid also coincides with a input
--   sync. Until then all input valid are ignored and there is no output then.
-- 
-- Usage:
-- * Example 1: Use snk_in.valid to recreate sync, sop, eop, bsn for a DP
--              function that only passes on the valid.
--
--   - g_check_input_sync = False
--   - g_nof_pages_bsn    = 0
--   
--                                           |------|
--               snk_in_arr() ----*--------->|      |----> src_out_arr
--                                |          | dp   |
--                             (0)|          | block|
--                                | snk_in   | gen  |
--                                \--------->| arr  |
--                                           |------|
--
-- * Example 2: Use snk_in.valid to recreate sop, eop, bsn and check that the
--              local sync is aligned with the snk_in.sync. If the snk_in.sync
--              does not coincide with the local sync, then stop the output of
--              blocks until the snk_in.sync occurs again.
--              
--   - g_check_input_sync = True
--   - g_nof_pages_bsn    = 0
--   
--                                           |------|
--               snk_in_arr() ----*--------->|      |----> src_out_arr
--                                |          | dp   |
--                             (0)|          | block|
--                                | snk_in   | gen  |
--                                \--------->| arr  |
--                                           |------|
--
-- * Example 3: Use snk_in.valid to recreate sop, eop, bsn for a DP
--              function that only passes on the valid. However use snk_in.sync
--              to delay the snk_in.bsn by g_nof_pages_bsn to account for the
--              block latency of the upstream DP components that did not pass
--              on the snk_in.bsn.
--
--   - g_check_input_sync = False
--   - g_nof_pages_bsn    >= 1
--
--                  |-----|    snk_in_arr()  |------|
--         -----*-->|     |-------*--------->|      |----> src_out_arr
--              |   | DP  |       |          | dp   |
--              |   |     |    (0)|          | block|
--              |   |     |       | snk_in   | gen  |
--              |   |     |       \--*------>| arr  |
--          sync|   |-----|          ^       |------|
--          bsn |                    |
--              \--------------------/
--
-- Remarks:
-- . This dp_block_gen_valid_arr relates to:
--   - dp_bsn_source.vhd
--   - dp_block_gen.vhd when snk_in.valid is used for flow control (so when
--     g_use_src_in=FALSE). This is why thsi dp_block_gen_valid_arr is called
--     with '_valid' in its name.
--   - dp_counter.vhd
--   - dp_paged_sop_eop_reg.vhd
--   - dp_fifo_info.vhd
--   - dp_sync_checker.vhd
-- . This dp_block_gen_valid_arr has no siso flow control, although enable
--   could be used as siso.xon.
-- . The channel, empty and err fields are passed on to the output. Typically
--   these fields are not used with DSP data. However this scheme still
--   allows setting these fields to a fixed value via snk_in.
-- . Using g_check_input_sync=True is similar to using a dp_sync_checker in
--   front of this dp_block_gen_valid_arr. However the advantage of
--   dp_sync_checker is that it provides monitoring and control via MM.

LIBRARY IEEE, common_pkg_lib, wb_fft_lib, wpfb_lib, common_components_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE wb_fft_lib.fft_gnrcs_intrfcs_pkg.ALL; 
USE wpfb_lib.wbpfb_gnrcs_intrfcs_pkg.ALL; 

ENTITY dp_block_gen_valid_arr IS
  GENERIC (
    g_nof_streams           : POSITIVE := 1;
    g_nof_data_per_block    : POSITIVE := 1;
    g_nof_blk_per_sync      : POSITIVE := 8;
    g_check_input_sync      : BOOLEAN := FALSE;
    g_nof_pages_bsn         : NATURAL := 0;
    g_restore_global_bsn    : BOOLEAN := FALSE
  );             
  PORT (         
    rst         : IN  STD_LOGIC;
    clk         : IN  STD_LOGIC;
    -- Streaming sink
    snk_in      : IN  t_fft_sosi_out;  -- = snk_in_arr(0)
    snk_in_arr  : IN  t_fft_sosi_arr_out(g_nof_streams-1 DOWNTO 0);
    -- Streaming source
    src_out_arr : OUT t_fft_sosi_arr_out(g_nof_streams-1 DOWNTO 0);
    -- Control
    enable      : IN  STD_LOGIC := '1'  -- can connect via MM or could also connect to a src_in.xon
  );
END dp_block_gen_valid_arr;


ARCHITECTURE rtl OF dp_block_gen_valid_arr IS

  -- Check consistancy of the parameters, the function return value is void, because always true or abort due to failure
  FUNCTION parameter_asserts(g_check_input_sync : BOOLEAN; g_nof_pages_bsn : NATURAL) return BOOLEAN IS
  BEGIN
    IF g_check_input_sync=TRUE THEN
      ASSERT g_nof_pages_bsn=0 REPORT "When g_check_input_sync=TRUE then g_nof_pages_bsn must be 0." SEVERITY FAILURE;
      -- because snk_in.sync and snk_in.bsn are then already aligned with the first snk_in.valid
    END IF;
    IF g_nof_pages_bsn>0 THEN
      ASSERT g_check_input_sync=FALSE REPORT "When g_nof_pages_bsn>0 then g_check_input_sync must be FALSE." SEVERITY FAILURE;
      -- because snk_in.sync and snk_in.bsn are then NOT aligned with the first snk_in.valid
    END IF;
    RETURN TRUE;
  END parameter_asserts;
  
  CONSTANT c_parameters_ok : BOOLEAN := parameter_asserts(g_check_input_sync, g_nof_pages_bsn);
  
  TYPE t_state IS (s_sop, s_data, s_eop);

  TYPE t_reg IS RECORD  -- local registers
    state       : t_state;
    data_cnt    : NATURAL RANGE 0 TO g_nof_data_per_block;
    blk_cnt     : NATURAL RANGE 0 TO g_nof_blk_per_sync;
    reg_sosi    : t_fft_sosi_out;
  END RECORD;
  
  CONSTANT c_reg_rst  : t_reg := (s_sop, 0, 0, c_fft_sosi_rst_out);

  SIGNAL in_sosi         : t_fft_sosi_out;
  SIGNAL in_sync_wr_en   : STD_LOGIC_VECTOR(g_nof_pages_bsn-1 DOWNTO 0);
  SIGNAL in_bsn_buffer   : STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);
  
  SIGNAL out_sosi        : t_fft_sosi_out;
  SIGNAL nxt_src_out_arr : t_fft_sosi_arr_out(g_nof_streams-1 DOWNTO 0);
    
  -- Define the local registers in t_reg record
  SIGNAL r         : t_reg;
  SIGNAL nxt_r     : t_reg;
  
BEGIN
  
  p_clk : PROCESS(rst, clk)
  BEGIN
    IF rst='1' THEN
      r           <= c_reg_rst;
      src_out_arr <= (OTHERS=>c_fft_sosi_rst_out);
    ELSIF rising_edge(clk) THEN
      r           <= nxt_r;
      src_out_arr <= nxt_src_out_arr;
    END IF;
  END PROCESS;
  
  no_bsn_buffer : IF g_nof_pages_bsn=0 GENERATE
    in_sosi <= snk_in;
  END GENERATE;
  
  gen_bsn_buffer : IF g_nof_pages_bsn>0 GENERATE
    -- Buffer input BSN at each input sync
    in_sync_wr_en <= (OTHERS=>snk_in.sync);
    
    u_paged_bsn : ENTITY common_components_lib.common_paged_reg
    GENERIC MAP (
      g_data_w    => c_dp_stream_bsn_w,
      g_nof_pages => g_nof_pages_bsn
    )
    PORT MAP (
      rst          => rst,
      clk          => clk,
      wr_en        => in_sync_wr_en,
      wr_dat       => snk_in.bsn,
      out_dat      => in_bsn_buffer
    );
    
    p_snk_in : PROCESS(snk_in, in_bsn_buffer)
    BEGIN
      in_sosi      <= snk_in;
      in_sosi.sync <= '0';
      in_sosi.bsn  <= in_bsn_buffer;
    END PROCESS;
  END GENERATE;
    
  -- Determine the output info and output ctrl using snk_in and r.reg_sosi
  p_state : PROCESS(r, enable, in_sosi, snk_in)
  BEGIN
    nxt_r <= r;

    -- default output in_sosi, hold output bsn and set the output ctrl to '0'
    nxt_r.reg_sosi       <= in_sosi;
    nxt_r.reg_sosi.bsn   <= r.reg_sosi.bsn;
    nxt_r.reg_sosi.valid <= '0';
    nxt_r.reg_sosi.sop   <= '0';
    nxt_r.reg_sosi.eop   <= '0';
    nxt_r.reg_sosi.sync  <= '0';
    
    CASE r.state IS
      WHEN s_sop =>
        nxt_r.data_cnt <= 0;    -- For clarity init data count to 0 (because it will become 1 anyway at sop)
        IF enable='0' THEN      -- Check enable in state s_sop to ensure that disable cannot happen during a block
          nxt_r.blk_cnt <= 0;   -- If disabled then reset block generator and remain in this state
        ELSE                    -- Enabled block generator
          IF snk_in.valid='1' THEN    -- Once enabled the complete block will be output dependent on the input valid
            -- maintain blk_cnt for output sync interval, the blk_cnt is the local bsn that wraps at every sync
            IF r.blk_cnt>=g_nof_blk_per_sync-1 THEN
              nxt_r.blk_cnt <= 0;
            ELSE
              nxt_r.blk_cnt <= r.blk_cnt+1;
            END IF;

            -- create local sync and pass on input bsn at local sync
            IF r.blk_cnt=0 THEN                        -- output sync starts at first input valid
              nxt_r.reg_sosi.sync <= '1';               -- output sync for this block
              nxt_r.reg_sosi.bsn  <= in_sosi.bsn;       -- output input bsn at sync
            ELSE
              nxt_r.reg_sosi.bsn  <= TO_UVEC(r.blk_cnt, c_dp_stream_bsn_w);  -- output local bsn for the subsequent blocks
            END IF;
          
            nxt_r.reg_sosi.valid <= '1';
            nxt_r.reg_sosi.sop   <= '1';
            
            IF g_nof_data_per_block=1 THEN
              nxt_r.reg_sosi.eop <= '1';  -- single word block
            ELSE
              nxt_r.data_cnt <= 1;       -- start of multi word block
              nxt_r.state <= s_data;
            END IF;
            
            -- if enabled then check input sync and stop the new block output if the local sync does not coincide with the input sync
            IF g_check_input_sync=TRUE THEN
              IF r.blk_cnt=0 THEN
                IF snk_in.sync='0' THEN
                  nxt_r.reg_sosi.valid <= '0';  -- undo all ctrl preparations for the new block
                  nxt_r.reg_sosi.sop   <= '0';
                  nxt_r.reg_sosi.eop   <= '0';
                  nxt_r.reg_sosi.sync  <= '0';
                  nxt_r.blk_cnt <= 0;          -- restart blk_cnt
                  nxt_r.state <= s_sop;        -- remain in this state and wait for snk_in.sync
                END IF;
              END IF;
            END IF;
          END IF;
        END IF;
      WHEN s_data =>
        IF snk_in.valid='1' THEN
          nxt_r.data_cnt <= r.data_cnt+1;
          nxt_r.reg_sosi.valid <= '1';
          IF r.data_cnt=g_nof_data_per_block-2 THEN
            nxt_r.state <= s_eop;
          END IF;
        END IF;
      WHEN OTHERS =>  -- s_eop
        IF snk_in.valid='1' THEN
          nxt_r.reg_sosi.valid <= '1';
          nxt_r.reg_sosi.eop   <= '1';
          nxt_r.state <= s_sop;
        END IF;
    END CASE;
  END PROCESS;  
  
  -- Use local BSN that counts from 0 during sync interval, or restore global BSN between syncs
  use_local_bsn : IF g_restore_global_bsn=FALSE GENERATE
    out_sosi <= nxt_r.reg_sosi;
  END GENERATE;
  
  use_global_bsn : IF g_restore_global_bsn=TRUE GENERATE
    u_dp_bsn_restore_global : ENTITY work.dp_bsn_restore_global
    GENERIC MAP (
      g_bsn_w    => c_dp_stream_bsn_w,
      g_pipeline => 0       -- pipeline registering is done via nxt_src_out_arr
    )
    PORT MAP (
      rst          => rst,
      clk          => clk,
      -- ST sink
      snk_in       => nxt_r.reg_sosi,
      -- ST source
      src_out      => out_sosi
    );
  END GENERATE;
 
  -- Combine input data with the same out_put info and output ctrl for all streams
  nxt_src_out_arr <= func_dp_stream_arr_combine_data_info_ctrl(snk_in_arr, out_sosi, out_sosi);

END rtl;
