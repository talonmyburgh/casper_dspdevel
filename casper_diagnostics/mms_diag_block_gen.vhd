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

-- Purpose: Block generator for multiple parallel SOSI streams
-- Description:
-- . The mms_diag_block_gen provides a MM slave interface to an array of
--   g_nof_streams diag_block_gen instances.
-- . The waveform data is stored in RAM and can be pre-load with data from a
--   file g_file_name_prefix. The stream index to the select the actual file
--   is default I, but can be set via g_file_index_arr(I). The g_file_index_arr
--   makes the relation between the instance index and file index flexible.

-- . g_use_usr_input and g_use_bg
--   When g_use_usr_input=FALSE the BG works standalone.
--   When g_use_bg=FALSE then only the user input is used.
--   When both g_use_usr_input=TRUE and g_use_bg=TRUE then default the user
--   input is passed on when the BG is disabled. The dynamic selection between
--   user input an BG output is done between blocks by the dp_mux using xon.
--
-- . g_use_bg_buffer_ram
--   When g_use_bg_buffer_ram=TRUE then each stream has a BG buffer RAM that
--   can be accessed via the ram_bg_data MM port. Else when
--   g_use_bg_buffer_ram= FALSE then the RAM is not implemented (to save
--   RAM resources) and instead the RAM read address is used as data in the
--   generated data block. Hence the data will then depend on mem_low_adrs,
--   mem_high_adrs and samples_per_packet, so typically it will output the
--   counter data (0:samples_per_packet-1) and the samedata foreach block.
--
-- . g_use_tx_seq
--   When g_use_tx_seq=TRUE then the diag_mms_tx_seq is instantiated. If the
--   tx_seq is enabled then the data field is overwitten with tx seq counter
--   or pseudo random data. The tx seq uses the valid as request for tx seq
--   data, so it preserves the output valid, sop, eop framing. For more info
--   on the tx_seq see mms_diag_tx_seq. If g_use_usr_input=FALSE and g_use_bg
--   =FALSE and g_use_tx_seq=TRUE then only the tx_seq is instantiated and
--   without input (c_use_tx_seq_input).
--
-- Block diagram:
--
--         g_use_bg
--         g_use_bg_buffer_ram
--          .
--          .  g_use_usr_input                     g_use_tx_seq
--          .   .     g_usr_bypass_xonoff               .
--          .   .      .                                .
--          .   .      .                                .
--          .   .      .                                .
--          .   .      ___     __ dp_mux                .
--          .   .     |dp |   |  \                      .
--          .  usr----|xon|-->|0  \                     .
--          .         |off|   |    \                    .
--          .         |___|   |     |----------------->|\ 
--          .                 |    /    |              | |---> out
--         BG ctrl----------->|1  /     \--> TX seq -->|/
--         BG data            |__/             |
--            ||                               |
--            ||                               |
--     MM ====================================================
--    
--   The dp_mux is only there if both the usr input and the BG are used.
--
-- Remark:
-- . The diag_block_gen does not support back pressure, but it does support
--   XON/XOFF flow control at block level via out_siso.xon.
-- . Default input *_mosi = c_mem_mosi_rst to support using the BG with default
--   control and memory settings and no MM interface
-- . The BG does support xon flow control.
-- . If the user input already supports xon then g_usr_bypass_xonoff can be
--   set to TRUE. However if g_usr_bypass_xonoff=FALSE then this is fine to
--   because an extra dp_xonoff stage merely causes the stream to resume one
--   block later when xon goes active (see test bench tb_dp_xonoff). The
--   diag_block_gen BG does already support xon.
-- . A nice new feature would be to support BG data width > 32b, similar as in
--   the DB mms_diag_data_buffer.vhd.
-- . A nice new feature would be to support a BG burst of N blocks.


LIBRARY IEEE, common_pkg_lib, casper_ram_lib, dp_pkg_lib, dp_components_lib, casper_multiplexer_lib, casper_mm_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL; 
USE work.diag_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

