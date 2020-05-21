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

-- Purpose: Provide MM access via slave register to diag_rx_seq
-- Description:
--
--   Each DP stream has its own diag_rx_seq and its own MM control register.
--   The MM control registers are accessible via a single MM port thanks to
--   the common_mem_mux. Each single MM control register is defined as:
--
--   31             24 23             16 15              8 7               0  wi
--  |-----------------|-----------------|-----------------|-----------------|
--  |                                         diag_sel = [1], diag_en = [0] |  0  RW
--  |-----------------------------------------------------------------------|
--  |                                       res_val_n = [1], res_ok_n = [0] |  1  RO
--  |-----------------------------------------------------------------------|
--  |                                      rx_cnt[31:0]                     |  2  RO
--  |-----------------------------------------------------------------------|
--  |                              rx_sample[g_seq_dat_w-1:0]               |  3  RO
--  |-----------------------------------------------------------------------|
--  |                      diag_steps_arr[0][g_seq_dat_w-1:0]               |  4  RW
--  |-----------------------------------------------------------------------|
--  |                      diag_steps_arr[1][g_seq_dat_w-1:0]               |  5  RW
--  |-----------------------------------------------------------------------|
--  |                      diag_steps_arr[2][g_seq_dat_w-1:0]               |  6  RW
--  |-----------------------------------------------------------------------|
--  |                      diag_steps_arr[3][g_seq_dat_w-1:0]               |  7  RW
--  |-----------------------------------------------------------------------|
--
-- . g_nof_streams
--   The MM control register for stream I in 0:g_nof_streams-1 starts at word
--   index wi = I * 2**c_mm_reg.adr_w.
--
-- . diag_en
--     '0' = stop and reset input sequence verification
--     '1' = enable input sequence verification
--   
-- . diag_sel
--     '0' = verify PSRG data
--     '1' = verify CNTR data
--
-- . Results
--   When res_val_n = '1' then no valid data is being received. When
--   res_val_n = '0' then at least two valid data have been received so the
--   diag_rx_seq can detect whether the subsequent data is ok. When res_ok_n
--   = '0' then indeed all data that has been received so far is correct.
--   When res_ok_n = '1' then at least 1 data word was received with errors.
--   Once res_ok_n goes high it remains high.
--
-- . g_data_w and g_seq_dat_w
--   The DP streaming data field is c_dp_stream_data_w bits wide but only
--   g_data_w bits are used. The g_seq_dat_w must be >= 1 and <= g_data_w.
--   If g_seq_dat_w < g_data_w then the data carries replicated copies of 
--   the g_seq_dat_w. The maximum g_seq_dat_w depends on the pseudo random
--   data width of the LFSR sequeces in common_lfsr_sequences_pkg and on
--   whether timing closure can still be achieved for wider g_seq_dat_w.
--   Thanks to the replication a smaller g_seq_dat_w can be used to provide
--   CNTR or LFSR data for the DP data. If the higher bits do notmatch the 
--   sequence in the lower bits, then the rx data is forced to -1, and that
--   will then be detected and reported by u_diag_rx_seq as a sequence error.
--
-- . rx_cnt
--   Counts the number of valid input data that was received since diag_en
--   went active. An incrementing rx_cnt shows that data is being received.
--
-- . rx_sample
--   The rx_sample keeps the last valid in_dat value. When diag_en='0' it is
--   reset to 0. Reading rx_sample via MM gives an impression of the valid
--   in_dat activity.
--
-- . g_use_steps
--   When g_use_steps=FALSE then diag_sel selects whether PSRG or COUNTER
--   data with increment +1 is used to verify the input data.
--   When g_use_steps=TRUE then the g_nof_steps = 
--   c_diag_seq_rx_reg_nof_steps = 4 MM step registers define the allowed
--   COUNTER increment values.

LIBRARY IEEE, common_pkg_lib, dp_pkg_lib, casper_mm_lib, casper_ram_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE casper_mm_lib.common_field_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;
USE work.diag_pkg.ALL;

