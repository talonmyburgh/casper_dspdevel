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

-- Purpose: Multi page memory
-- Description:
--   When next_page_* pulses then the next access will occur in the next page.
-- Remarks:
-- . There are three architecture variants (default use "use_adr"):
--   . use_mux : Use multiplexer logic and one RAM per page
--   . use_adr : Use MSbit address lines and one buf RAM for all pages
--   . use_ofs : Use address offset adders and one buf RAM for all pages
-- . The "use_mux" variant requires the multiplexer logic but can be more
--   efficient regarding RAM usage than the "use_adr" variant.
--   The "use_ofs" variant requires address adder logic, but is optimal
--   regarding RAM usage in case the page size is not a power of 2, because the
--   pages are then mapped at subsequent addresses in the buf RAM.
-- . The "use_adr" variant is optimal for speed, so that is set as default.

LIBRARY IEEE; --, technology_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
LIBRARY common_pkg_lib;
USE common_pkg_lib.common_pkg.ALL;
USE work.common_ram_pkg.ALL;
-- USE technology_lib.technology_select_pkg.ALL;

ENTITY common_paged_ram_crw_crw IS
  GENERIC (
    g_technology     : NATURAL := 0;
    g_str            : STRING := "use_adr";
    g_data_w         : NATURAL;
    g_nof_pages      : NATURAL := 2;  -- >= 2
    g_page_sz        : NATURAL;
    g_start_page_a   : NATURAL := 0;
    g_start_page_b   : NATURAL := 0;
    g_rd_latency     : NATURAL := 1;
    g_true_dual_port : BOOLEAN := TRUE
  );
  PORT (
    rst_a       : IN  STD_LOGIC;
    rst_b       : IN  STD_LOGIC;
    clk_a       : IN  STD_LOGIC;
    clk_b       : IN  STD_LOGIC;
    clken_a     : IN  STD_LOGIC := '1';
    clken_b     : IN  STD_LOGIC := '1';
    next_page_a : IN  STD_LOGIC;
    adr_a       : IN  STD_LOGIC_VECTOR(ceil_log2(g_page_sz)-1 DOWNTO 0) := (OTHERS=>'0');
    wr_en_a     : IN  STD_LOGIC := '0';
    wr_dat_a    : IN  STD_LOGIC_VECTOR(g_data_w-1 DOWNTO 0) := (OTHERS=>'0');
    rd_en_a     : IN  STD_LOGIC := '1';
    rd_dat_a    : OUT STD_LOGIC_VECTOR(g_data_w-1 DOWNTO 0);
    rd_val_a    : OUT STD_LOGIC;
    next_page_b : IN  STD_LOGIC;
    adr_b       : IN  STD_LOGIC_VECTOR(ceil_log2(g_page_sz)-1 DOWNTO 0) := (OTHERS=>'0');
    wr_en_b     : IN  STD_LOGIC := '0';
    wr_dat_b    : IN  STD_LOGIC_VECTOR(g_data_w-1 DOWNTO 0) := (OTHERS=>'0');
    rd_en_b     : IN  STD_LOGIC := '1';
    rd_dat_b    : OUT STD_LOGIC_VECTOR(g_data_w-1 DOWNTO 0);
    rd_val_b    : OUT STD_LOGIC
  );
END common_paged_ram_crw_crw;


