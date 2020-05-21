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
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;


ENTITY st_ctrl IS
  GENERIC (
    g_nof_mux    : NATURAL := 1;
    g_nof_stat   : NATURAL := 512;
    g_adr_w      : NATURAL := 9;     -- ceil_log2(g_nof_mux*g_nof_stat)
    g_dly_rd     : NATURAL := 1; 
    g_dly_mul    : NATURAL := 4;
    g_dly_acc    : NATURAL := 2;
    g_dly_out    : NATURAL := 2
  );
  PORT (
    rst          : IN  STD_LOGIC;
    clk          : IN  STD_LOGIC;
    
    in_sync      : IN  STD_LOGIC;
    in_val       : IN  STD_LOGIC;

    rd_en        : OUT STD_LOGIC;
    rd_adr       : OUT STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0);
    rd_val       : OUT STD_LOGIC;
        
    mult_val     : OUT STD_LOGIC;    
    acc_load     : OUT STD_LOGIC;
    
    wr_en        : OUT STD_LOGIC;
    wr_adr       : OUT STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0);
    
    out_val      : OUT STD_LOGIC;
    out_val_m    : OUT STD_LOGIC_VECTOR(g_nof_mux-1 DOWNTO 0);
    out_adr      : OUT STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0)
  );
END;