ENTITY mms_diag_rx_seq IS
  GENERIC (
    g_nof_streams : NATURAL := 1;
    g_use_steps   : BOOLEAN := FALSE;
    g_nof_steps   : NATURAL := c_diag_seq_rx_reg_nof_steps;
    g_seq_dat_w   : NATURAL := c_word_w;  -- >= 1, test sequence data width
    g_data_w      : NATURAL := c_word_w   -- >= g_seq_dat_w, user data width
  );
  PORT (
    -- Clocks and reset
    mm_rst         : IN  STD_LOGIC;  -- reset synchronous with mm_clk
    mm_clk         : IN  STD_LOGIC;  -- MM bus clock
    dp_rst         : IN  STD_LOGIC;  -- reset synchronous with dp_clk
    dp_clk         : IN  STD_LOGIC;  -- DP streaming bus clock

    -- Memory Mapped Slave
    reg_mosi       : IN  t_mem_mosi;   -- multiplexed port for g_nof_streams MM control/status registers
    reg_miso       : OUT t_mem_miso;

    -- Streaming interface
    rx_snk_in_arr  : IN t_dp_sosi_arr(g_nof_streams-1 DOWNTO 0)
  );
END mms_diag_rx_seq;


ARCHITECTURE str OF mms_diag_rx_seq IS

  -- Define MM slave register size
  CONSTANT c_mm_reg      : t_c_mem  := (latency  => 1,
                                        adr_w    => c_diag_seq_rx_reg_adr_w,
                                        dat_w    => c_word_w,                   -- Use MM bus data width = c_word_w = 32 for all MM registers
                                        nof_dat  => c_diag_seq_rx_reg_nof_dat,
                                        init_sl  => '0');
  
  -- Define MM slave register fields for Python peripheral using pi_common.py (specify MM register access per word, not per individual bit because mm_fields assumes 1 field per MM word)
  CONSTANT c_mm_reg_field_arr : t_common_field_arr(c_mm_reg.nof_dat-1 DOWNTO 0) := ( ( field_name_pad("step_3"),    "RW", c_word_w, field_default(0) ),   -- [7] = diag_steps_arr[3], c_diag_seq_rx_reg_nof_steps = 4
                                                                                     ( field_name_pad("step_2"),    "RW", c_word_w, field_default(0) ),   -- [6] = diag_steps_arr[2]
                                                                                     ( field_name_pad("step_1"),    "RW", c_word_w, field_default(0) ),   -- [5] = diag_steps_arr[1]
                                                                                     ( field_name_pad("step_0"),    "RW", c_word_w, field_default(0) ),   -- [4] = diag_steps_arr[0]
                                                                                     ( field_name_pad("rx_sample"), "RO", c_word_w, field_default(0) ),   -- [3]
                                                                                     ( field_name_pad("rx_cnt"),    "RO", c_word_w, field_default(0) ),   -- [2]
                                                                                     ( field_name_pad("result"),    "RO",        2, field_default(0) ),   -- [1] = result[1:0]  = res_val_n & res_ok_n
                                                                                     ( field_name_pad("control"),   "RW",        2, field_default(0) ));  -- [0] = control[1:0] = diag_sel & diag_en
                                  
  CONSTANT c_reg_slv_w   : NATURAL := c_mm_reg.nof_dat*c_mm_reg.dat_w;
  CONSTANT c_reg_dat_w   : NATURAL := smallest(c_word_w, g_seq_dat_w);
  
  CONSTANT c_nof_steps_wi     : NATURAL := c_diag_seq_rx_reg_nof_steps_wi;
  
  TYPE t_reg_slv_arr IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_reg_slv_w-1 DOWNTO 0);
  TYPE t_seq_dat_arr IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(g_seq_dat_w-1 DOWNTO 0);
  TYPE t_data_arr    IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(g_data_w-1 DOWNTO 0);
  TYPE t_steps_2arr  IS ARRAY (INTEGER RANGE <>) OF t_integer_arr(g_nof_steps-1 DOWNTO 0);
  
  SIGNAL reg_mosi_arr        : t_mem_mosi_arr(g_nof_streams-1 DOWNTO 0);
  SIGNAL reg_miso_arr        : t_mem_miso_arr(g_nof_streams-1 DOWNTO 0);
    
  -- Registers in dp_clk domain
  SIGNAL ctrl_reg_arr        : t_reg_slv_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>(OTHERS=>'0'));
  SIGNAL stat_reg_arr        : t_reg_slv_arr(g_nof_streams-1 DOWNTO 0) := (OTHERS=>(OTHERS=>'0'));
  
  SIGNAL diag_en_arr         : STD_LOGIC_VECTOR(g_nof_streams-1 DOWNTO 0);
  SIGNAL diag_sel_arr        : STD_LOGIC_VECTOR(g_nof_streams-1 DOWNTO 0);
  SIGNAL diag_steps_2arr     : t_steps_2arr(g_nof_streams-1 DOWNTO 0);
  
  SIGNAL rx_cnt_arr          : t_slv_32_arr(g_nof_streams-1 DOWNTO 0);  -- can use t_slv_32_arr because c_mm_reg.dat_w = c_word_w = 32 fixed
  SIGNAL rx_sample_arr       : t_seq_dat_arr(g_nof_streams-1 DOWNTO 0);
  SIGNAL rx_sample_diff_arr  : t_seq_dat_arr(g_nof_streams-1 DOWNTO 0);
  SIGNAL rx_sample_val_arr   : STD_LOGIC_VECTOR(g_nof_streams-1 DOWNTO 0);
  SIGNAL rx_seq_arr          : t_seq_dat_arr(g_nof_streams-1 DOWNTO 0);
  SIGNAL rx_seq_val_arr      : STD_LOGIC_VECTOR(g_nof_streams-1 DOWNTO 0);
  SIGNAL rx_data_arr         : t_data_arr(g_nof_streams-1 DOWNTO 0);
  SIGNAL rx_data_val_arr     : STD_LOGIC_VECTOR(g_nof_streams-1 DOWNTO 0);

  SIGNAL diag_res_arr        : t_seq_dat_arr(g_nof_streams-1 DOWNTO 0);
  SIGNAL diag_res_val_arr    : STD_LOGIC_VECTOR(g_nof_streams-1 DOWNTO 0);
  
  SIGNAL stat_res_ok_n_arr   : STD_LOGIC_VECTOR(g_nof_streams-1 DOWNTO 0);
  SIGNAL stat_res_val_n_arr  : STD_LOGIC_VECTOR(g_nof_streams-1 DOWNTO 0);
  signal clken : STD_LOGIC;

