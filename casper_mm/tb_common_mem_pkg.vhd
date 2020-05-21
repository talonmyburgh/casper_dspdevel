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
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;


PACKAGE tb_common_mem_pkg IS

  ------------------------------------------------------------------------------
  -- MM bus access functions
  ------------------------------------------------------------------------------

  -- The mm_miso input needs to be declared as signal, because otherwise the
  -- procedure does not notice a change (also not when the mm_clk is declared
  -- as signal).
  
  -- Write data to the MM bus
  PROCEDURE proc_mem_mm_bus_wr(CONSTANT wr_addr : IN  NATURAL;  -- [31:0]
                               CONSTANT wr_data : IN  INTEGER;  -- [31:0]
                               SIGNAL   mm_clk  : IN  STD_LOGIC;
                               SIGNAL   mm_miso : IN  t_mem_miso;  -- used for waitrequest
                               SIGNAL   mm_mosi : OUT t_mem_mosi);
                               
  PROCEDURE proc_mem_mm_bus_wr(CONSTANT wr_addr : IN  NATURAL;  -- [31:0]
                               CONSTANT wr_data : IN  INTEGER;  -- [31:0]
                               SIGNAL   mm_clk  : IN  STD_LOGIC;
                               SIGNAL   mm_mosi : OUT t_mem_mosi);

  PROCEDURE proc_mem_mm_bus_wr(CONSTANT wr_addr : IN  NATURAL;  -- [31:0]
                               CONSTANT wr_data : IN  STD_LOGIC_VECTOR;  -- [31:0]
                               SIGNAL   mm_clk  : IN  STD_LOGIC;
                               SIGNAL   mm_mosi : OUT t_mem_mosi);
                               
  -- Read data request to the MM bus
  PROCEDURE proc_mem_mm_bus_rd(CONSTANT rd_addr : IN  NATURAL;  -- [31:0]
                               SIGNAL   mm_clk  : IN  STD_LOGIC;
                               SIGNAL   mm_miso : IN  t_mem_miso;  -- used for waitrequest
                               SIGNAL   mm_mosi : OUT t_mem_mosi);
                               
  PROCEDURE proc_mem_mm_bus_rd(CONSTANT rd_addr : IN  NATURAL;  -- [31:0]
                               SIGNAL   mm_clk  : IN  STD_LOGIC;
                               SIGNAL   mm_mosi : OUT t_mem_mosi);
                               
  -- Wait for read data valid after read latency mm_clk cycles
  PROCEDURE proc_mem_mm_bus_rd_latency(CONSTANT c_rd_latency : IN NATURAL;
                                       SIGNAL   mm_clk       : IN STD_LOGIC);
                                       
  -- Write array of data words to the memory
  PROCEDURE proc_mem_write_ram(CONSTANT offset   : IN  NATURAL;
                               CONSTANT nof_data : IN  NATURAL; 
                               CONSTANT data_arr : IN  t_slv_32_arr;
                               SIGNAL   mm_clk   : IN  STD_LOGIC;
                               SIGNAL   mm_mosi  : OUT t_mem_mosi);
  
  PROCEDURE proc_mem_write_ram(CONSTANT data_arr : IN  t_slv_32_arr;
                               SIGNAL   mm_clk   : IN  STD_LOGIC;
                               SIGNAL   mm_mosi  : OUT t_mem_mosi);
                               
  -- Read array of data words from the memory
  PROCEDURE proc_mem_read_ram(CONSTANT offset   : IN  NATURAL; 
                              CONSTANT nof_data : IN  NATURAL;
                              SIGNAL   mm_clk   : IN  STD_LOGIC;
                              SIGNAL   mm_mosi  : OUT t_mem_mosi;
                              SIGNAL   mm_miso  : IN  t_mem_miso;
                              SIGNAL   data_arr : OUT t_slv_32_arr);
                               
  PROCEDURE proc_mem_read_ram(SIGNAL   mm_clk   : IN  STD_LOGIC;
                              SIGNAL   mm_mosi  : OUT t_mem_mosi;
                              SIGNAL   mm_miso  : IN  t_mem_miso;
                              SIGNAL   data_arr : OUT t_slv_32_arr);
                               
