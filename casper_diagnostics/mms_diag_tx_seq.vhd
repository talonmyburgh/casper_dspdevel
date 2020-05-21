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

-- Purpose: Provide MM access via slave register to diag_tx_seq
-- Description:
--
--   Each DP stream has its own diag_tx_seq, because each stream can have its
--   own flow control. Each DP stream also has its own MM control register to
--   support reading tx_cnt per stream.
--
--   31             24 23             16 15              8 7               0  wi
--  |-----------------|-----------------|-----------------|-----------------|
--  |                          diag_dc = [2], diag_sel = [1], diag_en = [0] |  0  RW
--  |-----------------------------------------------------------------------|
--  |                              diag_init[31:0]                          |  1  RW
--  |-----------------------------------------------------------------------|
--  |                                 tx_cnt[31:0]                          |  2  RO
--  |-----------------------------------------------------------------------|
--  |                               diag_mod[31:0]                          |  3  RW
--  |-----------------------------------------------------------------------|
--
-- . g_use_usr_input
--   When diag_en='0' then the usr_sosi_arr input is passed on.
--   When diag_en='1' then the the tx_seq data overrules the usr_sosi_arr. Dependent on g_use_usr_input
--   the overule differs:
--   
--   1) When g_use_usr_input=TRUE then usr_sosi_arr().valid sets the pace else
--   2) when g_use_usr_input=FALSE then tx_src_in_arr().ready sets the pace of the valid output data.
--
--   This scheme allows filling user data with Tx seq data using the user valid or to completely
--   overrule the user by deriving the Tx seq valid directly from the ready.
--
--   g_use_usr_input=FALSE :
--
--                          g_nof_streams
--                          c_latency=1
--                               .
--                               .
--    usr_snk_out_arr <-------------------/------------------------------ tx_src_in_arr
--    usr_snk_in_arr  --------------------|---------------->|\
--                               .        |                 |0|
--                            ______      |                 | |---------> tx_src_out_arr
--                           |      |     |.ready           | |   
--                           |diag  |<----/                 |1|   
--                           |tx_seq|---------------------->|/    
--                           |______|    .                   |
--                            __|___     .                   |
--                           |u_reg |   tx_seq_src_in_arr    |
--                           |______|   tx_seq_src_out_arr   |
--                            __|___                         |
--                           | mux  |                     diag_en_arr
--                           |______|
--                              |
--                 MM =================
--
--
--   g_use_usr_input=TRUE :
--                           g_nof_streams
--                           c_latency=0
--                               .
--                               .                                     ____
--    usr_snk_out_arr ------------------------------------------------|    |<-- tx_src_in_arr
--    usr_snk_in_arr  -----------------------\------------>|\         |dp  |
--                               .           |             |0|        |pipe|
--                            ______   valid |             | |------->|line|--> tx_src_out_arr
--                           |diag  |<-------/             |1|   .    |arr |
--                           |tx_seq|--------------------->|/    .    |____|
--                           |______|    .                  |    .
--                            __|___     .                  |   mux_seq_src_in_arr
--                           |u_reg |   tx_seq_src_in_arr   |   mux_seq_src_out_arr
--                           |______|   tx_seq_src_out_arr  |
--                            __|___                        |
--                           | mux  |                    diag_en_arr
--                           |______|
--                              |
--                 MM =================
--
--
-- . g_nof_streams
--   The MM control register for stream I in 0:g_nof_streams-1 starts at word
--   index wi = I * 2**c_mm_reg.adr_w.
--
-- . g_mm_broadcast
--   Use default g_mm_broadcast=FALSE for multiplexed individual MM access to
--   each reg_mosi_arr/reg_miso_arr MM port. When g_mm_broadcast=TRUE then a
--   write access to MM port [0] is passed on to all ports and a read access
--   is done from MM port [0]. The other MM array ports cannot be read then.
--
-- . g_seq_dat_w
--   The g_seq_dat_w must be >= 1. The DP streaming data field is
--   c_dp_stream_data_w bits wide and the REPLICATE_DP_DATA() is used to wire
--   the g_seq_dat_w from the u_diag_tx_seq to fill the entire DP data width.
--   The maximum g_seq_dat_w depends on the pseudo random data width of the
--   LFSR sequeces in common_lfsr_sequences_pkg and on whether timing closure
--   can still be achieved for wider g_seq_dat_w. Thanks to the replication a
--   smaller g_seq_dat_w can be used to provide CNTR or LFSR data for the DP
--   data.
--
-- . diag_en
--     '0' = init and disable output sequence
--     '1' = enable output sequence
--
-- . diag_sel
--     '0' = generate PSRG data
--     '1' = generate CNTR data
--
-- . diag_dc
--     '0' = Output sequence data (as selected by diag_sel)
--     '1' = Output constant data (value as set by diag_init)
--
-- . diag_init
--   Note that MM diag_init has c_word_w=32 bits, so if g_seq_dat_w is wider
--   then the MSbits are 0 and if it is smaller, then the MSbits are ignored.
--
-- . tx_cnt
--   Counts the number of valid output data that was transmitted on stream 0
--   since diag_en went active. An incrementing tx_cnt shows that data is
--   being transmitted.
--
-- . diag_mod
--    CNTR counts modulo diag_mod, so diag_mod becomes 0. Use diag_mod = 0
--    for default binary wrap at 2**g_seq_dat_w. For diag_rx_seq choose
--    diag_step = 2**g_seq_dat_w - diag_mod + g_cnt_incr to verify ok as 
--    simulated with tb_tb_diag_rx_seq. In this mms_diag_tx_seq g_cnt_incr=1
--    fixed for diag_tx_seq.
--    The default diag_mod=0 is equivalent to diag_mod=2**g_seq_dat_w.
--    Using diag_mod < 2**g_seq_dat_w can be useful to generate tx seq CNTR
--    data that is written to a memory that is larger than 2**g_seq_dat_w
--    addresses. The CNTR values then differ from the memory address values,
--    which can be useful to ensure that reading e.g. address 2**g_seq_dat_w
--    yields a different CNTR value than reading 2**(g_seq_dat_w+1).


