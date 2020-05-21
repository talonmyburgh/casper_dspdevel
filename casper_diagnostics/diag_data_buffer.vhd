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

-- Purpose : Capture a block of streaming data for analysis via MM access
-- Description :
--   The first g_nof_data valid streaming data input words are stored in the
--   data buffer. Then they can be read via the MM interface. Dependent on
--   g_use_in_sync the nxt block of valid streaming data input words gets
--   stored when a new in_sync occurs or when the last word was read from via
--   the MM interface.
-- Remarks:
-- . The actual RAM usage depends on g_data_w. Unused bits are forced to '0'
--   when read.
-- . The c_mm_factor must be a power of 2 factor. Typically c_mm_factor=1 is
--   sufficient for most purposes. If the application only requires
--   eg. c_mm_factor=3 then it needs to extend the data to c_mm_factor=4.
-- . If c_mm_factor=2 then in_data[g_data_w/2-1:0] will appear at MM address
--   even and in_data[g_data_w-1:g_data_w/2] at address odd.
--   The advantage of splitting at g_data_w/2 instead of at c_word_w=32 is
--   that streaming 36b data can then map on 18b RAM still fit in a single
--   RAM block. Whereas mapping the LS 32b part at even address and the MS 4b
--   part at odd address would require using c_word_w=32b RAM that could
--   require two RAM blocks. For g_data_w=2*c_word_w=64b there is no
--   difference between these 2 schemes. Hence by rising the g_data_w to a
--   power of 2 multiple of 32b the user can enforce using splitting the data
--   a c_word_w parts.

LIBRARY IEEE, common_pkg_lib, casper_mm_lib, casper_ram_lib, casper_counter_lib, common_components_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE work.diag_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

ENTITY diag_data_buffer IS
  GENERIC (
    g_technology  : NATURAL := 0;
    g_data_w      : NATURAL := 32;
    g_nof_data    : NATURAL := 1024;
    g_use_in_sync : BOOLEAN := FALSE   -- when TRUE start filling the buffer at the in_sync, else after the last word was read
  );
  PORT (
    -- Memory-mapped clock domain
    mm_rst       : IN  STD_LOGIC;
    mm_clk       : IN  STD_LOGIC;

    ram_mm_mosi  : IN  t_mem_mosi;  -- read and overwrite access to the data buffer
    ram_mm_miso  : OUT t_mem_miso;
   
    reg_mm_mosi  : IN  t_mem_mosi := c_mem_mosi_rst;
    reg_mm_miso  : OUT t_mem_miso; 
 
    -- Streaming clock domain
    st_rst       : IN  STD_LOGIC;
    st_clk       : IN  STD_LOGIC;

    in_data      : IN  STD_LOGIC_VECTOR(g_data_w-1 DOWNTO 0);
    in_sync      : IN  STD_LOGIC := '0';
    in_val       : IN  STD_LOGIC  
  );
END diag_data_buffer;


ARCHITECTURE rtl OF diag_data_buffer IS

  CONSTANT c_mm_factor     : NATURAL := ceil_div(g_data_w, c_word_w);  -- must be a power of 2 multiple
  
  CONSTANT c_nof_data_mm   : NATURAL := g_nof_data*c_mm_factor;
  CONSTANT g_data_mm_w     : NATURAL := g_data_w/c_mm_factor;

  CONSTANT c_buf_mm        : t_c_mem := (latency  => 1,
                                         adr_w    => ceil_log2(c_nof_data_mm),
                                         dat_w    => g_data_mm_w,
                                         nof_dat  => c_nof_data_mm,
                                         init_sl  => '0');

  CONSTANT c_buf_st        : t_c_mem := (latency  => 1,
                                         adr_w    => ceil_log2(g_nof_data),
                                         dat_w    => g_data_w,
                                         nof_dat  => g_nof_data,
                                         init_sl  => '0');

  CONSTANT c_reg           : t_c_mem := (latency  => 1,
                                         adr_w    => c_diag_db_reg_adr_w,   
                                         dat_w    => c_word_w,       -- Use MM bus data width = c_word_w = 32 for all MM registers
                                         nof_dat  => c_diag_db_reg_nof_dat,   -- 1: word_cnt; 0:sync_cnt
                                         init_sl  => '0');
                
  SIGNAL i_ram_mm_miso   : t_mem_miso := c_mem_miso_rst;   -- used to avoid vsim-8684 error "No drivers exist" for the unused fields
  
  SIGNAL rd_last         : STD_LOGIC;
  SIGNAL wr_sync         : STD_LOGIC;
  
  SIGNAL wr_done         : STD_LOGIC;
  SIGNAL nxt_wr_done     : STD_LOGIC;
  
  SIGNAL wr_data         : STD_LOGIC_VECTOR(c_buf_st.dat_w-1 DOWNTO 0);
  SIGNAL nxt_wr_data     : STD_LOGIC_VECTOR(c_buf_st.dat_w-1 DOWNTO 0);
  SIGNAL wr_addr         : STD_LOGIC_VECTOR(c_buf_st.adr_w-1 DOWNTO 0);
  SIGNAL nxt_wr_addr     : STD_LOGIC_VECTOR(c_buf_st.adr_w-1 DOWNTO 0);
  SIGNAL wr_en           : STD_LOGIC;
  SIGNAL nxt_wr_en       : STD_LOGIC;

  SIGNAL reg_rd_arr      : STD_LOGIC_VECTOR(c_reg.nof_dat-1 DOWNTO 0);
  SIGNAL reg_slv         : STD_LOGIC_VECTOR(c_reg.nof_dat*c_word_w-1 DOWNTO 0);

  SIGNAL sync_cnt_clr    : STD_LOGIC := '0';  
  SIGNAL sync_cnt        : STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0); -- Nof times buffer has been written
  SIGNAL word_cnt        : STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0) := (OTHERS=>'0');
  
