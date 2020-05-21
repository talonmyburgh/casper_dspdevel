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

LIBRARY IEEE, common_pkg_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.MATH_REAL.ALL;
USE common_pkg_lib.common_pkg.ALL;

PACKAGE diag_pkg IS

  -----------------------------------------------------------------------------
  -- PHY interface tests (e.g. for ethernet, transceivers, lvds, memory)
  -----------------------------------------------------------------------------
  
  CONSTANT c_diag_test_mode_no_tst      : NATURAL := 0;   -- no test, the PHY interface runs in normal user mode
  CONSTANT c_diag_test_mode_loop_local  : NATURAL := 1;   -- loop back via PHY chip
  CONSTANT c_diag_test_mode_loop_remote : NATURAL := 2;   -- loop back via loopback cable or plug in the connector
  CONSTANT c_diag_test_mode_tx          : NATURAL := 4;   -- transmit only
  CONSTANT c_diag_test_mode_rx          : NATURAL := 5;   -- receive only
  CONSTANT c_diag_test_mode_tx_rx       : NATURAL := 6;   -- transmit and receive
  
  CONSTANT c_diag_test_data_lfsr        : NATURAL := 0;   -- use pseudo random data
  CONSTANT c_diag_test_data_incr        : NATURAL := 1;   -- use incrementing counter data
  
  CONSTANT c_diag_test_duration_quick   : NATURAL := 0;   -- end Rx test after 1 data frame or word, end Tx test after correspondingly sufficient data frames or words transmitted, or all memory lines
  CONSTANT c_diag_test_duration_normal  : NATURAL := 1;   -- idem for e.g. 100 data frames or words, or full memory
  CONSTANT c_diag_test_duration_extra   : NATURAL := 2;   -- idem for e.g. 100000 data frames or words
  
  CONSTANT c_diag_test_result_ok        : NATURAL := 0;   -- test went OK
  CONSTANT c_diag_test_result_none      : NATURAL := 1;   -- test did not run, default
  CONSTANT c_diag_test_result_timeout   : NATURAL := 2;   -- test started but no valid data was received
  CONSTANT c_diag_test_result_error     : NATURAL := 3;   -- test received valid data, but the value was wrong for one or more
  CONSTANT c_diag_test_result_illegal   : NATURAL := 4;   -- exception, condition that can not occur in the logic
  
  
  -----------------------------------------------------------------------------
  -- Waveform Generator
  -----------------------------------------------------------------------------
  
  -- control register
  CONSTANT c_diag_wg_mode_w             : NATURAL :=  8;
  CONSTANT c_diag_wg_nofsamples_w       : NATURAL := 16;  -- >~ minimum data path block size
  CONSTANT c_diag_wg_phase_w            : NATURAL := 16;  -- =  c_diag_wg_nofsamples_w
  CONSTANT c_diag_wg_freq_w             : NATURAL := 31;  -- >> c_diag_wg_nofsamples_w, determines the minimum frequency = Fs / 2**c_diag_wg_freq_w
  CONSTANT c_diag_wg_ampl_w             : NATURAL := 17;  -- Typically fit DSP multiply 18x18 element so use <= 17, to fit unsigned in 18 bit signed,
                                                          -- = waveform data width-1 (sign bit) to be able to make a 1 LSBit amplitude sinus
                                                          
  CONSTANT c_diag_wg_mode_off           : NATURAL := 0;
  CONSTANT c_diag_wg_mode_calc          : NATURAL := 1;
  CONSTANT c_diag_wg_mode_repeat        : NATURAL := 2;
  CONSTANT c_diag_wg_mode_single        : NATURAL := 3;
  
  TYPE t_diag_wg IS RECORD
    mode        : STD_LOGIC_VECTOR(c_diag_wg_mode_w       -1 DOWNTO 0);
    nof_samples : STD_LOGIC_VECTOR(c_diag_wg_nofsamples_w -1 DOWNTO 0);  -- unsigned value
    phase       : STD_LOGIC_VECTOR(c_diag_wg_phase_w      -1 DOWNTO 0);  -- unsigned value
    freq        : STD_LOGIC_VECTOR(c_diag_wg_freq_w       -1 DOWNTO 0);  -- unsigned value
    ampl        : STD_LOGIC_VECTOR(c_diag_wg_ampl_w       -1 DOWNTO 0);  -- unsigned value, range [0:2**c_diag_wg_ampl_w> normalized to range [0 c_diag_wg_gain>
  END RECORD;

  CONSTANT c_diag_wg_ampl_norm          : REAL := 1.0;   -- Use this default amplitude norm = 1.0 when WG data width = WG waveform buffer data width,
                                                         -- else use extra amplitude unit scaling by (WG data max)/(WG data max + 1)
  CONSTANT c_diag_wg_gain_w             : NATURAL := 1;  -- Normalized range [0 1>  maps to fixed point range [0:2**c_diag_wg_ampl_w>
                                                         -- . use gain 2**0             = 1 to have fulle scale without clipping
                                                         -- . use gain 2**g_calc_gain_w > 1 to cause clipping
  CONSTANT c_diag_wg_ampl_unit          : REAL := 2**REAL(c_diag_wg_ampl_w-c_diag_wg_gain_w)*c_diag_wg_ampl_norm;  -- ^= Full Scale range [-c_wg_full_scale +c_wg_full_scale] without clipping
  CONSTANT c_diag_wg_freq_unit          : REAL := 2**REAL(c_diag_wg_freq_w);                                       -- ^= c_clk_freq = Fs (sample frequency), assuming one sinus waveform in the buffer
  CONSTANT c_diag_wg_phase_unit         : REAL := 2**REAL(c_diag_wg_phase_w)/ 360.0;                               -- ^= 1 degree
  
  CONSTANT c_diag_wg_rst : t_diag_wg := (TO_UVEC(c_diag_wg_mode_off, c_diag_wg_mode_w),
                                         TO_UVEC(              1024, c_diag_wg_nofsamples_w),
                                         TO_UVEC(                 0, c_diag_wg_phase_w),
                                         TO_UVEC(                 0, c_diag_wg_freq_w),
                                         TO_UVEC(                 0, c_diag_wg_ampl_w));
  
  TYPE t_diag_wg_arr IS ARRAY (INTEGER RANGE <>) OF t_diag_wg;
  
  -----------------------------------------------------------------------------
  -- Block Generator
  -----------------------------------------------------------------------------
  
  -- control register
  CONSTANT c_diag_bg_reg_nof_dat : NATURAL := 8;
  CONSTANT c_diag_bg_reg_adr_w   : NATURAL := ceil_log2(c_diag_bg_reg_nof_dat);
  
  CONSTANT c_diag_bg_mode_w               : NATURAL :=  8;
  CONSTANT c_diag_bg_samples_per_packet_w : NATURAL := 24;   
  CONSTANT c_diag_bg_blocks_per_sync_w    : NATURAL := 24;   
  CONSTANT c_diag_bg_gapsize_w            : NATURAL := 24;
  CONSTANT c_diag_bg_mem_adrs_w           : NATURAL := 24;  
  CONSTANT c_diag_bg_mem_low_adrs_w       : NATURAL := c_diag_bg_mem_adrs_w;  
  CONSTANT c_diag_bg_mem_high_adrs_w      : NATURAL := c_diag_bg_mem_adrs_w;
  CONSTANT c_diag_bg_bsn_init_w           : NATURAL := 64;
                                                          
  TYPE t_diag_block_gen IS RECORD
    enable             : STD_LOGIC;  -- block enable
    enable_sync        : STD_LOGIC;  -- block enable on sync pulse
    samples_per_packet : STD_LOGIC_VECTOR(c_diag_bg_samples_per_packet_w -1 DOWNTO 0);  
    blocks_per_sync    : STD_LOGIC_VECTOR(c_diag_bg_blocks_per_sync_w    -1 DOWNTO 0);  
    gapsize            : STD_LOGIC_VECTOR(c_diag_bg_gapsize_w            -1 DOWNTO 0);  
    mem_low_adrs       : STD_LOGIC_VECTOR(c_diag_bg_mem_low_adrs_w       -1 DOWNTO 0);  
    mem_high_adrs      : STD_LOGIC_VECTOR(c_diag_bg_mem_high_adrs_w      -1 DOWNTO 0);  
    bsn_init           : STD_LOGIC_VECTOR(c_diag_bg_bsn_init_w           -1 DOWNTO 0);  
  END RECORD;   
  
  CONSTANT c_diag_block_gen_rst     : t_diag_block_gen := (         '0',      
                                                                    '0',      
                                                           TO_UVEC( 256, c_diag_bg_samples_per_packet_w), 
                                                           TO_UVEC(  10, c_diag_bg_blocks_per_sync_w),      
                                                           TO_UVEC( 128, c_diag_bg_gapsize_w), 
                                                           TO_UVEC(   0, c_diag_bg_mem_low_adrs_w),      
                                                           TO_UVEC(   1, c_diag_bg_mem_high_adrs_w), 
                                                           TO_UVEC(   0, c_diag_bg_bsn_init_w));      
  
  CONSTANT c_diag_block_gen_enabled : t_diag_block_gen := (         '1',
                                                                    '0',      
                                                           TO_UVEC(  50, c_diag_bg_samples_per_packet_w), 
                                                           TO_UVEC(  10, c_diag_bg_blocks_per_sync_w),      
                                                           TO_UVEC(   7, c_diag_bg_gapsize_w), 
                                                           TO_UVEC(   0, c_diag_bg_mem_low_adrs_w),      
                                                           TO_UVEC(  15, c_diag_bg_mem_high_adrs_w),   -- fits any BG buffer that has address width >= 4
                                                           TO_UVEC(   0, c_diag_bg_bsn_init_w));
                                                       
  TYPE t_diag_block_gen_arr IS ARRAY (INTEGER RANGE <>) OF t_diag_block_gen;
 
  -- Overloaded sel_a_b (from common_pkg) for t_diag_block_gen
  FUNCTION sel_a_b(sel : BOOLEAN; a, b : t_diag_block_gen) RETURN t_diag_block_gen; 

  -----------------------------------------------------------------------------
  -- Data buffer
  -----------------------------------------------------------------------------
  CONSTANT c_diag_db_reg_nof_dat : NATURAL := 2;
  CONSTANT c_diag_db_reg_adr_w   : NATURAL := ceil_log2(c_diag_db_reg_nof_dat);
  
  CONSTANT c_diag_db_max_data_w  : NATURAL := 32;
  
  TYPE t_diag_data_type_enum IS (
    e_data,
    e_complex,           -- im & re
    e_real,
    e_imag
  );        

  -----------------------------------------------------------------------------
  -- Data buffer dev
  -----------------------------------------------------------------------------
  CONSTANT c_diag_db_dev_reg_nof_dat : NATURAL := 8;   -- Create headroom of 4 registers. 
  CONSTANT c_diag_db_dev_reg_adr_w   : NATURAL := ceil_log2(c_diag_db_dev_reg_nof_dat);
 
  -----------------------------------------------------------------------------
  -- CNTR / PSRG sequence test data
  -----------------------------------------------------------------------------
  
  CONSTANT c_diag_seq_tx_reg_nof_dat      : NATURAL := 4;
  CONSTANT c_diag_seq_tx_reg_adr_w        : NATURAL := ceil_log2(c_diag_seq_tx_reg_nof_dat);
  CONSTANT c_diag_seq_rx_reg_nof_steps_wi : NATURAL := 4;
  CONSTANT c_diag_seq_rx_reg_nof_steps    : NATURAL := 4;
  CONSTANT c_diag_seq_rx_reg_nof_dat      : NATURAL := c_diag_seq_rx_reg_nof_steps_wi + c_diag_seq_rx_reg_nof_steps;
  CONSTANT c_diag_seq_rx_reg_adr_w        : NATURAL := ceil_log2(c_diag_seq_rx_reg_nof_dat);
  
  -- Record with all diag seq MM register fields
  TYPE t_diag_seq_mm_reg IS RECORD
    -- readback control
    tx_init   : STD_LOGIC_VECTOR(c_word_w -1 DOWNTO 0);
    tx_mod    : STD_LOGIC_VECTOR(c_word_w -1 DOWNTO 0);
    tx_ctrl   : STD_LOGIC_VECTOR(c_word_w -1 DOWNTO 0);
    rx_ctrl   : STD_LOGIC_VECTOR(c_word_w -1 DOWNTO 0);
    rx_steps  : t_integer_arr(c_diag_seq_rx_reg_nof_steps-1 DOWNTO 0);
    -- read only status
    tx_cnt    : STD_LOGIC_VECTOR(c_word_w -1 DOWNTO 0);
    rx_cnt    : STD_LOGIC_VECTOR(c_word_w -1 DOWNTO 0);
    rx_stat   : STD_LOGIC_VECTOR(c_word_w -1 DOWNTO 0);
    rx_sample : STD_LOGIC_VECTOR(c_word_w -1 DOWNTO 0);
  END RECORD;  

  CONSTANT c_diag_seq_tx_reg_dis        : NATURAL := 0;
  CONSTANT c_diag_seq_tx_reg_en_psrg    : NATURAL := 1;
  CONSTANT c_diag_seq_tx_reg_en_cntr    : NATURAL := 3;
  
  TYPE t_diag_seq_mm_reg_arr IS ARRAY (INTEGER RANGE <>) OF t_diag_seq_mm_reg;
  
END diag_pkg;

PACKAGE BODY diag_pkg IS

  FUNCTION sel_a_b(sel : BOOLEAN; a, b : t_diag_block_gen) RETURN t_diag_block_gen IS
  BEGIN
    IF sel = TRUE THEN
      RETURN a;
    ELSE
      RETURN b;
    END IF;
  END;

END diag_pkg;
