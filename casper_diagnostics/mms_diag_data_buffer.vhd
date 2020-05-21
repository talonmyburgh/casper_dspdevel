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

-- Purpose: MM data buffer and Rx seq for multiple parallel SOSI streams
-- Description:                             
-- . g_use_db
--   The mms_diag_data_buffer can capture data from an input stream in a data
--   buffer when g_use_db=TRUE. Dependend on g_buf_use_sync the data buffer
--   is rewritten after each in_sync or when the last word was read via MM.
-- . g_use_rx_seq
--   The mms_diag_data_buffer can continously verify a input Rx data sequence
--   when g_use_rx_seq=TRUE. The expected sequence data is typically generated
--   by an remote upstream tx_seq source.
-- . The advantage of the rx_seq is that is can continously verify the
--   correctness of all rx data in hardware, whereas the DB can only take a
--   snapshot that then needs to be examined via MM. The advandage of the DB
--   is that it can take a snapshot of the values of the received data. The
--   DB requires RAM resources and the rx_seq does not.
--
-- Block diagram:
--
--                           g_use_db 
--                           g_buf_use_sync
--                              .
--                              .      g_use_tx_seq
--                              .          .
--                              .          .
--                      /-------------> Rx seq 
--                      |       .         |
--     in_sosi_arr -----*---> DB RAM      |
--     in_sync -------------> DB reg      |
--                              ||        |
--                              ||        |
--              MM ================================
--
-- Remark:
-- . A nice new feature would be to continuously write the DB and to stop
--   writting it on a trigger. This trigger can then eg. be when the rx_seq
--   detects an error. By delaying the trigger somewhat it the DB can then
--   capture some data before and after the trigger event.

LIBRARY IEEE, common_pkg_lib, dp_pkg_lib, casper_ram_lib, casper_mm_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL; 
USE work.diag_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

ENTITY mms_diag_data_buffer IS
  GENERIC (    
    g_technology   : NATURAL := 0;
    -- Generate configurations
    g_use_db       : BOOLEAN := TRUE;
    g_use_rx_seq   : BOOLEAN := FALSE;
    -- General
    g_nof_streams  : POSITIVE := 16;    -- each stream gets an data buffer
    -- DB settings
    g_data_type    : t_diag_data_type_enum := e_data;      -- define the sosi field that gets stored: e_data=data, e_complex=im&re, e_real=re, e_imag=im
    g_data_w       : NATURAL := 32;     -- the g_data_w is the width of the data, re, im values or of the combined im&re value
    g_buf_nof_data : NATURAL := 1024;   -- nof words per data buffer
    g_buf_use_sync : BOOLEAN := FALSE;  -- when TRUE start filling the buffer at the in_sync, else after the last word was read
    -- Rx_seq
    g_use_steps    : BOOLEAN := FALSE;
    g_nof_steps    : NATURAL := c_diag_seq_rx_reg_nof_steps;
    g_seq_dat_w    : NATURAL := 32  -- >= 1, test sequence data width. Choose g_seq_dat_w <= g_data_w
  );
  PORT (
    -- System
    mm_rst            : IN  STD_LOGIC;
    mm_clk            : IN  STD_LOGIC;
    dp_rst            : IN  STD_LOGIC;
    dp_clk            : IN  STD_LOGIC;
    -- MM interface
    reg_data_buf_mosi : IN  t_mem_mosi := c_mem_mosi_rst;  -- DB control register (one per stream)
    reg_data_buf_miso : OUT t_mem_miso;

    ram_data_buf_mosi : IN  t_mem_mosi := c_mem_mosi_rst;  -- DB buffer RAM (one per streams)
    ram_data_buf_miso : OUT t_mem_miso;

    reg_rx_seq_mosi   : IN  t_mem_mosi := c_mem_mosi_rst;  -- Rx seq control register (one per streams)
    reg_rx_seq_miso   : OUT t_mem_miso;
    
    -- ST interface
    in_sync           : IN  STD_LOGIC := '0';  -- input sync pulse in ST dp_clk domain that starts data buffer when g_use_in_sync = TRUE
    in_sosi_arr       : IN t_dp_sosi_arr(g_nof_streams-1 DOWNTO 0)
  );
END mms_diag_data_buffer;

ARCHITECTURE str OF mms_diag_data_buffer IS

  CONSTANT c_buf_mm_factor   : NATURAL := ceil_div(g_data_w, c_word_w);
  CONSTANT c_buf_nof_data_mm : NATURAL := g_buf_nof_data*c_buf_mm_factor;

  CONSTANT c_buf_adr_w : NATURAL := ceil_log2(c_buf_nof_data_mm);
  CONSTANT c_reg_adr_w : NATURAL := c_diag_db_reg_adr_w;

  TYPE t_data_arr IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(g_data_w-1 DOWNTO 0);
  
  SIGNAL in_data_arr           : t_data_arr(g_nof_streams-1 DOWNTO 0);
  
  SIGNAL ram_data_buf_mosi_arr : t_mem_mosi_arr(g_nof_streams-1 DOWNTO 0);
  SIGNAL ram_data_buf_miso_arr : t_mem_miso_arr(g_nof_streams-1 DOWNTO 0); 

  SIGNAL reg_data_buf_mosi_arr : t_mem_mosi_arr(g_nof_streams-1 DOWNTO 0);
  SIGNAL reg_data_buf_miso_arr : t_mem_miso_arr(g_nof_streams-1 DOWNTO 0); 
  