BEGIN
  
  ASSERT c_mm_factor=2**true_log2(c_mm_factor) REPORT "Only support mixed width data that uses a power of 2 multiple." SEVERITY FAILURE;
  
  ram_mm_miso <= i_ram_mm_miso;
      
  rd_last <= '1' WHEN UNSIGNED(ram_mm_mosi.address(c_buf_mm.adr_w-1 DOWNTO 0))=c_nof_data_mm-1 AND ram_mm_mosi.rd='1' ELSE '0';
  
  -- Determine the write trigger
  use_rd_last : IF g_use_in_sync=FALSE GENERATE
    u_wr_sync : ENTITY common_components_lib.common_spulse
    GENERIC MAP (
      g_delay_len => c_meta_delay_len
    )
    PORT MAP (
      in_rst    => mm_rst,
      in_clk    => mm_clk,
      in_pulse  => rd_last,
      out_rst   => st_rst,
      out_clk   => st_clk,
      out_pulse => wr_sync
    );
  END GENERATE;

  use_in_sync : IF g_use_in_sync=TRUE GENERATE
    sync_cnt_clr <= rd_last;  -- clear sync_cnt register on read of last data
    wr_sync      <= in_sync;
  END GENERATE;
  
  p_st_clk : PROCESS (st_clk, st_rst)
  BEGIN
    IF st_rst='1' THEN
      wr_data <= (OTHERS => '0');
      wr_addr <= (OTHERS => '0');
      wr_en   <= '0';
      wr_done <= '0';
    ELSIF rising_edge(st_clk) THEN
      wr_data <= nxt_wr_data;
      wr_addr <= nxt_wr_addr;
      wr_en   <= nxt_wr_en;
      wr_done <= nxt_wr_done;
    END IF;
  END PROCESS;

  -- Write access control
  nxt_wr_data <= in_data;
  nxt_wr_en   <= in_val AND NOT nxt_wr_done;
  
  p_wr_addr : PROCESS (wr_done, wr_addr, wr_sync, wr_en)
  BEGIN
    nxt_wr_done <= wr_done;
    nxt_wr_addr <= wr_addr;
    IF wr_sync='1' THEN
      nxt_wr_done <= '0';
      nxt_wr_addr <= (OTHERS => '0');
    ELSIF wr_en='1' THEN
      IF UNSIGNED(wr_addr)=g_nof_data-1 THEN
        nxt_wr_done <= '1';   -- keep wr_addr, do not allow wr_addr increment >= g_nof_data to avoid RAM address out-of-bound warning in Modelsim in case c_buf.nof_dat < 2**c_buf.adr_w
      ELSE
        nxt_wr_addr <= INCR_UVEC(wr_addr, 1);
      END IF;
    END IF;
  END PROCESS;

  u_buf : ENTITY casper_ram_lib.common_ram_crw_crw_ratio
  GENERIC MAP (
    g_technology => g_technology,
    g_ram_a     => c_buf_mm,
    g_ram_b     => c_buf_st,
    g_init_file => "UNUSED"
  )
  PORT MAP (
    -- MM read/write port clock domain
    rst_a    => mm_rst,
    clk_a    => mm_clk,
    wr_en_a  => ram_mm_mosi.wr,
    wr_dat_a => ram_mm_mosi.wrdata(c_buf_mm.dat_w-1 DOWNTO 0),
    adr_a    => ram_mm_mosi.address(c_buf_mm.adr_w-1 DOWNTO 0),
    rd_en_a  => ram_mm_mosi.rd,
    rd_dat_a => i_ram_mm_miso.rddata(c_buf_mm.dat_w-1 DOWNTO 0),
    rd_val_a => i_ram_mm_miso.rdval,

    -- ST write only port clock domain
    rst_b     => st_rst,
    clk_b     => st_clk,
    wr_en_b   => wr_en,
    wr_dat_b  => wr_data,
    adr_b     => wr_addr,
    rd_en_b   => '0',
    rd_dat_b  => OPEN,
    rd_val_b  => OPEN
  ); 

  u_reg : ENTITY casper_mm_lib.common_reg_r_w_dc
  GENERIC MAP (
    g_reg       => c_reg
  )
  PORT MAP (
    -- Clocks and reset
    mm_rst      => mm_rst,
    mm_clk      => mm_clk,
    st_rst      => st_rst,
    st_clk      => st_clk,
    
    -- Memory Mapped Slave in mm_clk domain
    sla_in      => reg_mm_mosi,
    sla_out     => reg_mm_miso,
    
    -- MM registers in st_clk domain
    reg_wr_arr  => OPEN,
    reg_rd_arr  => reg_rd_arr,
    in_reg      => reg_slv,
    out_reg     => OPEN
  );

  reg_slv <= word_cnt & sync_cnt;

  u_word_cnt : ENTITY casper_counter_lib.common_counter
  PORT MAP (
    rst     => st_rst,
    clk     => st_clk,
    cnt_en  => wr_en,
    cnt_clr => wr_sync,
    count   => word_cnt
  );

  u_sync_cnt : ENTITY casper_counter_lib.common_counter
  PORT MAP (
    rst     => st_rst,
    clk     => st_clk,
    cnt_en  => wr_sync,
    cnt_clr => sync_cnt_clr,
    count   => sync_cnt
  );
    
END rtl;

