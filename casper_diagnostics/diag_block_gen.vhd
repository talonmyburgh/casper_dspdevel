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

-- Purpose: Block generator repeating a data pattern
-- Description:
--   The data pattern is read via the buf_* MM interface. The output data
--   block is controlled via ctrl of type t_diag_block_gen with fields:
--
--     enable             : sl  -- block enable immediately
--     enable_sync        : sl  -- block enable at next en_sync pulse
--     samples_per_packet : slv -- number of valid per block, from sop to eop
--     blocks_per_sync    : slv -- number of blocks per sync interval
--     gapsize            : slv -- number of clk cycles between blocks, so
--                                 between last eop and next sop
--     mem_low_adrs       : slv -- block start address at MM interface
--     mem_high_adrs      : slv -- end address at MM interface
--     bsn_init           : slv -- BSN of first output block
--                                          
--   The MM reading starts at mem_low_adrs when the BG is first enabled. If
--   the mem_high_adrs-mem_low_adrs+1 < samples_per_packet then the reading
--   wraps and continues from mem_low_adrs. For every new block the reading
--   continues where it left in the previous block. This MM reading scheme
--   allows using a periodic data pattern that can extends accross blocks and
--   sync intervals, because is continues for as long as the BG remains
--   enabled.
--
--   The input en_sync can be used as trigger to start multiple BG at the same
--   clk cycle. The BG creates a out_sosi.sync at the first sop and the sop of
--   every blocks_per_sync.
--
--   The current block is finished properly after enable gows low, to ensure 
--   that all blocks have the same length. A new ctrl is accepted after a
--   current block has finished, to ensure that no fractional blocks will 
--   enter the stream.
--
--   The BG supports block flow control via out_siso.xon. The BG also supports
--   sample flow control via out_siso.ready.
--
--   The read data is resized and output as unsigned via:
--   . out_sosi.data(g_buf_dat_w-1:0).
--   The read data is also output as complex data via:
--   . out_sosi.im(g_buf_dat_w  -1:g_buf_dat_w/2)
--   . out_sosi.re(g_buf_dat_w/2-1:            0)

library IEEE, common_pkg_lib, dp_pkg_lib;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use common_pkg_lib.common_pkg.ALL;
use work.diag_pkg.ALL; 
use dp_pkg_lib.dp_stream_pkg.ALL; 

entity diag_block_gen is
  generic (
    g_blk_sync   : boolean := false;  -- when true use active sync during entire block, else use single clock cycle sync pulse
    g_buf_dat_w  : natural := 32;
    g_buf_addr_w : natural := 7
  );             
  port (         
    rst          : in  std_logic;
    clk          : in  std_logic;
    buf_addr     : out std_logic_vector(g_buf_addr_w-1 downto 0);
    buf_rden     : out std_logic;
    buf_rddat    : in  std_logic_vector(g_buf_dat_w-1 downto 0);
    buf_rdval    : in  std_logic;
    ctrl         : in  t_diag_block_gen;
    en_sync      : in  std_logic := '1';
    out_siso     : in  t_dp_siso := c_dp_siso_rdy;
    out_sosi     : out t_dp_sosi
  );
  
end diag_block_gen;
 
architecture rtl of diag_block_gen is

  type state_type is (s_idle, s_block, s_gap);

  type reg_type is record
    ctrl_reg    : t_diag_block_gen;  -- capture ctrl
    blk_en      : std_logic;  -- enable at block level
    blk_xon     : std_logic;  -- siso.xon at block level, the BG continues but the sosi control depend on xon (the BG does not support siso.ready)
    blk_sync    : std_logic;  -- block sync alternative of the pulse sync
    pls_sync    : std_logic;  -- pulse sync
    valid       : std_logic;
    sop         : std_logic;
    eop         : std_logic;
    rd_ena      : std_logic;                          
    samples_cnt : natural range 0 to 2**c_diag_bg_samples_per_packet_w-1;
    blocks_cnt  : natural range 0 to 2**c_diag_bg_blocks_per_sync_w-1;
    bsn_cnt     : std_logic_vector(c_diag_bg_bsn_init_w-1 downto 0);  -- = c_dp_stream_bsn_w
    mem_cnt     : natural range 0 to 2**g_buf_addr_w-1;
    state       : state_type;   -- The state machine. 
  end record;

  signal r, rin     : reg_type;
  signal out_sosi_i : t_dp_sosi := c_dp_sosi_rst;  -- Signal used to assign reset values to output
  
