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

LIBRARY IEEE, common_pkg_lib, casper_ram_lib, casper_multiplier_lib;
USE IEEE.std_logic_1164.ALL;
--USE technology_lib.technology_select_pkg.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;

-- Purpose:
--   Maintain a set of accumulators and output their values at every in_sync.
-- Description:
-- . The products of two input streams are accumulated per block. The block
--   size is g_nof_mux*g_nof_stat. The nof accumulators is equal to the block
--   size. The nof blocks that get accumulated depends on in_sync, because a
--   new accumulation starts every time when in_sync pulses. Also when in_sync
--   pulses then after some latency the accumulation values of the previous
--   in_sync interval become available at the out_* ports.
-- . If g_complex = FALSE then only the real power statistic out_re is calculated,
--   else also the imaginary power statistic out_im. The real power statistic
--   is used for auto power calulations of a complex input, by connecting the
--   signal to both input a and b. The imaginary is power statistic is used when
--   the cross power needs to be calculated between 2 different complex inputs.
-- Remarks:
-- . The required accumulator width depends the input data width and the nof of
--   block, i.e. the nof accumulations. E.g. for 18b*18b = 36b products and
--   200000 accumulations yielding 18b bit growth so in total 36b+18b = 54b for
--   the accumulators.
-- . The nof accumulators determines the size (c_mem_acc) of the internal
--   accumulator memory.
-- . Using g_nof_mux>1 allows distinghuising different streams with a block.
--   The g_nof_mux does not impact the address range instead it impacts the
--   out_val_m strobes that can be used as wr_en to the corresponding statistics
--   output register in a range of g_nof_mux statistics output registers.

ENTITY st_calc IS
  GENERIC (
    g_technology   : NATURAL := 0;
    g_nof_mux      : NATURAL := 1;
    g_nof_stat     : NATURAL := 512;
    g_in_dat_w     : NATURAL := 18;  -- = input data width
    g_out_dat_w    : NATURAL := 54;  -- = accumulator width for the input data products, so >> 2*g_in_dat_w
    g_out_adr_w    : NATURAL := 9;   -- = ceil_log2(g_nof_stat)
    g_complex      : BOOLEAN := FALSE;
    g_ram_primitive : STRING := "auto"
    );
  PORT (
    rst            : IN   STD_LOGIC;
    clk            : IN   STD_LOGIC;
    clken          : IN   STD_LOGIC := '1';
    in_ar          : IN   STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
    in_ai          : IN   STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
    in_br          : IN   STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
    in_bi          : IN   STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
    in_val         : IN   STD_LOGIC;
    in_sync        : IN   STD_LOGIC;
    out_adr        : OUT  STD_LOGIC_VECTOR(g_out_adr_w-1 DOWNTO 0);
    out_re         : OUT  STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);
    out_im         : OUT  STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);
    out_val        : OUT  STD_LOGIC;                                -- Use when g_nof_mux = 1, else leave OPEN
    out_val_m      : OUT  STD_LOGIC_VECTOR(g_nof_mux-1 DOWNTO 0)    -- Use when g_nof_mux > 1, else leave OPEN
  );
END;