ARCHITECTURE rtl OF common_paged_ram_crw_crw IS

  TYPE t_page_sel_arr IS ARRAY (INTEGER RANGE <>) OF NATURAL RANGE 0 TO g_nof_pages-1;
  
  CONSTANT c_page_addr_w      : NATURAL := ceil_log2(g_page_sz);
  
  -- g_str = "use_mux" :
  CONSTANT c_page_ram         : t_c_mem := (latency  => g_rd_latency,
                                            adr_w    => c_page_addr_w,
                                            dat_w    => g_data_w,
                                            nof_dat  => g_page_sz,
                                            init_sl  => '0');
                                           
  TYPE t_data_arr IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(g_data_w-1 DOWNTO 0);
  
  -- g_str = "use_adr" :
  CONSTANT c_mem_nof_pages_w  : NATURAL := true_log2(g_nof_pages);  
  CONSTANT c_mem_addr_w       : NATURAL := c_mem_nof_pages_w + c_page_addr_w;
  CONSTANT c_mem_nof_words    : NATURAL := g_nof_pages * 2**c_page_addr_w;  -- <= 2**c_mem_addr_w

  CONSTANT c_mem_ram          : t_c_mem := (latency  => g_rd_latency,
                                            adr_w    => c_mem_addr_w,
                                            dat_w    => g_data_w,
                                            nof_dat  => c_mem_nof_words,
                                            init_sl  => '0');
                                           
  -- g_str = "use_ofs" :
  CONSTANT c_buf_addr_w       : NATURAL := ceil_log2(g_nof_pages * g_page_sz);
  CONSTANT c_buf_nof_words    : NATURAL := g_nof_pages * g_page_sz;
  
  CONSTANT c_buf_ram          : t_c_mem := (latency  => g_rd_latency,
                                            adr_w    => c_buf_addr_w,
                                            dat_w    => g_data_w,
                                            nof_dat  => c_buf_nof_words,
                                            init_sl  => '0');
  
  -- >>> Page control
  
  -- g_str = "use_mux" and g_str = "use_adr" :
  -- . use page_sel direct for wr_en, rd_en, and address
  SIGNAL page_sel_a         : NATURAL RANGE 0 TO g_nof_pages-1;
  SIGNAL nxt_page_sel_a     : NATURAL;
  SIGNAL page_sel_b         : NATURAL RANGE 0 TO g_nof_pages-1;
  SIGNAL nxt_page_sel_b     : NATURAL;
  
  -- . use page_sel_dly to adjust for g_rd_latency of rd_dat and rd_val
  SIGNAL page_sel_a_dly     : t_page_sel_arr(0 TO g_rd_latency-1);
  SIGNAL nxt_page_sel_a_dly : t_page_sel_arr(0 TO g_rd_latency-1);
  SIGNAL page_sel_b_dly     : t_page_sel_arr(0 TO g_rd_latency-1);
  SIGNAL nxt_page_sel_b_dly : t_page_sel_arr(0 TO g_rd_latency-1);
    
  -- g_str = "use_ofs" :
  SIGNAL page_ofs_a         : NATURAL RANGE 0 TO c_buf_nof_words-1;
  SIGNAL nxt_page_ofs_a     : NATURAL;
  SIGNAL page_ofs_b         : NATURAL RANGE 0 TO c_buf_nof_words-1;
  SIGNAL nxt_page_ofs_b     : NATURAL;
  
  -- >>> Access control
  
  -- g_str = "use_mux" :
  SIGNAL page_wr_en_a       : STD_LOGIC_VECTOR(0 TO g_nof_pages-1);
  SIGNAL page_wr_dat_a      : t_data_arr(0 TO g_nof_pages-1);
  SIGNAL page_rd_en_a       : STD_LOGIC_VECTOR(0 TO g_nof_pages-1);
  SIGNAL page_rd_dat_a      : t_data_arr(0 TO g_nof_pages-1);
  SIGNAL page_rd_val_a      : STD_LOGIC_VECTOR(0 TO g_nof_pages-1);

  SIGNAL page_wr_en_b       : STD_LOGIC_VECTOR(0 TO g_nof_pages-1);
  SIGNAL page_wr_dat_b      : t_data_arr(0 TO g_nof_pages-1);
  SIGNAL page_rd_en_b       : STD_LOGIC_VECTOR(0 TO g_nof_pages-1);
  SIGNAL page_rd_dat_b      : t_data_arr(0 TO g_nof_pages-1);
  SIGNAL page_rd_val_b      : STD_LOGIC_VECTOR(0 TO g_nof_pages-1);
  
  -- g_str = "use_adr" :
  SIGNAL mem_adr_a          : STD_LOGIC_VECTOR(c_mem_addr_w-1 DOWNTO 0);  
  SIGNAL mem_adr_b          : STD_LOGIC_VECTOR(c_mem_addr_w-1 DOWNTO 0);
  
  -- g_str = "use_ofs" :
  SIGNAL buf_adr_a          : STD_LOGIC_VECTOR(c_buf_addr_w-1 DOWNTO 0);
  SIGNAL buf_adr_b          : STD_LOGIC_VECTOR(c_buf_addr_w-1 DOWNTO 0);
  
