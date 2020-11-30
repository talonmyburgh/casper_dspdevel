--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------
 
LIBRARY IEEE, common_pkg_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;

PACKAGE dp_stream_pkg Is

  ------------------------------------------------------------------------------
  -- General DP stream record defintion
  ------------------------------------------------------------------------------
  
  -- Remarks:
  -- * Choose smallest maximum SOSI slv lengths that fit all use cases, because unconstrained record fields slv is not allowed
  -- * The large SOSI data field width of 256b has some disadvantages:
  --   . about 10% extra simulation time and PC memory usage compared to 72b (measured using tb_unb_tse_board)
  --   . a 256b number has 64 hex digits in the Wave window which is awkward because of the leading zeros when typically
  --     only 32b are used, fortunately integer representation still works OK (except 0 which is shown as blank).
  --   However the alternatives are not attractive, because they affect the implementation of the streaming
  --   components that use the SOSI record. Alternatives are e.g.:
  --   . define an extra long SOSI data field ldata[255:0] in addition to the existing data[71:0] field
  --   . use the array of SOSI records to contain wider data, all with the same SOSI control field values
  --   . define another similar SOSI record with data[255:0].
  --   Therefore define data width as 256b, because the disadvantages are acceptable and the benefit is great, because all
  --   streaming components can remain as they are.
  -- * Added sync and bsn to SOSI to have timestamp information with the data
  -- * Added re and im to SOSI to support complex data for DSP
  -- * The sosi fields can be labeled in diffent groups: ctrl, info and data as shown in comment at the t_dp_sosi definition.
  --   This grouping is useful for functions that operate on a t_dp_sosi signal.
  -- * The info fields are valid at the sop or at the eop, but typically they hold their last active value to avoid unnessary
  --   toggling and to ease viewing in the wave window.
  CONSTANT c_dp_stream_bsn_w      : NATURAL :=  64;  -- 64 is sufficient to count blocks of data for years
  CONSTANT c_dp_stream_data_w     : NATURAL :=  72;  -- 72 is sufficient for max word 8 * 9-bit. 576 supports half rate DDR4 bus data width. The current 768 is enough for wide single clock SLVs (e.g. headers)
  CONSTANT c_dp_stream_dsp_data_w : NATURAL :=  64;  -- 64 is sufficient for DSP data, including complex power accumulates
  CONSTANT c_dp_stream_empty_w    : NATURAL :=  16;  --  8 is sufficient for max 256 symbols per data word, still use 16 bit to be able to count c_dp_stream_data_w in bits
  CONSTANT c_dp_stream_channel_w  : NATURAL :=  32;  -- 32 is sufficient for several levels of hierarchy in mapping types of streams on to channels 
  CONSTANT c_dp_stream_error_w    : NATURAL :=  32;  -- 32 is sufficient for several levels of hierarchy in mapping error numbers, e.g. 32 different one-hot encoded errors, bit [0] = 0 = OK
  
  CONSTANT c_dp_stream_ok         : NATURAL := 0;  -- SOSI err field OK value
  CONSTANT c_dp_stream_err        : NATURAL := 1;  -- SOSI err field error value /= OK
  
  CONSTANT c_dp_stream_rl         : NATURAL := 1;  -- SISO default data path stream ready latency RL = 1
  
  TYPE t_dp_siso IS RECORD  -- Source In or Sink Out
    ready    : STD_LOGIC;   -- fine cycle based flow control using ready latency RL >= 0
    xon      : STD_LOGIC;   -- coarse typically block based flow control using xon/xoff
  END RECORD;
  
  TYPE t_dp_sosi IS RECORD  -- Source Out or Sink In
    sync     : STD_LOGIC;                                           -- ctrl
    bsn      : STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);      -- info at sop      (block sequence number)
    data     : STD_LOGIC_VECTOR(c_dp_stream_data_w-1 DOWNTO 0);     -- data
    re       : STD_LOGIC_VECTOR(c_dp_stream_dsp_data_w-1 DOWNTO 0); -- data
    im       : STD_LOGIC_VECTOR(c_dp_stream_dsp_data_w-1 DOWNTO 0); -- data
    valid    : STD_LOGIC;                                           -- ctrl
    sop      : STD_LOGIC;                                           -- ctrl
    eop      : STD_LOGIC;                                           -- ctrl
    empty    : STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);    -- info at eop
    channel  : STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);  -- info at sop
    err      : STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);    -- info at eop (name field 'err' to avoid the 'error' keyword)
  END RECORD;


 
  -- Initialise signal declarations with c_dp_stream_rst/rdy to ease the interpretation of slv fields with unused bits
  CONSTANT c_dp_siso_rst   : t_dp_siso := ('0', '0');
  CONSTANT c_dp_siso_x     : t_dp_siso := ('X', 'X');
  CONSTANT c_dp_siso_hold  : t_dp_siso := ('0', '1');
  CONSTANT c_dp_siso_rdy   : t_dp_siso := ('1', '1');
  CONSTANT c_dp_siso_flush : t_dp_siso := ('1', '0');
  CONSTANT c_dp_sosi_rst   : t_dp_sosi := ('0', (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'), '0', '0', '0', (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'));
  CONSTANT c_dp_sosi_x     : t_dp_sosi := ('X', (OTHERS=>'X'), (OTHERS=>'X'), (OTHERS=>'X'), (OTHERS=>'X'), 'X', 'X', 'X', (OTHERS=>'X'), (OTHERS=>'X'), (OTHERS=>'X'));
  
  -- Use integers instead of slv for monitoring purposes (integer range limited to 31 bit plus sign bit)
  TYPE t_dp_sosi_integer IS RECORD
    sync     : STD_LOGIC;
    bsn      : NATURAL;
    data     : INTEGER;
    re       : INTEGER;
    im       : INTEGER;
    valid    : STD_LOGIC;
    sop      : STD_LOGIC;
    eop      : STD_LOGIC;
    empty    : NATURAL;
    channel  : NATURAL;
    err      : NATURAL;
  END RECORD;
  
  -- Use unsigned instead of slv for monitoring purposes beyond the integer range of t_dp_sosi_integer
  TYPE t_dp_sosi_unsigned IS RECORD
    sync     : STD_LOGIC;
    bsn      : UNSIGNED(c_dp_stream_bsn_w-1 DOWNTO 0);
    data     : UNSIGNED(c_dp_stream_data_w-1 DOWNTO 0);
    re       : UNSIGNED(c_dp_stream_dsp_data_w-1 DOWNTO 0);
    im       : UNSIGNED(c_dp_stream_dsp_data_w-1 DOWNTO 0);
    valid    : STD_LOGIC;
    sop      : STD_LOGIC;
    eop      : STD_LOGIC;
    empty    : UNSIGNED(c_dp_stream_empty_w-1 DOWNTO 0);
    channel  : UNSIGNED(c_dp_stream_channel_w-1 DOWNTO 0);
    err      : UNSIGNED(c_dp_stream_error_w-1 DOWNTO 0);
  END RECORD;
  
  CONSTANT c_dp_sosi_unsigned_rst  : t_dp_sosi_unsigned := ('0', (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'), '0', '0', '0', (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'));
  CONSTANT c_dp_sosi_unsigned_ones : t_dp_sosi_unsigned := ('1',
                                                            TO_UNSIGNED(1, c_dp_stream_bsn_w),
                                                            TO_UNSIGNED(1, c_dp_stream_data_w),
                                                            TO_UNSIGNED(1, c_dp_stream_dsp_data_w),
                                                            TO_UNSIGNED(1, c_dp_stream_dsp_data_w),
                                                            '1', '1', '1',
                                                            TO_UNSIGNED(1, c_dp_stream_empty_w),
                                                            TO_UNSIGNED(1, c_dp_stream_channel_w),
                                                            TO_UNSIGNED(1, c_dp_stream_error_w));
  
  -- Use boolean to define whether a t_dp_siso, t_dp_sosi field is used ('1') or not ('0')
  TYPE t_dp_siso_sl IS RECORD
    ready    : STD_LOGIC;
    xon      : STD_LOGIC;
  END RECORD;
  
  TYPE t_dp_sosi_sl IS RECORD
    sync     : STD_LOGIC;
    bsn      : STD_LOGIC;
    data     : STD_LOGIC;
    re       : STD_LOGIC;
    im       : STD_LOGIC;
    valid    : STD_LOGIC;
    sop      : STD_LOGIC;
    eop      : STD_LOGIC;
    empty    : STD_LOGIC;
    channel  : STD_LOGIC;
    err      : STD_LOGIC;
  END RECORD;
  
  CONSTANT c_dp_siso_sl_rst  : t_dp_siso_sl := ('0', '0');
  CONSTANT c_dp_siso_sl_ones : t_dp_siso_sl := ('1', '1');
  CONSTANT c_dp_sosi_sl_rst  : t_dp_sosi_sl := ('0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0');
  CONSTANT c_dp_sosi_sl_ones : t_dp_sosi_sl := ('1', '1', '1', '1', '1', '1', '1', '1', '1', '1', '1');
  
  -- Multi port or multi register array for DP stream records
  TYPE t_dp_siso_arr IS ARRAY (INTEGER RANGE <>) OF t_dp_siso;
  TYPE t_dp_sosi_arr IS ARRAY (INTEGER RANGE <>) OF t_dp_sosi;

  TYPE t_dp_sosi_integer_arr  IS ARRAY (INTEGER RANGE <>) OF t_dp_sosi_integer;
  TYPE t_dp_sosi_unsigned_arr IS ARRAY (INTEGER RANGE <>) OF t_dp_sosi_unsigned;

  TYPE t_dp_siso_sl_arr IS ARRAY (INTEGER RANGE <>) OF t_dp_siso_sl;
  TYPE t_dp_sosi_sl_arr IS ARRAY (INTEGER RANGE <>) OF t_dp_sosi_sl;
  
  -- Multi port or multi register slv arrays for DP stream records fields
  TYPE t_dp_bsn_slv_arr      IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);
  TYPE t_dp_data_slv_arr     IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_dp_stream_data_w-1 DOWNTO 0);
  TYPE t_dp_dsp_data_slv_arr IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_dp_stream_dsp_data_w-1 DOWNTO 0);
  TYPE t_dp_empty_slv_arr    IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);
  TYPE t_dp_channel_slv_arr  IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);
  TYPE t_dp_error_slv_arr    IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);
  
  -- Multi-dimemsion array types with fixed LS-dimension
  TYPE t_dp_siso_2arr_1 IS ARRAY (INTEGER RANGE <>) OF t_dp_siso_arr(0 DOWNTO 0);
  TYPE t_dp_sosi_2arr_1 IS ARRAY (INTEGER RANGE <>) OF t_dp_sosi_arr(0 DOWNTO 0);

  -- . 2 dimensional array with 2 fixed LS sosi/siso interfaces (dp_split, dp_concat)
  TYPE t_dp_siso_2arr_2 IS ARRAY (INTEGER RANGE <>) OF t_dp_siso_arr(1 DOWNTO 0);
  TYPE t_dp_sosi_2arr_2 IS ARRAY (INTEGER RANGE <>) OF t_dp_sosi_arr(1 DOWNTO 0);

  TYPE t_dp_siso_2arr_3 IS ARRAY (INTEGER RANGE <>) OF t_dp_siso_arr(2 DOWNTO 0);
  TYPE t_dp_sosi_2arr_3 IS ARRAY (INTEGER RANGE <>) OF t_dp_sosi_arr(2 DOWNTO 0);

  TYPE t_dp_siso_2arr_4 IS ARRAY (INTEGER RANGE <>) OF t_dp_siso_arr(3 DOWNTO 0);
  TYPE t_dp_sosi_2arr_4 IS ARRAY (INTEGER RANGE <>) OF t_dp_sosi_arr(3 DOWNTO 0);

  TYPE t_dp_siso_2arr_8 IS ARRAY (INTEGER RANGE <>) OF t_dp_siso_arr(7 DOWNTO 0);
  TYPE t_dp_sosi_2arr_8 IS ARRAY (INTEGER RANGE <>) OF t_dp_sosi_arr(7 DOWNTO 0);

  TYPE t_dp_siso_2arr_9 IS ARRAY (INTEGER RANGE <>) OF t_dp_siso_arr(8 DOWNTO 0);
  TYPE t_dp_sosi_2arr_9 IS ARRAY (INTEGER RANGE <>) OF t_dp_sosi_arr(8 DOWNTO 0);

  TYPE t_dp_siso_2arr_12 IS ARRAY (INTEGER RANGE <>) OF t_dp_siso_arr(11 DOWNTO 0);
  TYPE t_dp_sosi_2arr_12 IS ARRAY (INTEGER RANGE <>) OF t_dp_sosi_arr(11 DOWNTO 0);
 
  TYPE t_dp_siso_3arr_4_2 IS ARRAY (INTEGER RANGE <>) OF t_dp_siso_2arr_2(3 DOWNTO 0);
  TYPE t_dp_sosi_3arr_4_2 IS ARRAY (INTEGER RANGE <>) OF t_dp_sosi_2arr_2(3 DOWNTO 0);
 
  -- 2-dimensional streaming array type:
  -- Note:
  --   This t_*_mat is less useful then a t_*_2arr array of arrays, because assignments can only be done per element (i.e. not per row). However for t_*_2arr
  --   the arrays dimension must be fixed, so these t_*_2arr types are application dependent and need to be defined where used. 
  TYPE t_dp_siso_mat IS ARRAY (INTEGER RANGE <>, INTEGER RANGE <>) OF t_dp_siso;
  TYPE t_dp_sosi_mat IS ARRAY (INTEGER RANGE <>, INTEGER RANGE <>) OF t_dp_sosi;

  -- Check sosi.valid against siso.ready
  PROCEDURE proc_dp_siso_alert(CONSTANT c_ready_latency : IN    NATURAL;
                               SIGNAL   clk             : IN    STD_LOGIC;
                               SIGNAL   sosi            : IN    t_dp_sosi;
                               SIGNAL   siso            : IN    t_dp_siso;
                               SIGNAL   ready_reg       : INOUT STD_LOGIC_VECTOR);

  -- Default RL=1
  PROCEDURE proc_dp_siso_alert(SIGNAL   clk             : IN    STD_LOGIC;
                               SIGNAL   sosi            : IN    t_dp_sosi;
                               SIGNAL   siso            : IN    t_dp_siso;
                               SIGNAL   ready_reg       : INOUT STD_LOGIC_VECTOR);

  -- SOSI/SISO array version
  PROCEDURE proc_dp_siso_alert(CONSTANT c_ready_latency : IN    NATURAL;
                               SIGNAL   clk             : IN    STD_LOGIC;
                               SIGNAL   sosi_arr        : IN    t_dp_sosi_arr;
                               SIGNAL   siso_arr        : IN    t_dp_siso_arr;
                               SIGNAL   ready_reg       : INOUT STD_LOGIC_VECTOR);

  -- SOSI/SISO array version with RL=1
  PROCEDURE proc_dp_siso_alert(SIGNAL   clk             : IN    STD_LOGIC;
                               SIGNAL   sosi_arr        : IN    t_dp_sosi_arr;
                               SIGNAL   siso_arr        : IN    t_dp_siso_arr;
                               SIGNAL   ready_reg       : INOUT STD_LOGIC_VECTOR);

  -- Resize functions to fit an integer or an SLV in the corresponding t_dp_sosi field width
  -- . Use these functions to assign sosi data TO a record field
  -- . Use the range selection [n-1 DOWNTO 0] to assign sosi data FROM a record field to an slv
  -- . The unused sosi data field bits could remain undefined 'X', because the unused bits in the fields are not used at all. 
  --   Typically the sosi data are treated as unsigned in the record field, so extended with '0'. However for interpretating
  --   signed data in the simulation wave window it is easier to use sign extension in the record field. Therefore TO_DP_SDATA
  --   and RESIZE_DP_SDATA are defined as well.
  FUNCTION TO_DP_BSN(     n : NATURAL) RETURN STD_LOGIC_VECTOR;
  FUNCTION TO_DP_DATA(    n : INTEGER) RETURN STD_LOGIC_VECTOR;  -- use integer to support 32 bit range, so -1 = 0xFFFFFFFF = +2**32-1
  FUNCTION TO_DP_SDATA(   n : INTEGER) RETURN STD_LOGIC_VECTOR;  -- use integer to support 32 bit range and signed
  FUNCTION TO_DP_UDATA(   n : INTEGER) RETURN STD_LOGIC_VECTOR;  -- alias of TO_DP_DATA()
  FUNCTION TO_DP_DSP_DATA(n : INTEGER) RETURN STD_LOGIC_VECTOR;  -- for re and im fields, signed data
  FUNCTION TO_DP_DSP_UDATA(n: INTEGER) RETURN STD_LOGIC_VECTOR;  -- for re and im fields, unsigned data (useful to carry indices)
  FUNCTION TO_DP_EMPTY(   n : NATURAL) RETURN STD_LOGIC_VECTOR;
  FUNCTION TO_DP_CHANNEL( n : NATURAL) RETURN STD_LOGIC_VECTOR;
  FUNCTION TO_DP_ERROR(   n : NATURAL) RETURN STD_LOGIC_VECTOR;
  FUNCTION RESIZE_DP_BSN(     vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;
  FUNCTION RESIZE_DP_DATA(    vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;  -- set unused MSBits to '0'
  FUNCTION RESIZE_DP_SDATA(   vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;  -- sign extend unused MSBits
  FUNCTION RESIZE_DP_XDATA(   vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;  -- set unused MSBits to 'X'
  FUNCTION RESIZE_DP_DSP_DATA(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;  -- sign extend unused MSBits of re and im fields
  FUNCTION RESIZE_DP_EMPTY(   vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;
  FUNCTION RESIZE_DP_CHANNEL( vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;
  FUNCTION RESIZE_DP_ERROR(   vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;
  
  FUNCTION INCR_DP_DATA(    vec : STD_LOGIC_VECTOR; dec : INTEGER; w : NATURAL) RETURN STD_LOGIC_VECTOR;  -- unsigned vec(w-1:0) + dec
  FUNCTION INCR_DP_SDATA(   vec : STD_LOGIC_VECTOR; dec : INTEGER; w : NATURAL) RETURN STD_LOGIC_VECTOR;  --   signed vec(w-1:0) + dec
  FUNCTION INCR_DP_DSP_DATA(vec : STD_LOGIC_VECTOR; dec : INTEGER; w : NATURAL) RETURN STD_LOGIC_VECTOR;  --   signed vec(w-1:0) + dec
  
  FUNCTION REPLICATE_DP_DATA(  seq  : STD_LOGIC_VECTOR                 ) RETURN STD_LOGIC_VECTOR;  -- replicate seq as often as fits in c_dp_stream_data_w
  FUNCTION UNREPLICATE_DP_DATA(data : STD_LOGIC_VECTOR; seq_w : NATURAL) RETURN STD_LOGIC_VECTOR;  -- unreplicate data to width seq_w, return low seq_w bits and set mismatch MSbits bits to '1'

  FUNCTION TO_DP_SOSI_UNSIGNED(sync, valid, sop, eop : STD_LOGIC; bsn, data, re, im, empty, channel, err : UNSIGNED) RETURN t_dp_sosi_unsigned;

  -- Keep part of head data and combine part of tail data, use the other sosi from head_sosi
  FUNCTION func_dp_data_shift_first(head_sosi, tail_sosi : t_dp_sosi; symbol_w, nof_symbols_per_data, nof_symbols_from_tail              : NATURAL) RETURN t_dp_sosi;
  -- Shift and combine part of previous data and this data, use the other sosi from prev_sosi
  FUNCTION func_dp_data_shift(      prev_sosi, this_sosi : t_dp_sosi; symbol_w, nof_symbols_per_data, nof_symbols_from_this              : NATURAL) RETURN t_dp_sosi;
  -- Shift part of tail data and account for input empty
  FUNCTION func_dp_data_shift_last(            tail_sosi : t_dp_sosi; symbol_w, nof_symbols_per_data, nof_symbols_from_tail, input_empty : NATURAL) RETURN t_dp_sosi;
    
  -- Determine resulting empty if two streams are concatenated or split
  FUNCTION func_dp_empty_concat(head_empty, tail_empty : STD_LOGIC_VECTOR; nof_symbols_per_data : NATURAL) RETURN STD_LOGIC_VECTOR;
  FUNCTION func_dp_empty_split(input_empty, head_empty : STD_LOGIC_VECTOR; nof_symbols_per_data : NATURAL) RETURN STD_LOGIC_VECTOR;
  
  -- Multiplex the t_dp_sosi_arr based on the valid, assuming that at most one input is active valid.
  FUNCTION func_dp_sosi_arr_mux(dp : t_dp_sosi_arr) RETURN t_dp_sosi;
  
  -- Determine the combined logical value of corresponding STD_LOGIC fields in t_dp_*_arr (for all elements or only for the mask[]='1' elements)
  FUNCTION func_dp_stream_arr_and(dp : t_dp_siso_arr; mask : STD_LOGIC_VECTOR; str : STRING) RETURN STD_LOGIC;
  FUNCTION func_dp_stream_arr_and(dp : t_dp_sosi_arr; mask : STD_LOGIC_VECTOR; str : STRING) RETURN STD_LOGIC;
  FUNCTION func_dp_stream_arr_and(dp : t_dp_siso_arr;                          str : STRING) RETURN STD_LOGIC;
  FUNCTION func_dp_stream_arr_and(dp : t_dp_sosi_arr;                          str : STRING) RETURN STD_LOGIC;
  FUNCTION func_dp_stream_arr_or( dp : t_dp_siso_arr; mask : STD_LOGIC_VECTOR; str : STRING) RETURN STD_LOGIC;
  FUNCTION func_dp_stream_arr_or( dp : t_dp_sosi_arr; mask : STD_LOGIC_VECTOR; str : STRING) RETURN STD_LOGIC;
  FUNCTION func_dp_stream_arr_or( dp : t_dp_siso_arr;                          str : STRING) RETURN STD_LOGIC;
  FUNCTION func_dp_stream_arr_or( dp : t_dp_sosi_arr;                          str : STRING) RETURN STD_LOGIC;
  
  -- Functions to set or get a STD_LOGIC field as a STD_LOGIC_VECTOR to or from an siso or an sosi array
  FUNCTION func_dp_stream_arr_set(dp : t_dp_siso_arr; slv : STD_LOGIC_VECTOR; str : STRING) RETURN t_dp_siso_arr;
  FUNCTION func_dp_stream_arr_set(dp : t_dp_sosi_arr; slv : STD_LOGIC_VECTOR; str : STRING) RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_arr_set(dp : t_dp_siso_arr; sl  : STD_LOGIC;        str : STRING) RETURN t_dp_siso_arr;
  FUNCTION func_dp_stream_arr_set(dp : t_dp_sosi_arr; sl  : STD_LOGIC;        str : STRING) RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_arr_get(dp : t_dp_siso_arr;                         str : STRING) RETURN STD_LOGIC_VECTOR;
  FUNCTION func_dp_stream_arr_get(dp : t_dp_sosi_arr;                         str : STRING) RETURN STD_LOGIC_VECTOR;
  
  -- Functions to select elements from two siso or two sosi arrays (sel[] = '1' selects a, sel[] = '0' selects b)
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a,                 b : t_dp_siso)     RETURN t_dp_siso_arr;
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a,                 b : t_dp_sosi)     RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a : t_dp_siso_arr; b : t_dp_siso)     RETURN t_dp_siso_arr;
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a : t_dp_sosi_arr; b : t_dp_sosi)     RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a : t_dp_siso;     b : t_dp_siso_arr) RETURN t_dp_siso_arr;
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a : t_dp_sosi;     b : t_dp_sosi_arr) RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a,                 b : t_dp_siso_arr) RETURN t_dp_siso_arr;
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a,                 b : t_dp_sosi_arr) RETURN t_dp_sosi_arr;

  -- Fix reversed buses due to connecting TO to DOWNTO range arrays. 
  FUNCTION func_dp_stream_arr_reverse_range(in_arr : t_dp_sosi_arr) RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_arr_reverse_range(in_arr : t_dp_siso_arr) RETURN t_dp_siso_arr;

  -- Functions to combinatorially hold the data fields and to set or reset the control fields in an sosi array
  FUNCTION func_dp_stream_arr_combine_data_info_ctrl(dp : t_dp_sosi_arr; info, ctrl : t_dp_sosi) RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_arr_set_info(              dp : t_dp_sosi_arr; info       : t_dp_sosi) RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_arr_set_control(           dp : t_dp_sosi_arr;       ctrl : t_dp_sosi) RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_arr_reset_control(         dp : t_dp_sosi_arr                        ) RETURN t_dp_sosi_arr;
  
  -- Reset sosi ctrl and preserve the sosi data (to avoid unnecessary data toggling and to ease data view in Wave window)
  FUNCTION func_dp_stream_reset_control(dp : t_dp_sosi) RETURN t_dp_sosi;
  
  -- Functions to combinatorially determine the maximum and minimum sosi bsn[w-1:0] value in the sosi array (for all elements or only for the mask[]='1' elements)
  FUNCTION func_dp_stream_arr_bsn_max(dp : t_dp_sosi_arr; mask : STD_LOGIC_VECTOR; w : NATURAL) RETURN STD_LOGIC_VECTOR;
  FUNCTION func_dp_stream_arr_bsn_max(dp : t_dp_sosi_arr;                          w : NATURAL) RETURN STD_LOGIC_VECTOR;
  FUNCTION func_dp_stream_arr_bsn_min(dp : t_dp_sosi_arr; mask : STD_LOGIC_VECTOR; w : NATURAL) RETURN STD_LOGIC_VECTOR;
  FUNCTION func_dp_stream_arr_bsn_min(dp : t_dp_sosi_arr;                          w : NATURAL) RETURN STD_LOGIC_VECTOR;
  
  -- Function to copy the BSN of one valid stream to all output streams. 
  FUNCTION func_dp_stream_arr_copy_valid_bsn(dp : t_dp_sosi_arr; mask : STD_LOGIC_VECTOR) RETURN t_dp_sosi_arr;
  
  -- Functions to combinatorially handle channels
  -- Note that the *_select and *_remove function are equivalent to dp_demux with g_combined=TRUE
  FUNCTION func_dp_stream_channel_set   (st_sosi : t_dp_sosi; ch : NATURAL) RETURN t_dp_sosi;  -- select channel nr, add the channel field
  FUNCTION func_dp_stream_channel_select(st_sosi : t_dp_sosi; ch : NATURAL) RETURN t_dp_sosi;  -- select channel nr, skip the channel field
  FUNCTION func_dp_stream_channel_remove(st_sosi : t_dp_sosi; ch : NATURAL) RETURN t_dp_sosi;  -- skip channel nr
  
  -- Functions to combinatorially handle the error field
  FUNCTION func_dp_stream_error_set(st_sosi : t_dp_sosi; n : NATURAL) RETURN t_dp_sosi;  -- force err = 0, is OK
  
  -- Functions to combinatorially handle the BSN field
  FUNCTION func_dp_stream_bsn_set(st_sosi : t_dp_sosi; bsn : STD_LOGIC_VECTOR) RETURN t_dp_sosi;
  
  -- Functions to combine sosi fields
  FUNCTION func_dp_stream_combine_info_and_data(info, data : t_dp_sosi) RETURN t_dp_sosi;
  
  -- Functions to convert sosi fields
  FUNCTION func_dp_stream_slv_to_integer(slv_sosi : t_dp_sosi; w : NATURAL) RETURN t_dp_sosi_integer;

  -- Functions to set the DATA, RE and IM field in a stream.
  FUNCTION func_dp_stream_set_data(dp : t_dp_sosi;     slv : STD_LOGIC_VECTOR; str : STRING                         ) RETURN t_dp_sosi;
  FUNCTION func_dp_stream_set_data(dp : t_dp_sosi_arr; slv : STD_LOGIC_VECTOR; str : STRING                         ) RETURN t_dp_sosi_arr; 
  FUNCTION func_dp_stream_set_data(dp : t_dp_sosi_arr; slv : STD_LOGIC_VECTOR; str : STRING; mask : STD_LOGIC_VECTOR) RETURN t_dp_sosi_arr;
 
   -- Functions to rewire between concatenated sosi.data and concatenated sosi.re,im
   -- . data_order_im_re defines the concatenation order data = im&re or re&im
   -- . nof_data defines the number of concatenated streams that are concatenated in the sosi.data or sosi.re,im
   -- . rewire nof_data streams from data  to re,im and force data = X  to show that sosi data    is used
   -- . rewire nof_data streams from re,im to data  and force re,im = X to show that sosi complex is used
  FUNCTION func_dp_stream_complex_to_data(dp : t_dp_sosi; data_w : NATURAL; nof_data : NATURAL; data_order_im_re : BOOLEAN) RETURN t_dp_sosi;
  FUNCTION func_dp_stream_complex_to_data(dp : t_dp_sosi; data_w : NATURAL; nof_data : NATURAL                            ) RETURN t_dp_sosi;  -- data_order_im_re = TRUE
  FUNCTION func_dp_stream_complex_to_data(dp : t_dp_sosi; data_w : NATURAL                                                ) RETURN t_dp_sosi;  -- data_order_im_re = TRUE, nof_data = 1
  FUNCTION func_dp_stream_data_to_complex(dp : t_dp_sosi; data_w : NATURAL; nof_data : NATURAL; data_order_im_re : BOOLEAN) RETURN t_dp_sosi;
  FUNCTION func_dp_stream_data_to_complex(dp : t_dp_sosi; data_w : NATURAL; nof_data : NATURAL                            ) RETURN t_dp_sosi;  -- data_order_im_re = TRUE
  FUNCTION func_dp_stream_data_to_complex(dp : t_dp_sosi; data_w : NATURAL                                                ) RETURN t_dp_sosi;  -- data_order_im_re = TRUE, nof_data = 1

  FUNCTION func_dp_stream_complex_to_data(dp_arr : t_dp_sosi_arr; data_w : NATURAL; nof_data : NATURAL; data_order_im_re : BOOLEAN) RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_complex_to_data(dp_arr : t_dp_sosi_arr; data_w : NATURAL; nof_data : NATURAL                            ) RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_complex_to_data(dp_arr : t_dp_sosi_arr; data_w : NATURAL                                                ) RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_data_to_complex(dp_arr : t_dp_sosi_arr; data_w : NATURAL; nof_data : NATURAL; data_order_im_re : BOOLEAN) RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_data_to_complex(dp_arr : t_dp_sosi_arr; data_w : NATURAL; nof_data : NATURAL                            ) RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_data_to_complex(dp_arr : t_dp_sosi_arr; data_w : NATURAL                                                ) RETURN t_dp_sosi_arr;

  -- Concatenate the data and complex re,im fields from a SOSI array into a single SOSI stream (assumes streams are in sync)
  FUNCTION func_dp_stream_concat(snk_in_arr : t_dp_sosi_arr; data_w : NATURAL) RETURN t_dp_sosi; -- Concat SOSI_ARR data into single SOSI
  FUNCTION func_dp_stream_concat(src_in     : t_dp_siso; nof_streams : NATURAL) RETURN t_dp_siso_arr; -- Wire single SISO to SISO_ARR

  -- Reconcatenate the data and complex re,im fields from a SOSI array from nof_data*in_w to nof_data*out_w
  -- . data_representation = "SIGNED"   treat sosi.data field as signed
  --                         "UNSIGNED" treat sosi.data field as unsigned
  --                         "COMPLEX"  treat sosi.data field as complex concatenated
  -- . data_order_im_re = TRUE  then "COMPLEX" data = im&re
  --                      FALSE then "COMPLEX" data = re&im
  --                      ignore when data_representation /= "COMPLEX"
  FUNCTION func_dp_stream_reconcat(snk_in     : t_dp_sosi;     in_w, out_w, nof_data : NATURAL; data_representation : STRING; data_order_im_re : BOOLEAN) RETURN t_dp_sosi;
  FUNCTION func_dp_stream_reconcat(snk_in     : t_dp_sosi;     in_w, out_w, nof_data : NATURAL; data_representation : STRING                            ) RETURN t_dp_sosi;
  FUNCTION func_dp_stream_reconcat(snk_in_arr : t_dp_sosi_arr; in_w, out_w, nof_data : NATURAL; data_representation : STRING; data_order_im_re : BOOLEAN) RETURN t_dp_sosi_arr;
  FUNCTION func_dp_stream_reconcat(snk_in_arr : t_dp_sosi_arr; in_w, out_w, nof_data : NATURAL; data_representation : STRING                            ) RETURN t_dp_sosi_arr;

  -- Deconcatenate data and complex re,im fields from SOSI into SOSI array
  FUNCTION func_dp_stream_deconcat(snk_in      : t_dp_sosi; nof_streams, data_w : NATURAL) RETURN t_dp_sosi_arr; -- Deconcat SOSI data
  FUNCTION func_dp_stream_deconcat(src_out_arr : t_dp_siso_arr) RETURN t_dp_siso; -- Wire SISO_ARR(0) to single SISO 
  