BEGIN

  ASSERT g_data_w >= g_seq_dat_w REPORT "mms_diag_rx_seq: g_data_w < g_seq_dat_w is not allowed." SEVERITY FAILURE;
  
  gen_nof_streams: FOR I IN 0 to g_nof_streams-1 GENERATE
  
    -- no unreplicate needed
    gen_one : IF g_data_w = g_seq_dat_w GENERATE
      rx_seq_arr(I)     <= rx_snk_in_arr(i).data(g_seq_dat_w-1 DOWNTO 0);
      rx_seq_val_arr(I) <= rx_snk_in_arr(i).valid;
    END GENERATE;
    
    -- unreplicate needed
    gen_unreplicate : IF g_data_w > g_seq_dat_w GENERATE
      -- keep sequence in low bits and set high bits to '1' if they mismatch the corresponding bit in the sequence
      rx_data_arr(I)     <= UNREPLICATE_DP_DATA(rx_snk_in_arr(i).data(g_data_w-1 DOWNTO 0), g_seq_dat_w);
      rx_data_val_arr(I) <=                     rx_snk_in_arr(i).valid;
      
      -- keep sequence in low bits if the high bits match otherwise force low bits value to -1 to indicate the mismatch
      p_rx_seq : PROCESS(dp_clk)
      BEGIN
        IF rising_edge(dp_clk) THEN  -- register to ease timing closure
          IF UNSIGNED(rx_data_arr(I)(g_data_w-1 DOWNTO g_seq_dat_w))=0 THEN
            rx_seq_arr(I) <= rx_data_arr(I)(g_seq_dat_w-1 DOWNTO 0);
          ELSE
            rx_seq_arr(I) <= TO_SVEC(-1, g_seq_dat_w);
          END IF;
          rx_seq_val_arr(I) <= rx_data_val_arr(I);
        END IF;
      END PROCESS;
    END GENERATE;
      
    -- detect rx sequence errors
    u_diag_rx_seq: ENTITY work.diag_rx_seq
    	generic map(
    		g_use_steps  => g_use_steps,
    		g_nof_steps  => g_nof_steps,
    		g_cnt_w      => c_word_w,
    		g_dat_w      => g_seq_dat_w,
    		g_diag_res_w => g_seq_dat_w
    	)
    	port map(
    		rst              => dp_rst,
    		clk              => dp_clk,
    		
    		clken            => clken,
    		-- Write and read back registers:
    		diag_en          => diag_en_arr(I),
    		diag_sel         => diag_sel_arr(I),
    		diag_steps_arr   => diag_steps_2arr(I),
    		
    		-- Read only registers:
    		diag_res         => diag_res_arr(I),
    		diag_res_val     => diag_res_val_arr(I),
    		diag_sample      => rx_sample_arr(I),
    		diag_sample_diff => rx_sample_diff_arr(I),
    		diag_sample_val  => rx_sample_val_arr(I),
    		
    		-- Streaming
    		in_cnt           => rx_cnt_arr(I),
    		in_dat           => rx_seq_arr(I),
    		in_val           => rx_seq_val_arr(I)
    	);
    
    -- Map diag_res to single bit and register it to ease timing closure
    stat_res_ok_n_arr(I)  <= orv(diag_res_arr(I))    WHEN rising_edge(dp_clk);
    stat_res_val_n_arr(I) <= NOT diag_res_val_arr(I) WHEN rising_edge(dp_clk);
    
    -- Register mapping
    -- . write ctrl_reg_arr
    diag_en_arr(I)   <= ctrl_reg_arr(I)(0);  -- address 0, data bit [0]
    diag_sel_arr(I)  <= ctrl_reg_arr(I)(1);  -- address 0, data bit [1]
    
    gen_diag_steps_2arr : FOR J IN 0 TO g_nof_steps-1 GENERATE
      diag_steps_2arr(I)(J) <= TO_SINT(ctrl_reg_arr(I)(c_reg_dat_w-1 + (c_nof_steps_wi+J)*c_word_w DOWNTO (c_nof_steps_wi+J)*c_word_w));  -- address 4, 5, 6, 7
    END GENERATE;
    
    -- . read stat_reg_arr
    p_stat_reg_arr : PROCESS(ctrl_reg_arr, stat_res_ok_n_arr, stat_res_val_n_arr, rx_cnt_arr, rx_sample_arr)
    BEGIN
      -- Default write / readback:
      stat_reg_arr(I) <= ctrl_reg_arr(I);                                        -- default control read back
      -- Status read only:
      stat_reg_arr(I)(                  0+1*c_word_w) <= stat_res_ok_n_arr(I);   -- address 1, data bit [0]
      stat_reg_arr(I)(                  1+1*c_word_w) <= stat_res_val_n_arr(I);  -- address 1, data bit [1]
      stat_reg_arr(I)(3*c_word_w-1 DOWNTO 2*c_word_w) <= rx_cnt_arr(I);          -- address 2: read rx_cnt per stream
      stat_reg_arr(I)(4*c_word_w-1 DOWNTO 3*c_word_w) <= RESIZE_UVEC(rx_sample_arr(I), c_word_w);  -- address 3: read valid sample per stream
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
      in_reg      => stat_reg_arr(I),
      out_reg     => ctrl_reg_arr(I)
    );
  END GENERATE;

  -- Combine the internal array of mm interfaces for the bg_data to one array that is connected to the port of the MM bus
  u_mem_mux : ENTITY casper_mm_lib.common_mem_mux
  GENERIC MAP (    
    g_nof_mosi    => g_nof_streams,
    g_mult_addr_w => c_mm_reg.adr_w
  )
  PORT MAP (
    mosi     => reg_mosi,
    miso     => reg_miso,
    mosi_arr => reg_mosi_arr,
    miso_arr => reg_miso_arr
  );

END str;