BEGIN

  -- page select (for all) and page address offset (for use_ofs)
  p_reg_a : PROCESS (rst_a, clk_a)
  BEGIN
    IF rst_a = '1' THEN
      page_sel_a     <=          g_start_page_a;
      page_sel_a_dly <= (OTHERS=>g_start_page_a);
      page_ofs_a     <=          g_start_page_a * g_page_sz;
    ELSIF rising_edge(clk_a) THEN
      page_sel_a     <= nxt_page_sel_a;
      page_sel_a_dly <= nxt_page_sel_a_dly;
      page_ofs_a     <= nxt_page_ofs_a;
    END IF;
  END PROCESS;

  p_reg_b : PROCESS (rst_b, clk_b)
  BEGIN
    IF rst_b = '1' THEN
      page_sel_b     <=          g_start_page_b;
      page_sel_b_dly <= (OTHERS=>g_start_page_b);
      page_ofs_b     <=          g_start_page_b * g_page_sz;
    ELSIF rising_edge(clk_b) THEN
      page_sel_b     <= nxt_page_sel_b;
      page_sel_b_dly <= nxt_page_sel_b_dly;
      page_ofs_b     <= nxt_page_ofs_b;
    END IF;
  END PROCESS;

  nxt_page_sel_a_dly(0)                   <= page_sel_a;
  nxt_page_sel_a_dly(1 TO g_rd_latency-1) <= page_sel_a_dly(0 TO g_rd_latency-2);
  nxt_page_sel_b_dly(0)                   <= page_sel_b;
  nxt_page_sel_b_dly(1 TO g_rd_latency-1) <= page_sel_b_dly(0 TO g_rd_latency-2);
    
  p_next_page_a : PROCESS(next_page_a, page_sel_a, page_ofs_a)
  BEGIN
    nxt_page_sel_a <= page_sel_a;
    nxt_page_ofs_a <= page_ofs_a;
    IF next_page_a='1' THEN
      IF page_sel_a < g_nof_pages-1 THEN
        nxt_page_sel_a <= page_sel_a + 1;
        nxt_page_ofs_a <= page_ofs_a + g_page_sz;
      ELSE
        nxt_page_sel_a <= 0;
        nxt_page_ofs_a <= 0;
      END IF;
    END IF;
  END PROCESS;
      
  p_next_page_b : PROCESS(next_page_b, page_sel_b, page_ofs_b)
  BEGIN
    nxt_page_sel_b <= page_sel_b;
    nxt_page_ofs_b <= page_ofs_b;
    IF next_page_b='1' THEN
      IF page_sel_b < g_nof_pages-1 THEN
        nxt_page_sel_b <= page_sel_b + 1;
        nxt_page_ofs_b <= page_ofs_b + g_page_sz;
      ELSE
        nxt_page_sel_b <= 0;
        nxt_page_ofs_b <= 0;
      END IF;
    END IF;
  END PROCESS;

    
  gen_mux : IF g_str = "use_mux" GENERATE
    gen_pages : FOR I IN 0 TO g_nof_pages-1 GENERATE
      u_ram : ENTITY work.common_ram_crw_crw
      GENERIC MAP (
        g_technology     => g_technology,
        g_ram            => c_page_ram,
        g_init_file      => "UNUSED",
        g_true_dual_port => g_true_dual_port
      )
      PORT MAP (
        rst_a     => rst_a,
        rst_b     => rst_b,
        clk_a     => clk_a,
        clk_b     => clk_b,
        clken_a   => clken_a,
        clken_b   => clken_b,
        adr_a     => adr_a,
        wr_en_a   => page_wr_en_a(I),
        wr_dat_a  => wr_dat_a,
        rd_en_a   => page_rd_en_a(I),
        rd_dat_a  => page_rd_dat_a(I),
        rd_val_a  => page_rd_val_a(I),
        adr_b     => adr_b,
        wr_en_b   => page_wr_en_b(I),
        wr_dat_b  => wr_dat_b,
        rd_en_b   => page_rd_en_b(I),
        rd_dat_b  => page_rd_dat_b(I),
        rd_val_b  => page_rd_val_b(I)
      );
    END GENERATE;
    
    p_mux : PROCESS(page_sel_a, wr_en_a, rd_en_a, page_sel_a_dly, page_rd_dat_a, page_rd_val_a,
                    page_sel_b, wr_en_b, rd_en_b, page_sel_b_dly, page_rd_dat_b, page_rd_val_b)
    BEGIN
      -- use page_sel direct for control
      page_wr_en_a <= (OTHERS=>'0');
      page_wr_en_b <= (OTHERS=>'0');
      page_rd_en_a <= (OTHERS=>'0');
      page_rd_en_b <= (OTHERS=>'0');
      page_wr_en_a(page_sel_a) <= wr_en_a;
      page_wr_en_b(page_sel_b) <= wr_en_b;
      page_rd_en_a(page_sel_a) <= rd_en_a;
      page_rd_en_b(page_sel_b) <= rd_en_b;
      
      -- use page_sel_dly to account for the RAM read latency
      rd_dat_a <= page_rd_dat_a(page_sel_a_dly(g_rd_latency-1));
      rd_dat_b <= page_rd_dat_b(page_sel_b_dly(g_rd_latency-1));
      rd_val_a <= page_rd_val_a(page_sel_a_dly(g_rd_latency-1));
      rd_val_b <= page_rd_val_b(page_sel_b_dly(g_rd_latency-1));
    END PROCESS;
  END GENERATE;  -- gen_mux
  
  gen_adr : IF g_str = "use_adr" GENERATE
    u_mem : ENTITY work.common_ram_crw_crw
    GENERIC MAP (
      g_technology     => g_technology,
      g_ram            => c_mem_ram,
      g_init_file      => "UNUSED",
      g_true_dual_port => g_true_dual_port
    )
    PORT MAP (
      rst_a     => rst_a,
      rst_b     => rst_b,
      clk_a     => clk_a,
      clk_b     => clk_b,
      clken_a   => clken_a,
      clken_b   => clken_b,
      adr_a     => mem_adr_a,
      wr_en_a   => wr_en_a,
      wr_dat_a  => wr_dat_a,
      rd_en_a   => rd_en_a,
      rd_dat_a  => rd_dat_a,
      rd_val_a  => rd_val_a,
      adr_b     => mem_adr_b,
      wr_en_b   => wr_en_b,
      wr_dat_b  => wr_dat_b,
      rd_en_b   => rd_en_b,
      rd_dat_b  => rd_dat_b,
      rd_val_b  => rd_val_b
    );
    
    mem_adr_a <= TO_UVEC(page_sel_a, c_mem_nof_pages_w) & adr_a;
    mem_adr_b <= TO_UVEC(page_sel_b, c_mem_nof_pages_w) & adr_b;
  END GENERATE;  -- gen_adr
  
  
  gen_ofs : IF g_str = "use_ofs" GENERATE
    u_buf : ENTITY work.common_ram_crw_crw
    GENERIC MAP (
      g_technology     => g_technology,
      g_ram            => c_buf_ram,
      g_init_file      => "UNUSED",
      g_true_dual_port => g_true_dual_port
    )
    PORT MAP (
      rst_a     => rst_a,
      rst_b     => rst_b,
      clk_a     => clk_a,
      clk_b     => clk_b,
      clken_a   => clken_a,
      clken_b   => clken_b,
      adr_a     => buf_adr_a,
      wr_en_a   => wr_en_a,
      wr_dat_a  => wr_dat_a,
      rd_en_a   => rd_en_a,
      rd_dat_a  => rd_dat_a,
      rd_val_a  => rd_val_a,
      adr_b     => buf_adr_b,
      wr_en_b   => wr_en_b,
      wr_dat_b  => wr_dat_b,
      rd_en_b   => rd_en_b,
      rd_dat_b  => rd_dat_b,
      rd_val_b  => rd_val_b
    );
    
    buf_adr_a <= INCR_UVEC(RESIZE_UVEC(adr_a, c_buf_addr_w), page_ofs_a);
    buf_adr_b <= INCR_UVEC(RESIZE_UVEC(adr_b, c_buf_addr_w), page_ofs_b);
  END GENERATE;  -- gen_ofs
  
END rtl;