LIBRARY IEEE, common_pkg_lib, dp_pkg_lib, casper_pipeline_lib, casper_ram_lib, casper_mm_lib;  -- init value for out_dat when diag_en = '0'
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE casper_mm_lib.common_field_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;
USE work.diag_pkg.ALL;

ENTITY mms_diag_tx_seq IS
  GENERIC (
    g_use_usr_input : BOOLEAN := FALSE;
    g_mm_broadcast  : BOOLEAN := FALSE;
    g_nof_streams   : NATURAL := 1;
    g_seq_dat_w     : NATURAL := c_word_w  -- >= 1, test sequence data width
  );
  PORT (
    -- Clocks and reset
    mm_rst          : IN  STD_LOGIC;  -- reset synchronous with mm_clk
    mm_clk          : IN  STD_LOGIC;  -- MM bus clock
    dp_rst          : IN  STD_LOGIC;  -- reset synchronous with dp_clk
    dp_clk          : IN  STD_LOGIC;  -- DP streaming bus clock

    -- MM interface
    reg_mosi        : IN  t_mem_mosi;   -- single MM control register applied to all g_nof_streams
    reg_miso        : OUT t_mem_miso;

    -- DP streaming interface
    usr_snk_out_arr : OUT t_dp_siso_arr(g_nof_streams-1 DOWNTO 0);
    usr_snk_in_arr  : IN  t_dp_sosi_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>c_dp_sosi_rst);
    tx_src_out_arr  : OUT t_dp_sosi_arr(g_nof_streams-1 DOWNTO 0);
    tx_src_in_arr   : IN  t_dp_siso_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>c_dp_siso_rdy)   -- Default xon='1';
  );
