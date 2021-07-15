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
-- Purpose: Performing a poly phase prefilter (PPF) function on one or more
--          wideband data stream.
--
-- Description:
--   The poly phase prefilter function is applied on multiple inputs. In
--   array notation:
--
--               parallel                 serial             type
--   in_dat_arr  [wb_factor][nof_streams] [t][nof_channels]  int
--   out_dat_arr [wb_factor][nof_streams] [t][nof_channels]  int
-- 
--   If g_big_endian_wb_*=true then the time t to wb_factor P mapping for the
--   fil_ppf_wide is t[0,1,2,3] = P[3,2,1,0], else when it is false then the
--   mapping is t[3,2,1,0] = P[3,2,1,0]. The mapping can be selected
--   independently for the in_dat_arr and the out_dat_arr.
--
--   The incoming data must be divided over the inputs as shown in the
--   following example for nof_streams=1 and wb_factor is 4. The array
--   index I runs from [wb_factor*nof_streams-1:0].
--
--     array   wb     stream   time index when g_big_endian_wb_*=true)
--     index   index  index 
--       I       P      S      t
--       3       3      0    : 0, 4,  8, 12, 16, ...
--       2       2      0    : 1, 5,  9, 13, 17, ...
--       1       1      0    : 2, 6, 10, 14, 18, ...
--       0       0      0    : 3, 7, 11, 15, 19, ...
--                             ^
--                             big endian
--              
--   Every array input will be filtered by a fil_ppf_single instance. It is
--   also possible to offer multiple wideband input streams. Those wide
--   band input streams will share the filter coefficients. For a system with
--   nof_streams=2 and wb_factor=4 the array inputs become:
--
--     array   wb     stream   time index when g_big_endian_wb_*=true)
--     index   index  index  
--       I       P      S      t
--       7       3      1    : 0, 4, 8,  12, 16, ...
--       6       3      0    : 0, 4, 8,  12, 16, ...
--       5       2      1    : 1, 5, 9,  13, 17, ...
--       4       2      0    : 1, 5, 9,  13, 17, ...
--       3       1      1    : 2, 6, 10, 14, 18, ...
--       2       1      0    : 2, 6, 10, 14, 18, ...
--       1       0      1    : 3, 7, 11, 15, 19, ...
--       0       0      0    : 3, 7, 11, 15, 19, ...
--                             ^
--                             big endian
--
--   Note that I, P and S all increment in the same direction and t increments 
--   in the opposite direction of P. This is the g_big_endian_wb_in=true and
--   g_big_endian_wb_out=true format for the in_dat_arr and out_dat_arr.
--
--   If g_big_endian_wb_in=false and g_big_endian_wb_out=false for little endian
--   format, then the time t increments in the same direction as P, for both
--   in_dat_arr and out_dat_arr, so then I, P and S all increment in the same
--   direction:
--
--     array   wb     stream   time index when g_big_endian_wb_*=false
--     index   index  index  
--       I       P      S      t
--       7       3      1    : 3, 7, 11, 15, 19, ...
--       6       3      0    : 3, 7, 11, 15, 19, ...
--       5       2      1    : 2, 6, 10, 14, 18, ...
--       4       2      0    : 2, 6, 10, 14, 18, ...
--       3       1      1    : 1, 5, 9,  13, 17, ...
--       2       1      0    : 1, 5, 9,  13, 17, ...
--       1       0      1    : 0, 4, 8,  12, 16, ...
--       0       0      0    : 0, 4, 8,  12, 16, ...
--                             ^
--                             little endian
--
--   The FIR coefficients must always be provided as for little endian wb input,
--   independent of g_big_endian_wb_in, because internally this fil_ppf_wide
--   adjusts the streams_in_arr to little endian wb input when needed.
--
--   With wb_factor > 1 and nof_streams > 1 the streams in in_dat_arr and
--   out_dat_arr are looped first and then the wb_factor is looped. This
--   fits with the fact that all streams for a certain wb_index use the same
--   filter coeffcients and may thus ease routing. The alternative would be
--   to group the data per stream and loop over the wb_factor first and then
--   over these wide band streams. This may ease the routing of the further
--   data processing per wide band stream. One may instante one fil_ppf_wide
--   for all streams (all using the same set of coefficients) or multiple
--   fil_ppf_wide instances for all streams (each with their own set of
--   coefficients).
--
-- Remarks:
-- . See also description tb_fil_ppf_single.vhd for more info.
--              
library IEEE, common_pkg_lib, casper_ram_lib, casper_mm_lib;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;
use common_pkg_lib.common_pkg.ALL; 
use casper_ram_lib.common_ram_pkg.ALL;  
use work.fil_pkg.ALL;