ENTITY mms_diag_block_gen IS
  GENERIC (
    g_technology         : NATURAL := 0;
    -- Generate configurations
    g_use_usr_input      : BOOLEAN := FALSE;
    g_use_bg             : BOOLEAN := TRUE;
    g_use_tx_seq         : BOOLEAN := FALSE;
    -- General
    g_nof_streams        : POSITIVE := 1;
    -- BG settings
    g_use_bg_buffer_ram  : BOOLEAN := TRUE;
    g_buf_dat_w          : POSITIVE := 32; 
    g_buf_addr_w         : POSITIVE := 7;                -- Waveform buffer size 2**g_buf_addr_w nof samples
    g_file_index_arr     : t_nat_natural_arr := array_init(0, 128, 1);  -- default use the instance index as file index 0, 1, 2, 3, 4 ...
    g_file_name_prefix   : STRING := "data/bf_in_data";  -- Path to the hex files that contain the initial data for the memories. The sequence number and ".hex" are added within the entity.
    g_diag_block_gen_rst : t_diag_block_gen := c_diag_block_gen_rst;
    -- User input multiplexer option
    g_usr_bypass_xonoff  : BOOLEAN := FALSE;
    -- Tx_seq
    g_seq_dat_w          : NATURAL := 32;  -- >= 1, test sequence data width. Choose g_seq_dat_w <= g_buf_dat_w
    -- LOFAR Lofar style block sync that is active from SOP to EOP
    g_blk_sync           : BOOLEAN := FALSE
  );
  PORT (
    -- System
    mm_rst           : IN  STD_LOGIC;                     -- reset synchronous with mm_clk
    mm_clk           : IN  STD_LOGIC;                     -- memory-mapped bus clock
    dp_rst           : IN  STD_LOGIC;                     -- reset synchronous with st_clk
    dp_clk           : IN  STD_LOGIC;                     -- streaming clock domain clock
    en_sync          : IN  STD_LOGIC := '1';              -- block generator enable sync pulse in ST dp_clk domain
    -- MM interface
    reg_bg_ctrl_mosi : IN  t_mem_mosi := c_mem_mosi_rst;  -- BG control register (one for all streams)
    reg_bg_ctrl_miso : OUT t_mem_miso;
    ram_bg_data_mosi : IN  t_mem_mosi := c_mem_mosi_rst;  -- BG buffer RAM (one per stream)
    ram_bg_data_miso : OUT t_mem_miso;
    reg_tx_seq_mosi  : IN  t_mem_mosi := c_mem_mosi_rst;  -- Tx seq control (one per stream because c_reg_tx_seq_broadcast=FALSE)
    reg_tx_seq_miso  : OUT t_mem_miso;
    -- ST interface
    usr_siso_arr     : OUT t_dp_siso_arr(g_nof_streams-1 DOWNTO 0);  -- connect when g_use_usr_input=TRUE, else leave not connected 
    usr_sosi_arr     : IN  t_dp_sosi_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>c_dp_sosi_rst);
    out_siso_arr     : IN  t_dp_siso_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>c_dp_siso_rdy);  -- Default xon='1'
    out_sosi_arr     : OUT t_dp_sosi_arr(g_nof_streams-1 DOWNTO 0)  -- Output SOSI that contains the waveform data
  );
END mms_diag_block_gen;

