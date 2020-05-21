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
USE common_pkg_lib.common_str_pkg.ALL;

-- Purpose:
-- . Dynamically map record-like field structures onto SLVs.
-- Description:
-- . The MM register is defined by mm_fields.vhd.
-- . The MM register consists of "RO" = input fields (status) and "RW" = output fields (control) in
--   arbitrary order. The entire register is kept in a word_arr slv. The functions can extract the
--   "RO" fields into a slv_in and the "RW" fields into a slv_out. Hence the slv_in'LENGTH +
--   slv_out'LENGTH = word_arr'LENGTH.
--
-- . Advantages:
--   . Replaces non-generic (dedicated) records;
--   . Field widths are variable
-- Remarks:


PACKAGE common_field_pkg IS

  CONSTANT c_common_field_name_len    : NATURAL := 64;
  CONSTANT c_common_field_default_len : NATURAL := 256;
 
  TYPE t_common_field IS RECORD
    name     : STRING(1 TO c_common_field_name_len);
    mode     : STRING(1 TO 2);
    size     : POSITIVE;
    dflt  : STD_LOGIC_VECTOR(c_common_field_default_len-1 DOWNTO 0);
END RECORD;

  TYPE t_common_field_arr IS ARRAY(INTEGER RANGE <>) OF t_common_field;

  FUNCTION field_name_pad(name: STRING) RETURN STRING;
 
  FUNCTION field_default(slv_in: STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR;
  FUNCTION field_default(nat_in: NATURAL) RETURN STD_LOGIC_VECTOR;

  FUNCTION field_map_defaults(field_arr : t_common_field_arr) RETURN STD_LOGIC_VECTOR;  -- returns slv_out

  FUNCTION field_mode        (field_arr : t_common_field_arr; name: STRING     ) RETURN STRING;
  FUNCTION field_size        (field_arr : t_common_field_arr; name: STRING     ) RETURN NATURAL;
  FUNCTION field_hi          (field_arr : t_common_field_arr; name: STRING     ) RETURN INTEGER;
  FUNCTION field_hi          (field_arr : t_common_field_arr; index: NATURAL   ) RETURN NATURAL;
  FUNCTION field_lo          (field_arr : t_common_field_arr; name: STRING     ) RETURN NATURAL;
  FUNCTION field_lo          (field_arr : t_common_field_arr; index: NATURAL   ) RETURN NATURAL;
  FUNCTION field_slv_len     (field_arr : t_common_field_arr                   ) RETURN NATURAL;
  FUNCTION field_slv_in_len  (field_arr : t_common_field_arr                   ) RETURN NATURAL;
  FUNCTION field_slv_out_len (field_arr : t_common_field_arr                   ) RETURN NATURAL;
  FUNCTION field_nof_words   (field_arr : t_common_field_arr; word_w : NATURAL ) RETURN NATURAL; 
  FUNCTION field_map_in      (field_arr : t_common_field_arr; slv        : STD_LOGIC_VECTOR; word_w : NATURAL ; mode : STRING) RETURN STD_LOGIC_VECTOR;  -- returns word_arr
  FUNCTION field_map_out     (field_arr : t_common_field_arr; word_arr   : STD_LOGIC_VECTOR; word_w : NATURAL                ) RETURN STD_LOGIC_VECTOR;  -- returns slv_out
  FUNCTION field_map         (field_arr : t_common_field_arr; word_arr_in: STD_LOGIC_VECTOR; word_arr_out: STD_LOGIC_VECTOR; word_w : NATURAL) RETURN STD_LOGIC_VECTOR;  -- returns word_arr

  FUNCTION field_ovr_arr(field_arr : t_common_field_arr; ovr_init: STD_LOGIC_VECTOR) RETURN t_common_field_arr;

  FUNCTION field_exists(field_arr : t_common_field_arr; name: STRING) RETURN BOOLEAN;

  FUNCTION field_arr_set_mode(field_arr : t_common_field_arr; mode : STRING) RETURN t_common_field_arr;

  FUNCTION sel_a_b(sel : BOOLEAN; a, b : t_common_field_arr ) RETURN t_common_field_arr;

END common_field_pkg;


PACKAGE BODY common_field_pkg IS

  FUNCTION field_name_pad(name: STRING) RETURN STRING IS
  BEGIN
    RETURN pad(name, c_common_field_name_len, ' ');
  END field_name_pad;

  FUNCTION field_default(slv_in: STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN RESIZE_UVEC(slv_in, c_common_field_default_len);
  END field_default;

  FUNCTION field_default(nat_in: NATURAL) RETURN STD_LOGIC_VECTOR IS
  BEGIN
    RETURN TO_UVEC(nat_in, c_common_field_default_len);
  END field_default;

  FUNCTION field_map_defaults(field_arr : t_common_field_arr) RETURN STD_LOGIC_VECTOR IS
    VARIABLE v_slv_out : STD_LOGIC_VECTOR(field_slv_out_len(field_arr)-1 DOWNTO 0);
  BEGIN
    FOR f IN 0 TO field_arr'HIGH LOOP
      IF field_arr(f).mode="RW" THEN
        v_slv_out( field_hi(field_arr, field_arr(f).name) DOWNTO field_lo(field_arr, field_arr(f).name)) := field_arr(f).dflt(field_arr(f).size-1 DOWNTO 0);
      END IF;
    END LOOP;
    RETURN v_slv_out;
  END field_map_defaults;

  FUNCTION field_mode(field_arr : t_common_field_arr; name: STRING) RETURN STRING IS
  -- Returns the mode string of the passed (via name) field
  BEGIN
    IF field_exists(field_arr, name) THEN 
      FOR i IN 0 TO field_arr'HIGH LOOP
        IF field_arr(i).name=field_name_pad(name) THEN
          RETURN field_arr(i).mode;
        END IF;
      END LOOP;
    ELSE
      RETURN "-1";
    END IF;
  END field_mode;

  FUNCTION field_size(field_arr : t_common_field_arr; name: STRING) RETURN NATURAL IS
  -- Returns the size of the passed (via name) field
  BEGIN
    FOR i IN 0 TO field_arr'HIGH LOOP
      IF field_arr(i).name=field_name_pad(name) THEN
        RETURN field_arr(i).size;
      END IF;
    END LOOP;
  END field_size;

  FUNCTION field_hi(field_arr : t_common_field_arr; name: STRING) RETURN INTEGER IS
  -- Returns the high (=left) bit range index of the field within the field_arr interpreted as concatenated IN or OUT SLV
    VARIABLE v_acc_hi : NATURAL := 0;
  BEGIN 
    IF field_exists(field_arr, name) THEN   
      FOR i IN 0 TO field_arr'HIGH LOOP
        IF field_arr(i).mode=field_mode(field_arr, name) THEN  -- increment index only for the "RO" = IN or the "RW" = OUT
          v_acc_hi := v_acc_hi + field_arr(i).size;
          IF field_arr(i).name = field_name_pad(name) THEN
            RETURN v_acc_hi-1;
          END IF;
        END IF;
      END LOOP;
    ELSE --field does not exist; return -1 which results in null array
      RETURN -1;
    END IF;
  END field_hi;

  FUNCTION field_hi(field_arr : t_common_field_arr; index : NATURAL) RETURN NATURAL IS
  -- Returns the high (=left) bit range index of the field within the field_arr interpreted as concatenated SLV
    VARIABLE v_acc_hi : NATURAL := 0;
  BEGIN    
    FOR i IN 0 TO index LOOP
      v_acc_hi := v_acc_hi + field_arr(i).size;
      IF i = index THEN
        RETURN v_acc_hi-1;
      END IF;
    END LOOP;
  END field_hi;

  FUNCTION field_lo(field_arr : t_common_field_arr; name: STRING) RETURN NATURAL IS
  -- Returns the low (=right) bit range index of the field within the field_arr interpreted as concatenated IN or OUT SLV
    VARIABLE v_acc_hi : NATURAL := 0;
  BEGIN
    IF field_exists(field_arr, name) THEN  
      FOR i IN 0 TO field_arr'HIGH LOOP
        IF field_arr(i).mode=field_mode(field_arr, name) THEN  -- increment index only for the "RO" = IN or the "RW" = OUT
          v_acc_hi := v_acc_hi + field_arr(i).size;
          IF field_arr(i).name = field_name_pad(name) THEN
            RETURN v_acc_hi-field_arr(i).size;
          END IF;
        END IF;
      END LOOP;
    ELSE
      RETURN 0;
    END IF;
  END field_lo;

  FUNCTION field_lo(field_arr : t_common_field_arr; index : NATURAL) RETURN NATURAL IS
  -- Returns the low (=right) bit range index of the field within the field_arr interpreted as concatenated SLV
    VARIABLE v_acc_hi : NATURAL := 0;
  BEGIN
    FOR i IN 0 TO index LOOP
      v_acc_hi := v_acc_hi + field_arr(i).size;
      IF i = index THEN
        RETURN v_acc_hi-field_arr(i).size;
      END IF;
    END LOOP;
  END field_lo;

  FUNCTION field_slv_len(field_arr : t_common_field_arr) RETURN NATURAL IS
  -- Return the total length of all fields in field_arr
    VARIABLE v_len : NATURAL := 0;
  BEGIN
    FOR i IN 0 TO field_arr'HIGH LOOP
      v_len := v_len + field_arr(i).size;
    END LOOP;  
    RETURN v_len;  
  END field_slv_len;

  FUNCTION field_slv_in_len(field_arr : t_common_field_arr) RETURN NATURAL IS
  -- Return the total length of the input fields in field_arr (= all "RO")
    VARIABLE v_len : NATURAL := 0;
  BEGIN
    FOR f IN 0 TO field_arr'HIGH LOOP
      IF field_arr(f).mode="RO" THEN
        v_len := v_len + field_arr(f).size;      
      END IF;
    END LOOP;  
    RETURN v_len;  
  END field_slv_in_len;

  FUNCTION field_slv_out_len(field_arr : t_common_field_arr) RETURN NATURAL IS
  -- Return the total length of the output fields in field_arr (= all "RW")
    VARIABLE v_len : NATURAL := 0;
  BEGIN
    FOR f IN 0 TO field_arr'HIGH LOOP
      IF field_arr(f).mode="RW" THEN
        v_len := v_len + field_arr(f).size;
      END IF;
    END LOOP;  
    RETURN v_len;  
  END field_slv_out_len;

  FUNCTION field_nof_words(field_arr : t_common_field_arr; word_w : NATURAL) RETURN NATURAL IS
  -- Return the number of words (of width word_w) required to hold field_arr
    VARIABLE v_word_cnt      : NATURAL := 0;
    VARIABLE v_nof_reg_words : NATURAL;
  BEGIN
    FOR f IN 0 TO field_arr'HIGH LOOP
      -- Get the number of register words this field spans
      v_nof_reg_words := ceil_div(field_arr(f).size, word_w);
      FOR w IN 0 TO v_nof_reg_words-1 LOOP 
        v_word_cnt := v_word_cnt +1;
      END LOOP;
    END LOOP;
    RETURN v_word_cnt;
  END field_nof_words;

  FUNCTION field_map_in(field_arr : t_common_field_arr; slv: STD_LOGIC_VECTOR; word_w : NATURAL; mode : STRING) RETURN STD_LOGIC_VECTOR IS
  -- Re-map a field SLV into a larger SLV, support mapping both the slv_in or the slv_out that dependents on mode; each field starting at a word boundary (word_w)
    VARIABLE v_word_arr : STD_LOGIC_VECTOR(field_nof_words(field_arr, word_w)*word_w-1 DOWNTO 0) := (OTHERS=>'0');
    VARIABLE v_word_cnt : NATURAL := 0;
  BEGIN
    FOR f IN 0 TO field_arr'HIGH LOOP
       -- Only extract the fields that are inputs
      IF field_arr(f).mode=mode THEN  -- if mode="RO" then slv = slv_in, else if mode="RW" then slv = slv_out
        -- Extract the field 
        v_word_arr( v_word_cnt*word_w+field_arr(f).size-1 DOWNTO v_word_cnt*word_w) := slv( field_hi(field_arr, field_arr(f).name) DOWNTO field_lo(field_arr, field_arr(f).name) );
      END IF; 
      -- Calculate the correct word offset for the next field
      v_word_cnt  := v_word_cnt + ceil_div(field_arr(f).size, word_w);
    END LOOP;
    RETURN v_word_arr;
  END field_map_in;

  FUNCTION field_map_out(field_arr : t_common_field_arr; word_arr: STD_LOGIC_VECTOR; word_w : NATURAL) RETURN STD_LOGIC_VECTOR IS
  -- Reverse of field_map_in
    VARIABLE v_slv_out  : STD_LOGIC_VECTOR(field_slv_out_len(field_arr)-1 DOWNTO 0) := (OTHERS=>'0');
    VARIABLE v_word_cnt : NATURAL := 0;
  BEGIN
    FOR f IN 0 TO field_arr'HIGH LOOP
      -- Only extract the fields that are outputs 
      IF field_arr(f).mode="RW" THEN
        -- Extract the field 
        v_slv_out( field_hi(field_arr, field_arr(f).name) DOWNTO field_lo(field_arr, field_arr(f).name)) := word_arr( v_word_cnt*word_w+field_arr(f).size-1 DOWNTO v_word_cnt*word_w);
      END IF;
      -- Calculate the correct word offset for the next field
      v_word_cnt  := v_word_cnt + ceil_div(field_arr(f).size, word_w);
    END LOOP;
    RETURN v_slv_out;
  END field_map_out;

  FUNCTION field_map(field_arr : t_common_field_arr; word_arr_in: STD_LOGIC_VECTOR; word_arr_out: STD_LOGIC_VECTOR; word_w : NATURAL) RETURN STD_LOGIC_VECTOR IS
  -- Create one SLV consisting of both read-only and output-readback fields, e.g. as input to an MM reg
    VARIABLE v_word_arr : STD_LOGIC_VECTOR(field_nof_words(field_arr, word_w)*word_w-1 DOWNTO 0);
    VARIABLE v_word_cnt : NATURAL := 0;
  BEGIN
    -- Wire the entire SLV to the input SLV by default
    v_word_arr := word_arr_in;
    -- Now re-assign the words that need to be read back from word_arr_out
    FOR f IN 0 TO field_arr'HIGH LOOP
      IF field_arr(f).mode="RW" THEN
        v_word_arr( v_word_cnt*word_w+field_arr(f).size-1 DOWNTO v_word_cnt*word_w):= word_arr_out( v_word_cnt*word_w+field_arr(f).size-1 DOWNTO v_word_cnt*word_w);
      END IF;
      -- Calculate the correct word offset for the next field
      v_word_cnt := v_word_cnt + ceil_div(field_arr(f).size, word_w);
    END LOOP;
    RETURN v_word_arr;
  END field_map;

  FUNCTION field_ovr_arr(field_arr : t_common_field_arr; ovr_init: STD_LOGIC_VECTOR) RETURN t_common_field_arr IS
  -- Copy field_arr but change widths to 1 to create a 1-bit override field for each field in field_arr.
    VARIABLE v_ovr_field_arr : t_common_field_arr(field_arr'RANGE);
  BEGIN
    v_ovr_field_arr:= field_arr;
    FOR i IN field_arr'RANGE LOOP
      v_ovr_field_arr(i).size := 1;
      v_ovr_field_arr(i).dflt := field_default(slv(ovr_init(i)));
    END LOOP;
    RETURN v_ovr_field_arr;
  END field_ovr_arr;

  FUNCTION field_exists(field_arr : t_common_field_arr; name: STRING) RETURN BOOLEAN IS
  BEGIN
    FOR i IN field_arr'RANGE LOOP
      IF field_arr(i).name=field_name_pad(name) THEN
        RETURN TRUE;
      END IF;
    END LOOP;
  RETURN FALSE;
  END field_exists;

  FUNCTION field_arr_set_mode(field_arr : t_common_field_arr; mode : STRING) RETURN t_common_field_arr IS
    VARIABLE v_field_arr : t_common_field_arr(field_arr'RANGE);
  BEGIN
    v_field_arr := field_arr;  
    FOR i IN field_arr'RANGE LOOP
      v_field_arr(i).mode := mode;
    END LOOP;
    RETURN v_field_arr; 
  END field_arr_set_mode;

  FUNCTION sel_a_b(sel :BOOLEAN; a, b : t_common_field_arr) RETURN t_common_field_arr IS
  BEGIN
    IF sel = TRUE THEN
      RETURN a;
    ELSE
      RETURN b;
    END IF;
  END;

END common_field_pkg;
