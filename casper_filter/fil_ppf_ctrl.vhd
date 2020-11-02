-------------------------------------------------------------------------------
--
-- Copyright (C) 2009
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
-- Purpose: Controlling the data streams for the filter units
-- 
-- Description: This unit prepairs the data streams for the ppf_filter 
--              unit. Incoming data (in_dat) is combined with stored 
--              data (taps_in_vec) to generate a new vector that is 
--              offered to the filter unit: taps_out_vec. 
--             
--              It also delays the in_val signal in order to generate 
--              the out_val that is proper alligned with the output data
--              that is coming from the filter unit. 
--              

library IEEE, common_pkg_lib;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;
use common_pkg_lib.common_pkg.ALL; 
use work.fil_pkg.ALL;

entity fil_ppf_ctrl is
  generic (
    g_fil_ppf          : t_fil_ppf; 
    g_fil_ppf_pipeline : t_fil_ppf_pipeline
  );
  port (       
    rst         : in  std_logic := '0';  
    clk         : in  std_logic;         
    in_dat      : in  std_logic_vector;
    in_val      : in  std_logic;         
    taps_in_vec : in  std_logic_vector;
    taps_rdaddr : out std_logic_vector;
    taps_wraddr : out std_logic_vector;
    taps_wren   : out std_logic;         
    taps_out_vec: out std_logic_vector;
    out_val     : out std_logic
  );
end fil_ppf_ctrl;

architecture rtl of fil_ppf_ctrl is
  
  type     t_in_dat_delay is array (g_fil_ppf_pipeline.mem_delay downto 0) of std_logic_vector(g_fil_ppf.in_dat_w*g_fil_ppf.nof_streams-1 downto 0);
  
  constant c_addr_w             : natural := ceil_log2(g_fil_ppf.nof_bands * (2**g_fil_ppf.nof_chan));
  constant c_ctrl_latency       : natural := 1;                               -- due to taps_out_vec register
  constant c_mult_latency       : natural := g_fil_ppf_pipeline.mult_input + g_fil_ppf_pipeline.mult_product + g_fil_ppf_pipeline.mult_output;
  constant c_adder_latency      : natural := ceil_log2(g_fil_ppf.nof_taps) * g_fil_ppf_pipeline.adder_stage;
  constant c_filter_zdly        : natural := g_fil_ppf.nof_bands * (2**g_fil_ppf.nof_chan); 

  constant c_tot_latency        : natural := g_fil_ppf_pipeline.mem_delay + c_ctrl_latency + c_mult_latency + 
                                             c_adder_latency + g_fil_ppf_pipeline.requant_remove_lsb + 
                                             g_fil_ppf_pipeline.requant_remove_msb;
                                             
  constant c_single_taps_vec_w  : natural := g_fil_ppf.in_dat_w*g_fil_ppf.nof_taps;                                             
  constant c_taps_vec_w         : natural := c_single_taps_vec_w*g_fil_ppf.nof_streams;
  
  type reg_type is record
    in_dat_arr   : t_in_dat_delay;                             -- Input register for the data
    init_dly_cnt : integer range 0 to c_filter_zdly;           -- Counter used to overcome the settling time of the filter. 
    val_dly      : std_logic_vector(c_tot_latency-1 downto 0); -- Delay register for the valid signal 
    rd_addr      : std_logic_vector(c_addr_w-1 downto 0);      -- The read address
    wr_addr      : std_logic_vector(c_addr_w-1 downto 0);      -- The write address
    wr_en        : std_logic;                                  -- Write enable signal for the taps memory
    taps_out_vec : std_logic_vector(c_taps_vec_w-1 downto 0);  -- Output register containing the next taps data
    out_val_ena  : std_logic;                                  -- Output enable 
  end record;
  
  signal r, rin : reg_type; 
  
begin
  
  comb : process(r, rst, in_val, in_dat, taps_in_vec)
    variable v : reg_type;
  begin

    v := r;  
    v.wr_en  := '0';  
    
    -- Perform the shifting for the shiftregister for the valid signal and the input data: 
    v.val_dly(0) := in_val; 
    v.val_dly(c_tot_latency-1 downto 1) := r.val_dly(c_tot_latency-2 downto 0);
    v.in_dat_arr(0) := RESIZE_SVEC(in_dat, r.in_dat_arr(0)'LENGTH);           
    v.in_dat_arr(g_fil_ppf_pipeline.mem_delay downto 1) := r.in_dat_arr(g_fil_ppf_pipeline.mem_delay-1 downto 0);
    
    if(r.val_dly(0) = '1') then                                 -- Wait for incoming data
      v.rd_addr := INCR_UVEC(r.rd_addr, 1);
    end if;                                     

    if(r.val_dly(c_tot_latency-2) = '1') then                                 -- Wait for incoming data
      if(r.init_dly_cnt < c_filter_zdly) then
        v.init_dly_cnt := r.init_dly_cnt + 1;
        v.out_val_ena := '0';
      else 
        v.out_val_ena := '1';
      end if;
    end if;                                     
    
    if(r.val_dly(g_fil_ppf_pipeline.mem_delay+1) = '1') then 
      v.wr_addr := INCR_UVEC(r.wr_addr, 1);
    end if; 

    if(r.val_dly(g_fil_ppf_pipeline.mem_delay) = '1') then 
      for I in 0 to g_fil_ppf.nof_streams-1 loop
        v.taps_out_vec((I+1)*c_single_taps_vec_w-1 downto I*c_single_taps_vec_w) := taps_in_vec((I+1)*c_single_taps_vec_w - g_fil_ppf.in_dat_w -1 downto I*c_single_taps_vec_w) & r.in_dat_arr(g_fil_ppf_pipeline.mem_delay)((I+1)*g_fil_ppf.in_dat_w-1 downto I*g_fil_ppf.in_dat_w);
      end loop;
      --v.taps_out_vec := taps_in_vec(taps_in_vec'HIGH - g_fil_ppf.in_dat_w downto 0) & r.in_dat_arr(g_fil_ppf_pipeline.mem_delay);
      v.wr_en        := '1';  
    end if; 
      
    if(rst = '1') then
      v.init_dly_cnt := 0;
      v.in_dat_arr   := (others => (others => '0'));
      v.val_dly      := (others => '0');
      v.rd_addr      := (others => '0');
      v.wr_addr      := (others => '0');
      v.wr_en        := '0';  
      v.taps_out_vec := (others => '0');
      v.out_val_ena  := '0';
    end if;
    
    rin <= v;  
    
  end process comb;
  
  regs : process(clk)
  begin 
    if rising_edge(clk) then 
      r <= rin; 
    end if; 
  end process; 
  
  taps_rdaddr  <= r.rd_addr;
  taps_wraddr  <= r.wr_addr;
  taps_wren    <= r.wr_en;
  taps_out_vec <= r.taps_out_vec; 
  out_val      <= r.val_dly(c_tot_latency-1) AND r.out_val_ena;
  
end rtl;
