-----------------------------------------------------------------------------      
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
                                                                                   
                                           
library IEEE, common_pkg_lib, casper_ram_lib, common_components_lib;
use IEEE.std_logic_1164.ALL;   
use IEEE.numeric_std.ALL;
use common_pkg_lib.common_pkg.ALL;
use casper_ram_lib.common_ram_pkg.ALL;
use work.diag_pkg.ALL;

entity diag_block_gen_reg is
  generic (
    g_cross_clock_domain : boolean  := TRUE;    -- use FALSE when mm_clk and st_clk are the same, else use TRUE to cross the clock domain
    g_diag_block_gen_rst : t_diag_block_gen := c_diag_block_gen_rst
  );
  port (
    mm_rst  : in  std_logic;                   -- Clocks and reset
    mm_clk  : in  std_logic;
    dp_rst  : in  std_logic := '0';
    dp_clk  : in  std_logic;
    mm_mosi : in  t_mem_mosi;                  -- Memory Mapped Slave in mm_clk domain
    mm_miso : out t_mem_miso       := c_mem_miso_rst;
    bg_ctrl : out t_diag_block_gen := g_diag_block_gen_rst                        
  ); 
end diag_block_gen_reg;  

architecture rtl of diag_block_gen_reg is                                                                                        
  
  constant c_adrs_width : positive := c_diag_bg_reg_adr_w;
  signal   mm_bg_ctrl   : t_diag_block_gen := g_diag_block_gen_rst;
  signal   dp_bg_ctrl   : t_diag_block_gen := g_diag_block_gen_rst;
                                                                                                                        