ARCHITECTURE rtl OF mms_diag_block_gen IS

  CONSTANT c_buf                  : t_c_mem  := (latency  => 1,
                                                 adr_w    => g_buf_addr_w,
                                                 dat_w    => g_buf_dat_w,
                                                 nof_dat  => 2**g_buf_addr_w,
                                                 init_sl  => '0');   
                                             
  CONSTANT c_post_buf_file        : STRING := ".hex";
  
  CONSTANT c_use_mux              : BOOLEAN := g_use_usr_input AND g_use_bg;
  CONSTANT c_use_tx_seq_input     : BOOLEAN := g_use_usr_input OR g_use_bg;
  CONSTANT c_mux_nof_input        : NATURAL := 2;   -- fixed
  
  CONSTANT c_reg_tx_seq_broadcast : BOOLEAN := FALSE;  -- fixed use dedicated MM register per stream

  TYPE t_buf_dat_arr IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(g_buf_dat_w -1 DOWNTO 0);
  TYPE t_buf_adr_arr IS ARRAY (NATURAL RANGE <>) OF STD_LOGIC_VECTOR(g_buf_addr_w-1 DOWNTO 0);

  SIGNAL st_addr_arr           : t_buf_adr_arr(g_nof_streams    -1 DOWNTO 0);
  SIGNAL st_rd_arr             : STD_LOGIC_VECTOR(g_nof_streams -1 DOWNTO 0);
  SIGNAL st_rdval_arr          : STD_LOGIC_VECTOR(g_nof_streams -1 DOWNTO 0);
  SIGNAL st_rddata_arr         : t_buf_dat_arr(g_nof_streams    -1 DOWNTO 0);
  SIGNAL ram_bg_data_mosi_arr  : t_mem_mosi_arr(g_nof_streams   -1 DOWNTO 0);
  SIGNAL ram_bg_data_miso_arr  : t_mem_miso_arr(g_nof_streams   -1 DOWNTO 0); 
  SIGNAL bg_ctrl               : t_diag_block_gen;
  
  SIGNAL mux_ctrl              : NATURAL RANGE 0 TO c_mux_nof_input-1;
  SIGNAL mux_snk_out_2arr_2    : t_dp_siso_2arr_2(g_nof_streams-1 DOWNTO 0);  -- [g_nof_streams-1:0][c_mux_nof_input-1:0] = [1:0]
  SIGNAL mux_snk_in_2arr_2     : t_dp_sosi_2arr_2(g_nof_streams-1 DOWNTO 0);  -- [g_nof_streams-1:0][c_mux_nof_input-1:0] = [1:0]

  SIGNAL usr_xflow_src_in_arr  : t_dp_siso_arr(g_nof_streams-1 DOWNTO 0);  -- optionally use dp_xonoff to add siso.xon flow control to use input when g_usr_bypass_xonoff=FALSE
  SIGNAL usr_xflow_src_out_arr : t_dp_sosi_arr(g_nof_streams-1 DOWNTO 0);
  
  SIGNAL bg_src_in_arr         : t_dp_siso_arr(g_nof_streams-1 DOWNTO 0);  -- BG has siso.xon flow control but no siso.ready flow control
  SIGNAL bg_src_out_arr        : t_dp_sosi_arr(g_nof_streams-1 DOWNTO 0);
  
  SIGNAL mux_src_in_arr        : t_dp_siso_arr(g_nof_streams-1 DOWNTO 0);
  SIGNAL mux_src_out_arr       : t_dp_sosi_arr(g_nof_streams-1 DOWNTO 0);
  
