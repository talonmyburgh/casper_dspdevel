------------------------------------- 
-- Twiddle Generation in VHDL
-- Note: This is no longer generated by Python/Matlab
-- Any automated generation should be disabled in your build scripts! 
-------------------------------------
--Author	: M. Schiller (NRAO)
--Date    : 23-March-2023

--------------------------------------------------------------------------------
-- Copyright NRAO March 23, 2023
--------------------------------------------------------------------------------
-- License
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
Library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use ieee.math_real.all;
library common_pkg_lib;
use ieee.fixed_float_types.all;
--use ieee.fixed_pkg.all;
use ieee.fixed_pkg.all;

 package twiddlesPkg is 
 constant copyRightNotice: string := "Copyright 2023 , NRAO. All rights reserved."; 




  -- Twiddles need two generation mechanisms.  The ROM (or Memory) generation is needed for Pipelined stages
  -- Constants needs to be generated for Parallel mode
  --
  	function min_one(n:integer) return integer;

  function gen_twiddle_factor_real(k: integer; wb_instance : integer; stage: integer; wb_factor : integer; constant twiddle_width : integer; constant do_ifft : boolean; constant gen_real : boolean) return REAL;
  function gen_twiddle_factor(k: integer; wb_instance : integer; stage: integer; wb_factor : integer; constant twiddle_width : integer; constant do_ifft : boolean; constant gen_real : boolean) return signed;

  
  --function gen_terminal_idxA(fftsize: integer; butterflyidx: integer; num_data_buses : integer) return integer;
  --function gen_terminal_idxB(fftsize: integer; butterflyidx: integer; num_data_buses : integer) return integer;
 end package twiddlesPkg; 

package body twiddlesPkg is
	function min_one(n:integer) return integer is
	begin
		if n<1 then
			return 1;
		else
			return n;
		end if;
	end function min_one;

  function gen_twiddle_factor_real(k: integer; wb_instance : integer; stage: integer; wb_factor : integer; constant twiddle_width : integer; constant do_ifft : boolean; constant gen_real : boolean) return real is
  -- When g_gen_real = true, returns the real component (eg uses cos)
  -- when g_gen_real = false, returns the imag component (eg uses sin)
  -- When g_do_ifft = false:
  --    Output will be twiddle factor = e^((-2*pi*j*k)/fftsize)
  -- When g_do_ifft = true
  --    Output will be twiddle factor = e^((2*pi*j*k)/fftsize)  [basically just the conjugation of the other case]
  -- 
  -- K = Index into ROM (when this is used in ROM mode)
  -- wb_instance = Wide Band Instance Number
  -- Stage = Stage of the FFT

  -- The Indexing used here to generate twiddles is based on the processing order and division of data
  -- when processing wide-band (parallel) data.
  --variable twiddle_sfixed : sfixed(0 downto (0-(twiddle_width-1)));  --S0.17 for G_twiddle_width=18
  --variable twiddle_signed : signed(twiddle_width-1 downto 0);
  variable twiddle_factor : real;
  variable startidx       : integer;
  variable fftsize        : integer;
  variable idx            : integer;
  begin
    -- In python we'd want
    -- coeff_indices = np.arange(wb_instance%2**stage, 2**stage, wb_factor)
    -- idx = coeff_indices(k)
    fftsize   := (2**stage)*wb_factor; 
    startidx  := wb_instance mod fftsize;
    idx       := (startidx + k*wb_factor);  -- Note this is just a no-op effectively (k gets passed through) when wb_factor is 1 since startidx=0 in that case too.
    assert idx<fftsize report "gen_twiddle_factor: Calculated idx exceed idx size, possible problem in gen_twiddle_factor_rom" severity failure;
    assert twiddle_width<50 report "gen_twiddle_factor: Large Twiddle Widths may have precision problems due to double floating point" severity failure;
    if gen_real then
      if do_ifft then
        --ifft real
        twiddle_factor := cos(1.0*MATH_PI*real(idx)/real(fftsize));
      else
        --fft Real
        twiddle_factor := cos(-1.0*MATH_PI*real(idx)/real(fftsize));
      end if;
    else
      if do_ifft then
        --ifft imag
        twiddle_factor := sin(1.0*MATH_PI*real(idx)/real(fftsize));
      else
        --fft Real
        twiddle_factor := sin(-1.0*MATH_PI*real(idx)/real(fftsize));
      end if;
    end if;
    return twiddle_factor;
  end function gen_twiddle_factor_real;


  function gen_twiddle_factor(k: integer; wb_instance : integer; stage: integer; wb_factor : integer; constant twiddle_width : integer; constant do_ifft : boolean; constant gen_real : boolean) return signed is
  -- When g_gen_real = true, returns the real component (eg uses cos)
  -- when g_gen_real = false, returns the imag component (eg uses sin)
  -- When g_do_ifft = false:
  --    Output will be twiddle factor = e^((-2*pi*j*k)/fftsize)
  -- When g_do_ifft = true
  --    Output will be twiddle factor = e^((2*pi*j*k)/fftsize)  [basically just the conjugation of the other case]
  -- 
  -- K = Index into ROM (when this is used in ROM mode)
  -- wb_instance = Wide Band Instance Number
  -- Stage = Stage of the FFT

  -- The Indexing used here to generate twiddles is based on the processing order and division of data
  -- when processing wide-band (parallel) data.
  variable twiddle_sfixed : sfixed(0 downto (0-(twiddle_width-1)));  --S0.17 for G_twiddle_width=18
  variable twiddle_signed : signed(twiddle_width-1 downto 0);
  variable twiddle_factor : real;
  begin
    twiddle_factor := gen_twiddle_factor_real(k,wb_instance, stage,wb_factor,twiddle_width,do_ifft,gen_real);

    twiddle_sfixed := to_sfixed(twiddle_factor,twiddle_sfixed);
    twiddle_signed := signed(to_slv(twiddle_sfixed));
    return twiddle_signed;
  end function gen_twiddle_factor;