END mms_diag_tx_seq;


ARCHITECTURE str OF mms_diag_tx_seq IS

  -- Define MM slave register size
  CONSTANT c_mm_reg      : t_c_mem  := (latency  => 1,
                                        adr_w    => c_diag_seq_tx_reg_adr_w,
                                        dat_w    => c_word_w,                   -- Use MM bus data width = c_word_w = 32 for all MM registers
                                        nof_dat  => c_diag_seq_tx_reg_nof_dat,
                                        init_sl  => '0');

  -- Define MM slave register fields for Python peripheral using pi_common.py (specify MM register access per word, not per individual bit because mm_fields assumes 1 field per MM word)
  CONSTANT c_mm_reg_field_arr : t_common_field_arr(c_mm_reg.nof_dat-1 DOWNTO 0) := ( ( field_name_pad("modulo"),  "RW", c_word_w, field_default(0) ),
                                                                                     ( field_name_pad("tx_cnt"),  "RO", c_word_w, field_default(0) ),
                                                                                     ( field_name_pad("init"),    "RW", c_word_w, field_default(0) ),
                                                                                     ( field_name_pad("control"), "RW",        3, field_default(0) ));  -- control[2:0] = diag_dc & diag_sel & diag_en
  
  CONSTANT c_reg_slv_w   : NATURAL := c_mm_reg.nof_dat*c_mm_reg.dat_w;

  CONSTANT c_latency     : NATURAL := sel_a_b(g_use_usr_input, 0, 1);  -- default 1 for registered diag_tx_seq out_cnt/dat/val output, use 0 for immediate combinatorial diag_tx_seq out_cnt/dat/val output

  TYPE t_reg_slv_arr IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_reg_slv_w-1 DOWNTO 0);
  TYPE t_seq_dat_arr IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(g_seq_dat_w-1 DOWNTO 0);
  TYPE t_replicate_arr IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_dp_stream_data_w-1 DOWNTO 0);

  SIGNAL reg_mosi_arr          : t_mem_mosi_arr(g_nof_streams-1 DOWNTO 0);
  SIGNAL reg_miso_arr          : t_mem_miso_arr(g_nof_streams-1 DOWNTO 0);

  -- Registers in dp_clk domain
  SIGNAL ctrl_reg_arr          : t_reg_slv_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>(OTHERS=>'0'));
  SIGNAL stat_reg_arr          : t_reg_slv_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>(OTHERS=>'0'));

  SIGNAL diag_en_arr           : STD_LOGIC_VECTOR(g_nof_streams-1 DOWNTO 0);
  SIGNAL diag_sel_arr          : STD_LOGIC_VECTOR(g_nof_streams-1 DOWNTO 0);
  SIGNAL diag_dc_arr           : STD_LOGIC_VECTOR(g_nof_streams-1 DOWNTO 0);

  SIGNAL diag_init_mm_arr      : t_slv_32_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>(OTHERS=>'0'));  -- can use t_slv_32_arr because c_mm_reg.dat_w = c_word_w = 32 fixed
  SIGNAL diag_init_arr         : t_seq_dat_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>(OTHERS=>'0'));

  SIGNAL diag_mod_mm_arr       : t_slv_32_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>(OTHERS=>'0'));  -- can use t_slv_32_arr because c  -- init value for out_dat when diag_en = '0'_mm_reg.dat_w = c_word_w = 32 fixed
  SIGNAL diag_mod_arr          : t_seq_dat_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>(OTHERS=>'0'));
  
  SIGNAL tx_cnt_arr            : t_slv_32_arr(g_nof_streams-1 DOWNTO 0);  -- can use t_slv_32_arr because c_mm_reg.dat_w = c_word_w = 32 fixed
  SIGNAL tx_dat_arr            : t_seq_dat_arr(g_nof_streams-1 DOWNTO 0);
  SIGNAL tx_val_arr            : STD_LOGIC_VECTOR(g_nof_streams-1 DOWNTO 0);
  SIGNAL tx_req_arr            : STD_LOGIC_VECTOR(g_nof_streams-1 DOWNTO 0);

  SIGNAL tx_replicate_dat_arr  : t_dp_data_slv_arr(g_nof_streams-1 DOWNTO 0);

  SIGNAL tx_seq_src_in_arr     : t_dp_siso_arr(g_nof_streams-1 DOWNTO 0);
  SIGNAL tx_seq_src_out_arr    : t_dp_sosi_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>c_dp_sosi_rst);  -- default set all other fields then data and valid to inactive.

  -- Use user input or self generate
  SIGNAL mux_seq_src_in_arr    : t_dp_siso_arr(g_nof_streams-1 DOWNTO 0);  -- multiplex user sosi control with tx_seq data
  SIGNAL mux_seq_src_out_arr   : t_dp_sosi_arr(g_nof_streams-1 DOWNTO 0);