begin                                                                                                                   
                                                                                                                        
  ------------------------------------------------------------------------------                                        
  -- MM register access in the mm_clk domain                                                                            
  -- . Hardcode the shared MM slave register directly in RTL instead of using                                           
  --   the common_reg_r_w instance. Directly using RTL is easier when the large                                         
  --   MM register has multiple different fields and with different read and                                            
  --   write options per field in one MM register.                                                                      
  ------------------------------------------------------------------------------                                        
                                                                                                                        
  p_mm_reg : process (mm_rst, mm_clk)                                                                                   
  begin                                                                                                                 
    if(mm_rst = '1') then                                                                                                
      mm_miso    <= c_mem_miso_rst;
      mm_bg_ctrl <= g_diag_block_gen_rst;
    elsif(rising_edge(mm_clk)) then                                                                                      
      -- Read access defaults                                                                                           
      mm_miso.rdval <= '0';                                                                                             
      -- Write access: set register value                                                                               
      if(mm_mosi.wr = '1') then 
        case TO_UINT(mm_mosi.address(c_adrs_width-1 downto 0)) is
          when 0 =>                      
            mm_bg_ctrl.enable                 <= mm_mosi.wrdata(0);
            mm_bg_ctrl.enable_sync            <= mm_mosi.wrdata(1);
          when 1 =>
            mm_bg_ctrl.samples_per_packet     <= mm_mosi.wrdata(c_diag_bg_samples_per_packet_w -1 downto 0);
          when 2 =>
            mm_bg_ctrl.blocks_per_sync        <= mm_mosi.wrdata(c_diag_bg_blocks_per_sync_w    -1 downto 0);   
          when 3 =>                                                 
            mm_bg_ctrl.gapsize                <= mm_mosi.wrdata(c_diag_bg_gapsize_w            -1 downto 0);
          when 4 =>                                                 
            mm_bg_ctrl.mem_low_adrs           <= mm_mosi.wrdata(c_diag_bg_mem_low_adrs_w       -1 downto 0);        
          when 5 =>                                                 
            mm_bg_ctrl.mem_high_adrs          <= mm_mosi.wrdata(c_diag_bg_mem_high_adrs_w      -1 downto 0);
          when 6 =>                                                 
            mm_bg_ctrl.bsn_init(31 downto  0) <= mm_mosi.wrdata(31 downto 0);         
          when 7 =>                                                 
            mm_bg_ctrl.bsn_init(63 downto 32) <= mm_mosi.wrdata(31 downto 0); 
          when others => null;  -- not used MM addresses
        end case;
      -- Read access: get register value                                                                                
      elsif mm_mosi.rd = '1' then                                                                                        
        mm_miso       <= c_mem_miso_rst;    -- set unused rddata bits to '0' when read                                  
        mm_miso.rdval <= '1'; 
        case TO_UINT(mm_mosi.address(c_adrs_width-1 downto 0)) is
          -- Read Block Sync
          when 0 =>
            mm_miso.rddata(0)                                          <= mm_bg_ctrl.enable;
            mm_miso.rddata(1)                                          <= mm_bg_ctrl.enable_sync;
          when 1 =>
            mm_miso.rddata(c_diag_bg_samples_per_packet_w -1 downto 0) <= mm_bg_ctrl.samples_per_packet;
          when 2 =>
            mm_miso.rddata(c_diag_bg_blocks_per_sync_w    -1 downto 0) <= mm_bg_ctrl.blocks_per_sync;
          when 3 =>
            mm_miso.rddata(c_diag_bg_gapsize_w            -1 downto 0) <= mm_bg_ctrl.gapsize;
          when 4 =>
            mm_miso.rddata(c_diag_bg_mem_low_adrs_w       -1 downto 0) <= mm_bg_ctrl.mem_low_adrs;
          when 5 =>
            mm_miso.rddata(c_diag_bg_mem_high_adrs_w      -1 downto 0) <= mm_bg_ctrl.mem_high_adrs;
          when 6 =>
            mm_miso.rddata(31 downto 0) <= mm_bg_ctrl.bsn_init(31 downto 0);
          when 7 =>
            mm_miso.rddata(31 downto 0) <= mm_bg_ctrl.bsn_init(63 downto 32);  
          when others => null;  -- not used MM addresses
        end case;
      end if; 
    end if;   
  end process;                                                                                                          
                                                                                                                        
  ------------------------------------------------------------------------------                                        
  -- Transfer register value between mm_clk and dp_clk domain.                                                          
  -- If the function of the register ensures that the value will not be used                                            
  -- immediately when it was set, then the transfer between the clock domains                                           
  -- can be done by wires only. Otherwise if the change in register value can                                           
  -- have an immediate effect then the bit or word value needs to be transfered                                         
  -- using:                                                                                                             
  --                                                                                                                    
  -- . common_async            --> for single-bit level signal                                                          
  -- . common_spulse           --> for single-bit pulse signal                                                          
  -- . common_reg_cross_domain --> for a multi-bit (a word) signal                                                      
  --                                                                                                                    
  -- Typically always use a crossing component for the single bit signals (to                                           
  -- be on the save side) and only use a crossing component for the word                                                
  -- signals if it is necessary (to avoid using more logic than necessary).                                             
  ------------------------------------------------------------------------------                                        
                                                                                                                        
  no_cross : if g_cross_clock_domain = FALSE generate                                                                   
    dp_bg_ctrl <= mm_bg_ctrl;                                                                                         
  end generate;  -- no_cross                                                                                            
                                                                                                                        
  gen_crossing : if g_cross_clock_domain = TRUE generate                                                                   
    -- Assume diag BG enable gets written last, so when diag BG enable is transfered properly to the dp_clk domain, then
    -- the other diag BG control fields are stable as well
    u_bg_enable : entity common_components_lib.common_async
    generic map (
      g_rst_level => '0'
    )
    port map (
      rst  => dp_rst,
      clk  => dp_clk,
      din  => mm_bg_ctrl.enable,
      dout => dp_bg_ctrl.enable
    );
    dp_bg_ctrl.enable_sync        <= mm_bg_ctrl.enable_sync;
    dp_bg_ctrl.samples_per_packet <= mm_bg_ctrl.samples_per_packet;
    dp_bg_ctrl.blocks_per_sync    <= mm_bg_ctrl.blocks_per_sync;   
    dp_bg_ctrl.gapsize            <= mm_bg_ctrl.gapsize;
    dp_bg_ctrl.mem_low_adrs       <= mm_bg_ctrl.mem_low_adrs;        
    dp_bg_ctrl.mem_high_adrs      <= mm_bg_ctrl.mem_high_adrs;
    dp_bg_ctrl.bsn_init           <= mm_bg_ctrl.bsn_init;                                                                           
  end generate;  -- gen_crossing                                                                                           
  
  bg_ctrl <= dp_bg_ctrl; 
  
end rtl;                                                                                                                