END dp_stream_pkg;


PACKAGE BODY dp_stream_pkg IS
 
  -- Check sosi.valid against siso.ready
  PROCEDURE proc_dp_siso_alert(CONSTANT c_ready_latency : IN    NATURAL;
                               SIGNAL   clk             : IN    STD_LOGIC;
                               SIGNAL   sosi            : IN    t_dp_sosi;
                               SIGNAL   siso            : IN    t_dp_siso;
                               SIGNAL   ready_reg       : INOUT STD_LOGIC_VECTOR) IS
  BEGIN
    ready_reg(0) <= siso.ready;
    -- Register siso.ready in c_ready_latency registers
    IF rising_edge(clk) THEN
      -- Check DP sink
      IF sosi.valid = '1' AND ready_reg(c_ready_latency) = '0' THEN
        REPORT "RL ERROR" SEVERITY FAILURE;
      END IF;
      ready_reg( 1 TO c_ready_latency) <= ready_reg( 0 TO c_ready_latency-1);
    END IF;
  END proc_dp_siso_alert;

  -- Default RL=1
  PROCEDURE proc_dp_siso_alert(SIGNAL   clk             : IN    STD_LOGIC;
                               SIGNAL   sosi            : IN    t_dp_sosi;
                               SIGNAL   siso            : IN    t_dp_siso;
                               SIGNAL   ready_reg       : INOUT STD_LOGIC_VECTOR) IS
  BEGIN
    proc_dp_siso_alert(1, clk, sosi, siso, ready_reg);
  END proc_dp_siso_alert;

  -- SOSI/SISO array version
  PROCEDURE proc_dp_siso_alert(CONSTANT c_ready_latency : IN    NATURAL;
                               SIGNAL   clk             : IN    STD_LOGIC;
                               SIGNAL   sosi_arr        : IN    t_dp_sosi_arr;
                               SIGNAL   siso_arr        : IN    t_dp_siso_arr;
                               SIGNAL   ready_reg       : INOUT STD_LOGIC_VECTOR) IS
  BEGIN
    FOR i IN 0 TO sosi_arr'LENGTH-1 LOOP 
      ready_reg(i*(c_ready_latency+1)) <= siso_arr(i).ready; -- SLV is used as an array: nof_streams*(0..c_ready_latency)
    END LOOP;
    -- Register siso.ready in c_ready_latency registers
    IF rising_edge(clk) THEN
      FOR i IN 0 TO sosi_arr'LENGTH-1 LOOP
        -- Check DP sink
        IF sosi_arr(i).valid = '1' AND ready_reg(i*(c_ready_latency+1)+1) = '0' THEN
          REPORT "RL ERROR" SEVERITY FAILURE;
        END IF; 
        ready_reg(i*(c_ready_latency+1)+1 TO i*(c_ready_latency+1)+c_ready_latency) <=  ready_reg(i*(c_ready_latency+1) TO i*(c_ready_latency+1)+c_ready_latency-1);
      END LOOP;
    END IF;  
  END proc_dp_siso_alert;

  -- SOSI/SISO array version with RL=1
  PROCEDURE proc_dp_siso_alert(SIGNAL   clk             : IN    STD_LOGIC;
                               SIGNAL   sosi_arr        : IN    t_dp_sosi_arr;
                               SIGNAL   siso_arr        : IN    t_dp_siso_arr;
                               SIGNAL   ready_reg       : INOUT STD_LOGIC_VECTOR) IS
  BEGIN
    proc_dp_siso_alert(1, clk, sosi_arr, siso_arr, ready_reg);
  END proc_dp_siso_alert;
 
  -- Resize functions to fit an integer or an SLV in the corresponding t_dp_sosi field width
  FUNCTION TO_DP_BSN(n : NATURAL) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(TO_SVEC(n, 32), c_dp_stream_bsn_w);
  END TO_DP_BSN;
  
  FUNCTION TO_DP_DATA(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(TO_SVEC(n, 32), c_dp_stream_data_w);
  END TO_DP_DATA;
  
  FUNCTION TO_DP_SDATA(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_SVEC(TO_SVEC(n, 32), c_dp_stream_data_w);
  END TO_DP_SDATA;
  
  FUNCTION TO_DP_UDATA(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN TO_DP_DATA(n);
  END TO_DP_UDATA;
  
  FUNCTION TO_DP_DSP_DATA(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_SVEC(TO_SVEC(n, 32), c_dp_stream_dsp_data_w);
  END TO_DP_DSP_DATA;
  
  FUNCTION TO_DP_DSP_UDATA(n : INTEGER) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(TO_SVEC(n, 32), c_dp_stream_dsp_data_w);
  END TO_DP_DSP_UDATA;
  
  FUNCTION TO_DP_EMPTY(n : NATURAL) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN TO_UVEC(n, c_dp_stream_empty_w);
  END TO_DP_EMPTY;
  
  FUNCTION TO_DP_CHANNEL(n : NATURAL) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN TO_UVEC(n, c_dp_stream_channel_w);
  END TO_DP_CHANNEL;
  
  FUNCTION TO_DP_ERROR(n : NATURAL) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN TO_UVEC(n, c_dp_stream_error_w);
  END TO_DP_ERROR;
  
  FUNCTION RESIZE_DP_BSN(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(vec, c_dp_stream_bsn_w);
  END RESIZE_DP_BSN;
  
  FUNCTION RESIZE_DP_DATA(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(vec, c_dp_stream_data_w);
  END RESIZE_DP_DATA;
  
  FUNCTION RESIZE_DP_SDATA(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_SVEC(vec, c_dp_stream_data_w);
  END RESIZE_DP_SDATA;
  
  FUNCTION RESIZE_DP_XDATA(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
    VARIABLE v_vec : STD_LOGIC_VECTOR(c_dp_stream_data_w-1 DOWNTO 0) := (OTHERS=>'X');
  BEGIN
    v_vec(vec'LENGTH-1 DOWNTO 0) := vec;
    RETURN v_vec;
  END RESIZE_DP_XDATA;
  
  FUNCTION RESIZE_DP_DSP_DATA(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_SVEC(vec, c_dp_stream_dsp_data_w);
  END RESIZE_DP_DSP_DATA;
  
  FUNCTION RESIZE_DP_EMPTY(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(vec, c_dp_stream_empty_w);
  END RESIZE_DP_EMPTY;
  
  FUNCTION RESIZE_DP_CHANNEL(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(vec, c_dp_stream_channel_w);
  END RESIZE_DP_CHANNEL;
  
  FUNCTION RESIZE_DP_ERROR(vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(vec, c_dp_stream_error_w);
  END RESIZE_DP_ERROR;
  
  FUNCTION INCR_DP_DATA(vec : STD_LOGIC_VECTOR; dec : INTEGER; w : NATURAL) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_DP_DATA(STD_LOGIC_VECTOR(UNSIGNED(vec(w-1 DOWNTO 0)) + dec));
  END INCR_DP_DATA;
  
  FUNCTION INCR_DP_SDATA(vec : STD_LOGIC_VECTOR; dec : INTEGER; w : NATURAL) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_DP_SDATA(STD_LOGIC_VECTOR(SIGNED(vec(w-1 DOWNTO 0)) + dec));
  END INCR_DP_SDATA;

  FUNCTION INCR_DP_DSP_DATA(vec : STD_LOGIC_VECTOR; dec : INTEGER; w : NATURAL) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_DP_DSP_DATA(STD_LOGIC_VECTOR(SIGNED(vec(w-1 DOWNTO 0)) + dec));
  END INCR_DP_DSP_DATA;  
  
  FUNCTION REPLICATE_DP_DATA(seq : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
    CONSTANT c_seq_w            : NATURAL := seq'LENGTH;
    CONSTANT c_nof_replications : NATURAL := ceil_div(c_dp_stream_data_w, c_seq_w);
    CONSTANT c_vec_w            : NATURAL := ceil_value(c_dp_stream_data_w, c_seq_w);
    VARIABLE v_vec              : STD_LOGIC_VECTOR(c_vec_w-1 DOWNTO 0);
  BEGIN
    FOR I IN 0 TO c_nof_replications-1 LOOP
      v_vec((I+1)*c_seq_w-1 DOWNTO I*c_seq_w) := seq;
    END LOOP;
    RETURN v_vec(c_dp_stream_data_w-1 DOWNTO 0);
  END REPLICATE_DP_DATA;
  
  FUNCTION UNREPLICATE_DP_DATA(data : STD_LOGIC_VECTOR; seq_w :NATURAL) RETURN STD_LOGIC_VECTOR IS
    CONSTANT c_data_w           : NATURAL := data'LENGTH;
    CONSTANT c_nof_replications : NATURAL := ceil_div(c_data_w, seq_w);
    CONSTANT c_vec_w            : NATURAL := ceil_value(c_data_w, seq_w);
    VARIABLE v_seq              : STD_LOGIC_VECTOR(seq_w-1 DOWNTO 0);
    VARIABLE v_data             : STD_LOGIC_VECTOR(c_vec_w-1 DOWNTO 0);
    VARIABLE v_vec              : STD_LOGIC_VECTOR(c_vec_w-1 DOWNTO 0);
  BEGIN
    v_data := RESIZE_UVEC(data, c_vec_w);
    v_seq := v_data(seq_w-1 DOWNTO 0);                                                          -- low data part is the v_seq
    v_vec(seq_w-1 DOWNTO 0) := v_seq;                                                           -- keep v_seq at low part of return value
    IF c_nof_replications>1 THEN
      FOR I IN 1 TO c_nof_replications-1 LOOP
        v_vec((I+1)*seq_w-1 DOWNTO I*seq_w) := v_data((I+1)*seq_w-1 DOWNTO I*seq_w) XOR v_seq;  -- set return bit to '1' for high part data bits that do not match low part v_seq
      END LOOP;
    END IF;
    RETURN v_vec(c_data_w-1 DOWNTO 0);
  END UNREPLICATE_DP_DATA;
  
  FUNCTION TO_DP_SOSI_UNSIGNED(sync, valid, sop, eop : STD_LOGIC; bsn, data, re, im, empty, channel, err : UNSIGNED) RETURN t_dp_sosi_unsigned IS
    VARIABLE v_sosi_unsigned : t_dp_sosi_unsigned;
  BEGIN
    v_sosi_unsigned.sync    := sync;
    v_sosi_unsigned.valid   := valid;
    v_sosi_unsigned.sop     := sop;
    v_sosi_unsigned.eop     := eop;
    v_sosi_unsigned.bsn     := RESIZE(bsn,     c_dp_stream_bsn_w);
    v_sosi_unsigned.data    := RESIZE(data,    c_dp_stream_data_w);
    v_sosi_unsigned.re      := RESIZE(re,      c_dp_stream_dsp_data_w);
    v_sosi_unsigned.im      := RESIZE(im,      c_dp_stream_dsp_data_w);
    v_sosi_unsigned.empty   := RESIZE(empty,   c_dp_stream_empty_w);
    v_sosi_unsigned.channel := RESIZE(channel, c_dp_stream_channel_w);
    v_sosi_unsigned.err     := RESIZE(err,     c_dp_stream_error_w);
    RETURN v_sosi_unsigned;
  END TO_DP_SOSI_UNSIGNED;

  -- Keep part of head data and combine part of tail data
  FUNCTION func_dp_data_shift_first(head_sosi, tail_sosi : t_dp_sosi; symbol_w, nof_symbols_per_data, nof_symbols_from_tail : NATURAL) RETURN t_dp_sosi IS
    VARIABLE vN     : NATURAL := nof_symbols_per_data;
    VARIABLE v_sosi : t_dp_sosi;
  BEGIN
    ASSERT nof_symbols_from_tail<vN REPORT "func_dp_data_shift_first : no symbols from head" SEVERITY FAILURE;
    -- use the other sosi from head_sosi
    v_sosi := head_sosi;     -- I = nof_symbols_from_tail = 0
    FOR I IN 1 TO vN-1 LOOP  -- I > 0
      IF nof_symbols_from_tail = I THEN
        v_sosi.data(I*symbol_w-1 DOWNTO 0) := tail_sosi.data(vN*symbol_w-1 DOWNTO (vN-I)*symbol_w);
      END IF;
    END LOOP;
    RETURN v_sosi;
  END func_dp_data_shift_first;
  
  
  -- Shift and combine part of previous data and this data,
  FUNCTION func_dp_data_shift(prev_sosi, this_sosi : t_dp_sosi; symbol_w, nof_symbols_per_data, nof_symbols_from_this : NATURAL) RETURN t_dp_sosi IS
    VARIABLE vK     : NATURAL := nof_symbols_from_this;
    VARIABLE vN     : NATURAL := nof_symbols_per_data;
    VARIABLE v_sosi : t_dp_sosi;
  BEGIN
    -- use the other sosi from this_sosi if nof_symbols_from_this > 0 else use other sosi from prev_sosi
    IF vK>0 THEN
      v_sosi := this_sosi;
    ELSE
      v_sosi := prev_sosi;
    END IF;
    
    -- use sosi data from both if 0 < nof_symbols_from_this < nof_symbols_per_data (i.e. 0 < I < vN)
    IF vK<nof_symbols_per_data THEN   -- I = vK = nof_symbols_from_this < vN
      -- Implementation using variable vK directly instead of via I in a LOOP
      -- IF vK > 0 THEN
      --   v_sosi.data(vN*symbol_w-1 DOWNTO vK*symbol_w)            := prev_sosi.data((vN-vK)*symbol_w-1 DOWNTO                0);
      --   v_sosi.data(                     vK*symbol_w-1 DOWNTO 0) := this_sosi.data( vN    *symbol_w-1 DOWNTO (vN-vK)*symbol_w);
      -- END IF;
      -- Implementaion using LOOP vK rather than VARIABLE vK directly as index to help synthesis and avoid potential multiplier
      v_sosi.data := prev_sosi.data;  -- I = vK = nof_symbols_from_this = 0
      FOR I IN 1 TO vN-1 LOOP         -- I = vK = nof_symbols_from_this > 0
        IF vK = I THEN
          v_sosi.data(vN*symbol_w-1 DOWNTO I*symbol_w)            := prev_sosi.data((vN-I)*symbol_w-1 DOWNTO               0);
          v_sosi.data(                     I*symbol_w-1 DOWNTO 0) := this_sosi.data( vN   *symbol_w-1 DOWNTO (vN-I)*symbol_w);
        END IF;
      END LOOP;
    END IF;
    RETURN v_sosi;
  END func_dp_data_shift;
  
  
  -- Shift part of tail data and account for input empty
  FUNCTION func_dp_data_shift_last(tail_sosi : t_dp_sosi; symbol_w, nof_symbols_per_data, nof_symbols_from_tail, input_empty : NATURAL) RETURN t_dp_sosi IS
    VARIABLE vK     : NATURAL := nof_symbols_from_tail;
    VARIABLE vL     : NATURAL := input_empty;
    VARIABLE vN     : NATURAL := nof_symbols_per_data;
    VARIABLE v_sosi : t_dp_sosi;
  BEGIN
    ASSERT vK   > 0  REPORT "func_dp_data_shift_last : no symbols from tail" SEVERITY FAILURE;
    ASSERT vK+vL<=vN REPORT "func_dp_data_shift_last : impossible shift" SEVERITY FAILURE;
    v_sosi := tail_sosi;
    -- Implementation using variable vK directly instead of via I in a LOOP
    -- IF vK > 0 THEN
    --   v_sosi.data(vN*symbol_w-1 DOWNTO (vN-vK)*symbol_w) <= tail_sosi.data((vK+vL)*symbol_w-1 DOWNTO vL*symbol_w);
    -- END IF;  
    -- Implementation using LOOP vK rather than VARIABLE vK directly as index to help synthesis and avoid potential multiplier
    -- Implementation using LOOP vL rather than VARIABLE vL directly as index to help synthesis and avoid potential multiplier
    FOR I IN 1 TO vN-1 LOOP
      IF vK = I THEN
        FOR J IN 0 TO vN-1 LOOP
          IF vL = J THEN
            v_sosi.data(vN*symbol_w-1 DOWNTO (vN-I)*symbol_w) := tail_sosi.data((I+J)*symbol_w-1 DOWNTO J*symbol_w);
          END IF;
        END LOOP;
      END IF;
    END LOOP;
    RETURN v_sosi;
  END func_dp_data_shift_last;  

  
  -- Determine resulting empty if two streams are concatenated
  -- . both empty must use the same nof symbols per data
  FUNCTION func_dp_empty_concat(head_empty, tail_empty : STD_LOGIC_VECTOR; nof_symbols_per_data : NATURAL) RETURN STD_LOGIC_VECTOR IS
    VARIABLE v_a, v_b, v_empty : NATURAL;
  BEGIN
    v_a := TO_UINT(head_empty);
    v_b := TO_UINT(tail_empty);
    v_empty := v_a + v_b;
    IF v_empty >= nof_symbols_per_data THEN
      v_empty := v_empty - nof_symbols_per_data;
    END IF;
    RETURN TO_UVEC(v_empty, head_empty'LENGTH);
  END func_dp_empty_concat;
  
  FUNCTION func_dp_empty_split(input_empty, head_empty : STD_LOGIC_VECTOR; nof_symbols_per_data : NATURAL) RETURN STD_LOGIC_VECTOR IS
    VARIABLE v_a, v_b, v_empty : NATURAL;
  BEGIN
    v_a   := TO_UINT(input_empty);
    v_b   := TO_UINT(head_empty);
    IF v_a >= v_b THEN
      v_empty := v_a - v_b;
    ELSE
      v_empty := (nof_symbols_per_data + v_a) - v_b;
    END IF;
    RETURN TO_UVEC(v_empty, head_empty'LENGTH);
  END func_dp_empty_split;
  
  
  -- Multiplex the t_dp_sosi_arr based on the valid, assuming that at most one input is active valid.
  FUNCTION func_dp_sosi_arr_mux(dp : t_dp_sosi_arr) RETURN t_dp_sosi IS
    VARIABLE v_sosi : t_dp_sosi := c_dp_sosi_rst;
  BEGIN
    FOR I IN dp'RANGE LOOP
      IF dp(I).valid='1' THEN
        v_sosi := dp(I);
        EXIT;
      END IF;
    END LOOP;
    RETURN v_sosi;
  END func_dp_sosi_arr_mux;

  
  -- Determine the combined logical value of corresponding STD_LOGIC fields in t_dp_*_arr (for all elements or only for the mask[]='1' elements)
  FUNCTION func_dp_stream_arr_and(dp : t_dp_siso_arr; mask : STD_LOGIC_VECTOR; str : STRING) RETURN STD_LOGIC IS
    VARIABLE v_vec : STD_LOGIC_VECTOR(dp'RANGE) := (OTHERS=>'1');  -- set default v_vec such that unmasked input have no influence on operation result
    VARIABLE v_any : STD_LOGIC := '0';
  BEGIN
    -- map siso field to v_vec
    FOR I IN dp'RANGE LOOP
      IF mask(I)='1' THEN
        v_any := '1';
        IF    str="READY" THEN v_vec(I) := dp(I).ready;
        ELSIF str="XON"   THEN v_vec(I) := dp(I).xon;
        ELSE  REPORT "Error in func_dp_stream_arr_and for t_dp_siso_arr";
        END IF;
      END IF;
    END LOOP;
    -- do operation on the selected record field
    IF v_any='1' THEN
      RETURN vector_and(v_vec);   -- return AND of the masked input fields
    ELSE
      RETURN '0';                 -- return '0' if no input was masked
    END IF;
  END func_dp_stream_arr_and;
  
  FUNCTION func_dp_stream_arr_and(dp : t_dp_sosi_arr; mask : STD_LOGIC_VECTOR; str : STRING) RETURN STD_LOGIC IS
    VARIABLE v_vec : STD_LOGIC_VECTOR(dp'RANGE) := (OTHERS=>'1');  -- set default v_vec such that unmasked input have no influence on operation result
    VARIABLE v_any : STD_LOGIC := '0';
  BEGIN
    -- map siso field to v_vec
    FOR I IN dp'RANGE LOOP
      IF mask(I)='1' THEN
        v_any := '1';
        IF    str="VALID" THEN v_vec(I) := dp(I).valid;
        ELSIF str="SOP"   THEN v_vec(I) := dp(I).sop;
        ELSIF str="EOP"   THEN v_vec(I) := dp(I).eop;
        ELSIF str="SYNC"  THEN v_vec(I) := dp(I).sync;
        ELSE  REPORT "Error in func_dp_stream_arr_and for t_dp_sosi_arr";
        END IF;
      END IF;
    END LOOP;
    -- do operation on the selected record field
    IF v_any='1' THEN
      RETURN vector_and(v_vec);   -- return AND of the masked input fields
    ELSE
      RETURN '0';                 -- return '0' if no input was masked
    END IF;
  END func_dp_stream_arr_and;
  
  FUNCTION func_dp_stream_arr_and(dp : t_dp_siso_arr; str : STRING) RETURN STD_LOGIC IS
    CONSTANT c_mask : STD_LOGIC_VECTOR(dp'RANGE) := (OTHERS=>'1');
  BEGIN
    RETURN func_dp_stream_arr_and(dp, c_mask, str);
  END func_dp_stream_arr_and;
  
  FUNCTION func_dp_stream_arr_and(dp : t_dp_sosi_arr; str : STRING) RETURN STD_LOGIC IS
    CONSTANT c_mask : STD_LOGIC_VECTOR(dp'RANGE) := (OTHERS=>'1');
  BEGIN
    RETURN func_dp_stream_arr_and(dp, c_mask, str);
  END func_dp_stream_arr_and;
  
  FUNCTION func_dp_stream_arr_or(dp : t_dp_siso_arr; mask : STD_LOGIC_VECTOR; str : STRING) RETURN STD_LOGIC IS
    VARIABLE v_vec : STD_LOGIC_VECTOR(dp'RANGE) := (OTHERS=>'0');  -- set default v_vec such that unmasked input have no influence on operation result
    VARIABLE v_any : STD_LOGIC := '0';
  BEGIN
    -- map siso field to v_vec
    FOR I IN dp'RANGE LOOP
      IF mask(I)='1' THEN
        v_any := '1';
        IF    str="READY" THEN v_vec(I) := dp(I).ready;
        ELSIF str="XON"   THEN v_vec(I) := dp(I).xon;
        ELSE  REPORT "Error in func_dp_stream_arr_or for t_dp_siso_arr";
        END IF;
      END IF;
    END LOOP;
    -- do operation on the selected record field
    IF v_any='1' THEN
      RETURN vector_or(v_vec);   -- return OR of the masked input fields
    ELSE
      RETURN '0';                -- return '0' if no input was masked
    END IF;
  END func_dp_stream_arr_or;
  
  FUNCTION func_dp_stream_arr_or(dp : t_dp_sosi_arr; mask : STD_LOGIC_VECTOR; str : STRING) RETURN STD_LOGIC IS
    VARIABLE v_vec : STD_LOGIC_VECTOR(dp'RANGE) := (OTHERS=>'0');  -- set default v_vec such that unmasked input have no influence on operation result
    VARIABLE v_any : STD_LOGIC := '0';
  BEGIN
    -- map siso field to v_vec
    FOR I IN dp'RANGE LOOP
      IF mask(I)='1' THEN
        v_any := '1';
        IF    str="VALID" THEN v_vec(I) := dp(I).valid;
        ELSIF str="SOP"   THEN v_vec(I) := dp(I).sop;
        ELSIF str="EOP"   THEN v_vec(I) := dp(I).eop;
        ELSIF str="SYNC"  THEN v_vec(I) := dp(I).sync;
        ELSE  REPORT "Error in func_dp_stream_arr_or for t_dp_sosi_arr";
        END IF;
      END IF;
    END LOOP;
    -- do operation on the selected record field
    IF v_any='1' THEN
      RETURN vector_or(v_vec);   -- return OR of the masked input fields
    ELSE
      RETURN '0';                -- return '0' if no input was masked
    END IF;
  END func_dp_stream_arr_or;
  
  FUNCTION func_dp_stream_arr_or(dp : t_dp_siso_arr; str : STRING) RETURN STD_LOGIC IS
    CONSTANT c_mask : STD_LOGIC_VECTOR(dp'RANGE) := (OTHERS=>'1');
  BEGIN
    RETURN func_dp_stream_arr_or(dp, c_mask, str);
  END func_dp_stream_arr_or;
  
  FUNCTION func_dp_stream_arr_or(dp : t_dp_sosi_arr; str : STRING) RETURN STD_LOGIC IS
    CONSTANT c_mask : STD_LOGIC_VECTOR(dp'RANGE) := (OTHERS=>'1');
  BEGIN
    RETURN func_dp_stream_arr_or(dp, c_mask, str);
  END func_dp_stream_arr_or;
  
  
  -- Functions to set or get a STD_LOGIC field as a STD_LOGIC_VECTOR to or from an siso or an sosi array
  FUNCTION func_dp_stream_arr_set(dp : t_dp_siso_arr; slv : STD_LOGIC_VECTOR; str : STRING) RETURN t_dp_siso_arr IS
    VARIABLE v_dp  : t_dp_siso_arr(dp'RANGE)    := dp;   -- default
    VARIABLE v_slv : STD_LOGIC_VECTOR(dp'RANGE) := slv;  -- map to ensure same range as for dp
  BEGIN
    FOR I IN dp'RANGE LOOP
      IF    str="READY" THEN v_dp(I).ready := v_slv(I);
      ELSIF str="XON"   THEN v_dp(I).xon   := v_slv(I);
      ELSE  REPORT "Error in func_dp_stream_arr_set for t_dp_siso_arr";
      END IF;
    END LOOP;
    RETURN v_dp;
  END func_dp_stream_arr_set;
  
  FUNCTION func_dp_stream_arr_set(dp : t_dp_sosi_arr; slv : STD_LOGIC_VECTOR; str : STRING) RETURN t_dp_sosi_arr IS
    VARIABLE v_dp  : t_dp_sosi_arr(dp'RANGE)    := dp;   -- default
    VARIABLE v_slv : STD_LOGIC_VECTOR(dp'RANGE) := slv;  -- map to ensure same range as for dp
  BEGIN
    FOR I IN dp'RANGE LOOP
      IF    str="VALID" THEN v_dp(I).valid := v_slv(I);
      ELSIF str="SOP"   THEN v_dp(I).sop   := v_slv(I);
      ELSIF str="EOP"   THEN v_dp(I).eop   := v_slv(I);
      ELSIF str="SYNC"  THEN v_dp(I).sync  := v_slv(I);
      ELSE  REPORT "Error in func_dp_stream_arr_set for t_dp_sosi_arr";
      END IF;
    END LOOP;
    RETURN v_dp;
  END func_dp_stream_arr_set;
  
  FUNCTION func_dp_stream_arr_set(dp : t_dp_siso_arr; sl : STD_LOGIC; str : STRING) RETURN t_dp_siso_arr IS
    VARIABLE v_slv : STD_LOGIC_VECTOR(dp'RANGE) := (OTHERS=>sl);
  BEGIN
    RETURN func_dp_stream_arr_set(dp, v_slv, str);
  END func_dp_stream_arr_set;
  
  FUNCTION func_dp_stream_arr_set(dp : t_dp_sosi_arr; sl : STD_LOGIC; str : STRING) RETURN t_dp_sosi_arr IS
    VARIABLE v_slv : STD_LOGIC_VECTOR(dp'RANGE) := (OTHERS=>sl);
  BEGIN
    RETURN func_dp_stream_arr_set(dp, v_slv, str);
  END func_dp_stream_arr_set;
  
  FUNCTION func_dp_stream_arr_get(dp : t_dp_siso_arr; str : STRING) RETURN STD_LOGIC_VECTOR IS
    VARIABLE v_ctrl : STD_LOGIC_VECTOR(dp'RANGE);
  BEGIN
    FOR I IN dp'RANGE LOOP
      IF    str="READY" THEN v_ctrl(I) := dp(I).ready;
      ELSIF str="XON"   THEN v_ctrl(I) := dp(I).xon;
      ELSE  REPORT "Error in func_dp_stream_arr_get for t_dp_siso_arr";
      END IF;
    END LOOP;
    RETURN v_ctrl;
  END func_dp_stream_arr_get;
  
  FUNCTION func_dp_stream_arr_get(dp : t_dp_sosi_arr; str : STRING) RETURN STD_LOGIC_VECTOR IS
    VARIABLE v_ctrl : STD_LOGIC_VECTOR(dp'RANGE);
  BEGIN
    FOR I IN dp'RANGE LOOP
      IF    str="VALID" THEN v_ctrl(I) := dp(I).valid;
      ELSIF str="SOP"   THEN v_ctrl(I) := dp(I).sop;
      ELSIF str="EOP"   THEN v_ctrl(I) := dp(I).eop;
      ELSIF str="SYNC"  THEN v_ctrl(I) := dp(I).sync;
      ELSE  REPORT "Error in func_dp_stream_arr_get for t_dp_sosi_arr";
      END IF;
    END LOOP;
    RETURN v_ctrl;
  END func_dp_stream_arr_get;
  
  
  -- Functions to select elements from two siso or two sosi arrays (sel[] = '1' selects a, sel[] = '0' selects b)
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a, b : t_dp_siso) RETURN t_dp_siso_arr IS
    VARIABLE v_dp : t_dp_siso_arr(sel'RANGE);
  BEGIN
    FOR I IN sel'RANGE LOOP
      IF sel(I)='1' THEN
        v_dp(I) := a;
      ELSE
        v_dp(I) := b;
      END IF;
    END LOOP;
    RETURN v_dp;
  END func_dp_stream_arr_select;
  
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a : t_dp_siso_arr; b : t_dp_siso) RETURN t_dp_siso_arr IS
    VARIABLE v_dp : t_dp_siso_arr(sel'RANGE);
  BEGIN
    FOR I IN sel'RANGE LOOP
      IF sel(I)='1' THEN
        v_dp(I) := a(I);
      ELSE
        v_dp(I) := b;
      END IF;
    END LOOP;
    RETURN v_dp;
  END func_dp_stream_arr_select;
  
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a : t_dp_siso; b : t_dp_siso_arr) RETURN t_dp_siso_arr IS
    VARIABLE v_dp : t_dp_siso_arr(sel'RANGE);
  BEGIN
    FOR I IN sel'RANGE LOOP
      IF sel(I)='1' THEN
        v_dp(I) := a;
      ELSE
        v_dp(I) := b(I);
      END IF;
    END LOOP;
    RETURN v_dp;
  END func_dp_stream_arr_select;
  
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a, b : t_dp_siso_arr) RETURN t_dp_siso_arr IS
    VARIABLE v_dp : t_dp_siso_arr(sel'RANGE);
  BEGIN
    FOR I IN sel'RANGE LOOP
      IF sel(I)='1' THEN
        v_dp(I) := a(I);
      ELSE
        v_dp(I) := b(I);
      END IF;
    END LOOP;
    RETURN v_dp;
  END func_dp_stream_arr_select;
  
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a, b : t_dp_sosi) RETURN t_dp_sosi_arr IS
    VARIABLE v_dp : t_dp_sosi_arr(sel'RANGE);
  BEGIN
    FOR I IN sel'RANGE LOOP
      IF sel(I)='1' THEN
        v_dp(I) := a;
      ELSE
        v_dp(I) := b;
      END IF;
    END LOOP;
    RETURN v_dp;
  END func_dp_stream_arr_select;
  
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a : t_dp_sosi_arr; b : t_dp_sosi) RETURN t_dp_sosi_arr IS
    VARIABLE v_dp : t_dp_sosi_arr(sel'RANGE);
  BEGIN
    FOR I IN sel'RANGE LOOP
      IF sel(I)='1' THEN
        v_dp(I) := a(I);
      ELSE
        v_dp(I) := b;
      END IF;
    END LOOP;
    RETURN v_dp;
  END func_dp_stream_arr_select;
  
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a : t_dp_sosi; b : t_dp_sosi_arr) RETURN t_dp_sosi_arr IS
    VARIABLE v_dp : t_dp_sosi_arr(sel'RANGE);
  BEGIN
    FOR I IN sel'RANGE LOOP
      IF sel(I)='1' THEN
        v_dp(I) := a;
      ELSE
        v_dp(I) := b(I);
      END IF;
    END LOOP;
    RETURN v_dp;
  END func_dp_stream_arr_select;
  
  FUNCTION func_dp_stream_arr_select(sel : STD_LOGIC_VECTOR; a, b : t_dp_sosi_arr) RETURN t_dp_sosi_arr IS
    VARIABLE v_dp : t_dp_sosi_arr(sel'RANGE);
  BEGIN
    FOR I IN sel'RANGE LOOP
      IF sel(I)='1' THEN
        v_dp(I) := a(I);
      ELSE
        v_dp(I) := b(I);
      END IF;
    END LOOP;
    RETURN v_dp;
  END func_dp_stream_arr_select;

  FUNCTION func_dp_stream_arr_reverse_range(in_arr : t_dp_siso_arr) RETURN t_dp_siso_arr IS
    VARIABLE v_to_range : t_dp_siso_arr(0 TO in_arr'HIGH);
    VARIABLE v_downto_range : t_dp_siso_arr(in_arr'HIGH DOWNTO 0);
  BEGIN
    FOR i IN in_arr'RANGE LOOP
      v_to_range(i)     := in_arr(in_arr'HIGH-i);
      v_downto_range(i) := in_arr(in_arr'HIGH-i);
    END LOOP;
    IF in_arr'LEFT>in_arr'RIGHT THEN
      RETURN v_downto_range;
    ELSIF in_arr'LEFT<in_arr'RIGHT THEN
      RETURN v_to_range;
    ELSE
      RETURN in_arr;
    END IF;
  END func_dp_stream_arr_reverse_range;

  FUNCTION func_dp_stream_arr_reverse_range(in_arr : t_dp_sosi_arr) RETURN t_dp_sosi_arr IS
    VARIABLE v_to_range : t_dp_sosi_arr(0 TO in_arr'HIGH);
    VARIABLE v_downto_range : t_dp_sosi_arr(in_arr'HIGH DOWNTO 0);
  BEGIN
    FOR i IN in_arr'RANGE LOOP
      v_to_range(i)     := in_arr(in_arr'HIGH-i);
      v_downto_range(i) := in_arr(in_arr'HIGH-i);
    END LOOP;
    IF in_arr'LEFT>in_arr'RIGHT THEN
      RETURN v_downto_range;
    ELSIF in_arr'LEFT<in_arr'RIGHT THEN
      RETURN v_to_range;
    ELSE
      RETURN in_arr;
    END IF;
  END func_dp_stream_arr_reverse_range;
  
  -- Functions to combinatorially hold the data fields and to set or reset the info and control fields in an sosi array
  FUNCTION func_dp_stream_arr_combine_data_info_ctrl(dp : t_dp_sosi_arr; info, ctrl : t_dp_sosi) RETURN t_dp_sosi_arr IS
    VARIABLE v_dp : t_dp_sosi_arr(dp'RANGE) := dp;       -- hold sosi data
  BEGIN
    v_dp := func_dp_stream_arr_set_info(   v_dp, info);  -- set sosi info
    v_dp := func_dp_stream_arr_set_control(v_dp, ctrl);  -- set sosi ctrl
    RETURN v_dp;
  END func_dp_stream_arr_combine_data_info_ctrl;
    
  FUNCTION func_dp_stream_arr_set_info(dp : t_dp_sosi_arr; info : t_dp_sosi) RETURN t_dp_sosi_arr IS
    VARIABLE v_dp : t_dp_sosi_arr(dp'RANGE) := dp;  -- hold sosi data
  BEGIN
    FOR I IN dp'RANGE LOOP                          -- set sosi info
      v_dp(I).bsn     := info.bsn;      -- sop
      v_dp(I).channel := info.channel;  -- sop
      v_dp(I).empty   := info.empty;    -- eop
      v_dp(I).err     := info.err;      -- eop
    END LOOP;
    RETURN v_dp;
  END func_dp_stream_arr_set_info;
  
  FUNCTION func_dp_stream_arr_set_control(dp : t_dp_sosi_arr; ctrl : t_dp_sosi) RETURN t_dp_sosi_arr IS
    VARIABLE v_dp : t_dp_sosi_arr(dp'RANGE) := dp;  -- hold sosi data
  BEGIN
    FOR I IN dp'RANGE LOOP                          -- set sosi control
      v_dp(I).valid := ctrl.valid;
      v_dp(I).sop   := ctrl.sop;
      v_dp(I).eop   := ctrl.eop;
      v_dp(I).sync  := ctrl.sync;
    END LOOP;
    RETURN v_dp;
  END func_dp_stream_arr_set_control;
  
  FUNCTION func_dp_stream_arr_reset_control(dp : t_dp_sosi_arr) RETURN t_dp_sosi_arr IS
    VARIABLE v_dp : t_dp_sosi_arr(dp'RANGE) := dp;  -- hold sosi data
  BEGIN
    FOR I IN dp'RANGE LOOP                          -- reset sosi control
      v_dp(I).valid := '0';
      v_dp(I).sop   := '0';
      v_dp(I).eop   := '0';
      v_dp(I).sync  := '0';
    END LOOP;
    RETURN v_dp;
  END func_dp_stream_arr_reset_control;
  
  FUNCTION func_dp_stream_reset_control(dp : t_dp_sosi) RETURN t_dp_sosi IS
    VARIABLE v_dp : t_dp_sosi := dp;  -- hold sosi data
  BEGIN
    -- reset sosi control
    v_dp.valid := '0';
    v_dp.sop   := '0';
    v_dp.eop   := '0';
    v_dp.sync  := '0';
    RETURN v_dp;
  END func_dp_stream_reset_control;
  
  -- Functions to combinatorially determine the maximum and minimum sosi bsn[w-1:0] value in the sosi array (for all elements or only for the mask[]='1' elements)
  FUNCTION func_dp_stream_arr_bsn_max(dp : t_dp_sosi_arr; mask : STD_LOGIC_VECTOR; w : NATURAL) RETURN STD_LOGIC_VECTOR IS
    VARIABLE v_bsn : STD_LOGIC_VECTOR(w-1 DOWNTO 0) := (OTHERS=>'0');  -- init max v_bsn with minimum value
  BEGIN
    FOR I IN dp'RANGE LOOP
      IF mask(I)='1' THEN
        IF UNSIGNED(v_bsn) < UNSIGNED(dp(I).bsn(w-1 DOWNTO 0)) THEN
          v_bsn := dp(I).bsn(w-1 DOWNTO 0);
        END IF;
      END IF;
    END LOOP;
    RETURN v_bsn;
  END func_dp_stream_arr_bsn_max;
  
  FUNCTION func_dp_stream_arr_bsn_max(dp : t_dp_sosi_arr; w : NATURAL) RETURN STD_LOGIC_VECTOR IS
    CONSTANT c_mask : STD_LOGIC_VECTOR(dp'RANGE) := (OTHERS=>'1');
  BEGIN
    RETURN func_dp_stream_arr_bsn_max(dp, c_mask, w);
  END func_dp_stream_arr_bsn_max;
  
  FUNCTION func_dp_stream_arr_bsn_min(dp : t_dp_sosi_arr; mask : STD_LOGIC_VECTOR; w : NATURAL) RETURN STD_LOGIC_VECTOR IS
    VARIABLE v_bsn : STD_LOGIC_VECTOR(w-1 DOWNTO 0) := (OTHERS=>'1');  -- init min v_bsn with maximum value
  BEGIN
    FOR I IN dp'RANGE LOOP
      IF mask(I)='1' THEN
        IF UNSIGNED(v_bsn) > UNSIGNED(dp(I).bsn(w-1 DOWNTO 0)) THEN
          v_bsn := dp(I).bsn(w-1 DOWNTO 0);
        END IF;
      END IF;
    END LOOP;
    RETURN v_bsn;
  END func_dp_stream_arr_bsn_min;
  
  FUNCTION func_dp_stream_arr_bsn_min(dp : t_dp_sosi_arr; w : NATURAL) RETURN STD_LOGIC_VECTOR IS
    CONSTANT c_mask : STD_LOGIC_VECTOR(dp'RANGE) := (OTHERS=>'1');
  BEGIN
    RETURN func_dp_stream_arr_bsn_min(dp, c_mask, w);
  END func_dp_stream_arr_bsn_min;

  -- Function to copy the BSN number of one valid stream to all other streams. 
  FUNCTION func_dp_stream_arr_copy_valid_bsn(dp : t_dp_sosi_arr; mask : STD_LOGIC_VECTOR) RETURN t_dp_sosi_arr IS
    VARIABLE v_bsn : STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0) := (OTHERS=>'0');
    VARIABLE v_dp  : t_dp_sosi_arr(dp'RANGE) := dp;  -- hold sosi data
  BEGIN
    FOR I IN dp'RANGE LOOP
      IF mask(I)='1' THEN
        v_bsn := dp(I).bsn;
      END IF;
    END LOOP;
    FOR I IN dp'RANGE LOOP
      v_dp(I).bsn := v_bsn;
    END LOOP;  
    RETURN v_dp;
  END func_dp_stream_arr_copy_valid_bsn;
 
  
  -- Functions to combinatorially handle channels
  FUNCTION func_dp_stream_channel_set(st_sosi : t_dp_sosi; ch : NATURAL) RETURN t_dp_sosi IS
    VARIABLE v_rec : t_dp_sosi := st_sosi;
  BEGIN
    v_rec.channel := TO_UVEC(ch, c_dp_stream_channel_w);
    RETURN v_rec;
  END func_dp_stream_channel_set;
  
  FUNCTION func_dp_stream_channel_select(st_sosi : t_dp_sosi; ch : NATURAL) RETURN t_dp_sosi IS
    VARIABLE v_rec : t_dp_sosi := st_sosi;
  BEGIN
    IF UNSIGNED(st_sosi.channel)/=ch THEN
      v_rec.valid := '0';
      v_rec.sop   := '0';
      v_rec.eop   := '0';
    END IF;
    RETURN v_rec;
  END func_dp_stream_channel_select;
  
  FUNCTION func_dp_stream_channel_remove(st_sosi : t_dp_sosi; ch : NATURAL) RETURN t_dp_sosi IS
    VARIABLE v_rec : t_dp_sosi := st_sosi;
  BEGIN
    IF UNSIGNED(st_sosi.channel)=ch THEN
      v_rec.valid := '0';
      v_rec.sop   := '0';
      v_rec.eop   := '0';
    END IF;
    RETURN v_rec;
  END func_dp_stream_channel_remove;
  
  
  FUNCTION func_dp_stream_error_set(st_sosi : t_dp_sosi; n : NATURAL) RETURN t_dp_sosi IS
    VARIABLE v_rec : t_dp_sosi := st_sosi;
  BEGIN
    v_rec.err := TO_UVEC(n, c_dp_stream_error_w);
    RETURN v_rec;
  END func_dp_stream_error_set;
  
  
  FUNCTION func_dp_stream_bsn_set(st_sosi : t_dp_sosi; bsn : STD_LOGIC_VECTOR) RETURN t_dp_sosi IS
    VARIABLE v_rec : t_dp_sosi := st_sosi;
  BEGIN
    v_rec.bsn := RESIZE_DP_BSN(bsn);
    RETURN v_rec;
  END func_dp_stream_bsn_set;
  
    
  FUNCTION func_dp_stream_combine_info_and_data(info, data : t_dp_sosi) RETURN t_dp_sosi IS
    VARIABLE v_rec : t_dp_sosi := data;  -- Sosi data fields
  BEGIN
    -- Combine sosi data with the sosi info fields
    v_rec.sync    := info.sync AND data.sop;  -- force sync only active at data.sop
    v_rec.bsn     := info.bsn;
    v_rec.channel := info.channel;
    v_rec.empty   := info.empty;
    v_rec.err     := info.err;
    RETURN v_rec;
  END func_dp_stream_combine_info_and_data;
  
  
  FUNCTION func_dp_stream_slv_to_integer(slv_sosi : t_dp_sosi; w : NATURAL) RETURN t_dp_sosi_integer IS
    VARIABLE v_rec : t_dp_sosi_integer;
  BEGIN
    v_rec.sync     := slv_sosi.sync;
    v_rec.bsn      := TO_UINT(slv_sosi.bsn(30 DOWNTO 0));         -- NATURAL'width = 31 bit
    v_rec.data     := TO_SINT(slv_sosi.data(w-1 DOWNTO 0));
    v_rec.re       := TO_SINT(slv_sosi.re(w-1 DOWNTO 0));
    v_rec.im       := TO_SINT(slv_sosi.im(w-1 DOWNTO 0));
    v_rec.valid    := slv_sosi.valid;
    v_rec.sop      := slv_sosi.sop;
    v_rec.eop      := slv_sosi.eop;
    v_rec.empty    := TO_UINT(slv_sosi.empty);
    v_rec.channel  := TO_UINT(slv_sosi.channel);
    v_rec.err      := TO_UINT(slv_sosi.err);
    RETURN v_rec;
  END func_dp_stream_slv_to_integer;

  FUNCTION func_dp_stream_set_data(dp : t_dp_sosi; slv : STD_LOGIC_VECTOR; str : STRING) RETURN t_dp_sosi IS
    VARIABLE v_dp : t_dp_sosi := dp;   
  BEGIN 
      IF    str="DATA" THEN v_dp.data := RESIZE_DP_DATA(slv);
      ELSIF str="DSP"  THEN v_dp.re   := RESIZE_DP_DSP_DATA(slv);
                            v_dp.im   := RESIZE_DP_DSP_DATA(slv);
      ELSIF str="RE"  THEN  v_dp.re   := RESIZE_DP_DSP_DATA(slv);
      ELSIF str="IM"  THEN  v_dp.im   := RESIZE_DP_DSP_DATA(slv);
      ELSIF str="ALL" THEN  v_dp.data := RESIZE_DP_DATA(slv);    
                            v_dp.re   := RESIZE_DP_DSP_DATA(slv);
                            v_dp.im   := RESIZE_DP_DSP_DATA(slv);
      ELSE  REPORT "Error in func_dp_stream_set_data for t_dp_sosi";
      END IF;
    RETURN v_dp;
  END;

  FUNCTION func_dp_stream_set_data(dp : t_dp_sosi_arr; slv : STD_LOGIC_VECTOR; str : STRING) RETURN t_dp_sosi_arr IS
    VARIABLE v_dp : t_dp_sosi_arr(dp'RANGE) := dp;   
  BEGIN 
    FOR I IN dp'RANGE LOOP
      v_dp(I) := func_dp_stream_set_data(dp(I), slv, str);
    END LOOP;
    RETURN v_dp;
  END;

  FUNCTION func_dp_stream_set_data(dp : t_dp_sosi_arr; slv : STD_LOGIC_VECTOR; str : STRING; mask : STD_LOGIC_VECTOR) RETURN t_dp_sosi_arr IS
    VARIABLE v_dp : t_dp_sosi_arr(dp'RANGE) := dp;   
  BEGIN 
    FOR I IN dp'RANGE LOOP
      IF mask(I)='0' THEN
        v_dp(I) := func_dp_stream_set_data(dp(I), slv, str);
      END IF; 
    END LOOP;
    RETURN v_dp;
  END;

   -- Functions to rewire between concatenated sosi.data and concatenated sosi.re,im
  FUNCTION func_dp_stream_complex_to_data(dp : t_dp_sosi; data_w : NATURAL; nof_data : NATURAL; data_order_im_re : BOOLEAN) RETURN t_dp_sosi IS
    CONSTANT c_compl_data_w : NATURAL := data_w/2;
    VARIABLE v_dp           : t_dp_sosi := dp;
    VARIABLE v_re           : STD_LOGIC_VECTOR(c_compl_data_w-1 DOWNTO 0);
    VARIABLE v_im           : STD_LOGIC_VECTOR(c_compl_data_w-1 DOWNTO 0);
  BEGIN
    v_dp.data := (OTHERS=>'0');
    v_dp.re := (OTHERS=>'X');
    v_dp.im := (OTHERS=>'X');
    FOR I IN 0 TO nof_data-1 LOOP
      v_re := dp.re(c_compl_data_w-1 + I*c_compl_data_w DOWNTO I*c_compl_data_w);
      v_im := dp.im(c_compl_data_w-1 + I*c_compl_data_w DOWNTO I*c_compl_data_w);
      IF data_order_im_re=TRUE THEN
        v_dp.data((I+1)*data_w-1 DOWNTO I*data_w) := v_im & v_re;
      ELSE
        v_dp.data((I+1)*data_w-1 DOWNTO I*data_w) := v_re & v_im;
      END IF;
    END LOOP;
    RETURN v_dp;
  END;

  FUNCTION func_dp_stream_complex_to_data(dp : t_dp_sosi; data_w : NATURAL; nof_data : NATURAL) RETURN t_dp_sosi IS
  BEGIN 
    RETURN func_dp_stream_complex_to_data(dp, data_w, nof_data, TRUE);
  END;
  
  FUNCTION func_dp_stream_complex_to_data(dp : t_dp_sosi; data_w : NATURAL) RETURN t_dp_sosi IS
  BEGIN 
    RETURN func_dp_stream_complex_to_data(dp, data_w, 1, TRUE);
  END;
  
  FUNCTION func_dp_stream_data_to_complex(dp : t_dp_sosi; data_w : NATURAL; nof_data : NATURAL; data_order_im_re : BOOLEAN) RETURN t_dp_sosi IS
    CONSTANT c_compl_data_w : NATURAL := data_w/2;
    VARIABLE v_dp           : t_dp_sosi := dp;
    VARIABLE v_hi           : STD_LOGIC_VECTOR(c_compl_data_w-1 DOWNTO 0);
    VARIABLE v_lo           : STD_LOGIC_VECTOR(c_compl_data_w-1 DOWNTO 0);
  BEGIN 
    v_dp.data := (OTHERS=>'X');
    v_dp.re := (OTHERS=>'0');
    v_dp.im := (OTHERS=>'0');
    FOR I IN 0 TO nof_data-1 LOOP
      v_hi := dp.data(        data_w-1 + I*data_w DOWNTO c_compl_data_w + I*data_w);
      v_lo := dp.data(c_compl_data_w-1 + I*data_w DOWNTO              0 + I*data_w);
      IF data_order_im_re=TRUE THEN
        v_dp.im((I+1)*c_compl_data_w-1 DOWNTO I*c_compl_data_w) := v_hi;
        v_dp.re((I+1)*c_compl_data_w-1 DOWNTO I*c_compl_data_w) := v_lo;
      ELSE
        v_dp.re((I+1)*c_compl_data_w-1 DOWNTO I*c_compl_data_w) := v_hi;
        v_dp.im((I+1)*c_compl_data_w-1 DOWNTO I*c_compl_data_w) := v_lo;
      END IF;
    END LOOP;
    RETURN v_dp;
  END;

  FUNCTION func_dp_stream_data_to_complex(dp : t_dp_sosi; data_w : NATURAL; nof_data : NATURAL) RETURN t_dp_sosi IS
  BEGIN 
    RETURN func_dp_stream_data_to_complex(dp, data_w, nof_data, TRUE);
  END;

  FUNCTION func_dp_stream_data_to_complex(dp : t_dp_sosi; data_w : NATURAL) RETURN t_dp_sosi IS
  BEGIN 
    RETURN func_dp_stream_data_to_complex(dp, data_w, 1, TRUE);
  END;
  
  FUNCTION func_dp_stream_complex_to_data(dp_arr : t_dp_sosi_arr; data_w : NATURAL; nof_data : NATURAL; data_order_im_re : BOOLEAN) RETURN t_dp_sosi_arr IS
    VARIABLE v_dp_arr : t_dp_sosi_arr(dp_arr'RANGE);
  BEGIN 
    FOR i IN dp_arr'RANGE LOOP
      v_dp_arr(i) := func_dp_stream_complex_to_data(dp_arr(i), data_w, nof_data, data_order_im_re);  -- nof_data per stream is 1
    END LOOP;
    RETURN v_dp_arr;
  END;
  
  FUNCTION func_dp_stream_complex_to_data(dp_arr : t_dp_sosi_arr; data_w : NATURAL; nof_data : NATURAL) RETURN t_dp_sosi_arr IS
  BEGIN
    RETURN func_dp_stream_complex_to_data(dp_arr, data_w, nof_data, TRUE);
  END;

  FUNCTION func_dp_stream_complex_to_data(dp_arr : t_dp_sosi_arr; data_w : NATURAL) RETURN t_dp_sosi_arr IS
  BEGIN
    RETURN func_dp_stream_complex_to_data(dp_arr, data_w, 1, TRUE);
  END;
  
  FUNCTION func_dp_stream_data_to_complex(dp_arr : t_dp_sosi_arr; data_w : NATURAL; nof_data : NATURAL; data_order_im_re : BOOLEAN) RETURN t_dp_sosi_arr IS
    VARIABLE v_dp_arr : t_dp_sosi_arr(dp_arr'RANGE);
  BEGIN 
    FOR i IN dp_arr'RANGE LOOP
      v_dp_arr(i) := func_dp_stream_data_to_complex(dp_arr(i), data_w, nof_data, data_order_im_re);  -- nof_data per stream is 1
    END LOOP;
    RETURN v_dp_arr;
  END;
  
  FUNCTION func_dp_stream_data_to_complex(dp_arr : t_dp_sosi_arr; data_w : NATURAL; nof_data : NATURAL) RETURN t_dp_sosi_arr IS
  BEGIN 
    RETURN func_dp_stream_data_to_complex(dp_arr, data_w, nof_data, TRUE);
  END;

  FUNCTION func_dp_stream_data_to_complex(dp_arr : t_dp_sosi_arr; data_w : NATURAL) RETURN t_dp_sosi_arr IS
  BEGIN 
    RETURN func_dp_stream_data_to_complex(dp_arr, data_w, 1, TRUE);
  END;
  
  -- Concatenate the data (and complex fields) from a SOSI array into a single SOSI stream (assumes streams are in sync)
  FUNCTION func_dp_stream_concat(snk_in_arr : t_dp_sosi_arr; data_w : NATURAL) RETURN t_dp_sosi IS
    CONSTANT c_compl_data_w : NATURAL   := data_w/2;
    VARIABLE v_src_out      : t_dp_sosi := snk_in_arr(0);
  BEGIN
    v_src_out.data := (OTHERS=>'0');
    v_src_out.re   := (OTHERS=>'0');
    v_src_out.im   := (OTHERS=>'0');
    FOR i IN snk_in_arr'RANGE LOOP
      v_src_out.data((i+1)*        data_w-1 DOWNTO i*        data_w) := snk_in_arr(i).data(      data_w-1 DOWNTO 0);
      v_src_out.re(  (i+1)*c_compl_data_w-1 DOWNTO i*c_compl_data_w) := snk_in_arr(i).re(c_compl_data_w-1 DOWNTO 0);
      v_src_out.im(  (i+1)*c_compl_data_w-1 DOWNTO i*c_compl_data_w) := snk_in_arr(i).im(c_compl_data_w-1 DOWNTO 0);
    END LOOP;
    RETURN v_src_out;
  END;

  FUNCTION func_dp_stream_concat(src_in : t_dp_siso; nof_streams : NATURAL) RETURN t_dp_siso_arr IS -- Wire single SISO to SISO_ARR
    VARIABLE v_snk_out_arr : t_dp_siso_arr(nof_streams-1 DOWNTO 0);
  BEGIN
    FOR i IN v_snk_out_arr'RANGE LOOP
      v_snk_out_arr(i) := src_in;
    END LOOP;
    RETURN v_snk_out_arr;
  END;

  -- Reconcatenate the data and complex re,im fields from a SOSI array from nof_data*in_w to nof_data*out_w
  FUNCTION func_dp_stream_reconcat(snk_in : t_dp_sosi; in_w, out_w, nof_data : NATURAL; data_representation : STRING; data_order_im_re : BOOLEAN) RETURN t_dp_sosi IS
    CONSTANT c_compl_in_w  : NATURAL   := in_w/2;
    CONSTANT c_compl_out_w : NATURAL   := out_w/2;
    VARIABLE v_src_out     : t_dp_sosi := snk_in;
    VARIABLE v_in_data     : STD_LOGIC_VECTOR(in_w-1 DOWNTO 0);
    VARIABLE v_out_data    : STD_LOGIC_VECTOR(out_w-1 DOWNTO 0) := (OTHERS=>'0');   -- default set sosi.data to 0
  BEGIN
    v_src_out := snk_in;
    v_src_out.data := (OTHERS=>'0');
    v_src_out.re   := (OTHERS=>'0');
    v_src_out.im   := (OTHERS=>'0');
    FOR i IN 0 TO nof_data-1 LOOP
      v_in_data := snk_in.data((i+1)*in_w-1 DOWNTO i*in_w);
      IF data_representation="UNSIGNED" THEN  -- treat data as unsigned
        v_out_data := RESIZE_UVEC(v_in_data, out_w);
      ELSE
        IF data_representation="SIGNED" THEN  -- treat data as signed
          v_out_data := RESIZE_SVEC(v_in_data, out_w);
        ELSE
          -- treat data as complex
          IF data_order_im_re=TRUE THEN
            -- data = im&re
            v_out_data := RESIZE_SVEC(v_in_data(2*c_compl_in_w-1 DOWNTO c_compl_in_w), c_compl_out_w) &
                          RESIZE_SVEC(v_in_data(  c_compl_in_w-1 DOWNTO            0), c_compl_out_w);
          ELSE
            -- data = re&im
            v_out_data := RESIZE_SVEC(v_in_data(  c_compl_in_w-1 DOWNTO            0), c_compl_out_w) &
                          RESIZE_SVEC(v_in_data(2*c_compl_in_w-1 DOWNTO c_compl_in_w), c_compl_out_w);
          END IF;
        END IF;
      END IF;
      v_src_out.data((i+1)*        out_w-1 DOWNTO i*        out_w) := v_out_data;
      v_src_out.re(  (i+1)*c_compl_out_w-1 DOWNTO i*c_compl_out_w) := RESIZE_SVEC(snk_in.re((i+1)*c_compl_in_w-1 DOWNTO i*c_compl_in_w), c_compl_out_w);
      v_src_out.im(  (i+1)*c_compl_out_w-1 DOWNTO i*c_compl_out_w) := RESIZE_SVEC(snk_in.im((i+1)*c_compl_in_w-1 DOWNTO i*c_compl_in_w), c_compl_out_w);
    END LOOP;
    RETURN v_src_out;
  END;

  FUNCTION func_dp_stream_reconcat(snk_in : t_dp_sosi; in_w, out_w, nof_data : NATURAL; data_representation : STRING) RETURN t_dp_sosi IS
  BEGIN
    RETURN func_dp_stream_reconcat(snk_in, in_w, out_w, nof_data, data_representation, TRUE);
  END;

  FUNCTION func_dp_stream_reconcat(snk_in_arr : t_dp_sosi_arr; in_w, out_w, nof_data : NATURAL; data_representation : STRING; data_order_im_re : BOOLEAN) RETURN t_dp_sosi_arr IS
    VARIABLE v_src_out_arr : t_dp_sosi_arr(snk_in_arr'RANGE) := snk_in_arr;
  BEGIN
    FOR i IN v_src_out_arr'RANGE LOOP
      v_src_out_arr(i) := func_dp_stream_reconcat(snk_in_arr(i), in_w, out_w, nof_data, data_representation, data_order_im_re);
    END LOOP;
    RETURN v_src_out_arr;
  END;

  FUNCTION func_dp_stream_reconcat(snk_in_arr : t_dp_sosi_arr; in_w, out_w, nof_data : NATURAL; data_representation : STRING) RETURN t_dp_sosi_arr IS
  BEGIN
    RETURN func_dp_stream_reconcat(snk_in_arr, in_w, out_w, nof_data, data_representation, TRUE);
  END;

  -- Deconcatenate data from SOSI into SOSI array
  FUNCTION func_dp_stream_deconcat(snk_in : t_dp_sosi; nof_streams, data_w : NATURAL) RETURN t_dp_sosi_arr IS
    CONSTANT c_compl_data_w : NATURAL := data_w/2;
    VARIABLE v_src_out_arr  : t_dp_sosi_arr(nof_streams-1 DOWNTO 0);
  BEGIN
    FOR i IN v_src_out_arr'RANGE LOOP
      v_src_out_arr(i) := snk_in;
      v_src_out_arr(i).data := (OTHERS=>'0');
      v_src_out_arr(i).re   := (OTHERS=>'0');
      v_src_out_arr(i).im   := (OTHERS=>'0');
      v_src_out_arr(i).data := RESIZE_DP_DATA(    snk_in.data((i+1)*        data_w-1 DOWNTO i*        data_w));
      v_src_out_arr(i).re   := RESIZE_DP_DSP_DATA(snk_in.re  ((i+1)*c_compl_data_w-1 DOWNTO i*c_compl_data_w));
      v_src_out_arr(i).im   := RESIZE_DP_DSP_DATA(snk_in.im  ((i+1)*c_compl_data_w-1 DOWNTO i*c_compl_data_w));
    END LOOP;
    RETURN v_src_out_arr;
  END;

  FUNCTION func_dp_stream_deconcat(src_out_arr : t_dp_siso_arr) RETURN t_dp_siso IS -- Wire SISO_ARR(0) to single SISO
  BEGIN
    RETURN src_out_arr(0);
  END;

END dp_stream_pkg;

