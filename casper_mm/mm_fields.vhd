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

-- Purpose:
-- . Define fields in an SLV that can be read/written via an MM interface.
-- Description:
-- . This is basically a wrapper around common_reg_r_w_dc, but with the 
--   addition of a generic field description array and package functions
--   to ease the definition and assignment of individual fields within
--   the i/o SLVs.
-- . Each field defined in g_field_arr will get its own 32-bit MM register(s)
--   based on its defined length:
--   . <32 bits = one dedicated 32-bit register for that field
--   . >32 bits = multiple dedicated 32-bit registers for that field
-- . The register mode can be "RO" for input from slv_in (e.g. status) or "RW"
--   for output via slv_out (e.g. control). Other modes are not supported.
--   Hence the length of the reg_slv_* signals is equal to slv_in'LENGTH +
--   slv_out'LENGTH.
-- . The figure below shows how the following example field array would be mapped. 
--
--   c_my_field_arr:= (( "my_field_2", "RW",  2 ), 
--                     ( "my_field_1", "RO",  2 ), 
--                     ( "my_field_0", "RO",  1 ));
--
--   ----------------------------------------------------------------------------------------------------------------
--   | slv_in             reg_slv_in_arr   reg_slv_in     common_reg_r_w     reg_slv_out                     slv_out|
--   |                                                                                                              |
--   |                            __          __          ______________          __                                |
--   |                         w0|f0|      w0|f0|        |0             |      w0|  |                               |
--   |                           |  | =====> |  | =====> |      RO      | =====> |  | =====>                        |
--   |                           |  |        |  |        |              |        |  |                               |
--   |   __                      |--|        |--|        |--------------|        |--|                               |
--   |  |f0|                   w1|f1|      w1|f1|        |1             |      w1|  |                          __   |
--   |  |f1| ==field_map_in==>   |f1| =====> |f1| =====> |      RO      | =====> |  | =====> field_map_out==> |f2|  |
--   |  |f1|                     |  |        |  |        |              |        |  |                         |f2|  |
--   |                           |--|        |--|        |--------------|        |--|                               |
--   |                         w2|  |      w2|f2|        |2             |      w2|f2|                               |
--   |                           |  |  /===> |f2| =====> |      RW      | =====> |f2| ==+==>                        |
--   |                           |__|  |     |__|        |______________|        |__|   |                           |
--   |                                 |                                                |                           |
--   |                                 \================================================/                           |
--   |                                                                                                              |
--   ----------------------------------------------------------------------------------------------------------------   
--   . slv_in  = 3 bits wide
--   . slv_out = 2 bits wide (= my_field_2 which is looped back to reg_slv_in because it is defined "RW")
--   . reg_reg_slv_in_arr, reg_slv_in, reg_slv_out = 3*c_word_w bits wide
-- Remarks:

LIBRARY IEEE, common_pkg_lib, casper_ram_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE work.common_field_pkg.ALL;

ENTITY mm_fields IS
  GENERIC (
    g_cross_clock_domain : BOOLEAN := TRUE; 
    g_use_slv_in_val     : BOOLEAN := TRUE;  -- use TRUE when slv_in_val is used, use FALSE to save logic when always slv_in_val='1'
    g_field_arr          : t_common_field_arr
  );
  PORT (
    mm_rst     : IN  STD_LOGIC;
    mm_clk     : IN  STD_LOGIC;

    mm_mosi    : IN  t_mem_mosi;
    mm_miso    : OUT t_mem_miso;
    
    slv_rst    : IN  STD_LOGIC;
    slv_clk    : IN  STD_LOGIC;

    --fields in these SLVs are defined by g_field_arr
    slv_in     : IN  STD_LOGIC_VECTOR(field_slv_in_len( g_field_arr)-1 DOWNTO 0) := (OTHERS=>'0');  -- slv of all "RO" fields in g_field_arr
    slv_in_val : IN  STD_LOGIC := '0';   -- strobe to signal that slv_in is valid and needs to be captured

    slv_out    : OUT STD_LOGIC_VECTOR(field_slv_out_len(g_field_arr)-1 DOWNTO 0)                    -- slv of all "RW" fields in g_field_arr
  );
END mm_fields;


