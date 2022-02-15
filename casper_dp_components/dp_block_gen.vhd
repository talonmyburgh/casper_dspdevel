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

-- Purpose : Generate the sosi control for a block of data under flow control
-- Description:
--   When enabled a block of g_nof_data words is output via src_out under flow
--   control by the ready. The ready depends on g_use_src_in:
--
--   . If g_use_src_in=TRUE then the src_in.ready is used and snk_in is
--     ignored. This can be used as a block reference input parallel to a
--     group of user inputs.
--     The g_preserve_* generics do not apply, because the snk_in is ignored.
--
--   . If g_use_src_in=FALSE then the src_in is not used and the snk_in data,
--     re, im are passed on and the snk_in.valid is used as ready. This can
--     be used as a BSN source that creates sync, bsn, sop and eop from
--     snk_in.valid for snk_in.data that has data not valid gaps. The
--     dp_bsn_source is similar but only supports data that is always valid.
--     The g_preserve_* generics can be used to preserve the corresponding
--     snk_in fields or to use the local generated values for this fields.
--
--   The first active ready starts the dp_block_gen. The first output block
--   will have a src_out.sync and every g_nof_blk_per_sync another
--   src_out.sync. Each block is marked by src_out.sop and src_out.eop. The
--   sop also marks the BSN. The BSN is the block sequence number that
--   increments for every block.
--
--   The snk_in.sop and snk_in.eop are always ignored, because g_nof_data
--   will set the src_out.sop/eop blocks.
--   
--   If g_preserve_sync=TRUE then src_out.sync = snk_in.sync, else the
--   src_out.sync is depends on the first ready and on g_nof_blk_per_sync.
--   
--   If g_preserve_bsn=TRUE then src_out.bsn = snk_in.bsn, else the
--   src_out.bsn is depends on the first ready and the initial g_bsn. If
--   g_preserve_bsn=TRUE then g_nof_data needs to match the snk_in.sop/eop
--   blocks.
--
--   If g_preserve_channel=TRUE then src_out.channel = snk_in.channel, else
--   the src_out.channel = g_channel.
--
-- Remarks:
-- . Ready latency (RL) = 1
-- . Alternatively consider using dp_block_gen_valid_arr.vhd or
--   dp_block_reshape.vhd.


LIBRARY IEEE, common_pkg_lib, dp_pkg_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL; 

ENTITY dp_block_gen IS
  GENERIC (
    g_use_src_in         : BOOLEAN := TRUE;  -- when true use src_in.ready else use snk_in.valid for flow control
    g_nof_data           : POSITIVE := 1;    -- nof data per block
    g_nof_blk_per_sync   : POSITIVE := 8;
    g_empty              : NATURAL := 0;
    g_channel            : NATURAL := 0;
    g_error              : NATURAL := 0;
    g_bsn                : NATURAL := 0;
    g_preserve_sync      : BOOLEAN := FALSE;
    g_preserve_bsn       : BOOLEAN := FALSE;
    g_preserve_channel   : BOOLEAN := FALSE
  );             
  PORT (         
    rst        : IN  STD_LOGIC;
    clk        : IN  STD_LOGIC;
    -- Streaming sink
    snk_out    : OUT t_dp_siso;                   -- pass on src_in.xon, pass on or force snk_out.ready dependend on g_use_src_in
    snk_in     : IN  t_dp_sosi := c_dp_sosi_rst;
    -- Streaming source
    src_in     : IN  t_dp_siso := c_dp_siso_rdy;
    src_out    : OUT t_dp_sosi;
    -- MM control
    en         : IN  STD_LOGIC := '1'
  );
END dp_block_gen;


ARCHITECTURE rtl OF dp_block_gen IS

  TYPE t_state IS (s_sop, s_data, s_eop);

  TYPE t_reg IS RECORD  -- local registers
    state     : t_state;
    data_cnt  : NATURAL RANGE 0 TO g_nof_data;
    blk_cnt   : NATURAL RANGE 0 TO g_nof_blk_per_sync;
    bsn       : STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);
    src_out   : t_dp_sosi;
  END RECORD;
  
  CONSTANT c_reg_rst  : t_reg := (s_sop, 0, 0, TO_DP_BSN(g_bsn), c_dp_sosi_rst);

  SIGNAL ready     : STD_LOGIC;
    
  -- Define the local registers in t_reg record
  SIGNAL r         : t_reg;
  SIGNAL nxt_r     : t_reg;
  
