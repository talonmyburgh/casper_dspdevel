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

LIBRARY IEEE, common_pkg_lib, casper_ram_lib, casper_counter_lib, casper_mm_lib, dp_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE casper_mm_lib.common_field_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

-- Purpose:
--   Store the (auto)power statistics of a complex input stream with
--   blocks of nof_stat multiplexed subbands into a MM register.
-- Description:                                                          
--
--   When the treshold register is set to 0 the statistics will be auto-
--   correlations.
--   In case the treshold register is set to a non-zero value, it allows
--   to create a sample & hold function for the a-input of the multiplier.
--   The a-input of the multiplier is updated every "treshold" clockcycle.
--   Thereby cross statistics can be created.  
--  
--   After each sync the MM register gets updated with the (auto) power statistics
--   of the previous sync interval. The length of the sync interval determines
--   the nof accumlations per statistic, hence the integration time. See st_calc
--   for more details.
-- Remarks:
-- . The in_sync is assumed to be a pulse an interpreted directly.
-- . The MM register is single page RAM to save memory resources. Therefore
--   just after the sync its contents is undefined when it gets written, but
--   after that its contents remains stable for the rest of the sync interval.
--   Therefore it is not necessary to use a dual page register that swaps at
--   the sync. 
-- . The minimum g_nof_stat = 8. Lower values lead to simulation errors. This is
--   due to the read latency of 2 of the accumulation memory in the st_calc entity. 

ENTITY st_sst IS
  GENERIC (
    g_nof_stat      : NATURAL := 512;   -- nof accumulators
    g_xst_enable    : BOOLEAN := FALSE; -- when set to true, an extra memory is instantiated to hold the imaginary part of the cross-correlation results
    g_in_data_w     : NATURAL := 18;    -- width o dth edata to be accumulated
    g_stat_data_w   : NATURAL := 54;    -- statistics accumulator width
    g_stat_data_sz  : NATURAL := 2      -- statistics word width >= statistics accumulator width and fit in a power of 2 multiple 32b MM words
  );                
  PORT (            
    mm_rst          : IN  STD_LOGIC;
    mm_clk          : IN  STD_LOGIC;
    dp_rst          : IN  STD_LOGIC;
    dp_clk          : IN  STD_LOGIC;
                    
    -- Streaming    
    in_complex      : IN  t_dp_sosi;   -- Complex input data
    
    -- Memory Mapped
    ram_st_sst_mosi : IN  t_mem_mosi;  
    ram_st_sst_miso : OUT t_mem_miso;
    reg_st_sst_mosi : IN  t_mem_mosi := c_mem_mosi_rst;  
    reg_st_sst_miso : OUT t_mem_miso := c_mem_miso_rst
  );
END st_sst;


ARCHITECTURE str OF st_sst IS
  
  CONSTANT c_nof_stat_w   : NATURAL := ceil_log2(g_nof_stat);
  CONSTANT c_nof_word     : NATURAL := g_stat_data_sz*g_nof_stat;
  CONSTANT c_nof_word_w   : NATURAL := ceil_log2(c_nof_word);
  CONSTANT g_stat_word_w  : NATURAL := g_stat_data_sz*c_word_w;
  CONSTANT zeros          : STD_LOGIC_VECTOR(c_nof_stat_w-1 DOWNTO 0) := (OTHERS => '0');
  
  -- Statistics register
  CONSTANT c_mm_ram       : t_c_mem := (latency  => 1,
                                        adr_w    => c_nof_word_w,
                                        dat_w    => c_word_w,
                                        nof_dat  => c_nof_word,
                                        init_sl  => '0');           -- MM side : sla_in, sla_out
  CONSTANT c_stat_ram     : t_c_mem := (latency  => 1,
                                        adr_w    => c_nof_stat_w,
                                        dat_w    => g_stat_word_w,
                                        nof_dat  => g_nof_stat,
                                        init_sl  => '0');           -- ST side : stat_mosi
  
  CONSTANT c_field_arr : t_common_field_arr(0 DOWNTO 0) := (0=> ( field_name_pad("treshold"), "RW", c_nof_stat_w, field_default(0) ));

  SIGNAL mm_fields_out : STD_LOGIC_VECTOR(field_slv_out_len(c_field_arr)-1 DOWNTO 0);
  SIGNAL treshold      : STD_LOGIC_VECTOR(c_nof_stat_w-1 DOWNTO 0);  
  
  TYPE reg_type IS RECORD
    in_sosi_reg : t_dp_sosi;  
    in_a_re     : STD_LOGIC_VECTOR(g_in_data_w -1 DOWNTO 0);
    in_a_im     : STD_LOGIC_VECTOR(g_in_data_w -1 DOWNTO 0);
  END RECORD;
  
  SIGNAL r, rin       : reg_type;
  SIGNAL in_sync      : STD_LOGIC;  
  SIGNAL stat_data_re : STD_LOGIC_VECTOR(g_stat_data_w-1 DOWNTO 0);  
  SIGNAL stat_data_im : STD_LOGIC_VECTOR(g_stat_data_w-1 DOWNTO 0);  
  
  SIGNAL wrdata_re    : STD_LOGIC_VECTOR(c_mem_data_w-1 DOWNTO 0);
  SIGNAL wrdata_im    : STD_LOGIC_VECTOR(c_mem_data_w-1 DOWNTO 0);
  
  SIGNAL stat_mosi    : t_mem_mosi;
  SIGNAL count        : STD_LOGIC_VECTOR(c_nof_stat_w-1 DOWNTO 0);

  SIGNAL ram_st_sst_mosi_arr : t_mem_mosi_arr(c_nof_complex-1 DOWNTO 0) := (OTHERS => c_mem_mosi_rst);
  SIGNAL ram_st_sst_miso_arr : t_mem_miso_arr(c_nof_complex-1 DOWNTO 0) := (OTHERS => c_mem_miso_rst);
    
