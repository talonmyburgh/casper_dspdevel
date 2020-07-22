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
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE common_pkg_lib.common_pkg.ALL;

PACKAGE common_ram_pkg IS

  ------------------------------------------------------------------------------
  -- Simple memory access (for MM control interface)
  ------------------------------------------------------------------------------
  
  -- Assume the MM bus is for a 32 bit processor, therefore on the processor
  -- side of a memory peripheral typcially use c_word_w = 32 for the address
  -- and data fields in the MM bus records. However the MM bus can also be used
  -- on the user side of a memory peripheral and there the data width should
  -- not be limited by the processor type but rather by the maximum user data
  -- width on the streaming interface.
  --
  -- The std_logic_vector widths in the record need to be defined, because in
  -- a record they can not be unconstrained. A signal that needs less address
  -- or data width simply leaves the unused MSbits at 'X'. The actually used
  -- width of a memory gets set via a generic record type t_c_mem.
  --
  -- The alternative is to not put the std_logic_vector elements in the record,
  -- and declare them seperately, however then the compact representation that
  -- records provide gets lost, because the record then only contains wr_en and
  -- rd_en. Another alternative is to define the address as a integer and the
  -- data as an integer. However this limits their range to 32 bit numbers,
  -- which can be too few for data.
  
  -- Do not change these widths, because c_word_w just fits in a VHDL INTEGER
  -- Should wider address range or data width be needed, then define a new
  -- record type eg. t_mem_ctlr or t_mem_bus for that with
  -- sufficient widths.
  
  -- Choose smallest maximum slv lengths that fit all use cases, because unconstrained record fields slv is not allowed
  CONSTANT c_mem_address_w  : NATURAL := 32;   -- address range (suits 32-bit processor)
  CONSTANT c_mem_data_w     : NATURAL := 72;   -- data width (suit up to 8 bytes, that can also be 9 bit bytes)
  CONSTANT c_mem_address_sz : NATURAL := c_mem_address_w/c_byte_w;
  CONSTANT c_mem_data_sz    : NATURAL := c_mem_data_w/c_byte_w;
  
  TYPE t_mem_miso IS RECORD  -- Master In Slave Out
    rddata      : STD_LOGIC_VECTOR(c_mem_data_w-1 DOWNTO 0);  -- data width (suits 1, 2 or 4 bytes)
    rdval       : STD_LOGIC;
    waitrequest : STD_LOGIC;
  END RECORD;
  
  TYPE t_mem_mosi IS RECORD  -- Master Out Slave In
    address     : STD_LOGIC_VECTOR(c_mem_address_w-1 DOWNTO 0);  -- address range (suits 32-bit processor)
    wrdata      : STD_LOGIC_VECTOR(c_mem_data_w-1 DOWNTO 0);     -- data width (suits 1, 2 or 4 bytes)
    wr          : STD_LOGIC;
    rd          : STD_LOGIC;
  END RECORD;
  
  CONSTANT c_mem_miso_rst : t_mem_miso := ((OTHERS=>'0'), '0', '0');
  CONSTANT c_mem_mosi_rst : t_mem_mosi := ((OTHERS=>'0'), (OTHERS=>'0'), '0', '0');
  
  -- Multi port array for MM records
  TYPE t_mem_miso_arr IS ARRAY (INTEGER RANGE <>) OF t_mem_miso;
  TYPE t_mem_mosi_arr IS ARRAY (INTEGER RANGE <>) OF t_mem_mosi;
  
  -- Resize functions to fit an integer or an SLV in the corresponding t_mem_miso or t_mem_mosi field width
  FUNCTION TO_MEM_ADDRESS(n : INTEGER) RETURN STD_LOGIC_VECTOR;  -- unsigned, use integer to support 32 bit range
  FUNCTION TO_MEM_DATA(   n : INTEGER) RETURN STD_LOGIC_VECTOR;  -- unsigned, alias of TO_MEM_DATA()
  FUNCTION TO_MEM_UDATA(  n : INTEGER) RETURN STD_LOGIC_VECTOR;  -- unsigned, use integer to support 32 bit range
  FUNCTION TO_MEM_SDATA(  n : INTEGER) RETURN STD_LOGIC_VECTOR;  -- sign extended
  FUNCTION RESIZE_MEM_ADDRESS(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;  -- unsigned
  FUNCTION RESIZE_MEM_DATA(   vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;  -- unsigned, alias of RESIZE_MEM_UDATA
  FUNCTION RESIZE_MEM_UDATA(  vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;  -- unsigned
  FUNCTION RESIZE_MEM_SDATA(  vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;  -- sign extended
  FUNCTION RESIZE_MEM_XDATA(  vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;  -- set unused MSBits to 'X'
  
  
  ------------------------------------------------------------------------------
  -- Burst memory access (for DDR access interface)
  ------------------------------------------------------------------------------
  
  -- Choose smallest maximum slv lengths that fit all use cases, because unconstrained record fields slv is not allowed
  CONSTANT c_mem_ctlr_address_w    : NATURAL := 32;
  CONSTANT c_mem_ctlr_data_w       : NATURAL := 576;
  CONSTANT c_mem_ctlr_burstsize_w  : NATURAL := c_mem_ctlr_address_w;
  
  TYPE t_mem_ctlr_miso IS RECORD  
    rddata        : STD_LOGIC_VECTOR(c_mem_ctlr_data_w-1 DOWNTO 0);
    rdval         : STD_LOGIC;
    waitrequest_n : STD_LOGIC;  -- comparable to DP siso.ready
    done          : STD_LOGIC;  -- comparable to DP siso.xon, not part of Avalon bus, can eg. act as init done or init ok or ready for next block, useful for DDR controller
    cal_ok        : STD_LOGIC;
    cal_fail      : STD_LOGIC;
  END RECORD;
  
  TYPE t_mem_ctlr_mosi IS RECORD  
    address       : STD_LOGIC_VECTOR(c_mem_ctlr_address_w-1 DOWNTO 0);
    wrdata        : STD_LOGIC_VECTOR(c_mem_ctlr_data_w-1 DOWNTO 0);
    wr            : STD_LOGIC;
    rd            : STD_LOGIC;
    burstbegin    : STD_LOGIC;
    burstsize     : STD_LOGIC_VECTOR(c_mem_ctlr_burstsize_w-1 DOWNTO 0);
    flush         : STD_LOGIC;  -- not part of Avalon bus, but useful for DDR driver
  END RECORD;
  
  CONSTANT c_mem_ctlr_miso_rst : t_mem_ctlr_miso := ((OTHERS=>'0'), '0', '0', '0', '0', '0');
  CONSTANT c_mem_ctlr_mosi_rst : t_mem_ctlr_mosi := ((OTHERS=>'0'), (OTHERS=>'0'), '0', '0', '0', (OTHERS=>'0'), '0');

  -- Multi port array for mem_ctlr records
  TYPE t_mem_ctlr_miso_arr IS ARRAY (INTEGER RANGE <>) OF t_mem_ctlr_miso;
  TYPE t_mem_ctlr_mosi_arr IS ARRAY (INTEGER RANGE <>) OF t_mem_ctlr_mosi;

  
  -- Resize functions to fit an integer or an SLV in the corresponding t_mem_ctlr_miso or t_mem_ctlr_mosi field width
  FUNCTION TO_MEM_CTLR_ADDRESS(  n : INTEGER) RETURN STD_LOGIC_VECTOR;  -- unsigned, use integer to support 32 bit range
  FUNCTION TO_MEM_CTLR_DATA(     n : INTEGER) RETURN STD_LOGIC_VECTOR;  -- unsigned
  FUNCTION TO_MEM_CTLR_BURSTSIZE(n : INTEGER) RETURN STD_LOGIC_VECTOR;  -- unsigned

  FUNCTION RESIZE_MEM_CTLR_ADDRESS(  vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;  -- unsigned
  FUNCTION RESIZE_MEM_CTLR_DATA(     vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;  -- unsigned
  FUNCTION RESIZE_MEM_CTLR_BURSTSIZE(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;  -- unsigned
  
  
  ------------------------------------------------------------------------------
  -- RAM block memory and MM register defintions
  ------------------------------------------------------------------------------
  TYPE t_c_mem IS RECORD
    latency   : NATURAL;    -- read latency
    adr_w     : NATURAL;
    dat_w     : NATURAL;
    nof_dat   : NATURAL;    -- optional, nof dat words <= 2**adr_w
    ram_sz	  : STRING;     -- used by Xilinx RAM's instead of dat_w
    init_sl   : STD_LOGIC;  -- optional, init all dat words to std_logic '0', '1' or 'X'
    --init_file : STRING;     -- "UNUSED", unconstrained length can not be in record 
  END RECORD;
  
  CONSTANT c_mem_ram_rd_latency : NATURAL := 2;  -- note common_ram_crw_crw(stratix4) now also supports read latency 1
  CONSTANT c_mem_ram            : t_c_mem := (c_mem_ram_rd_latency, 10,  9, 2**10,"18kb",'X');  -- 1 M9K
  
  CONSTANT c_mem_reg_rd_latency : NATURAL := 1;
  CONSTANT c_mem_reg            : t_c_mem := (c_mem_reg_rd_latency,  1, 32,     1,"18kb", 'X');
  
  CONSTANT c_mem_reg_init_w     : NATURAL := 1*256*32;  -- >= largest expected value of dat_w*nof_dat (256 * 32 bit = 1k byte)
  
    
  ------------------------------------------------------------------------------
  -- Functions to swap endianess
  ------------------------------------------------------------------------------
  FUNCTION func_mem_swap_endianess(mm : t_mem_miso; sz : NATURAL) RETURN t_mem_miso;
  FUNCTION func_mem_swap_endianess(mm : t_mem_mosi; sz : NATURAL) RETURN t_mem_mosi;
  
END common_ram_pkg;

PACKAGE BODY common_ram_pkg IS

  -- Resize functions to fit an integer or an SLV in the corresponding t_mem_miso or t_mem_mosi field width
  FUNCTION TO_MEM_ADDRESS(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(TO_SVEC(n, 32), c_mem_address_w);
  END TO_MEM_ADDRESS;
  
  FUNCTION TO_MEM_DATA(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN TO_MEM_UDATA(n);
  END TO_MEM_DATA;
  
  FUNCTION TO_MEM_UDATA(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(TO_SVEC(n, 32), c_mem_data_w);
  END TO_MEM_UDATA;
  
  FUNCTION TO_MEM_SDATA(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_SVEC(TO_SVEC(n, 32), c_mem_data_w);
  END TO_MEM_SDATA;
  
  FUNCTION RESIZE_MEM_ADDRESS(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(vec, c_mem_address_w);
  END RESIZE_MEM_ADDRESS;
  
  FUNCTION RESIZE_MEM_DATA(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_MEM_UDATA(vec);
  END RESIZE_MEM_DATA;
  
  FUNCTION RESIZE_MEM_UDATA(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(vec, c_mem_data_w);
  END RESIZE_MEM_UDATA;
  
  FUNCTION RESIZE_MEM_SDATA(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_SVEC(vec, c_mem_data_w);
  END RESIZE_MEM_SDATA;
  
  FUNCTION RESIZE_MEM_XDATA(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
    VARIABLE v_vec : STD_LOGIC_VECTOR(c_mem_data_w-1 DOWNTO 0) := (OTHERS=>'X');
  BEGIN
    v_vec(vec'LENGTH-1 DOWNTO 0) := vec;
    RETURN v_vec;
  END RESIZE_MEM_XDATA;
  

  -- Resize functions to fit an integer or an SLV in the corresponding t_mem_miso or t_mem_mosi field width
  FUNCTION TO_MEM_CTLR_ADDRESS(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(TO_SVEC(n, 32), c_mem_ctlr_address_w);
  END TO_MEM_CTLR_ADDRESS;

  FUNCTION TO_MEM_CTLR_DATA(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(TO_SVEC(n, 32), c_mem_ctlr_data_w);
  END TO_MEM_CTLR_DATA;
  
  FUNCTION TO_MEM_CTLR_BURSTSIZE(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(TO_SVEC(n, 32), c_mem_ctlr_burstsize_w);
  END TO_MEM_CTLR_BURSTSIZE;
  
  FUNCTION RESIZE_MEM_CTLR_ADDRESS(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(vec, c_mem_ctlr_address_w);
  END RESIZE_MEM_CTLR_ADDRESS;
  
  FUNCTION RESIZE_MEM_CTLR_DATA(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(vec, c_mem_ctlr_data_w);
  END RESIZE_MEM_CTLR_DATA;
  
  FUNCTION RESIZE_MEM_CTLR_BURSTSIZE(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(vec, c_mem_ctlr_burstsize_w);
  END RESIZE_MEM_CTLR_BURSTSIZE;

    
  -- Functions to swap endianess
  FUNCTION func_mem_swap_endianess(mm : t_mem_miso; sz : NATURAL) RETURN t_mem_miso IS
    VARIABLE v_mm : t_mem_miso;
  BEGIN
    -- Master In Slave Out
    v_mm.rddata  := hton(mm.rddata, sz);
    RETURN v_mm;
  END func_mem_swap_endianess;

  FUNCTION func_mem_swap_endianess(mm : t_mem_mosi; sz : NATURAL) RETURN t_mem_mosi IS
    VARIABLE v_mm : t_mem_mosi;
  BEGIN
    -- Master Out Slave In
    v_mm.address := mm.address;
    v_mm.wrdata  := hton(mm.wrdata, sz);
    v_mm.wr      := mm.wr;
    v_mm.rd      := mm.rd;
    RETURN v_mm;
  END func_mem_swap_endianess;

END common_ram_pkg;
