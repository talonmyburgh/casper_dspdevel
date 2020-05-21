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

library ieee, common_pkg_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;

package fft_pkg is

  -- FFT parameters for pipelined FFT (fft_pipe), parallel FFT (fft_par) and wideband FFT (fft_wide)
  type t_fft is record
    use_reorder    : boolean;  -- = false for bit-reversed output, true for normal output
    use_fft_shift  : boolean;  -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
    use_separate   : boolean;  -- = false for complex input, true for two real inputs
    nof_chan       : natural;  -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan 
    wb_factor      : natural;  -- = default 1, wideband factor
    twiddle_offset : natural;  -- = default 0, twiddle offset for PFT sections in a wideband FFT
    nof_points     : natural;  -- = 1024, N point FFT
    in_dat_w       : natural;  -- = 8,  number of input bits
    out_dat_w      : natural;  -- = 13, number of output bits
    out_gain_w     : natural;  -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
    stage_dat_w    : natural;  -- = 18, data width used between the stages(= DSP multiplier-width)
    guard_w        : natural;  -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. 
                               --   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section
                               --   12.3.2], therefore use input guard_w = 2.
    guard_enable   : boolean;  -- = true when input needs guarding, false when input requires no guarding but scaling must be
                               --   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section
                               --   doing the input guard and par fft section doing the output compensation)
    stat_data_w    : positive; -- = 56
    stat_data_sz   : positive; -- = 2
  end record;
  
  constant c_fft   : t_fft := (true, false, true, 0, 4, 0, 1024, 8, 14, 0, c_dsp_mult_w, 2, true, 56, 2);
  
  -- Check consistancy of the FFT parameters
  function fft_r2_parameter_asserts(g_fft : t_fft) return boolean;  -- the return value is void, because always true or abort due to failure
  
  -- Definitions for fft slv array (an array can not have unconstraint elements, so choose sufficiently wide 32 bit slv elements)
  subtype  t_fft_slv_arr is t_slv_32_arr;    -- use subtype to ease interfacing to existing types and to have central definition for rtwo components
  constant c_fft_slv_w  : natural := 32;    -- match slv width of t_fft_slv_arr
  function to_fft_svec(n : integer) return std_logic_vector;                 -- map to c_fft_slv_w wide slv, no need for to_rtwo_uvec, because natural is subtype of integer
  function resize_fft_uvec(vec : std_logic_vector) return std_logic_vector;  -- map to c_fft_slv_w wide slv
  function resize_fft_svec(vec : std_logic_vector) return std_logic_vector;  -- map to c_fft_slv_w wide slv

  -- FFT shift swaps right and left half of bin axis to shift zero-frequency component to center of spectrum
  function fft_shift(bin : std_logic_vector) return std_logic_vector;
  function fft_shift(bin, w : natural) return natural;
  
end package fft_pkg;

package body fft_pkg is

  function fft_r2_parameter_asserts(g_fft : t_fft) return boolean is
  begin
    -- nof_points
    assert g_fft.nof_points=2**true_log2(g_fft.nof_points) report "fft_r2: nof_points must be a power of 2" severity failure;
    -- wb_factor
    assert g_fft.wb_factor=2**true_log2(g_fft.wb_factor) report "fft_r2: wb_factor must be a power of 2" severity failure;
    -- use_reorder
    if g_fft.use_reorder=false then
      assert g_fft.use_separate=false  report "fft_r2 : without use_reorder there cannot be use_separate for two real inputs" severity failure;
      assert g_fft.use_fft_shift=false report "fft_r2 : without use_reorder there cannot be use_fft_shift for complex input"  severity failure;
    end if;
    -- use_separate
    if g_fft.use_separate=true then
      assert g_fft.use_fft_shift=false report "fft_r2 : with use_separate there cannot be use_fft_shift for two real inputs"  severity failure;
    end if;
    return true;
  end;    

  function to_fft_svec(n : integer) return std_logic_vector is
  begin
    return RESIZE_SVEC(TO_SVEC(n, 32), c_fft_slv_w);
  end;

  function resize_fft_uvec(vec : std_logic_vector) return std_logic_vector is
  begin
    return RESIZE_UVEC(vec, c_fft_slv_w);
  end;

  function resize_fft_svec(vec : std_logic_vector) return std_logic_vector is
  begin
    return RESIZE_SVEC(vec, c_fft_slv_w);
  end;
  
  function fft_shift(bin : std_logic_vector) return std_logic_vector is
    constant c_w   : natural := bin'length;
    variable v_bin : std_logic_vector(c_w-1 downto 0) := bin;
  begin
    return not v_bin(c_w-1) & v_bin(c_w-2 downto 0);  -- invert MSbit for fft_shift
  end;
  
  function fft_shift(bin, w : natural) return natural is
  begin
    return TO_UINT(fft_shift(TO_UVEC(bin, w)));
  end;
  
end fft_pkg;

