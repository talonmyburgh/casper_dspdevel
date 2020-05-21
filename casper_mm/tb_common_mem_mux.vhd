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

LIBRARY IEEE, common_pkg_lib, casper_ram_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;
USE work.tb_common_mem_pkg.ALL; 

ENTITY tb_common_mem_mux IS 
 GENERIC (    
    g_nof_mosi    : POSITIVE := 16;     -- Number of memory interfaces in the array.                       
    g_mult_addr_w : POSITIVE := 4       -- Address width of each memory-interface element in the array.
  );
END tb_common_mem_mux;

-- Usage:
--   > as 10
--   > run -all
  

ARCHITECTURE tb OF tb_common_mem_mux IS

  CONSTANT clk_period   : TIME    := 10 ns;
  
  CONSTANT c_data_w     : NATURAL := 32; 
  CONSTANT c_test_ram   : t_c_mem := (latency  => 1,
                                      adr_w    => g_mult_addr_w,
                                      dat_w    => c_data_w,
                                      nof_dat  => 2**g_mult_addr_w,
                                      init_sl  => '0'); 
  SIGNAL rst      : STD_LOGIC;
  SIGNAL clk      : STD_LOGIC := '1'; 
  SIGNAL tb_end   : STD_LOGIC;
  
  SIGNAL mosi_arr : t_mem_mosi_arr(g_nof_mosi - 1 DOWNTO 0); 
  SIGNAL miso_arr : t_mem_miso_arr(g_nof_mosi - 1 DOWNTO 0); 
  SIGNAL mosi     : t_mem_mosi;
  SIGNAL miso     : t_mem_miso;

BEGIN

  clk <= NOT clk OR tb_end AFTER clk_period/2;
  rst <= '1', '0' AFTER clk_period*5;
  
  p_stimuli : PROCESS 
    VARIABLE temp : INTEGER;
  BEGIN
    tb_end <= '0';
    mosi   <= c_mem_mosi_rst;  
      
    -- Write the whole memory range
    FOR I IN 0 TO g_nof_mosi-1 LOOP
      FOR J IN 0 TO 2**g_mult_addr_w-1 LOOP
        proc_mem_mm_bus_wr(I*2**g_mult_addr_w + J, I+J, clk, mosi);  
      END LOOP;
    END LOOP;
    
    -- Read back the whole range and check if data is as expected
    FOR I IN 0 TO g_nof_mosi-1 LOOP
      FOR J IN 0 TO 2**g_mult_addr_w-1 LOOP
        proc_mem_mm_bus_rd(I*2**g_mult_addr_w + J, clk, mosi); 
        proc_common_wait_some_cycles(clk, 1);   
        temp := TO_UINT(miso.rddata(31 DOWNTO 0));  
        IF(temp /= I+J) THEN
          REPORT "Error! Readvalue is not as expected" SEVERITY ERROR;  
        END IF;
      END LOOP;
    END LOOP;
    tb_end <= '1';
    WAIT;
  END PROCESS;

  generation_of_test_rams : FOR I IN 0 TO g_nof_mosi-1 GENERATE 
    u_test_rams : ENTITY casper_ram_lib.common_ram_r_w
    GENERIC MAP (
      g_ram       => c_test_ram,
      g_init_file => "UNUSED"
    )
    PORT MAP (
      rst       => rst, 
      clk       => clk, 
      clken     => '1',
      wr_en     => mosi_arr(I).wr, 
      wr_adr    => mosi_arr(I).address(g_mult_addr_w-1 DOWNTO 0),
      wr_dat    => mosi_arr(I).wrdata(c_data_w-1 DOWNTO 0),  
      rd_en     => mosi_arr(I).rd,
      rd_adr    => mosi_arr(I).address(g_mult_addr_w-1 DOWNTO 0),  
      rd_dat    => miso_arr(I).rddata(c_data_w-1 DOWNTO 0),
      rd_val    => miso_arr(I).rdval   
    );
  END GENERATE;
  
  d_dut : ENTITY work.common_mem_mux
  GENERIC MAP (    
    g_nof_mosi    => g_nof_mosi,         
    g_mult_addr_w => g_mult_addr_w  
  )
  PORT MAP (
    mosi_arr => mosi_arr,  
    miso_arr => miso_arr,  
    mosi     => mosi,
    miso     => miso
  );
        
END tb;