begin 
    
    p_comb : process(r, rst, ctrl, en_sync, out_siso)
      variable v                    : reg_type;                              
      variable v_samples_per_packet : natural;    -- @suppress "The type of a variable has to be constrained in size"
      variable v_gapsize            : natural;    -- @suppress "The type of a variable has to be constrained in size"
      variable v_blocks_per_sync    : natural;  -- @suppress "The type of a variable has to be constrained in size"
      variable v_mem_low_adrs       : natural; -- @suppress "The type of a variable has to be constrained in size"
      variable v_mem_high_adrs      : natural; -- @suppress "The type of a variable has to be constrained in size"
    begin
    
      v_samples_per_packet := TO_UINT(r.ctrl_reg.samples_per_packet);
      v_gapsize            := TO_UINT(r.ctrl_reg.gapsize);
      v_blocks_per_sync    := TO_UINT(r.ctrl_reg.blocks_per_sync); 
      v_mem_low_adrs       := TO_UINT(r.ctrl_reg.mem_low_adrs); 
      v_mem_high_adrs      := TO_UINT(r.ctrl_reg.mem_high_adrs);
      
      v                   := r;     -- default hold all r fields
      v.pls_sync          := '0';
      v.valid             := '0';
      v.sop               := '0';
      v.eop               := '0';
      v.rd_ena            := '0';
      
      -- Control block generator enable
      if ctrl.enable='0' then
        v.blk_en := '0';  -- disable immediately
      elsif ctrl.enable_sync='0' then
        v.blk_en := '1';  -- enable immediately or keep enabled
      elsif en_sync='1' then
        v.blk_en := '1';  -- enable at input sync pulse or keep enabled
      end if;
      
      -- The pulse sync is high at the sop of the first block, the block sync is high during the entire block until the eop
      if r.eop='1' then
        v.blk_sync := '0';
      end if;
    
      -- Increment the block sequence number counter after each block
      if r.eop='1' then
        v.bsn_cnt := incr_uvec(r.bsn_cnt, 1);
      end if;
      
      case r.state is
        when s_idle => 
          v.ctrl_reg    := ctrl;        -- accept new control settings
          v.blk_xon     := out_siso.xon;
          v.blk_sync    := '0';
          v.samples_cnt := 0;
          v.blocks_cnt  := 0;    
          v.bsn_cnt     := ctrl.bsn_init;
          v.mem_cnt     := v_mem_low_adrs; 
          if r.blk_en = '1' then       -- Wait until enabled
            if out_siso.xon='1' then   -- Wait until XON is 1
              v.rd_ena      := '1';
              v.state       := s_block;
            end if;
          end if;
          
        when s_block =>
          if out_siso.ready='1' then
          
            v.rd_ena := '1';  -- read next data
            if r.samples_cnt = 0 and r.blocks_cnt = 0 then 
              v.pls_sync    := '1';                      -- Always start with a pulse sync          
              v.blk_sync    := '1';
              v.sop         := '1';
              v.samples_cnt := v.samples_cnt + 1; 
            elsif r.samples_cnt = 0 then
              v.sop         := '1';
              v.samples_cnt := v.samples_cnt + 1; 
            elsif r.samples_cnt >= v_samples_per_packet-1 and v_gapsize = 0 and r.blocks_cnt >= v_blocks_per_sync-1 then 
              v.eop         := '1'; 
              v.ctrl_reg    := ctrl;      -- accept new control settings at end of block when gapsize=0
              v.samples_cnt := 0; 
              v.blocks_cnt  := 0;
            elsif r.samples_cnt >= v_samples_per_packet-1 and v_gapsize = 0 then 
              v.eop         := '1'; 
              v.ctrl_reg    := ctrl;      -- accept new control settings at end of block when gapsize=0
              v.samples_cnt := 0; 
              v.blocks_cnt  := r.blocks_cnt + 1;
            elsif r.samples_cnt >= v_samples_per_packet-1 then 
              v.eop         := '1'; 
              v.samples_cnt := 0; 
              v.rd_ena      := '0';
              v.state       := s_gap;
            else 
              v.samples_cnt := r.samples_cnt + 1;
            end if;
            v.valid  := '1';  -- output pending data
            
            if r.mem_cnt >= v_mem_high_adrs then 
              v.mem_cnt := v_mem_low_adrs;
            else
              v.mem_cnt := r.mem_cnt + 1;
            end if; 
            
            if v.eop = '1' and r.blk_en = '0' then
              v.state := s_idle;          -- accept disable after eop, not during block
            end if;
            if r.eop = '1' then
              v.blk_xon := out_siso.xon;  -- accept XOFF after eop, not during block
            end if;
          
          end if;  -- out_siso.ready='1'

        when s_gap => 
          if r.samples_cnt >= v_gapsize-1 and r.blocks_cnt >= v_blocks_per_sync-1 then 
            v.ctrl_reg    := ctrl;      -- accept new control settings at end of gap
            v.samples_cnt := 0; 
            v.blocks_cnt  := 0;
            v.rd_ena      := '1';
            v.state       := s_block;
          elsif r.samples_cnt >= v_gapsize-1 then 
            v.ctrl_reg    := ctrl;      -- accept new control settings at end of gap
            v.samples_cnt := 0;             
            v.blocks_cnt  := r.blocks_cnt + 1;
            v.rd_ena      := '1';
            v.state       := s_block;
          else 
            v.samples_cnt := r.samples_cnt + 1;
          end if; 
          
          if r.blk_en = '0' then
            v.state := s_idle;
          end if;
          v.blk_xon := out_siso.xon;
                
        when others =>
          v.state := s_idle;

      end case;
      
      if rst = '1' then 
        v.ctrl_reg    := c_diag_block_gen_rst; 
        v.blk_en      := '0'; 
        v.blk_xon     := '0'; 
        v.blk_sync    := '0'; 
        v.pls_sync    := '0'; 
        v.valid       := '0'; 
        v.sop         := '0'; 
        v.eop         := '0'; 
        v.rd_ena      := '0';
        v.samples_cnt := 0; 
        v.blocks_cnt  := 0; 
        v.bsn_cnt     := (others=>'0');
        v.mem_cnt     := 0; 
        v.state       := s_idle; 
      end if;

      rin <= v;  
           
    end process;
    
    p_regs : process(rst, clk)
    begin
      if rising_edge(clk) then 
        r <= rin;
      end if; 
    end process;
    
    -- Connect to the outside world
    out_sosi_i.sop   <= r.sop      and r.blk_xon;
    out_sosi_i.eop   <= r.eop      and r.blk_xon;
    out_sosi_i.sync  <= r.pls_sync and r.blk_xon when g_blk_sync=false else r.blk_sync and r.blk_xon;
    out_sosi_i.valid <= r.valid    and r.blk_xon;
    out_sosi_i.bsn   <= r.bsn_cnt;
    out_sosi_i.re    <= RESIZE_DP_DSP_DATA(buf_rddat(g_buf_dat_w/2-1 downto 0));               -- treat as signed
    out_sosi_i.im    <= RESIZE_DP_DSP_DATA(buf_rddat(g_buf_dat_w-1   downto g_buf_dat_w/2));   -- treat as signed
    out_sosi_i.data  <= RESIZE_DP_DATA(    buf_rddat(g_buf_dat_w-1   downto 0));               -- treat as unsigned
    
    out_sosi <= out_sosi_i;
    buf_addr <= TO_UVEC(r.mem_cnt, g_buf_addr_w);
    buf_rden <= r.rd_ena;
 
end rtl;
