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
-- Purpose:  Merges the data of multiple input streams into one output stream. 
-- 
-- Description: An output stream is composed out of the input streams. The duty cycle
--              of the in_val signal must be 1/g_nof_streams in order 
--              to avoid the loss of data. 

library IEEE, common_pkg_lib;
use IEEE.std_logic_1164.ALL;
use common_pkg_lib.common_pkg.ALL;

entity common_zip is
  generic (
    g_nof_streams : natural := 2;  -- Number of input streams to be zipped
    g_dat_w       : natural := 8
  );
  port (
    rst        : in  std_logic := '0';
    clk        : in  std_logic;
    in_val     : in  std_logic := '0';
    in_dat_arr : in  t_slv_64_arr(g_nof_streams-1 downto 0);
    out_val    : out std_logic;
    out_dat    : out std_logic_vector(g_dat_w-1 downto 0)
  );
end common_zip;

architecture rtl of common_zip is

  type t_dat_arr is array (natural range <>) of std_logic_vector(out_dat'range);
  constant c_t_dat_arr : t_dat_arr(g_nof_streams-1 downto 1) := (others=>(others=>'0'));

  type reg_type is record
    in_dat_arr  : t_dat_arr(g_nof_streams-1 downto 1);  -- Input register
    index       : integer range 1 to g_nof_streams;     -- Index
    out_dat     : std_logic_vector(g_dat_w-1 downto 0); -- Registered output value
    out_val     : std_logic;                            -- Registered data valid signal  
  end record;

  constant c_reg_type : reg_type := (c_t_dat_arr,g_nof_streams,(others=>'0'),'0');
  
  signal r, rin : reg_type := c_reg_type; 
   
begin
  
  comb : process(r, rst, in_val, in_dat_arr)
    variable v : reg_type;
  begin

    v := r; 
    v.out_val := '0';                                         -- Default the output valid signal is low. 
    
    if(in_val = '1') then                                     -- Wait for incoming data
      v.index   := 1;
      v.out_val := '1';
      v.out_dat := in_dat_arr(0)(g_dat_w-1 downto 0);         -- Output the first stream already
      for I in 1 to g_nof_streams-1 loop
        v.in_dat_arr(I) := in_dat_arr(I)(g_dat_w-1 downto 0); -- Store input data in register
      end loop;
    end if;
    
    if(r.index < g_nof_streams) then 
      v.out_val := '1';
      v.out_dat := r.in_dat_arr(r.index);                     -- Output the next input stream
      v.index   := r.index+1;
    end if; 
      
    if(rst = '1') then
      v.in_dat_arr := (others => (others => '0'));
      v.index      := g_nof_streams;
      v.out_dat    := (others => '0');
      v.out_val    := '0';
    end if;
    
    rin <= v;  
    
  end process comb;
  
  regs : process(clk)
  begin 
    if rising_edge(clk) then 
      r <= rin; 
    end if; 
  end process; 
  
  out_dat <= r.out_dat;
  out_val <= r.out_val;
  
end rtl;