END tb_common_mem_pkg;


PACKAGE BODY tb_common_mem_pkg IS

  ------------------------------------------------------------------------------
  -- Private functions
  ------------------------------------------------------------------------------
  
  -- Issues a rd or a wr MM access
  PROCEDURE proc_mm_access(SIGNAL mm_clk    : IN  STD_LOGIC;
                           SIGNAL mm_access : OUT STD_LOGIC) IS
  BEGIN
    mm_access <= '1';
    WAIT UNTIL rising_edge(mm_clk);
    mm_access <= '0';
  END proc_mm_access;
  
  -- Issues a rd or a wr MM access and wait for it to have finished
  PROCEDURE proc_mm_access(SIGNAL mm_clk     : IN  STD_LOGIC;
                           SIGNAL mm_waitreq : IN  STD_LOGIC;
                           SIGNAL mm_access  : OUT STD_LOGIC) IS
  BEGIN
    mm_access <= '1';
    WAIT UNTIL rising_edge(mm_clk);
    WHILE mm_waitreq='1' LOOP
      WAIT UNTIL rising_edge(mm_clk);
    END LOOP;
    mm_access <= '0';
  END proc_mm_access;
  
  ------------------------------------------------------------------------------
  -- Public functions
  ------------------------------------------------------------------------------
  
  -- Write data to the MM bus
  PROCEDURE proc_mem_mm_bus_wr(CONSTANT wr_addr : IN  NATURAL;
                               CONSTANT wr_data : IN  INTEGER;
                               SIGNAL   mm_clk  : IN  STD_LOGIC;
                               SIGNAL   mm_miso : IN  t_mem_miso;
                               SIGNAL   mm_mosi : OUT t_mem_mosi) IS
  BEGIN
    mm_mosi.address <= TO_MEM_ADDRESS(wr_addr);
    mm_mosi.wrdata  <= TO_MEM_DATA(wr_data);
    proc_mm_access(mm_clk, mm_miso.waitrequest, mm_mosi.wr);
  END proc_mem_mm_bus_wr;
  
  PROCEDURE proc_mem_mm_bus_wr(CONSTANT wr_addr : IN  NATURAL;
                               CONSTANT wr_data : IN  INTEGER;
                               SIGNAL   mm_clk  : IN  STD_LOGIC;
                               SIGNAL   mm_mosi : OUT t_mem_mosi) IS
  BEGIN
    mm_mosi.address <= TO_MEM_ADDRESS(wr_addr);
    mm_mosi.wrdata  <= TO_MEM_DATA(wr_data);
    proc_mm_access(mm_clk, mm_mosi.wr);
  END proc_mem_mm_bus_wr;
  
  PROCEDURE proc_mem_mm_bus_wr(CONSTANT wr_addr : IN  NATURAL;
                               CONSTANT wr_data : IN  STD_LOGIC_VECTOR;
                               SIGNAL   mm_clk  : IN  STD_LOGIC;
                               SIGNAL   mm_mosi : OUT t_mem_mosi) IS
  BEGIN
    mm_mosi.address <= TO_MEM_ADDRESS(wr_addr);
    mm_mosi.wrdata  <= RESIZE_UVEC(wr_data, c_mem_data_w);
    proc_mm_access(mm_clk, mm_mosi.wr);
  END proc_mem_mm_bus_wr;                            
                               
  
  -- Read data request to the MM bus
  -- Use proc_mem_mm_bus_rd_latency() to wait for the MM MISO rd_data signal
  -- to show the data after some read latency
  PROCEDURE proc_mem_mm_bus_rd(CONSTANT rd_addr : IN  NATURAL;
                               SIGNAL   mm_clk  : IN  STD_LOGIC;
                               SIGNAL   mm_miso : IN  t_mem_miso;
                               SIGNAL   mm_mosi : OUT t_mem_mosi) IS
  BEGIN
    mm_mosi.address <= TO_MEM_ADDRESS(rd_addr);
    proc_mm_access(mm_clk, mm_miso.waitrequest, mm_mosi.rd);
  END proc_mem_mm_bus_rd;
  
  PROCEDURE proc_mem_mm_bus_rd(CONSTANT rd_addr : IN  NATURAL;
                               SIGNAL   mm_clk  : IN  STD_LOGIC;
                               SIGNAL   mm_mosi : OUT t_mem_mosi) IS
  BEGIN
    mm_mosi.address <= TO_MEM_ADDRESS(rd_addr);
    proc_mm_access(mm_clk, mm_mosi.rd);
  END proc_mem_mm_bus_rd;
  
  -- Wait for read data valid after read latency mm_clk cycles
  -- Directly assign mm_miso.rddata to capture the read data
  PROCEDURE proc_mem_mm_bus_rd_latency(CONSTANT c_rd_latency : IN NATURAL;
                                       SIGNAL   mm_clk       : IN STD_LOGIC) IS
  BEGIN
    FOR I IN 0 TO c_rd_latency-1 LOOP WAIT UNTIL rising_edge(mm_clk); END LOOP;
  END proc_mem_mm_bus_rd_latency;
  
  
  -- Write array of data words to the memory  
  PROCEDURE proc_mem_write_ram(CONSTANT offset   : IN  NATURAL;
                               CONSTANT nof_data : IN  NATURAL; 
                               CONSTANT data_arr : IN  t_slv_32_arr;
                               SIGNAL   mm_clk   : IN  STD_LOGIC;
                               SIGNAL   mm_mosi  : OUT t_mem_mosi) IS
    CONSTANT c_data_arr : t_slv_32_arr(data_arr'LENGTH-1 DOWNTO 0) := data_arr;  -- map to fixed range [h:0]
  BEGIN
    FOR I IN 0 TO nof_data-1 LOOP
      proc_mem_mm_bus_wr(offset + I, c_data_arr(I), mm_clk, mm_mosi);
    END LOOP;
  END proc_mem_write_ram;
  
  PROCEDURE proc_mem_write_ram(CONSTANT data_arr : IN  t_slv_32_arr;
                               SIGNAL   mm_clk   : IN  STD_LOGIC;
                               SIGNAL   mm_mosi  : OUT t_mem_mosi) IS
    CONSTANT c_offset   : NATURAL := 0;
    CONSTANT c_nof_data : NATURAL := data_arr'LENGTH;
  BEGIN
    proc_mem_write_ram(c_offset, c_nof_data, data_arr, mm_clk, mm_mosi);
  END proc_mem_write_ram;
  
  -- Read array of data words from the memory
  PROCEDURE proc_mem_read_ram(CONSTANT offset   : IN  NATURAL; 
                              CONSTANT nof_data : IN  NATURAL;
                              SIGNAL   mm_clk   : IN  STD_LOGIC;
                              SIGNAL   mm_mosi  : OUT t_mem_mosi;
                              SIGNAL   mm_miso  : IN  t_mem_miso;
                              SIGNAL   data_arr : OUT t_slv_32_arr) IS 
  BEGIN
    FOR I IN 0 TO nof_data-1 LOOP
      proc_mem_mm_bus_rd(offset+I, mm_clk, mm_mosi);  
      proc_mem_mm_bus_rd_latency(1, mm_clk);   -- assume read latency is 1
      data_arr(I) <= mm_miso.rddata(31 DOWNTO 0);
    END LOOP;
    -- wait one mm_clk cycle more to have last rddata captured in signal data_arr (otherwise this proc would need to use variable data_arr)
    WAIT UNTIL rising_edge(mm_clk);
  END proc_mem_read_ram;  
  
  PROCEDURE proc_mem_read_ram(SIGNAL   mm_clk   : IN  STD_LOGIC;
                              SIGNAL   mm_mosi  : OUT t_mem_mosi;
                              SIGNAL   mm_miso  : IN  t_mem_miso;
                              SIGNAL   data_arr : OUT t_slv_32_arr) IS 
    CONSTANT c_offset   : NATURAL := 0;
    CONSTANT c_nof_data : NATURAL := data_arr'LENGTH;
  BEGIN
    proc_mem_read_ram(c_offset, c_nof_data, mm_clk, mm_mosi, mm_miso, data_arr);
  END proc_mem_read_ram;
  
END tb_common_mem_pkg;