BEGIN
  
  -----------------------------------------------------------------------------
  -- BG
  -----------------------------------------------------------------------------
  
  no_bg : IF g_use_bg=FALSE GENERATE
    reg_bg_ctrl_miso <= c_mem_miso_rst;
    ram_bg_data_miso <= c_mem_miso_rst;
    
    bg_src_out_arr <= (OTHERS=>c_dp_sosi_rst);
  END GENERATE;
  
  gen_bg : IF g_use_bg=TRUE GENERATE
    mux_ctrl <= 0 WHEN bg_ctrl.enable='0' ELSE 1;
    
    u_bg_ctrl : ENTITY work.diag_block_gen_reg 
    GENERIC MAP(
      g_cross_clock_domain => TRUE,   -- use FALSE when mm_clk and st_clk are the same, else use TRUE to cross the clock domain
      g_diag_block_gen_rst => g_diag_block_gen_rst
    )
    PORT MAP (
      mm_rst  => mm_rst,                   -- Clocks and reset
      mm_clk  => mm_clk,
      dp_rst  => dp_rst,
      dp_clk  => dp_clk,
      mm_mosi => reg_bg_ctrl_mosi,
      mm_miso => reg_bg_ctrl_miso,
      bg_ctrl => bg_ctrl                       
    );
    
    -- Combine the internal array of mm interfaces for the bg_data to one array that is connected to the port of the MM bus
    u_mem_mux_bg_data : ENTITY casper_mm_lib.common_mem_mux
    GENERIC MAP (    
      g_nof_mosi    => g_nof_streams,
      g_mult_addr_w => g_buf_addr_w
    )
    PORT MAP (
      mosi     => ram_bg_data_mosi,
      miso     => ram_bg_data_miso,
      mosi_arr => ram_bg_data_mosi_arr,
      miso_arr => ram_bg_data_miso_arr
    );
    
    gen_streams : FOR I IN 0 TO g_nof_streams-1 GENERATE
      no_buffer_ram : IF g_use_bg_buffer_ram=FALSE GENERATE
        ram_bg_data_miso_arr(I) <= c_mem_miso_rst;
        
        -- Use read address as read data with read latency 1 similar as for u_buffer_ram
        st_rdval_arr(I)  <=             st_rd_arr(I)                 WHEN rising_edge(dp_clk);
        st_rddata_arr(I) <= RESIZE_UVEC(st_addr_arr(I), g_buf_dat_w) WHEN rising_edge(dp_clk);
      END GENERATE;
      
      gen_buffer_ram : IF g_use_bg_buffer_ram=TRUE GENERATE
        u_buffer_ram : ENTITY casper_ram_lib.common_ram_crw_crw
        GENERIC MAP (
          g_technology => g_technology,
          g_ram        => c_buf,
          -- Sequence number and ".hex" extension are added to the relative path in case a ram file is provided. 
          g_init_file  => sel_a_b(g_file_name_prefix = "UNUSED", g_file_name_prefix, g_file_name_prefix & "_" & NATURAL'IMAGE(g_file_index_arr(I)) & c_post_buf_file)    
        )
        PORT MAP (
          clk_a => mm_clk,
          
          -- Waveform side
          
          clk_b => dp_clk,
          
          -- MM side
          
          wr_en_a => ram_bg_data_mosi_arr(I).wr,
          
          wr_en_b => '0',
          
          wr_dat_a => ram_bg_data_mosi_arr(I).wrdata(c_buf.dat_w -1 DOWNTO 0),
          
          wr_dat_b => (OTHERS =>'0'),
          
          adr_a => ram_bg_data_mosi_arr(I).address(c_buf.adr_w-1 DOWNTO 0),
          
          adr_b => st_addr_arr(I),
          
          rd_en_a => ram_bg_data_mosi_arr(I).rd,
          
          rd_en_b => st_rd_arr(I),
          
          rd_dat_a => ram_bg_data_miso_arr(I).rddata(c_buf.dat_w -1 DOWNTO 0),
          
          rd_dat_b => st_rddata_arr(I),
          
          rd_val_a => ram_bg_data_miso_arr(I).rdval,
          
          rd_val_b => st_rdval_arr(I) 
        );
      END GENERATE;
      
      u_diag_block_gen : ENTITY work.diag_block_gen
      GENERIC MAP (
        g_blk_sync   => g_blk_sync,
        g_buf_dat_w  => g_buf_dat_w, 
        g_buf_addr_w => g_buf_addr_w
      )
      PORT MAP (
        rst        => dp_rst, 
        clk        => dp_clk, 
        buf_addr   => st_addr_arr(I),       
        buf_rden   => st_rd_arr(I),          
        buf_rddat  => st_rddata_arr(I),       
        buf_rdval  => st_rdval_arr(I),          
        ctrl       => bg_ctrl,
        en_sync    => en_sync,
        out_siso   => bg_src_in_arr(I),
        out_sosi   => bg_src_out_arr(I)
      );
    END GENERATE;
  END GENERATE;
          
  
  ---------------------------------------------------------------------------
  -- No multiplexer, so only one input or no input at all
  ---------------------------------------------------------------------------
  no_dp_mux : IF c_use_mux=FALSE GENERATE  -- so g_use_usr_input and g_use_bg are not both TRUE
    -- default pass on flow control
    usr_siso_arr  <= mux_src_in_arr;
    bg_src_in_arr <= mux_src_in_arr;
    
    -- User input only, BG only or no input
    mux_src_out_arr <= usr_sosi_arr             WHEN g_use_usr_input=TRUE ELSE
                       bg_src_out_arr           WHEN g_use_bg=TRUE        ELSE
                      (OTHERS=>c_dp_sosi_rst);
  END GENERATE;
  
  
  -----------------------------------------------------------------------------
  -- Multiplex user input and BG
  -----------------------------------------------------------------------------
  gen_dp_mux : IF c_use_mux=TRUE GENERATE  -- so g_use_usr_input and g_use_bg are both TRUE
    gen_streams : FOR I IN 0 TO g_nof_streams-1 GENERATE
      -- Add user xon flow control if the user input does not already support it
      u_dp_xonoff : ENTITY dp_components_lib.dp_xonoff
      GENERIC MAP (
        g_bypass => g_usr_bypass_xonoff  -- if the user input already has xon flow control then bypass using g_usr_bypass_xonoff=TRUE
      )
      PORT MAP (
        rst           => dp_rst,
        clk           => dp_clk,
        -- Frame in
        in_siso       => usr_siso_arr(I),
        in_sosi       => usr_sosi_arr(I),
        -- Frame out
        out_siso      => usr_xflow_src_in_arr(I),  -- flush control via out_siso.xon
        out_sosi      => usr_xflow_src_out_arr(I)
      );
        
      -- Multiplex the inputs:
      -- . [0] = usr input
      -- . [1] = BG
      usr_xflow_src_in_arr(I) <= mux_snk_out_2arr_2(I)(0);
      bg_src_in_arr(I)        <= mux_snk_out_2arr_2(I)(1);   
      
      mux_snk_in_2arr_2(I)(0) <= usr_xflow_src_out_arr(I);
      mux_snk_in_2arr_2(I)(1) <= bg_src_out_arr(I);
      
      u_dp_mux : ENTITY casper_multiplexer_lib.dp_mux
      GENERIC MAP (
        g_technology        => g_technology,
        -- MUX
        g_mode              => 4,                                 -- g_mode=4 for framed input select via sel_ctrl
        g_nof_input         => c_mux_nof_input,                   -- >= 1
        g_append_channel_lo => FALSE,
        g_sel_ctrl_invert   => TRUE,  -- Use default FALSE when stream array IO are indexed (0 TO g_nof_input-1), else use TRUE when indexed (g_nof_input-1 DOWNTO 0)
        -- Input FIFO
        g_use_fifo          => FALSE,
        g_fifo_size         => array_init(1024, c_mux_nof_input),  -- must match g_nof_input, even when g_use_fifo=FALSE
        g_fifo_fill         => array_init(   0, c_mux_nof_input)   -- must match g_nof_input, even when g_use_fifo=FALSE
      )
      PORT MAP (
        rst         => dp_rst,
        clk         => dp_clk,
        -- Control
        sel_ctrl    => mux_ctrl,  -- 0 = usr, 1 = BG
        -- ST sinks
        snk_out_arr => mux_snk_out_2arr_2(I),  -- [c_mux_nof_input-1:0]
        snk_in_arr  => mux_snk_in_2arr_2(I),   -- [c_mux_nof_input-1:0]
        -- ST source
        src_in      => mux_src_in_arr(I),
        src_out     => mux_src_out_arr(I)
      );
    END GENERATE;
  END GENERATE;
  
  no_tx_seq : IF g_use_tx_seq=FALSE GENERATE
    reg_tx_seq_miso <= c_mem_miso_rst;
    
    mux_src_in_arr <= out_siso_arr;
    out_sosi_arr   <= mux_src_out_arr;
  END GENERATE;
  
  gen_tx_seq : IF g_use_tx_seq=TRUE GENERATE
    u_mms_diag_tx_seq : ENTITY work.mms_diag_tx_seq
    GENERIC MAP (
      g_use_usr_input => c_use_tx_seq_input,
      g_mm_broadcast  => c_reg_tx_seq_broadcast,
      g_nof_streams   => g_nof_streams,
      g_seq_dat_w     => g_seq_dat_w
    )
    PORT MAP (
      -- Clocks and reset
      mm_rst         => mm_rst,
      mm_clk         => mm_clk,
      dp_rst         => dp_rst,
      dp_clk         => dp_clk,
  
      -- MM interface
      reg_mosi       => reg_tx_seq_mosi,
      reg_miso       => reg_tx_seq_miso,
  
      -- DP streaming interface
      usr_snk_out_arr => mux_src_in_arr,  -- connect when g_use_usr_input=TRUE, else leave not connected
      usr_snk_in_arr  => mux_src_out_arr,
      tx_src_out_arr  => out_sosi_arr,
      tx_src_in_arr   => out_siso_arr
    );
  END GENERATE;
    
END rtl;