end package body twiddlesPkg;
--function gen_terminal_idxA(fftsize: integer; butterflyidx: integer; num_data_buses : integer) return integer is
--variable mapping        : integer_array((num_data_buses/2)-1 downto 0);
--variable fftsize_cnt    : integer;
--variable last_fft_start : integer;
--
--begin
---- examples fftsize=16 databuses=16
-----       00 01 02 03 04 05 06 07
---- mapping 00 01 02 03 04 05 06 07
---- FFTsize=8 databuses =16
---- mapping 00 01 02 03 08 09 10 11
---- FFTsize=4 databuses =16
---- mapping 00 01 04 05 08 09 12 13
--  last_fft_start  := 0;
--  fftsize_cnt     := 0;
--  for idx in 1 to num_data_buses/2 loop 
--    mapping(idx-1)  := last_fft_start + fftsize_cnt;
--    fftsize_cnt     := fftsize_cnt + 1;
--    if fftsize_cnt = (fftsize/2) then
--      last_fft_start  := last_fft_start + fftsize;
--      fftsize_cnt     := 0;
--    end if;
--  end loop;
--  return mapping(butterflyidx);
--end function gen_terminal_idxA;

--function gen_terminal_idxB(fftsize: integer; butterflyidx: integer; num_data_buses : integer) return integer is
--
--variable mapping        : integer_array((num_data_buses/2)-1 downto 0);
--variable fftsize_cnt    : integer;
--variable last_fft_start : integer;
--begin
---- examples fftsize=16 databuses=16
-----       00 01 02 03 04 05 06 07
---- return 08 09 10 11 12 13 14 15
---- FFTsize=8 databuses =16
---- return 04 05 06 07 12 13 14 15
---- FFTsize=4 databuses =16
---- return 02 03 06 07 10 11 14 15
--  last_fft_start  := fftsize/2;
--  fftsize_cnt     := 0;
--  for idx in 1 to num_data_buses/2 loop 
--    mapping(idx-1)  := last_fft_start + fftsize_cnt;
--    fftsize_cnt     := fftsize_cnt + 1;
--    if fftsize_cnt = (fftsize/2) then
--      last_fft_start  := last_fft_start + fftsize;
--      fftsize_cnt     := 0;
--    end if;
--  end loop;
--  return mapping(butterflyidx);
--end function gen_terminal_idxB;    