BEGIN

  gen_nof_streams: FOR I IN 0 to g_nof_streams-1 GENERATE
    u_diag_tx_seq: ENTITY WORK.diag_tx_seq
    GENERIC MAP (
      g_latency  => c_latency,
      g_cnt_w    => c_word_w,
      g_dat_w    => g_seq_dat_w
    )
    PORT MAP (
      rst       => dp_rst,
      clk       => dp_clk,

      -- Write and read back registers:
      diag_en   => diag_en_arr(I),
      diag_sel  => diag_sel_arr(I),
      diag_dc   => diag_dc_arr(I),
      diag_init => diag_init_arr(I),
      diag_mod  => diag_mod_arr(I),

      -- Streaming
      diag_req  => tx_req_arr(I),
      out_cnt   => tx_cnt_arr(I),
      out_dat   => tx_dat_arr(I),
      out_val   => tx_val_arr(I)
    );

    tx_req_arr(I) <= tx_seq_src_in_arr(I).ready;

    tx_replicate_dat_arr(I) <= REPLICATE_DP_DATA(tx_dat_arr(I));

    -- for some reason the intermediate tx_replicate_dat_arr() signal is needed, otherwise the assignment to the tx_seq_src_out_arr().data field remains void in the Wave window
    tx_seq_src_out_arr(I).data  <= tx_replicate_dat_arr(I);
    tx_seq_src_out_arr(I).valid <= tx_val_arr(I);

    -- Register mapping
    diag_en_arr(I)      <= ctrl_reg_arr(I)(                             0);  -- address 0, data bit [0]
    diag_sel_arr(I)     <= ctrl_reg_arr(I)(                             1);  -- address 0, data bit [1]
    diag_dc_arr(I)      <= ctrl_reg_arr(I)(                             2);  -- address 0, data bit [2]
    diag_init_mm_arr(I) <= ctrl_reg_arr(I)(2*c_word_w-1 DOWNTO   c_word_w);  -- address 1, data bits [31:0]
    diag_mod_mm_arr(I)  <= ctrl_reg_arr(I)(4*c_word_w-1 DOWNTO 3*c_word_w);  -- address 3, data bits [31:0]

    diag_init_arr(I) <= RESIZE_UVEC(diag_init_mm_arr(I), g_seq_dat_w);
    diag_mod_arr(I)  <= RESIZE_UVEC(diag_mod_mm_arr(I), g_seq_dat_w);

    p_stat_reg : PROCESS(ctrl_reg_arr(I), tx_cnt_arr)
    BEGIN
      -- Default write / readback:
      stat_reg_arr(I) <= ctrl_reg_arr(I);                                 -- address 0, 1: control read back
      -- Status read only:
      stat_reg_arr(I)(3*c_word_w-1 DOWNTO 2*c_word_w) <= tx_cnt_arr(I);   -- address 2: read tx_cnt
    END PROCESS;

    u_reg : ENTITY casper_mm_lib.common_reg_r_w_dc
    GENERIC MAP (
      g_cross_clock_domain => TRUE,
      g_readback           => FALSE,  -- must use FALSE for write/read or read only register when g_cross_clock_domain=TRUE
      g_reg                => c_mm_reg
    )
    PORT MAP (
      -- Clocks and reset
      mm_rst      => mm_rst,
      mm_clk      => mm_clk,
      st_rst      => dp_rst,
      st_clk      => dp_clk,

      -- Memory Mapped Slave in mm_clk domain
      sla_in      => reg_mosi_arr(I),
      sla_out     => reg_miso_arr(I),

      -- MM registers in dp_clk domain
      in_reg      => stat_reg_arr(I),  -- connect out_reg to in_reg for write and readback register
      out_reg     => ctrl_reg_arr(I)
    );
  END GENERATE;

  -- Combine the internal array of mm interfaces for the bg_data to one array that is connected to the port of the MM bus
  u_mem_mux : ENTITY casper_mm_lib.common_mem_mux
  GENERIC MAP (
    g_broadcast   => g_mm_broadcast,
    g_nof_mosi    => g_nof_streams,
    g_mult_addr_w => c_mm_reg.adr_w
  )
  PORT MAP (
    mosi     => reg_mosi,
    miso     => reg_miso,
    mosi_arr => reg_mosi_arr,
    miso_arr => reg_miso_arr
  );

  ignore_usr_input : IF g_use_usr_input=FALSE GENERATE
    -- flow control
    usr_snk_out_arr   <= tx_src_in_arr;
    tx_seq_src_in_arr <= tx_src_in_arr;
    
    -- data
    p_tx_src_out_arr : PROCESS (usr_snk_in_arr, tx_seq_src_out_arr, diag_en_arr)
    BEGIN
      tx_src_out_arr <= usr_snk_in_arr;                -- Default pass on the usr data
      FOR I IN 0 TO g_nof_streams-1 LOOP
        IF diag_en_arr(I)='1' THEN
          tx_src_out_arr(I) <= tx_seq_src_out_arr(I);  -- When diag is enabled then pass on the Tx seq data
        END IF;
      END LOOP;
    END PROCESS;
  END GENERATE;

  use_usr_input : IF g_use_usr_input=TRUE GENERATE
    -- Request tx_seq data at user data valid rate
    p_tx_seq_src_in_arr : PROCESS(usr_snk_in_arr)
    BEGIN
      FOR I IN 0 TO g_nof_streams-1 LOOP
        tx_seq_src_in_arr(I).ready <= usr_snk_in_arr(I).valid;
      END LOOP;
    END PROCESS;

    -- Default output the user input or BG data, else when tx_seq is enabled overrule output with tx_seq data
    usr_snk_out_arr <= mux_seq_src_in_arr;

    p_mux_seq_src_out_arr : PROCESS (usr_snk_in_arr, tx_seq_src_out_arr, diag_en_arr)
    BEGIN
      mux_seq_src_out_arr <= usr_snk_in_arr;
      FOR I IN 0 TO g_nof_streams-1 LOOP
        IF diag_en_arr(I)='1' THEN
          mux_seq_src_out_arr(I).data <= tx_seq_src_out_arr(I).data;
        END IF;
      END LOOP;
    END PROCESS;

    -- Pipeline the streams by 1 to register the mux_seq_src_out_arr data to ease timing closure given that c_tx_seq_latency=0
    u_dp_pipeline_arr : ENTITY casper_pipeline_lib.dp_pipeline_arr
    GENERIC MAP (
      g_nof_streams => g_nof_streams
    )
    PORT MAP (
      rst          => dp_rst,
      clk          => dp_clk,
      -- ST sink
      snk_out_arr  => mux_seq_src_in_arr,
      snk_in_arr   => mux_seq_src_out_arr,
      -- ST source
      src_in_arr   => tx_src_in_arr,
      src_out_arr  => tx_src_out_arr
    );
  END GENERATE;

END str;