BEGIN

  ------------------------------------------------------------------------------
  -- Register map for the treshold register
  ------------------------------------------------------------------------------
  register_map : ENTITY casper_mm_lib.mm_fields
  GENERIC MAP(
    g_cross_clock_domain => TRUE, 
    g_field_arr          => c_field_arr
  )
  PORT MAP (
    mm_rst  => mm_rst,
    mm_clk  => mm_clk,

    mm_mosi => reg_st_sst_mosi, 
    mm_miso => reg_st_sst_miso, 
    
    slv_rst => dp_rst, 
    slv_clk => dp_clk, 

    slv_out => mm_fields_out
  );

  treshold <= mm_fields_out(field_hi(c_field_arr, "treshold") DOWNTO field_lo(c_field_arr, "treshold"));
  
  ------------------------------------------------------------------------------
  -- Input registers and preparation of the input data for the multiplier. 
  ------------------------------------------------------------------------------
  comb : PROCESS(r, dp_rst, in_complex, count, treshold)
    VARIABLE v : reg_type;
  BEGIN
    v               := r;
    v.in_sosi_reg   := in_complex; 
    
    IF(count = zeros OR treshold = zeros) THEN 
      v.in_a_re  := in_complex.re(g_in_data_w-1 DOWNTO 0);
      v.in_a_im  := in_complex.im(g_in_data_w-1 DOWNTO 0);
    END IF;
   
    IF(dp_rst = '1') THEN
      v.in_a_re := (OTHERS => '0');
      v.in_a_im := (OTHERS => '0');
    END IF;
      
    rin             <= v;  
    
  END PROCESS comb;
  
  regs : PROCESS(dp_clk)
  BEGIN 
    IF rising_edge(dp_clk) THEN 
      r <= rin; 
    END IF; 
  END PROCESS;  

  ------------------------------------------------------------------------------
  -- Counter used to detect when treshold is reached in order to load new 
  -- input vlaues for the multiplier. 
  ------------------------------------------------------------------------------
  treshold_cnt : ENTITY casper_counter_lib.common_counter
  GENERIC MAP(
    g_latency   => 1,            
    g_init      => 0,            
    g_width     => c_nof_stat_w, 
    g_max       => 0,            
    g_step_size => 1            
  )
  PORT MAP (
    rst     => dp_rst,           
    clk     => dp_clk,           
    cnt_clr => in_complex.eop,   
    cnt_en  => in_complex.valid, 
    cnt_max => treshold,       
    count   => count             
  );

  in_sync <= in_complex.sync;
  
  st_calc : ENTITY work.st_calc 
  GENERIC MAP (
    g_nof_mux      => 1,
    g_nof_stat     => g_nof_stat,
    g_in_dat_w     => g_in_data_w,
    g_out_dat_w    => g_stat_data_w,
    g_out_adr_w    => c_nof_stat_w,
    g_complex      => g_xst_enable
  )
  PORT MAP (
    rst            => dp_rst,
    clk            => dp_clk,
    in_ar          => r.in_a_re,
    in_ai          => r.in_a_im,
    in_br          => r.in_sosi_reg.re(g_in_data_w-1 DOWNTO 0),
    in_bi          => r.in_sosi_reg.im(g_in_data_w-1 DOWNTO 0),
    in_val         => r.in_sosi_reg.valid,
    in_sync        => in_sync,
    out_adr        => stat_mosi.address(c_stat_ram.adr_w-1 DOWNTO 0),
    out_re         => stat_data_re,
    out_im         => stat_data_im,
    out_val        => stat_mosi.wr,
    out_val_m      => OPEN
  );
  
  wrdata_re <= RESIZE_MEM_UDATA(stat_data_re);
  wrdata_im <= RESIZE_MEM_UDATA(stat_data_im);
  
  stat_reg_re : ENTITY casper_ram_lib.common_ram_crw_crw_ratio
  GENERIC MAP (
    g_ram_a      => c_mm_ram,
    g_ram_b      => c_stat_ram,
    g_init_file  => "UNUSED"
  )
  PORT MAP (
    rst_a     => mm_rst,
    clk_a     => mm_clk,
    
    rst_b     => dp_rst,
    clk_b     => dp_clk,
    
    wr_en_a   => ram_st_sst_mosi_arr(0).wr,  -- only for diagnostic purposes, typically statistics are read only
    wr_dat_a  => ram_st_sst_mosi_arr(0).wrdata(c_mm_ram.dat_w-1 DOWNTO 0),
    adr_a     => ram_st_sst_mosi_arr(0).address(c_mm_ram.adr_w-1 DOWNTO 0),
    rd_en_a   => ram_st_sst_mosi_arr(0).rd,
    rd_dat_a  => ram_st_sst_miso_arr(0).rddata(c_mm_ram.dat_w-1 DOWNTO 0),
    rd_val_a  => ram_st_sst_miso_arr(0).rdval,
    
    wr_en_b   => stat_mosi.wr,
    wr_dat_b  => wrdata_re(c_stat_ram.dat_w-1 DOWNTO 0),
    adr_b     => stat_mosi.address(c_stat_ram.adr_w-1 DOWNTO 0),
    rd_en_b   => '0',
    rd_dat_b  => OPEN,
    rd_val_b  => OPEN
  );                                   
 
  gen_re: IF g_xst_enable=FALSE GENERATE
    ram_st_sst_mosi_arr(0) <= ram_st_sst_mosi;
    ram_st_sst_miso        <= ram_st_sst_miso_arr(0);
  END GENERATE;
  
  gen_im: IF g_xst_enable=TRUE GENERATE
    ---------------------------------------------------------------
    -- COMBINE MEMORY MAPPED INTERFACES
    ---------------------------------------------------------------
    -- Combine the internal array of mm interfaces for both real
    -- and imaginary part. 
    u_mem_mux_select : entity casper_mm_lib.common_mem_mux
    generic map (    
      g_nof_mosi    => c_nof_complex,
      g_mult_addr_w => c_nof_word_w
    )
    port map (
      mosi     => ram_st_sst_mosi,
      miso     => ram_st_sst_miso,
      mosi_arr => ram_st_sst_mosi_arr,
      miso_arr => ram_st_sst_miso_arr
    );
  
    stat_reg_im : ENTITY casper_ram_lib.common_ram_crw_crw_ratio
    GENERIC MAP (
      g_ram_a      => c_mm_ram,
      g_ram_b      => c_stat_ram,
      g_init_file  => "UNUSED"
    )
    PORT MAP (
      rst_a     => mm_rst,
      clk_a     => mm_clk,
      
      rst_b     => dp_rst,
      clk_b     => dp_clk,
      
      wr_en_a   => ram_st_sst_mosi_arr(1).wr,  -- only for diagnostic purposes, typically statistics are read only
      wr_dat_a  => ram_st_sst_mosi_arr(1).wrdata(c_mm_ram.dat_w-1 DOWNTO 0),
      adr_a     => ram_st_sst_mosi_arr(1).address(c_mm_ram.adr_w-1 DOWNTO 0),
      rd_en_a   => ram_st_sst_mosi_arr(1).rd,
      rd_dat_a  => ram_st_sst_miso_arr(1).rddata(c_mm_ram.dat_w-1 DOWNTO 0),
      rd_val_a  => ram_st_sst_miso_arr(1).rdval,
      
      wr_en_b   => stat_mosi.wr,
      wr_dat_b  => wrdata_im(c_stat_ram.dat_w-1 DOWNTO 0),
      adr_b     => stat_mosi.address(c_stat_ram.adr_w-1 DOWNTO 0),
      rd_en_b   => '0',
      rd_dat_b  => OPEN,
      rd_val_b  => OPEN
    );     
    
  END GENERATE;
  
END str;