ARCHITECTURE str OF st_calc IS

  CONSTANT c_mux_w           : NATURAL := true_log2(g_nof_mux);
  CONSTANT c_adr_w           : NATURAL := c_mux_w+g_out_adr_w;   -- = = ceil_log2(g_nof_mux*g_nof_stat)
  
  CONSTANT c_dly_rd          : NATURAL := 2;
  CONSTANT c_dly_mul         : NATURAL := 3;
  CONSTANT c_dly_acc         : NATURAL := 2;
  CONSTANT c_dly_out         : NATURAL := 0;
 
  CONSTANT c_mult_w          : NATURAL := 2*g_in_dat_w;
  
  CONSTANT c_acc_w           : NATURAL := g_out_dat_w;
  CONSTANT c_acc_hold_load   : BOOLEAN := TRUE;
  
  CONSTANT c_rd_latency      : NATURAL := 2;
  CONSTANT c_mem_acc         : t_c_mem := (c_rd_latency, c_adr_w,  c_acc_w, g_nof_mux*g_nof_stat, 'X');  -- 1 M9K
  
  
  SIGNAL mult_re       : STD_LOGIC_VECTOR(c_mult_w-1 DOWNTO 0);
  SIGNAL mult_im       : STD_LOGIC_VECTOR(c_mult_w-1 DOWNTO 0);

  SIGNAL reg_ar        : STD_LOGIC_VECTOR(in_ar'RANGE);
  SIGNAL reg_ai        : STD_LOGIC_VECTOR(in_ai'RANGE);
  SIGNAL reg_br        : STD_LOGIC_VECTOR(in_br'RANGE);
  SIGNAL reg_bi        : STD_LOGIC_VECTOR(in_bi'RANGE);
  SIGNAL reg_val       : STD_LOGIC;
  SIGNAL reg_sync      : STD_LOGIC;

  SIGNAL nxt_reg_ar    : STD_LOGIC_VECTOR(in_ar'RANGE);
  SIGNAL nxt_reg_ai    : STD_LOGIC_VECTOR(in_ai'RANGE);
  SIGNAL nxt_reg_br    : STD_LOGIC_VECTOR(in_br'RANGE);
  SIGNAL nxt_reg_bi    : STD_LOGIC_VECTOR(in_bi'RANGE);
  SIGNAL nxt_reg_val   : STD_LOGIC;
  SIGNAL nxt_reg_sync  : STD_LOGIC;  

  SIGNAL acc_load      : STD_LOGIC;  

  SIGNAL rd_en         : STD_LOGIC;  
  SIGNAL rd_adr        : STD_LOGIC_VECTOR(c_adr_w-1 DOWNTO 0);
  SIGNAL rd_re         : STD_LOGIC_VECTOR(c_acc_w-1 DOWNTO 0);
  SIGNAL rd_im         : STD_LOGIC_VECTOR(c_acc_w-1 DOWNTO 0);
  
  SIGNAL wr_en         : STD_LOGIC;  
  SIGNAL wr_adr        : STD_LOGIC_VECTOR(c_adr_w-1 DOWNTO 0);
  SIGNAL wr_re         : STD_LOGIC_VECTOR(c_acc_w-1 DOWNTO 0);
  SIGNAL wr_im         : STD_LOGIC_VECTOR(c_acc_w-1 DOWNTO 0);
  
  SIGNAL out_adr_m     : STD_LOGIC_VECTOR(c_adr_w-1 DOWNTO 0);
  
BEGIN

  regs: PROCESS(rst,clk)
  BEGIN
    IF rst='1' THEN
      reg_ar   <= (OTHERS => '0');
      reg_ai   <= (OTHERS => '0');
      reg_br   <= (OTHERS => '0');
      reg_bi   <= (OTHERS => '0');
      reg_val  <= '0';
      reg_sync <= '0';
    ELSIF rising_edge(clk) THEN
      reg_ar   <= nxt_reg_ar;
      reg_ai   <= nxt_reg_ai;
      reg_br   <= nxt_reg_br;
      reg_bi   <= nxt_reg_bi;
      reg_val  <= nxt_reg_val;
      reg_sync <= nxt_reg_sync;
    END IF;
  END PROCESS;
  
  nxt_reg_ar   <= in_ar WHEN in_val='1' ELSE reg_ar;
  nxt_reg_ai   <= in_ai WHEN in_val='1' ELSE reg_ai;
  nxt_reg_br   <= in_br WHEN in_val='1' ELSE reg_br;
  nxt_reg_bi   <= in_bi WHEN in_val='1' ELSE reg_bi;
  nxt_reg_val  <= in_val;
  nxt_reg_sync <= in_sync;    

  -- ctrl block: generates all ctrl signals   
  ctrl: ENTITY work.st_ctrl
  GENERIC MAP (
    g_nof_mux    => g_nof_mux,
    g_nof_stat   => g_nof_stat,
    g_adr_w      => c_adr_w,
    g_dly_rd     => c_dly_rd, 
    g_dly_mul    => c_dly_mul,
    g_dly_acc    => c_dly_acc,
    g_dly_out    => c_dly_out
  )
  PORT MAP (
    rst          => rst,
    clk          => clk,
    in_sync      => reg_sync,
    in_val       => reg_val,
    rd_en        => rd_en,
    rd_adr       => rd_adr,
    rd_val       => OPEN,
    mult_val     => OPEN,
    acc_load     => acc_load,
    wr_en        => wr_en,
    wr_adr       => wr_adr,
    out_val      => out_val,
    out_val_m    => out_val_m,
    out_adr      => out_adr_m
  ); 
  
  out_adr <= out_adr_m(c_adr_w-1 DOWNTO c_mux_w);
  
  -- complex multiplier: computes a * conj(b)
  --mul: ENTITY common_lib.common_complex_mult(str)
  mul: ENTITY casper_multiplier_lib.common_complex_mult
  GENERIC MAP (
    g_technology       => g_technology,
    g_variant          => "IP",
    g_in_a_w           => in_ar'LENGTH,
    g_in_b_w           => in_br'LENGTH,
    g_out_p_w          => mult_re'LENGTH,
    g_conjugate_b      => TRUE,  -- use conjugate product for cross power
    g_pipeline_input   => 1,
    g_pipeline_product => 0,
    g_pipeline_adder   => 1,
    g_pipeline_output  => 1   -- 1+0+1+1 = 3 = c_dly_mul
  )
  PORT MAP (
    clk        => clk,
    clken      => clken,
    in_ar      => reg_ar,
    in_ai      => reg_ai,
    in_br      => reg_br,
    in_bi      => reg_bi,
    out_pr     => mult_re,
    out_pi     => mult_im
  );     
  
  -- accumulator for real part  
  acc_re: ENTITY work.st_acc
  GENERIC MAP (
    g_dat_w           => c_mult_w,
    g_acc_w           => c_acc_w,
    g_hold_load       => c_acc_hold_load,
    g_pipeline_input  => 1,
    g_pipeline_output => c_dly_acc-1
  )
  PORT MAP (
    clk         => clk,
    clken       => clken,
    in_load     => acc_load,
    in_dat      => mult_re,
    in_acc      => rd_re,
    out_acc     => wr_re
  );

  -- accumulator memory for real part  
  ram_re: ENTITY casper_ram_lib.common_ram_r_w
  GENERIC MAP (
    g_technology => g_technology,
    g_ram        => c_mem_acc,
    g_init_file  => "UNUSED",
    g_ram_primitive => g_ram_primitive
  )
  PORT MAP (
    clk       => clk,
    clken     => clken,
    wr_en     => wr_en,
    wr_adr    => wr_adr,
    wr_dat    => wr_re,
    rd_en     => rd_en,
    rd_adr    => rd_adr,
    rd_dat    => rd_re,
    rd_val    => OPEN
  );

  out_re <= rd_re;  -- c_dly_out = 0
  
  -- imaginary part is optional  
  no_im: IF g_complex=FALSE GENERATE
    out_im <= (OTHERS => '0');
  END GENERATE;
    
  gen_im: IF g_complex=TRUE GENERATE
    -- accumulator
    acc_im: ENTITY work.st_acc
    GENERIC MAP (
      g_dat_w           => c_mult_w,
      g_acc_w           => c_acc_w,
      g_hold_load       => c_acc_hold_load,
      g_pipeline_input  => 1,
      g_pipeline_output => c_dly_acc-1
    )
    PORT MAP (
      clk         => clk,
      clken       => clken,
      in_load     => acc_load,
      in_dat      => mult_im,
      in_acc      => rd_im,
      out_acc     => wr_im
    );
    
    -- dual port memory
    ram_im: ENTITY casper_ram_lib.common_ram_r_w
    GENERIC MAP (
      g_technology => g_technology,
      g_ram        => c_mem_acc,
      g_init_file  => "UNUSED",
      g_ram_primitive => g_ram_primitive
    )
    PORT MAP (
      clk       => clk,
      clken     => clken,
      wr_en     => wr_en,
      wr_adr    => wr_adr,
      wr_dat    => wr_im,
      rd_en     => rd_en,
      rd_adr    => rd_adr,
      rd_dat    => rd_im,
      rd_val    => OPEN
    );    
    
    out_im <= rd_im;  -- c_dly_out = 0
  END GENERATE;
  
END str;