ARCHITECTURE rtl OF st_ctrl IS

 CONSTANT c_mux_w     : NATURAL := true_log2(g_nof_mux);
 
 CONSTANT c_tin_mul   : NATURAL := 0;
 CONSTANT c_tot_mul   : NATURAL := c_tin_mul + g_dly_mul;
 
 CONSTANT c_tin_acc   : NATURAL := c_tot_mul;
 CONSTANT c_tot_acc   : NATURAL := c_tin_acc + g_dly_acc; 
 
 CONSTANT c_tin_wr    : NATURAL := c_tot_acc;  
 
 CONSTANT c_tin_rd    : NATURAL := c_tin_acc - g_dly_rd; 
 CONSTANT c_tot_rd    : NATURAL := c_tin_acc;
 
 CONSTANT c_tin_out   : NATURAL := c_tot_rd;
 CONSTANT c_tot_out   : NATURAL := c_tin_out + g_dly_out; 
  
 SIGNAL dly_val       : STD_LOGIC_VECTOR(0 TO c_tin_wr);
 SIGNAL dly_sync      : STD_LOGIC_VECTOR(0 TO c_tin_wr); 
 SIGNAL dly_load      : STD_LOGIC_VECTOR(c_tin_rd TO c_tin_wr);
 
 SIGNAL i_rd_adr      : STD_LOGIC_VECTOR(rd_adr'RANGE);
 SIGNAL nxt_rd_adr    : STD_LOGIC_VECTOR(rd_adr'RANGE);
 
 SIGNAL i_wr_adr      : STD_LOGIC_VECTOR(wr_adr'RANGE);
 SIGNAL nxt_wr_adr    : STD_LOGIC_VECTOR(wr_adr'RANGE);
 
 SIGNAL i_out_adr     : STD_LOGIC_VECTOR(out_adr'RANGE);
 SIGNAL nxt_out_adr   : STD_LOGIC_VECTOR(out_adr'RANGE);
 
 SIGNAL i_out_val     : STD_LOGIC;

 SIGNAL nxt_load      : STD_LOGIC; 
 
BEGIN

  -- hardwired
  
  dly_val (0) <= in_val;
  dly_sync(0) <= in_sync;
  
  rd_en    <= dly_val (c_tin_rd);
  rd_val   <= dly_val (c_tot_rd);
  
  mult_val <= dly_val(c_tin_acc);  
  acc_load <= dly_load(c_tin_acc) OR (NOT dly_val(c_tin_acc));  
  
  wr_en     <= dly_val(c_tin_wr);
  i_out_val <= dly_load(c_tot_out) AND dly_val(c_tot_out);
  
  rd_adr   <= i_rd_adr;
  wr_adr   <= i_wr_adr;
  out_adr  <= i_out_adr;  
  out_val  <= i_out_val;  
  
  no_mux : IF g_nof_mux = 1 GENERATE
    out_val_m <= (OTHERS => 'X');
  END GENERATE;
  
  gen_mux : IF g_nof_mux > 1 GENERATE
    p_out_val_m: PROCESS (i_out_val, i_out_adr)
    BEGIN
      out_val_m <= (OTHERS => '0');
      FOR i IN 0 TO g_nof_mux-1 LOOP
        IF UNSIGNED(i_out_adr(c_mux_w-1 DOWNTO 0)) = i THEN
          out_val_m(i) <= i_out_val;
        END IF;
      END LOOP;
    END PROCESS;
  END GENERATE;
  
  -- registers
  regs: PROCESS(rst,clk)
  BEGIN
    IF rst='1' THEN
      i_rd_adr  <= (OTHERS => '0');
      i_wr_adr  <= (OTHERS => '0');
      i_out_adr <= (OTHERS => '0');
      dly_load  <= (OTHERS => '1');
      dly_val (dly_val 'LOW+1 TO dly_val 'HIGH)  <= (OTHERS => '0');      
      dly_sync(dly_sync'LOW+1 TO dly_sync'HIGH)  <= (OTHERS => '0');  
    ELSIF rising_edge(clk) THEN
      i_rd_adr  <= nxt_rd_adr;
      i_wr_adr  <= nxt_wr_adr;
      i_out_adr <= nxt_out_adr;
      dly_load  <= nxt_load & dly_load(dly_load'LOW TO dly_load'HIGH-1);
      dly_val (dly_val 'LOW+1 TO dly_val 'HIGH) <= dly_val  (dly_val 'LOW to dly_val 'HIGH-1);
      dly_sync(dly_sync'LOW+1 TO dly_sync'HIGH) <= dly_sync (dly_sync'LOW to dly_sync'HIGH-1);
    END IF;
  END PROCESS;
  
  rd_ctrl: PROCESS(i_rd_adr, dly_load, dly_val, dly_sync)
  BEGIN
    nxt_load   <= dly_load(dly_load'LOW);        
    nxt_rd_adr <= i_rd_adr;
    IF dly_sync(c_tin_rd)='1' THEN
      nxt_rd_adr <= (OTHERS => '0');
      nxt_load   <= '1';
    ELSIF dly_val(c_tin_rd)='1' THEN
      IF UNSIGNED(i_rd_adr)=g_nof_mux*g_nof_stat-1 THEN
        nxt_rd_adr <= (OTHERS => '0');
        nxt_load   <= '0';
      ELSE
        nxt_rd_adr <= STD_LOGIC_VECTOR(UNSIGNED(i_rd_adr)+1);
      END IF;
    END IF;
  END PROCESS;
  
  out_ctrl: PROCESS(i_out_adr, dly_val, dly_sync)
  BEGIN
    nxt_out_adr   <= i_out_adr;    
    IF dly_sync(c_tot_out)='1' THEN
      nxt_out_adr <= (OTHERS => '0');
    ELSIF dly_val(c_tot_out)='1' THEN
      IF UNSIGNED(i_out_adr)=g_nof_mux*g_nof_stat-1 THEN
        nxt_out_adr <= (OTHERS => '0');
      ELSE
        nxt_out_adr <= STD_LOGIC_VECTOR(UNSIGNED(i_out_adr)+1);
      END IF;
    END IF;
  END PROCESS;
  
  wr_ctrl: PROCESS(i_wr_adr,dly_val,dly_sync)
  BEGIN
    nxt_wr_adr   <= i_wr_adr;  
    IF dly_sync(c_tin_wr)='1' THEN
      nxt_wr_adr <= (OTHERS => '0');
    ELSIF dly_val(c_tin_wr)='1' THEN
      IF UNSIGNED(i_wr_adr)=g_nof_mux*g_nof_stat-1 THEN
        nxt_wr_adr <= (OTHERS => '0');
      ELSE
        nxt_wr_adr <= STD_LOGIC_VECTOR(UNSIGNED(i_wr_adr)+1);
      END IF;
    END IF;
  END PROCESS;  
    
END rtl;