ARCHITECTURE str OF mm_fields IS

  CONSTANT c_reg_nof_words : NATURAL := field_nof_words(g_field_arr, c_word_w);

  CONSTANT c_reg           : t_c_mem := (latency  => 1,
                                         adr_w    => ceil_log2(c_reg_nof_words),
                                         dat_w    => c_word_w,
                                         nof_dat  => c_reg_nof_words,
                                         init_sl  => '0');

  CONSTANT c_slv_out_defaults : STD_LOGIC_VECTOR(field_slv_out_len(g_field_arr)-1 DOWNTO 0) := field_map_defaults(g_field_arr);
  -- Map the default values onto c_init_reg
  CONSTANT c_init_reg : STD_LOGIC_VECTOR(c_mem_reg_init_w-1 DOWNTO 0) := RESIZE_UVEC(field_map_in(g_field_arr, c_slv_out_defaults, c_reg.dat_w, "RW"), c_mem_reg_init_w);

  SIGNAL slv_in_arr         : STD_LOGIC_VECTOR(c_reg.dat_w*c_reg.nof_dat-1 DOWNTO 0);
  SIGNAL reg_slv_in_arr     : STD_LOGIC_VECTOR(c_reg.dat_w*c_reg.nof_dat-1 DOWNTO 0);
  SIGNAL nxt_reg_slv_in_arr : STD_LOGIC_VECTOR(c_reg.dat_w*c_reg.nof_dat-1 DOWNTO 0);

  SIGNAL reg_slv_in         : STD_LOGIC_VECTOR(c_reg.dat_w*c_reg.nof_dat-1 DOWNTO 0);
  SIGNAL reg_slv_out        : STD_LOGIC_VECTOR(c_reg.dat_w*c_reg.nof_dat-1 DOWNTO 0);

BEGIN

  -----------------------------------------------------------------------------
  -- reg_slv_out is persistent (always valid) while slv_in is not. Register
  -- slv_in_arr so reg_slv_in is persistent also.
  -----------------------------------------------------------------------------
  gen_capture_input : IF g_use_slv_in_val=TRUE GENERATE
    p_clk : PROCESS(slv_clk, slv_rst)
    BEGIN
      IF slv_rst='1' THEN
        reg_slv_in_arr <= (OTHERS=>'0');
      ELSIF rising_edge(slv_clk) THEN
        reg_slv_in_arr <= nxt_reg_slv_in_arr;
      END IF;
    END PROCESS;
  
    nxt_reg_slv_in_arr <= slv_in_arr WHEN slv_in_val = '1' ELSE reg_slv_in_arr;
  END GENERATE;
  
  gen_wire_input : IF g_use_slv_in_val=FALSE GENERATE
    reg_slv_in_arr <= slv_in_arr;
  END GENERATE;
  
  -----------------------------------------------------------------------------
  -- Field mapping
  -----------------------------------------------------------------------------
  -- Extract the all input fields ("RO") from slv_in and assign them to slv_in_arr
  slv_in_arr <= field_map_in(g_field_arr, slv_in, c_reg.dat_w, "RO");

  -- Map reg_slv_out onto slv_out for the write fields
  slv_out <= field_map_out(g_field_arr, reg_slv_out, c_reg.dat_w);

  -- Create the correct reg_slv_in using fields from both reg_slv_in_arr ("RO") reg_slv_out ("RW")
  reg_slv_in <= field_map(g_field_arr, reg_slv_in_arr, reg_slv_out, c_reg.dat_w);

  -----------------------------------------------------------------------------
  -- Actual MM <-> SLV R/W functionality is provided by common_reg_r_w_dc
  -----------------------------------------------------------------------------
  u_common_reg_r_w_dc : ENTITY work.common_reg_r_w_dc
  GENERIC MAP (
    g_cross_clock_domain => g_cross_clock_domain,
    g_readback           => FALSE,
    g_reg                => c_reg,
    g_init_reg           => c_init_reg
  )
  PORT MAP (
    mm_rst      => mm_rst,
    mm_clk      => mm_clk,
    st_rst      => slv_rst,
    st_clk      => slv_clk,

    sla_in      => mm_mosi,
    sla_out     => mm_miso,

    in_reg      => reg_slv_in,
    out_reg     => reg_slv_out
  );

END str;