BEGIN

  no_db : IF g_use_db=FALSE GENERATE
    ram_data_buf_miso <= c_mem_miso_rst;
    reg_data_buf_miso <= c_mem_miso_rst;
  END GENERATE;
  
  gen_db : IF g_use_db=TRUE GENERATE
    -- Combine the internal array of mm interfaces for the data_buf to one array that is connected to the port of the MM bus
    u_mem_mux_data_buf : ENTITY casper_mm_lib.common_mem_mux
    GENERIC MAP (    
      g_nof_mosi    => g_nof_streams,
      g_mult_addr_w => c_buf_adr_w
    )
    PORT MAP (
      mosi     => ram_data_buf_mosi,
      miso     => ram_data_buf_miso,
      mosi_arr => ram_data_buf_mosi_arr,
      miso_arr => ram_data_buf_miso_arr
    );
  
    u_mem_mux_reg : ENTITY casper_mm_lib.common_mem_mux
    GENERIC MAP (    
      g_nof_mosi    => g_nof_streams,
      g_mult_addr_w => c_reg_adr_w
    )
    PORT MAP (
      mosi     => reg_data_buf_mosi,
      miso     => reg_data_buf_miso,
      mosi_arr => reg_data_buf_mosi_arr,
      miso_arr => reg_data_buf_miso_arr
    );
      
    gen_stream : FOR I IN 0 TO g_nof_streams-1 GENERATE
      in_data_arr(I) <= in_sosi_arr(I).im(g_data_w/2-1 DOWNTO 0) & in_sosi_arr(I).re(g_data_w/2-1 DOWNTO 0) WHEN g_data_type=e_complex ELSE
                        in_sosi_arr(I).re(g_data_w-1 DOWNTO 0)                                              WHEN g_data_type=e_real ELSE
                        in_sosi_arr(I).im(g_data_w-1 DOWNTO 0)                                              WHEN g_data_type=e_imag ELSE
                        in_sosi_arr(I).data(g_data_w-1 DOWNTO 0);                                             -- g_data_type=e_data is default
    
      u_diag_data_buffer : ENTITY work.diag_data_buffer
      GENERIC MAP (
        g_technology  => g_technology,
        g_data_w      => g_data_w, 
        g_nof_data    => g_buf_nof_data,
        g_use_in_sync => g_buf_use_sync   -- when TRUE start filling the buffer at the in_sync, else after the last word was read
      )
      PORT MAP (
        -- Memory-mapped clock domain
        mm_rst      => mm_rst,
        mm_clk      => mm_clk,
    
        ram_mm_mosi => ram_data_buf_mosi_arr(I),
        ram_mm_miso => ram_data_buf_miso_arr(I),
  
        reg_mm_mosi => reg_data_buf_mosi_arr(I),
        reg_mm_miso => reg_data_buf_miso_arr(I),
        
        -- Streaming clock domain
        st_rst      => dp_rst,
        st_clk      => dp_clk,
    
        in_data     => in_data_arr(I),
        in_sync     => in_sync,
        in_val      => in_sosi_arr(I).valid
      );
    END GENERATE;
  END GENERATE;

  no_rx_seq : IF g_use_rx_seq=FALSE GENERATE
    reg_rx_seq_miso <= c_mem_miso_rst;
  END GENERATE;
  
  gen_rx_seq : IF g_use_rx_seq=TRUE GENERATE
    u_mms_diag_rx_seq : ENTITY work.mms_diag_rx_seq
    GENERIC MAP (
      g_nof_streams => g_nof_streams,
      g_use_steps   => g_use_steps,
      g_nof_steps   => g_nof_steps,
      g_seq_dat_w   => g_seq_dat_w,  -- >= 1, test sequence data width
      g_data_w      => g_data_w      -- >= g_seq_dat_w, user data width
    )
    PORT MAP (
      -- Clocks and reset
      mm_rst         => mm_rst,
      mm_clk         => mm_clk,
      dp_rst         => dp_rst,
      dp_clk         => dp_clk,
  
      -- Memory Mapped Slave
      reg_mosi       => reg_rx_seq_mosi,   -- multiplexed port for g_nof_streams MM control/status registers
      reg_miso       => reg_rx_seq_miso,
  
      -- Streaming interface
      rx_snk_in_arr  => in_sosi_arr
    );
  END GENERATE;
  
END str;
