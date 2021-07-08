-------------------------------------------------------------------------------
--
-- Copyright (C) 2012
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
-------------------------------------------------------------------------------
-- Purpose: Performing a poly phase prefilter (PPF) function on one or multiple datastreams.
--
-- Description:
--   The poly phase prefilter (PPF) function is based on a taps memory, a
--   coefficients memory, a filter and a control unit.
--
--   The control unit writes the incoming data to the taps memory, along with
--   the historical tap data. It also drives the read addresses for both the
--   taps- and the coefficients memory. The output of the taps memory and the
--   coefficients memory are connected to the input of the filter unit that
--   peforms the actual filter function(multiply and accumulate). The prefilter
--   support multiple streams that share the same filter coefficients. The
--   filter coefficients can be written and read via the MM interface. 
--
--   The PPF introduces a data valid latency of 1 tap, so nof_bands samples.
--   The nof_bands = nof_points of the FFT that gets the PPF output.
--
--   The following example shows the working for the poly phase prefilter
--   where nof_bands=4 and nof_taps=2. The total number of coefficients is 8.
--   For the given input stream all the multiplications and additions are
--   given that are required to generate the given output stream. Note that
--   every input sample is used nof_taps=2 times.
--                  
--   Time:                t0 t1 ....
--   Incoming datastream: a0 a1 a2 a3 b0 b1 b2 b3 c0 c1 c2 c3 ....
--   Outgoing datastream:             A0 A1 A2 A3 B0 B1 B2 B3 C0 C1 C2 C3 ....
--
--              A0 = coef0*a0 + coef1*b0
--              A1 = coef2*a1 + coef3*b1
--              A2 = coef4*a2 + coef5*b2
--              A3 = coef6*a3 + coef7*b3
--
--              B0 = coef0*b0 + coef1*c0
--              B1 = coef2*b1 + coef3*c1
--              B2 = coef4*b2 + coef5*c2
--              B3 = coef6*b3 + coef7*c3
--
--              C0 = coef0*c0 + coef1*d0
--              C1 = coef2*c1 + coef3*d1
--              C2 = coef4*c2 + coef5*d2
--              C3 = coef6*c3 + coef7*d3
--
-- Remarks:
-- .  See also description tb_fil_ppf_single.vhd for more info.
--
library IEEE, common_pkg_lib, casper_ram_lib, casper_mm_lib;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;
use common_pkg_lib.common_pkg.ALL; 
use casper_ram_lib.common_ram_pkg.ALL;  
use work.fil_pkg.ALL;

entity fil_ppf_single is
  generic (
    g_fil_ppf           : t_fil_ppf          := c_fil_ppf;    
    g_fil_ppf_pipeline  : t_fil_ppf_pipeline := c_fil_ppf_pipeline; 
    g_file_index_arr    : t_nat_natural_arr  := array_init(0, 128, 1);  -- default use the instance index as file index 0, 1, 2, 3, 4 ...
    g_coefs_file_prefix : string             := c_coefs_file;    -- Relative path to the mem files that contain the initial data for the coefficients memories
    g_technology        : natural            := 0;
    g_ram_primitive     : string             := "auto" 
  );                                                                    
  port (
    clk         : in  std_logic;
    ce          : in  std_logic;
    rst         : in  std_logic;
    -- mm_clk         : in  std_logic;
    -- mm_rst         : in  std_logic;
    -- ram_coefs_mosi : in  t_mem_mosi;               
    -- ram_coefs_miso : out t_mem_miso := c_mem_miso_rst;
    in_dat         : in  std_logic_vector(g_fil_ppf.nof_streams*g_fil_ppf.in_dat_w-1 downto 0);
    in_val         : in  std_logic;  
    out_dat        : out std_logic_vector(g_fil_ppf.nof_streams*g_fil_ppf.out_dat_w-1 downto 0);
    out_val        : out std_logic
  ); 
end fil_ppf_single;