BEGIN
  
  snk_out.ready <= src_in.ready WHEN g_use_src_in=TRUE ELSE '1';  -- force snk_out.ready = '1' when src_in.ready is not used
  snk_out.xon   <= src_in.xon;                                    -- always pass on siso.xon
  
  src_out <= r.src_out;
  
  p_clk : PROCESS(rst, clk)
  BEGIN
    IF rst='1' THEN
      r <= c_reg_rst;
    ELSIF rising_edge(clk) THEN
      r <= nxt_r;
    END IF;
  END PROCESS;  

  ready <= src_in.ready WHEN g_use_src_in=TRUE ELSE snk_in.valid;
  
  p_state : PROCESS(r, en, ready, snk_in)
  BEGIN
    nxt_r <= r;
    
    IF g_use_src_in=FALSE THEN
      nxt_r.src_out.data  <= snk_in.data;
      nxt_r.src_out.re    <= snk_in.re;
      nxt_r.src_out.im    <= snk_in.im;
    END IF;

    IF g_preserve_sync = FALSE THEN
      nxt_r.src_out.sync  <= '0';
    ELSE
      nxt_r.src_out.sync  <= snk_in.sync;
    END IF;

    nxt_r.src_out.valid <= '0';
    nxt_r.src_out.sop   <= '0';
    nxt_r.src_out.eop   <= '0';
    
    IF g_preserve_bsn=TRUE THEN
      nxt_r.src_out.bsn <= snk_in.bsn;
    END IF;
    
    IF g_preserve_channel=TRUE THEN
      nxt_r.src_out.channel <= snk_in.channel;
    END IF;
    
    CASE r.state IS
      WHEN s_sop =>
        nxt_r.data_cnt <= 0;            -- for clarity init data count to 0 (because it will become 1 anyway at sop)
        IF en='0' THEN                  -- if disabled then reset block generator and remain in this state
          nxt_r.blk_cnt <= 0;
          nxt_r.bsn     <= TO_DP_BSN(g_bsn);
        ELSE                            -- enabled block generator
          IF ready='1' THEN             -- once enabled the complete block will be output dependent on the flow control
            -- use input sync or create local sync
            IF g_preserve_sync = FALSE THEN
              IF r.blk_cnt=0 THEN
                nxt_r.src_out.sync  <= '1';              -- use local sync for this block, local sync starts at first ready
              END IF;
              IF r.blk_cnt>=g_nof_blk_per_sync-1 THEN    -- maintain local sync interval
                nxt_r.blk_cnt <= 0;
              ELSE
                nxt_r.blk_cnt <= r.blk_cnt+1;
              END IF;
            END IF;
            nxt_r.src_out.valid   <= '1';
            nxt_r.src_out.sop     <= '1';
            
            -- use input bsn or create local bsn
            IF g_preserve_bsn=FALSE THEN
              nxt_r.bsn             <= INCR_UVEC(r.bsn, 1);  -- increment local bsn for next block
              nxt_r.src_out.bsn     <= r.bsn;                -- use local bsn for this block
            END IF;
            
            -- use input channel or create fixed local channel
            IF g_preserve_channel=FALSE THEN
              nxt_r.src_out.channel <= TO_DP_CHANNEL(g_channel);
            END IF;
            
            IF g_nof_data=1 THEN
              nxt_r.src_out.eop   <= '1';  -- single word block
              nxt_r.src_out.empty <= TO_DP_EMPTY(g_empty);
              nxt_r.src_out.err   <= TO_DP_ERROR(g_error);
            ELSIF g_nof_data=2 THEN
              nxt_r.data_cnt <= 1;      -- start of two word block
              nxt_r.state <= s_eop;
            ELSE
              nxt_r.data_cnt <= 1;      -- start of multi word block
              nxt_r.state <= s_data;
            END IF;
          END IF;
        END IF;
      WHEN s_data =>
        IF ready='1' THEN
          nxt_r.data_cnt <= r.data_cnt+1;
          nxt_r.src_out.valid <= '1';
          IF r.data_cnt=g_nof_data-2 THEN
            nxt_r.state <= s_eop;
          END IF;
        END IF;
      WHEN OTHERS =>  -- s_eop
        IF ready='1' THEN
          nxt_r.src_out.valid <= '1';
          nxt_r.src_out.eop   <= '1';
          nxt_r.src_out.empty <= TO_DP_EMPTY(g_empty);
          nxt_r.src_out.err   <= TO_DP_ERROR(g_error);
          nxt_r.state <= s_sop;
        END IF;
    END CASE;
  END PROCESS;  
 
END rtl;