entity fil_ppf_wide is
  generic (
    g_big_endian_wb_in  : boolean            := false;              --! input endian
    g_big_endian_wb_out : boolean            := false;              --! output endian 
    g_fil_ppf           : t_fil_ppf          := c_fil_ppf;          --! data widths and filter information
    g_fil_ppf_pipeline  : t_fil_ppf_pipeline := c_fil_ppf_pipeline; --! pipeline delay factors
    g_coefs_file_prefix : string             := c_coefs_file;       --! coefficients file generated by fil_ppf_create.py
    g_technology        : natural            := 0;                  --! 0 for Xilinx, 1 for Altera
    g_ram_primitive     : string             := "auto"              --! ram primitive function for use
  );
  port (
    clk            : in  std_logic;
    ce             : in  std_logic;
    rst            : in  std_logic;
    -- mm_clk         : in  std_logic;
    -- mm_rst         : in  std_logic;
    -- ram_coefs_mosi : in  t_mem_mosi;               
    -- ram_coefs_miso : out t_mem_miso := c_mem_miso_rst;
    in_dat_arr     : in  t_fil_slv_arr_in(g_fil_ppf.wb_factor*g_fil_ppf.nof_streams-1 downto 0);  
    in_val         : in  std_logic;  
    out_dat_arr    : out t_fil_slv_arr_out(g_fil_ppf.wb_factor*g_fil_ppf.nof_streams-1 downto 0);  
    out_val        : out std_logic
  ); 
end fil_ppf_wide;

architecture rtl of fil_ppf_wide is   

  constant c_nof_files   : natural := g_fil_ppf.wb_factor * g_fil_ppf.nof_taps;
  constant c_file_index_arr  : t_nat_natural_arr := array_init(0, c_nof_files, 1);  -- use the instance index as file index 0, 1, 2, 3, 4 ...
  
  type t_fil_ppf_arr      is array(integer range <> ) of t_fil_ppf;                       -- An array of t_fil_ppf's generics.                                                                              
  type t_nat_natural_arr2 is array(integer range <> ) of t_nat_natural_arr(g_fil_ppf.nof_taps-1 downto 0); -- An array of arrays, used to point to the right .mif files for the coefficients

  type t_streams_in_arr   is array(integer range <> ) of std_logic_vector(g_fil_ppf.nof_streams*g_fil_ppf.in_dat_w  -1 downto 0);
  type t_streams_out_arr  is array(integer range <> ) of std_logic_vector(g_fil_ppf.nof_streams*g_fil_ppf.out_dat_w -1 downto 0);
  
  ----------------------------------------------------------
  -- This function creates an array of t_fil_ppf generics 
  -- for the single channel poly phase filters that are 
  -- used to compose the multichannel(wideband) poly phase
  -- filter. The array is based on the content of the g_fil_ppf
  -- generic that belongs to the fil_ppf_w entity. 
  -- Only the nof_bands is modified. 
  ----------------------------------------------------------
  function func_create_generics_for_ppfs(input: t_fil_ppf) return t_fil_ppf_arr is
    variable v_nof_bands : natural := input.nof_bands/input.wb_factor;                     -- The nof_bands for the single channel poly phase filters
    variable v_return    : t_fil_ppf_arr(input.wb_factor-1 downto 0) := (others => input); -- Variable that holds the return values
  begin
    for P in 0 to input.wb_factor-1 loop
      v_return(P).nof_bands := v_nof_bands;     -- The new number of bands
    end loop;                               
    return v_return; 
  end;
  
  ----------------------------------------------------------
  -- Function that divides the input file index array into 
  -- "wb_factor" new file index arrays. 
  ----------------------------------------------------------
  function func_create_file_index_array(input: t_nat_natural_arr; wb_factor: natural; nof_taps: natural) return t_nat_natural_arr2 is
    variable v_return : t_nat_natural_arr2(wb_factor-1 downto 0);    -- Variable that holds the return values
  begin
    for P in 0 to wb_factor-1 loop
      for T in 0 to nof_taps-1 loop
        v_return(P)(T) := input(P*nof_taps+T);
      end loop;
    end loop;                               
    return v_return; 
  end;
  
  constant c_fil_ppf_arr     : t_fil_ppf_arr(g_fil_ppf.wb_factor-1      downto 0) := func_create_generics_for_ppfs(g_fil_ppf);  
  constant c_file_index_arr2 : t_nat_natural_arr2(g_fil_ppf.wb_factor-1 downto 0) := func_create_file_index_array(c_file_index_arr, g_fil_ppf.wb_factor, g_fil_ppf.nof_taps);
  
  constant c_mem_addr_w      : natural := ceil_log2(g_fil_ppf.nof_bands * g_fil_ppf.nof_taps / g_fil_ppf.wb_factor); 

  -- signal ram_coefs_mosi_arr  : t_mem_mosi_arr(g_fil_ppf.wb_factor-1 downto 0);                               
  -- signal ram_coefs_miso_arr  : t_mem_miso_arr(g_fil_ppf.wb_factor-1 downto 0) := (others => c_mem_miso_rst); 

  signal streams_in_arr      : t_streams_in_arr( g_fil_ppf.wb_factor-1 downto 0);
  signal streams_out_arr     : t_streams_out_arr(g_fil_ppf.wb_factor-1 downto 0);
  signal streams_out_val_arr : std_logic_vector( g_fil_ppf.wb_factor-1 downto 0);
  