architecture rtl of fil_ppf_single is                                                                                
  
  constant c_coefs_postfix   : string  := sel_a_b(g_technology = 0, ".mem", ".mif"); 
  constant c_taps_mem_addr_w : natural := ceil_log2(g_fil_ppf.nof_bands * (2**g_fil_ppf.nof_chan));
  constant c_coef_mem_addr_w : natural := ceil_log2(g_fil_ppf.nof_bands);
  constant c_taps_mem_delay  : natural := g_fil_ppf_pipeline.mem_delay;                                                                                                              
  constant c_coef_mem_delay  : natural := g_fil_ppf_pipeline.mem_delay;
  constant c_taps_mem_data_w : natural := g_fil_ppf.in_dat_w*g_fil_ppf.nof_taps;
  constant c_coef_mem_data_w : natural := g_fil_ppf.coef_dat_w;

  constant c_taps_mem : t_c_mem := (latency   => c_taps_mem_delay,
                                    adr_w     => c_taps_mem_addr_w,
                                    dat_w     => c_taps_mem_data_w,
                                    nof_dat   => g_fil_ppf.nof_bands * (2**g_fil_ppf.nof_chan),
                                    init_sl   => '0');  -- use '0' instead of 'X' to avoid RTL RAM simulation warnings due to read before write

  constant c_coef_mem : t_c_mem := (latency   => c_coef_mem_delay,
                                    adr_w     => c_coef_mem_addr_w,
                                    dat_w     => c_coef_mem_data_w,
                                    nof_dat   => g_fil_ppf.nof_bands,
                                    init_sl   => '0');  -- use '0' instead of 'X' to avoid RTL RAM simulation warnings due to read before write

  -- signal ram_coefs_mosi_arr : t_mem_mosi_arr(g_fil_ppf.nof_taps-1 downto 0);                               
  -- signal ram_coefs_miso_arr : t_mem_miso_arr(g_fil_ppf.nof_taps-1 downto 0) := (others => c_mem_miso_rst); 
  signal taps_wren          : std_logic;
  signal taps_rdaddr        : std_logic_vector(c_taps_mem_addr_w-1 downto 0); 
  signal taps_wraddr        : std_logic_vector(c_taps_mem_addr_w-1 downto 0);
  signal taps_mem_out_vec   : std_logic_vector(c_taps_mem_data_w*g_fil_ppf.nof_streams-1 downto 0);
  signal taps_mem_in_vec    : std_logic_vector(c_taps_mem_data_w*g_fil_ppf.nof_streams-1 downto 0);
  signal coef_rdaddr        : std_logic_vector(c_coef_mem_addr_w-1 downto 0);     
  signal coef_vec           : std_logic_vector(c_coef_mem_data_w*g_fil_ppf.nof_taps-1 downto 0);

  signal wr_dat           :std_logic_vector(c_coef_mem_data_w-1 DOWNTO 0) := (others => '0');
  signal wr_adr           :std_logic_vector(c_coef_mem_addr_w-1 DOWNTO 0) := (others => '0');
                                                                                                                 
