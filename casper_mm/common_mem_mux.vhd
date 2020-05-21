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

-------------------------------------------------------------------------------
-- 
-- Purpose: Combines an array of MM interfaces into a single MM interface.
-- Description:
--   The common_mem_mux unit combines an array of mosi's and miso's to one
--   single set of mosi and miso. Should be used to decrease the amount of
--   slave memory interfaces to the MM bus.
--
--                                  g_rd_latency
--                                 ______________
--        strip index:             |            |
--        mosi.address[h:w] ---+-->| delay line |--\
--                             |   |____________|  |
--                             |                   |
--                 selected    v                   |
--   mosi -------> mosi_arr.wr[ ]-----------------------------> mosi_arr
--                          rd                     |
--                                        selected v
--   miso <-------------------------------miso_arr[ ]<--------- miso_arr
--
--        . not selected mosi_arr get mosi but with wr='0', rd='0'
--        . not selected miso_arr are ignored
--
--   Use default g_broadcast=FALSE for multiplexed individual MM access to
--   each mosi_arr/miso_arr MM port. When g_broadcast=TRUE then a write
--   access to MM port [0] is passed on to all ports and a read access is
--   done from MM port [0]. The other ports cannot be read.
--
-- Remarks:
-- . In simulation selecting an unused element address will cause a simulation
--   failure. Therefore the element index is only accepted when it is in the
--   g_nof_mosi-1 DOWNTO 0 range.
-- . In case multiple common_mem_mux would be used in series, then only the
--   top one needs to account for g_rd_latency>0, the rest can use 0.
--
-------------------------------------------------------------------------------


LIBRARY IEEE, common_pkg_lib, casper_ram_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;

ENTITY common_mem_mux IS
  GENERIC (
    g_broadcast   : BOOLEAN := FALSE;
    g_nof_mosi    : POSITIVE := 256;     -- Number of memory interfaces in the array.
    g_mult_addr_w : POSITIVE := 8;       -- Address width of each memory-interface element in the muliplexed array.
    g_rd_latency  : NATURAL := 0
  );
  PORT (
    clk      : IN  STD_LOGIC := '0';   -- only used when g_rd_latency > 0
    mosi     : IN  t_mem_mosi;
    miso     : OUT t_mem_miso;
    mosi_arr : OUT t_mem_mosi_arr(g_nof_mosi - 1 DOWNTO 0); 
    miso_arr : IN  t_mem_miso_arr(g_nof_mosi - 1 DOWNTO 0) := (OTHERS=>c_mem_miso_rst)
  );
END common_mem_mux;

ARCHITECTURE rtl OF common_mem_mux IS
  
  CONSTANT c_index_w        : NATURAL := ceil_log2(g_nof_mosi);
  CONSTANT c_total_addr_w   : NATURAL := c_index_w + g_mult_addr_w;

  SIGNAL index_arr : t_natural_arr(0 TO g_rd_latency);
  SIGNAL index_rw  : NATURAL;  -- read or write access
  SIGNAL index_rd  : NATURAL;  -- read response

BEGIN

  gen_single : IF g_broadcast=FALSE AND g_nof_mosi=1 GENERATE 
    mosi_arr(0) <= mosi;
    miso        <= miso_arr(0);
  END GENERATE;
    
  gen_multiple : IF g_broadcast=FALSE AND g_nof_mosi>1 GENERATE 
    -- The activated element of the array is detected here
    index_arr(0) <= TO_UINT(mosi.address(c_total_addr_w-1 DOWNTO g_mult_addr_w));

    -- Pipeline the index of the activated element to account for the read latency
    p_clk : PROCESS(clk)
    BEGIN
      IF rising_edge(clk) THEN
        index_arr(1 TO g_rd_latency) <= index_arr(0 TO g_rd_latency-1);
      END IF;
    END PROCESS;
    
    index_rw <= index_arr(0);
    index_rd <= index_arr(g_rd_latency);
    
    -- Master access, can be write or read
    p_mosi_arr : PROCESS(mosi, index_rw)
    BEGIN
      FOR I IN 0 TO g_nof_mosi-1 LOOP
        mosi_arr(I)    <= mosi;
        mosi_arr(I).rd <= '0';
        mosi_arr(I).wr <= '0';
        IF I = index_rw THEN
          mosi_arr(I).rd <= mosi.rd;  
          mosi_arr(I).wr <= mosi.wr; 
        END IF;
      END LOOP;
    END PROCESS;
    
    -- Slave response to read access after g_rd_latency clk cycles
    p_miso : PROCESS(miso_arr, index_rd)
    BEGIN
      miso <= c_mem_miso_rst;
      FOR I IN 0 TO g_nof_mosi-1 LOOP
        IF I = index_rd THEN
          miso <= miso_arr(I);
        END IF;
      END LOOP;
    END PROCESS;
  END GENERATE; 
  
  gen_broadcast : IF g_broadcast=TRUE GENERATE
    mosi_arr <= (OTHERS=>mosi);  -- broadcast write to all [g_nof_mosi-1:0] MM ports
    miso     <= miso_arr(0);     -- broadcast read only from MM port [0]
  END GENERATE;
  
END rtl;