begin
  ---------------------------------------------------------------
  -- COMBINE MEMORY MAPPED INTERFACES
  ---------------------------------------------------------------
  -- Combine the internal array of mm interfaces for the coefficents 
  -- memory to one array that is connected to the port of the fil_ppf_w
  -- u_mem_mux_coef : entity casper_mm_lib.common_mem_mux
  -- generic map (    
  --   g_nof_mosi    => g_fil_ppf.wb_factor,
  --   g_mult_addr_w => c_mem_addr_w
  -- )
  -- port map (
  --   mosi     => ram_coefs_mosi,
  --   miso     => ram_coefs_miso,
  --   mosi_arr => ram_coefs_mosi_arr,
  --   miso_arr => ram_coefs_miso_arr
  -- );

  p_wire_input : process(in_dat_arr)
    variable vP : natural;
  begin
    for P in 0 to g_fil_ppf.wb_factor-1 loop
      if g_big_endian_wb_in=true then
        vP := g_fil_ppf.wb_factor-1-P;  -- convert input big endian time [0,1,2,3] to P [3,2,1,0] index mapping to internal little endian
      else
        vP := P;                        -- keep input little endian time [0,1,2,3] to P [0,1,2,3] index mapping 
      end if;
      for S in 0 to g_fil_ppf.nof_streams-1 loop
        streams_in_arr(vP)((S+1)*g_fil_ppf.in_dat_w-1 downto S*g_fil_ppf.in_dat_w) <= in_dat_arr(P*g_fil_ppf.nof_streams+S)(g_fil_ppf.in_dat_w-1 downto 0);
      end loop;
    end loop;
  end process;

  ---------------------------------------------------------------
  -- INSTANTIATE MULTIPLE SINGLE CHANNEL POLY PHASE FILTERS
  ---------------------------------------------------------------
  gen_fil_ppf_singles : for P in 0 to g_fil_ppf.wb_factor-1 generate
    u_fil_ppf_single : entity work.fil_ppf_single 
    generic map (
      g_fil_ppf           => c_fil_ppf_arr(P),
      g_fil_ppf_pipeline  => g_fil_ppf_pipeline,
      g_file_index_arr    => c_file_index_arr2(P),  -- use (g_fil_ppf.wb_factor-1 - P) to try impact of reversed WB FIR coefficients
      g_coefs_file_prefix => g_coefs_file_prefix, 
      g_technology        => g_technology,
      g_ram_primitive     => g_ram_primitive        
    )
    port map (
      clk            => clk,
      rst            => rst,
      ce             => ce,
      -- mm_clk         => mm_clk,
      -- mm_rst         => mm_rst,
      -- ram_coefs_mosi => ram_coefs_mosi_arr(P), 
      -- ram_coefs_miso => ram_coefs_miso_arr(P), 
      in_dat         => streams_in_arr(P),
      in_val         => in_val,
      out_dat        => streams_out_arr(P),
      out_val        => streams_out_val_arr(P)
    ); 
  end generate;  
  
  p_wire_output : process(streams_out_arr)
    variable vP : natural;
  begin
    for P in 0 to g_fil_ppf.wb_factor-1 loop
      if g_big_endian_wb_out=true then
        vP := g_fil_ppf.wb_factor-1-P;  -- convert internal little endian to output big endian time [0,1,2,3] to P [3,2,1,0] index mapping
      else
        vP := P;                        -- keep internal little endian for output little endian time [0,1,2,3] to P [0,1,2,3] index mapping 
      end if;
      for S in 0 to g_fil_ppf.nof_streams-1 loop
        out_dat_arr(vP*g_fil_ppf.nof_streams+S)<= RESIZE_SVEC(streams_out_arr(P)((S+1)*g_fil_ppf.out_dat_w-1 downto S*g_fil_ppf.out_dat_w),g_fil_ppf.out_dat_w);
      end loop;
    end loop;
  end process;
    
  out_val <= streams_out_val_arr(0);                             
  
end rtl;