begin 

  ---------------------------------------------------------------
  -- MEMORY FOR THE HISTORICAL TAP DATA
  ---------------------------------------------------------------
  gen_taps_mems : for I in 0 to g_fil_ppf.nof_streams-1 generate
    u_taps_mem : entity casper_ram_lib.common_ram_r_w                                                          
    generic map (                                                                                    
      g_ram           => c_taps_mem,                                                                           
      g_init_file     => "UNUSED",     -- assume block RAM gets initialized to '0' by default in simulation
      g_ram_primitive => g_ram_primitive
    )                                                                                               
    port map (                                                                                                                                                                     
      clk       => clk,
      clken     => ce,                                                                               
      wr_en     => taps_wren,                                                                              
      wr_adr    => taps_wraddr,                                                                            
      wr_dat    => taps_mem_in_vec((I+1)*c_taps_mem_data_w-1 downto I*c_taps_mem_data_w),                                                                            
      rd_en     => '1',                                                                               
      rd_adr    => taps_rdaddr,                                                                            
      rd_dat    => taps_mem_out_vec((I+1)*c_taps_mem_data_w-1 downto I*c_taps_mem_data_w),  
      rd_val    => open                                                                               
    );  
  end generate;
  ---------------------------------------------------------------
  -- COMBINE MEMORY MAPPED INTERFACES
  ---------------------------------------------------------------
  -- Combine the internal array of mm interfaces for the coefficents 
  -- memory to one array that is connected to the port of the fil_ppf
  -- u_mem_mux_coef : entity casper_mm_lib.common_mem_mux
  -- generic map (    
  --   g_nof_mosi    => g_fil_ppf.nof_taps,
  --   g_mult_addr_w => c_coef_mem_addr_w
  -- )
  -- port map (
  --   mosi     => ram_coefs_mosi,
  --   miso     => ram_coefs_miso,
  --   mosi_arr => ram_coefs_mosi_arr,
  --   miso_arr => ram_coefs_miso_arr
  -- );

  ---------------------------------------------------------------
  -- GENERATE THE COEFFICIENT MEMORIES
  ---------------------------------------------------------------
  -- For every tap a unique memory is instantiated that holds
  -- the corresponding coefficients for all the bands. 
  gen_coefs_mems : for I in 0 to g_fil_ppf.nof_taps-1 generate
    u_coef_mem : entity casper_ram_lib.common_ram_r_w
    generic map (
      g_ram           =>     c_coef_mem,
      g_init_file     =>     sel_a_b(g_coefs_file_prefix = "UNUSED", 
                             g_coefs_file_prefix, 
                             g_coefs_file_prefix 
                             & "_" & integer'image(g_fil_ppf.wb_factor) 
                             & "wb" & "_" 
                             & NATURAL'IMAGE(g_file_index_arr(I)) & c_coefs_postfix),
      g_ram_primitive =>     g_ram_primitive,
      g_true_dual_port =>    FALSE
    )
    port map
    (
      clk =>        clk,
      clken =>      ce,
      wr_en =>      '0',
      wr_dat =>     wr_dat,
      wr_adr =>     wr_adr,
      rd_adr =>     coef_rdaddr,
      rd_en =>      '1',
      rd_dat =>     coef_vec((I+1)*c_coef_mem_data_w-1 downto I*c_coef_mem_data_w),
      rd_val =>     open
    );
  end generate;


  -- gen_coef_mems : for I in 0 to g_fil_ppf.nof_taps-1 generate
  --   u_coef_mem : entity casper_ram_lib.common_ram_crw_crw
  --   generic map (
  --     g_technology => g_technology,
  --     g_ram        => c_coef_mem,                                                  
  --     g_init_file  => g_coefs_file_prefix,
  --     g_ram_primitive => g_ram_primitive    
  --   )
  --   port map (
  --     -- MM side
  --     clk_a     => '0',                                                                     --mm_clk,
  --     clken_a   => '0',
  --     wr_en_a   => '0',                                                                     --ram_coefs_mosi_arr(I).wr,
  --     wr_dat_a  => wr_dat,                                                           --ram_coefs_mosi_arr(I).wrdata(g_fil_ppf.coef_dat_w-1 downto 0),
  --     adr_a     => wr_adr,                                                           --ram_coefs_mosi_arr(I).address(c_coef_mem.adr_w-1 downto 0),
  --     rd_en_a   => '0',                                                                     --ram_coefs_mosi_arr(I).rd,
  --     rd_dat_a  => open,                                                           --ram_coefs_miso_arr(I).rddata(g_fil_ppf.coef_dat_w-1 downto 0),
  --     rd_val_a  => open,                                                                     --ram_coefs_miso_arr(I).rdval,
  --     -- Datapath side
  --     clk_b     => clk,
  --     clken_b   => ce,
  --     wr_en_b   => '0',
  --     wr_dat_b  => wr_dat,
  --     adr_b     => coef_rdaddr,
  --     rd_en_b   => '1',
  --     rd_dat_b  => coef_vec((I+1)*c_coef_mem_data_w-1 downto I*c_coef_mem_data_w),
  --     rd_val_b  => open
  --   );
  -- end generate;              
  
  -- Address the coefficients, taking into account the nof_chan. The coefficients will only be
  -- updated if all 2**nof_chan time-multiples signals are processed. 
  coef_rdaddr <= taps_rdaddr(c_taps_mem_addr_w-1 downto (c_taps_mem_addr_w - c_coef_mem_addr_w));

  ---------------------------------------------------------------
  -- FILTER CONTROL UNIT
  ---------------------------------------------------------------
  -- The control unit receives the input data and writes it to 
  -- the tap memory, along with the historical tap data. 
  -- It also controls the reading of the coefficients memory.
  u_fil_ctrl : entity work.fil_ppf_ctrl
  generic map (
    g_fil_ppf_pipeline => g_fil_ppf_pipeline,
    g_fil_ppf          => g_fil_ppf
  )
  port map (
    clk          => clk,
    ce           => ce,
    rst          => rst,
    in_dat       => in_dat,
    in_val       => in_val,
    taps_rdaddr  => taps_rdaddr,
    taps_wraddr  => taps_wraddr,
    taps_wren    => taps_wren,
    taps_in_vec  => taps_mem_out_vec,
    taps_out_vec => taps_mem_in_vec,
    out_val      => out_val
  );

  ---------------------------------------------------------------
  -- FILTER UNIT
  ---------------------------------------------------------------
  -- The actual filter unit that performs the filter operations: 
  -- multiplications and additions.
  gen_filter_units : for I in 0 to g_fil_ppf.nof_streams-1 generate
    u_filter : entity work.fil_ppf_filter
    generic map (
      g_fil_ppf_pipeline => g_fil_ppf_pipeline,
      g_fil_ppf          => g_fil_ppf
    )
    port map (
      clk       => clk,  
      rst       => rst,
      taps      => taps_mem_out_vec((I+1)*c_taps_mem_data_w-1 downto I*c_taps_mem_data_w),
      coefs     => coef_vec,
      result    => out_dat((I+1)*g_fil_ppf.out_dat_w-1 downto I*g_fil_ppf.out_dat_w)
    );
  end generate;
      
end rtl;                                                                                
