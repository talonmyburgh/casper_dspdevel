--------------------------------------------------------------------------------
-- Author: Harm Jan Pepping : HJP at astron.nl: April 2012
--------------------------------------------------------------------------------
--
-- Copyright (C) 2012
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--
--------------------------------------------------------------------------------
-- Purpose: Wideband polyphase filterbank with subband statistics and streaming interfaces.
--
-- Description:
--
-- This WPFB unit connects an incoming array of streaming interfaces to the
-- wideband pft + fft.
-- The output of the wideband fft is connected to a set of subband statistics
-- units. The statistics can be read via the memory mapped interface.
-- A control unit takes care of the correct composition of the control of the 
-- output streams regarding sop, eop, sync, bsn, err.
--
-- The wpfb unit can handle a wideband factor >= 1 (g_wpfb.wb_factor) or
-- a narrowband factor >= 1 (2**g_wpfb.nof_chan).
-- . For wb_factor = 1 the wpfb_unit uses fft_r2_pipe
-- . For wb_factor > 1 the wpfb_unit uses fft_r2_wide
-- . For wb_factor >= 1 the wpfb_unit supports nof_chan >= 0, even though the
--   concept of channels is typically not useful when wb_factor > 1.
-- . The wpfb_unit does support use_reorder.
-- . The wpfb_unit does support use_separate.
-- . The wpfb_unit does support input flow control with invalid gaps in the
--   input.
--
-- . g_coefs_file_prefix:
--   The g_coefs_file_prefix points to the location where the files
--   with the initial content for the coefficients memories are located and
--   is described in fil_ppf_wide.vhd.
--
-- . fft_out_gain_w
--   For two real input typically fft_out_gain_w = 1 is used to compensate for
--   the divide by 2 in the separate function that is done because real input
--   frequency bins have norm 0.5. For complex input typically fft_out_gain_w
--   = 0, because the complex bins have norm 1.
--
-- . g_dont_flip_channels:
--   True preserves channel interleaving, set by g_wpfb.nof_chan>0, of the FFT
--   output when g_bit_flip=true to reorder the FFT output.
--   The g_dont_flip_channels applies for both complex input and two_real
--   input FFT. The g_dont_flip_channels is only implemented for the pipelined
--   fft_r2_pipe, because for g_wpfb.wb_factor=1 using g_wpfb.nof_chan>0 makes
--   sense, while for the fft_r2_wide with g_wpfb.wb_factor>1 using input
--   multiplexing via g_wpfb.nof_chan>0 makes less sense.
--
-- The reordering to the fil_ppf_wide is done such that the FIR filter
-- coefficients are reused. The same filter coefficients are used for all
-- streams. The filter has real coefficients, because the filterbank
-- channels are symmetrical in frequency. The real part and the imaginary
-- part are filtered independently and also use the same real FIR
-- coefficients.
--
-- Note that:
-- . The same P of all streams are grouped the in filter and all P per
--   stream are grouped in the FFT. Hence the WPFB input is grouped per
--   P for all wideband streams to allow FIR coefficients reuse per P
--   for all wideband streams. The WPFB output is grouped per wideband
--   stream to have all P together.
--
-- . The wideband time index t is big-endian inside the prefilter and
--   little-endian inside the FFT. 
--   When g_big_endian_wb_in=true then the WPFB input must be in big-endian
--   format, else in little-endian format.
--   For little-endian time index t increments in the same direction as the
--   wideband factor index P, so P = 0, 1, 2, 3 --> t0, t1, t2, t3.
--   For big-endian the time index t increments in the opposite direction of
--   the wideband factor index P, so P = 3, 2, 1, 0 --> t0, t1, t2, t3.
--   The WPFB output is fixed little-endian, so with frequency bins in
--   incrementing order. However the precise frequency bin order depends
--   on the reorder generics.
--
-- When wb_factor = 4 and nof_wb_streams = 2 the mapping is as follows using 
-- the array notation:
--
--   . I = array index
--   . S = stream index of a wideband stream
--   . P = wideband factor index
--   . t = time index
--
--                    parallel                           serial   type
--   in_sosi_arr      [nof_streams][wb_factor]           [t]      cint
--                                               
--   fil_in_arr       [wb_factor][nof_streams][complex]  [t]       int
--   fil_out_arr      [wb_factor][nof_streams][complex]  [t]       int
--                                               
--   fil_sosi_arr     [nof_streams][wb_factor]           [t]      cint
--   fft_in_re_arr    [nof_streams][wb_factor]           [t]       int
--   fft_in_im_arr    [nof_streams][wb_factor]           [t]       int
--   fft_out_re_arr   [nof_streams][wb_factor]           [bin]     int
--   fft_out_im_arr   [nof_streams][wb_factor]           [bin]     int
--   fft_out_sosi_arr [nof_streams][wb_factor]           [bin]    cint
--   pfb_out_sosi_arr [nof_streams][wb_factor]           [bin]    cint with sync, BSN, sop, eop
--   out_sosi_arr     [nof_streams][wb_factor]           [bin]    cint with sync, BSN, sop, eop
-- 
--   in_sosi_arr  | fil_in_arr  | fft_in_re_arr | fft_out_re_arr  
--   fil_sosi_arr | fil_out_arr | fft_in_im_arr | fft_out_im_arr  
--                |             |               | fft_out_sosi_arr
--                |             |               | pfb_out_sosi_arr
--                |             |               |     out_sosi_arr
--                |             |               |
--    I  S P t    |   I  P S    | I  S P t      | I  S P          
--    7  1 3 0    |  15  3 1 IM | 7  1 3 3      | 7  1 3          
--    6  1 2 1    |  14  3 1 RE | 6  1 2 2      | 6  1 2          
--    5  1 1 2    |  13  3 0 IM | 5  1 1 1      | 5  1 1          
--    4  1 0 3    |  12  3 0 RE | 4  1 0 0      | 4  1 0          
--    3  0 3 0    |  11  2 1 IM | 3  0 3 3      | 3  0 3          
--    2  0 2 1    |  10  2 1 RE | 2  0 2 2      | 2  0 2          
--    1  0 1 2    |   9  2 0 IM | 1  0 1 1      | 1  0 1          
--    0  0 0 3    |   8  2 0 RE | 0  0 0 0      | 0  0 0          
--                |   7  1 1 IM |               |                 
--           ^    |   6  1 1 RE |        ^      |                 
--         big    |   5  1 0 IM |      little   |                 
--         endian |   4  1 0 RE |      endian   |                 
--                |   3  0 1 IM |               |                 
--                |   2  0 1 RE |               |                 
--                |   1  0 0 IM |               |                 
--                |   0  0 0 RE |               |                 
--
-- The WPFB output are the frequency bins per transformed block:
--   . subbands, in case ot two real input or
--   . channels, in case of complex input
--
-- The order of the WPFB output depends on the g_fft fields:
--   . wb_factor
--   . use_reorder
--   . use_fft_shift
--   . use_separate
-- 
-- The frequency bin order at the output is obtained with reg_out_bin
-- in the test bench tb_wpfb_unit_dev.vhd.
--
-- Output examples:
--
-- Frequency bins:
--     fs = sample frequency
--     Bb = fs/nof_points = bin bandwidth
--
--     0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
--     ^                                           ^  ^  ^                                          ^
--     <--------- negative bin frequencies ---------> 0 <---------- positive bin frequencies ------->
--     -fs/2                                      -Bb 0 +Bb                                        +fs/2-Bb
--
-- I) Wideband wb_factor = 4
-- 1) Two real inputs:
-- 
--   out_sosi_arr:
--     I  S P    bin frequency order         . nof_streams   = 2            
--     7  1 3    12 12 13 13 14 14 15 15     . wb_factor     = 4                 
--     6  1 2     8  8  9  9 10 10 11 11     . nof_points    = 32               
--     5  1 1     4  4  5  5  6  6  7  7     . use_reorder   = true            
--     4  1 0     0  0  1  1  2  2  3  3     . use_fft_shift = false         
--     3  0 3    12 12 13 13 14 14 15 15     . use_separate  = true           
--     2  0 2     8  8  9  9 10 10 11 11       - input A via in_sosi_arr().re
--     1  0 1     4  4  5  5  6  6  7  7       - input B via in_sosi_arr().im
--     0  0 0     0  0  1  1  2  2  3  3
--      input     A  B  A  B  A  B  A  B
--
--   when nof_chan=1 then:
--     I  S P    bin frequency order    
--     7  1 3    12 12 13 13 14 14 15 15 12 12 13 13 14 14 15 15
--     6  1 2     8  8  9  9 10 10 11 11  8  8  9  9 10 10 11 11
--     5  1 1     4  4  5  5  6  6  7  7  4  4  5  5  6  6  7  7
--     4  1 0     0  0  1  1  2  2  3  3  0  0  1  1  2  2  3  3
--     3  0 3    12 12 13 13 14 14 15 15 12 12 13 13 14 14 15 15
--     2  0 2     8  8  9  9 10 10 11 11  8  8  9  9 10 10 11 11
--     1  0 1     4  4  5  5  6  6  7  7  4  4  5  5  6  6  7  7
--     0  0 0     0  0  1  1  2  2  3  3  0  0  1  1  2  2  3  3
--      input     A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B
--    channel     0....................0  1....................1
--
-- 2a) Complex input with fft_shift:
-- 
--   out_sosi_arr:
--     I  S P    bin frequency order         . nof_streams   = 2                    
--     7  1 3    24 25 26 27 28 29 30 31     . wb_factor     = 4                 
--     6  1 2    16 17 18 19 20 21 22 23     . nof_points    = 32               
--     5  1 1     8  9 10 11 12 13 14 15     . use_reorder   = true                         
--     4  1 0     0  1  2  3  4  5  6  7     . use_fft_shift = true 
--     3  0 3    24 25 26 27 28 29 30 31     . use_separate  = false                       
--     2  0 2    16 17 18 19 20 21 22 23       - complex input via in_sosi_arr().re and im
--     1  0 1     8  9 10 11 12 13 14 15
--     0  0 0     0  1  2  3  4  5  6  7
--
--   when nof_chan=1 then:
--     I  S P    bin frequency order    
--     7  1 3    24 25 26 27 28 29 30 31 24 25 26 27 28 29 30 31
--     6  1 2    16 17 18 19 20 21 22 23 16 17 18 19 20 21 22 23
--     5  1 1     8  9 10 11 12 13 14 15  8  9 10 11 12 13 14 15 
--     4  1 0     0  1  2  3  4  5  6  7  0  1  2  3  4  5  6  7
--     3  0 3    24 25 26 27 28 29 30 31 24 25 26 27 28 29 30 31
--     2  0 2    16 17 18 19 20 21 22 23 16 17 18 19 20 21 22 23
--     1  0 1     8  9 10 11 12 13 14 15  8  9 10 11 12 13 14 15
--     0  0 0     0  1  2  3  4  5  6  7  0  1  2  3  4  5  6  7
--    channel     0....................0  1....................1
--
-- 2b) Complex input with reorder, but no fft_shift:
-- 
--   out_sosi_arr:
--     I  S P    bin frequency order         . nof_streams   = 2                    
--     7  1 3     8  9 10 11 12 13 14 15     . wb_factor     = 4                 
--     6  1 2     0  1  2  3  4  5  6  7     . nof_points    = 32               
--     5  1 1    24 25 26 27 28 29 30 31     . use_reorder   = true                         
--     4  1 0    16 17 18 19 20 21 22 23     . use_fft_shift = false                      
--     3  0 3     8  9 10 11 12 13 14 15     . use_separate  = false                       
--     2  0 2     0  1  2  3  4  5  6  7       - complex input via in_sosi_arr().re and im
--     1  0 1    24 25 26 27 28 29 30 31
--     0  0 0    16 17 18 19 20 21 22 23
-- 
--   when nof_chan=1 then:
--     I  S P    bin frequency order
--     7  1 3     8  9 10 11 12 13 14 15  8  9 10 11 12 13 14 15
--     6  1 2     0  1  2  3  4  5  6  7  0  1  2  3  4  5  6  7
--     5  1 1    24 25 26 27 28 29 30 31 24 25 26 27 28 29 30 31  
--     4  1 0    16 17 18 19 20 21 22 23 16 17 18 19 20 21 22 23
--     3  0 3     8  9 10 11 12 13 14 15  8  9 10 11 12 13 14 15 
--     2  0 2     0  1  2  3  4  5  6  7  0  1  2  3  4  5  6  7
--     1  0 1    24 25 26 27 28 29 30 31 24 25 26 27 28 29 30 31
--     0  0 0    16 17 18 19 20 21 22 23 16 17 18 19 20 21 22 23
--    channel     0....................0  1....................1
--
-- 2c) Complex input without reorder (so bit flipped):
-- 
--   out_sosi_arr:
--     I  S P    bin frequency order         . nof_streams   = 2                
--     7  1 3     8 12 10 14  9 13 11 15     . wb_factor     = 4                
--     6  1 2    24 28 26 30 25 29 27 31     . nof_points    = 32               
--     5  1 1     0  4  2  6  1  5  3  7     . use_reorder   = false                        
--     4  1 0    16 20 18 22 17 21 19 23     . use_fft_shift = false                      
--     3  0 3     8 12 10 14  9 13 11 15     . use_separate  = false                       
--     2  0 2    24 28 26 30 25 29 27 31       - complex input via in_sosi_arr().re and im
--     1  0 1     0  4  2  6  1  5  3  7
--     0  0 0    16 20 18 22 17 21 19 23
--
--   when nof_chan=1 then:
--     I  S P    bin frequency order    
--     7  1 3     8  8 12 12 10 10 14 14  9  9 13 13 11 11 15 15
--     6  1 2    24 24 28 28 26 26 30 30 25 25 29 29 27 27 31 31
--     5  1 1     0  0  4  4  2  2  6  6  1  1  5  5  3  3  7  7  
--     4  1 0    16 16 20 20 18 18 22 22 17 17 21 21 19 19 23 23
--     3  0 3     8  8 12 12 10 10 14 14  9  9 13 13 11 11 15 15 
--     2  0 2    24 24 28 28 26 26 30 30 25 25 29 29 27 27 31 31
--     1  0 1     0  0  4  4  2  2  6  6  1  1  5  5  3  3  7  7
--     0  0 0    16 16 20 20 18 18 22 22 17 17 21 21 19 19 23 23
--    channel     0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1
--
-- II) Narrowband wb_factor = 1
--
-- 1) Two real inputs:
-- 
--   . nof_streams   = 2
--   . nof_chan      = 0
--   . wb_factor     = 1
--   . nof_points    = 32
--   . use_reorder   = true
--   . use_fft_shift = false
--   . use_separate  = true
--     - input A via in_sosi_arr().re
--     - input B via in_sosi_arr().im
--
--   out_sosi_arr:
--     I  S P    bin frequency order
--     1  1 0     0  0  1  1  2  2  3  3  4  4  5  5  6  6  7  7  8  8  9  9 10 10 11 11 12 12 13 13 14 14 15 15
--     0  0 0     0  0  1  1  2  2  3  3  4  4  5  5  6  6  7  7  8  8  9  9 10 10 11 11 12 12 13 13 14 14 15 15
--      input     A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B
--
--   when nof_chan=1 then:
--     I  S P    bin frequency order
--     1  1 0     0  0  1  1  2  2  3  3  4  4  5  5  6  6  7  7  8  8  9  9 10 10 11 11 12 12 13 13 14 14 15 15  0  0  1  1  2  2  3  3  4  4  5  5  6  6  7  7  8  8  9  9 10 10 11 11 12 12 13 13 14 14 15 15
--     0  0 0     0  0  1  1  2  2  3  3  4  4  5  5  6  6  7  7  8  8  9  9 10 10 11 11 12 12 13 13 14 14 15 15  0  0  1  1  2  2  3  3  4  4  5  5  6  6  7  7  8  8  9  9 10 10 11 11 12 12 13 13 14 14 15 15
--      input     A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B  A  B
--     channel:   0............................................................................................0  1............................................................................................1
--
-- 2) Complex input
--   . nof_streams = 2
--   . nof_chan = 0
--   . wb_factor = 1
--   . nof_points = 32
--   . use_separate = false
--     - complex input via in_sosi_arr().re and im

-- 2a) Complex input with fft_shift (so use_reorder = true, use_fft_shift = true)
-- 
--   out_sosi_arr:
--     I  S P    bin frequency order
--     1  1 0     0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
--     0  0 0     0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
--
--   when nof_chan=1 then:
--     I  S P    bin frequency order
--     1  1 0     0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
--     0  0 0     0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
--     channel:   0............................................................................................0  1............................................................................................1
--
-- 2b) Complex input with reorder but no fft_shift (so use_reorder = true, use_fft_shift = false)
-- 
--   out_sosi_arr:
--     I  S P    bin frequency order
--     1  1 0    16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
--     0  0 0    16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
--
--   when nof_chan=1 then:
--     I  S P    bin frequency order
--     1  1 0    16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
--     0  0 0    16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31  0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
--     channel:   0............................................................................................0  1............................................................................................1
--
-- 2c) Complex input without reorder (so use_reorder = false, use_fft_shift = false)
-- 
--   out_sosi_arr:
--     I  S P    bin frequency order
--     1  1 0    16  0 24  8 20  4 28 12 18  2 26 10 22  6 30 14 17  1 25  9 21  5 29 13 19  3 27 11 23  7 31 15
--     0  0 0    16  0 24  8 20  4 28 12 18  2 26 10 22  6 30 14 17  1 25  9 21  5 29 13 19  3 27 11 23  7 31 15
--
--   when nof_chan=1 then:
--     I  S P    bin frequency order
--     1  1 0    16 16  0  0 24 24  8  8 20 20  4  4 28 28 12 12 18 18  2  2 26 26 10 10 22 22  6  6 30 30 14 14 17 17  1  1 25 25  9  9 21 21  5  5 29 29 13 13 19 19  3  3 27 27 11 11 23 23  7  7 31 31 15 15
--     0  0 0    16 16  0  0 24 24  8  8 20 20  4  4 28 28 12 12 18 18  2  2 26 26 10 10 22 22  6  6 30 30 14 14 17 17  1  1 25 25  9  9 21 21  5  5 29 29 13 13 19 19  3  3 27 27 11 11 23 23  7  7 31 31 15 15
--     channel:   0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1  0  1
--
-- Remarks:
-- . The unit can handle only one sync at a time. Therfor the
--   sync interval should be larger than the total pipeline
--   stages of the wideband fft.
--

library ieee, common_pkg_lib, dp_pkg_lib, astron_r2sdf_fft_lib, astron_statistics_lib, astron_filter_lib, astron_wb_fft_lib, astron_diagnostics_lib, astron_ram_lib, astron_mm_lib;
use IEEE.std_logic_1164.all;
use STD.textio.all;
use common_pkg_lib.common_pkg.all;
use astron_ram_lib.common_ram_pkg.all;
use dp_pkg_lib.dp_stream_pkg.ALL;
use astron_r2sdf_fft_lib.rTwoSDFPkg.all;
use astron_statistics_lib.all;
use astron_filter_lib.all;
use astron_filter_lib.fil_pkg.all;
use astron_wb_fft_lib.all;
use astron_wb_fft_lib.fft_pkg.all;
use work.wpfb_pkg.all;

entity wpfb_unit_dev is
  generic (
    g_big_endian_wb_in  : boolean           := true;
    g_wpfb              : t_wpfb;
    g_dont_flip_channels: boolean           := false;   -- True preserves channel interleaving for pipelined FFT
    g_use_prefilter     : boolean           := TRUE;
    g_stats_ena         : boolean           := TRUE;    -- Enables the statistics unit
    g_use_bg            : boolean           := FALSE;
    g_coefs_file_prefix : string            := "data/coefs_wide" -- File prefix for the coefficients files.
   );
  port (
    dp_rst             : in  std_logic := '0';
    dp_clk             : in  std_logic;
    mm_rst             : in  std_logic;
    mm_clk             : in  std_logic;
    ram_fil_coefs_mosi : in  t_mem_mosi;
    ram_fil_coefs_miso : out t_mem_miso := c_mem_miso_rst;
    ram_st_sst_mosi    : in  t_mem_mosi;                   -- Subband statistics registers
    ram_st_sst_miso    : out t_mem_miso := c_mem_miso_rst;
    reg_bg_ctrl_mosi   : in  t_mem_mosi;
    reg_bg_ctrl_miso   : out t_mem_miso;
    ram_bg_data_mosi   : in  t_mem_mosi;
    ram_bg_data_miso   : out t_mem_miso;
    in_sosi_arr        : in  t_dp_sosi_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
    fil_sosi_arr       : out t_dp_sosi_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
    out_sosi_arr       : out t_dp_sosi_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0)
  );
end entity wpfb_unit_dev;

architecture str of wpfb_unit_dev is

  constant c_nof_channels          : natural := 2**g_wpfb.nof_chan;
  
  constant c_nof_data_per_block    : natural := c_nof_channels * g_wpfb.nof_points;
  constant c_nof_valid_per_block   : natural := c_nof_data_per_block / g_wpfb.wb_factor;
  
  constant c_nof_stats             : natural := c_nof_valid_per_block;
  
  constant c_fil_ppf         : t_fil_ppf := (g_wpfb.wb_factor,
                                             g_wpfb.nof_chan,
                                             g_wpfb.nof_points,
                                             g_wpfb.nof_taps,
                                             c_nof_complex*g_wpfb.nof_wb_streams,  -- Complex FFT always requires 2 filter streams: real and imaginary
                                             g_wpfb.fil_backoff_w,
                                             g_wpfb.fil_in_dat_w,
                                             g_wpfb.fil_out_dat_w,
                                             g_wpfb.coef_dat_w);

  constant c_fft             : t_fft     := (g_wpfb.use_reorder,
                                             g_wpfb.use_fft_shift,
                                             g_wpfb.use_separate,
                                             g_wpfb.nof_chan,
                                             g_wpfb.wb_factor,
                                             0,
                                             g_wpfb.nof_points,
                                             g_wpfb.fft_in_dat_w,
                                             g_wpfb.fft_out_dat_w,
                                             g_wpfb.fft_out_gain_w,
                                             g_wpfb.stage_dat_w,
                                             g_wpfb.guard_w,
                                             g_wpfb.guard_enable,
                                             g_wpfb.stat_data_w,
                                             g_wpfb.stat_data_sz);

  constant c_fft_r2_check           : boolean := fft_r2_parameter_asserts(c_fft);
  
  constant c_bg_buf_adr_w           : natural := ceil_log2(g_wpfb.nof_points/g_wpfb.wb_factor);
  constant c_bg_data_file_index_arr : t_nat_natural_arr := array_init(0, g_wpfb.nof_wb_streams*g_wpfb.wb_factor, 1);
  constant c_bg_data_file_prefix    : string  := "UNUSED";

  signal ram_st_sst_mosi_arr : t_mem_mosi_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal ram_st_sst_miso_arr : t_mem_miso_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0) := (others => c_mem_miso_rst);

  signal fil_in_arr          : t_fil_slv_arr(c_nof_complex*g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fil_in_val          : std_logic;
  signal fil_out_arr         : t_fil_slv_arr(c_nof_complex*g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fil_out_val         : std_logic;
  
  signal fft_in_re_arr       : t_fft_slv_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_in_im_arr       : t_fft_slv_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_in_val          : std_logic;

  signal fft_out_re_arr_i    : t_fft_slv_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_out_im_arr_i    : t_fft_slv_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_out_re_arr      : t_fft_slv_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_out_im_arr      : t_fft_slv_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_out_re_arr_pipe : t_fft_slv_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_out_im_arr_pipe : t_fft_slv_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  signal fft_out_val_arr     : std_logic_vector(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);

  signal fft_out_sosi        : t_dp_sosi;
  signal fft_out_sosi_arr    : t_dp_sosi_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0) := (others => c_dp_sosi_rst);
  
  signal pfb_out_sosi_arr    : t_dp_sosi_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0) := (others => c_dp_sosi_rst);
  
  type reg_type is record
    in_sosi_arr : t_dp_sosi_arr(g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 downto 0);
  end record;

  signal r, rin : reg_type;

begin

  -- The complete input sosi arry is registered.
  comb : process(r, in_sosi_arr)
    variable v : reg_type;
  begin
    v             := r;
    v.in_sosi_arr := in_sosi_arr;
    rin           <= v;
  end process comb;

  regs : process(dp_clk)
  begin
    if rising_edge(dp_clk) then
      r <= rin;
    end if;
  end process;

  ---------------------------------------------------------------
  -- COMBINE MEMORY MAPPED INTERFACES
  ---------------------------------------------------------------
  -- Combine the internal array of mm interfaces for the subband
  -- statistics to one array that is connected to the port of the
  -- fft_wide_unit.
  u_mem_mux_sst : entity astron_mm_lib.common_mem_mux
  generic map (
    g_nof_mosi    => g_wpfb.nof_wb_streams*g_wpfb.wb_factor,
    g_mult_addr_w => ceil_log2(g_wpfb.stat_data_sz*c_nof_stats)
  )
  port map (
    mosi     => ram_st_sst_mosi,
    miso     => ram_st_sst_miso,
    mosi_arr => ram_st_sst_mosi_arr,
    miso_arr => ram_st_sst_miso_arr
  );

  gen_pfb : if g_use_bg = FALSE generate
    ---------------------------------------------------------------
    -- REWIRE THE DATA FOR WIDEBAND POLY PHASE FILTER
    ---------------------------------------------------------------

    -- Wire in_sosi_arr --> fil_in_arr
    wire_fil_in_wideband: for P in 0 to g_wpfb.wb_factor-1 generate
      wire_fil_in_streams: for S in 0 to g_wpfb.nof_wb_streams-1 generate
        fil_in_arr(P*g_wpfb.nof_wb_streams*c_nof_complex+S*c_nof_complex)   <= RESIZE_SVEC_32(r.in_sosi_arr(S*g_wpfb.wb_factor+P).re(g_wpfb.fil_in_dat_w-1 downto 0));
        fil_in_arr(P*g_wpfb.nof_wb_streams*c_nof_complex+S*c_nof_complex+1) <= RESIZE_SVEC_32(r.in_sosi_arr(S*g_wpfb.wb_factor+P).im(g_wpfb.fil_in_dat_w-1 downto 0));
      end generate;
    end generate;
    fil_in_val <= r.in_sosi_arr(0).valid;

    -- Wire fil_out_arr --> fil_sosi_arr
    wire_fil_sosi_streams: for S in 0 to g_wpfb.nof_wb_streams-1 generate
      wire_fil_sosi_wideband: for P in 0 to g_wpfb.wb_factor-1 generate
        fil_sosi_arr(S*g_wpfb.wb_factor+P).valid <= fil_out_val;
        fil_sosi_arr(S*g_wpfb.wb_factor+P).re    <= RESIZE_DP_DSP_DATA(fil_out_arr(P*g_wpfb.nof_wb_streams*c_nof_complex+S*c_nof_complex  ));
        fil_sosi_arr(S*g_wpfb.wb_factor+P).im    <= RESIZE_DP_DSP_DATA(fil_out_arr(P*g_wpfb.nof_wb_streams*c_nof_complex+S*c_nof_complex+1));
      end generate;
    end generate; 
    
    -- Wire fil_out_arr --> fft_in_re_arr, fft_in_im_arr
    wire_fft_in_streams: for S in 0 to g_wpfb.nof_wb_streams-1 generate
      wire_fft_in_wideband: for P in 0 to g_wpfb.wb_factor-1 generate
        fft_in_re_arr(S*g_wpfb.wb_factor + P) <= fil_out_arr(P*g_wpfb.nof_wb_streams*c_nof_complex+S*c_nof_complex);
        fft_in_im_arr(S*g_wpfb.wb_factor + P) <= fil_out_arr(P*g_wpfb.nof_wb_streams*c_nof_complex+S*c_nof_complex+1);
      end generate;
    end generate;

    ---------------------------------------------------------------
    -- THE POLY PHASE FILTER
    ---------------------------------------------------------------
    gen_prefilter : IF g_use_prefilter = TRUE generate
      u_filter : entity astron_filter_lib.fil_ppf_wide
      generic map (
        g_big_endian_wb_in  => g_big_endian_wb_in,
        g_big_endian_wb_out => false,  -- reverse wideband order from big-endian [3:0] = [t0,t1,t2,t3] in fil_ppf_wide to little-endian [3:0] = [t3,t2,t1,t0] in fft_r2_wide
        g_fil_ppf           => c_fil_ppf,
        g_fil_ppf_pipeline  => g_wpfb.fil_pipeline,
        g_coefs_file_prefix => g_coefs_file_prefix
      )
      port map (
        dp_clk         => dp_clk,
        dp_rst         => dp_rst,
        mm_clk         => mm_clk,
        mm_rst         => mm_rst,
        ram_coefs_mosi => ram_fil_coefs_mosi,
        ram_coefs_miso => ram_fil_coefs_miso,
        in_dat_arr     => fil_in_arr,
        in_val         => fil_in_val,
        out_dat_arr    => fil_out_arr,
        out_val        => fil_out_val
      );
    end generate;

    -- Bypass filter
    no_prefilter : if g_use_prefilter = FALSE generate
      fil_out_arr <= fil_in_arr;
      fil_out_val <= fil_in_val;
    end generate;

    fft_in_val <= fil_out_val;

    ---------------------------------------------------------------
    -- THE WIDEBAND FFT
    ---------------------------------------------------------------
    gen_wideband_fft: if g_wpfb.wb_factor > 1  generate
      gen_fft_r2_wide_streams: for S in 0 to g_wpfb.nof_wb_streams-1 generate
        u_fft_r2_wide : entity astron_wb_fft_lib.fft_r2_wide
        generic map(
          g_fft          => c_fft,         -- generics for the WFFT
          g_pft_pipeline => g_wpfb.pft_pipeline,
          g_fft_pipeline => g_wpfb.fft_pipeline
        )
        port map(
          clk        => dp_clk,
          rst        => dp_rst,
          in_re_arr  => fft_in_re_arr((S+1)*g_wpfb.wb_factor-1 downto S*g_wpfb.wb_factor),
          in_im_arr  => fft_in_im_arr((S+1)*g_wpfb.wb_factor-1 downto S*g_wpfb.wb_factor),
          in_val     => fft_in_val,
          out_re_arr => fft_out_re_arr((S+1)*g_wpfb.wb_factor-1 downto S*g_wpfb.wb_factor),
          out_im_arr => fft_out_im_arr((S+1)*g_wpfb.wb_factor-1 downto S*g_wpfb.wb_factor),
          out_val    => fft_out_val_arr(S)
        );
      end generate;
    end generate;

    ---------------------------------------------------------------
    -- THE PIPELINED FFT
    ---------------------------------------------------------------
    gen_pipeline_fft: if g_wpfb.wb_factor = 1  generate
      gen_fft_r2_pipe_streams: for S in 0 to g_wpfb.nof_wb_streams-1 generate
        u_fft_r2_pipe : entity astron_wb_fft_lib.fft_r2_pipe
        generic map(
          g_fft      => c_fft,
          g_dont_flip_channels => g_dont_flip_channels,
          g_pipeline => g_wpfb.fft_pipeline
        )
        port map(
          clk       => dp_clk,
          rst       => dp_rst,
          in_re     => fft_in_re_arr(S)(c_fft.in_dat_w-1 downto 0),
          in_im     => fft_in_im_arr(S)(c_fft.in_dat_w-1 downto 0),
          in_val    => fft_in_val,
          out_re    => fft_out_re_arr_i(S)(c_fft.out_dat_w-1 downto 0),
          out_im    => fft_out_im_arr_i(S)(c_fft.out_dat_w-1 downto 0),
          out_val   => fft_out_val_arr(S)
        );
        
        fft_out_re_arr(S) <= RESIZE_SVEC_32(fft_out_re_arr_i(S)(c_fft.out_dat_w-1 downto 0));
        fft_out_im_arr(S) <= RESIZE_SVEC_32(fft_out_im_arr_i(S)(c_fft.out_dat_w-1 downto 0));
      end generate;
    end generate;

    ---------------------------------------------------------------
    -- FFT CONTROL UNIT
    ---------------------------------------------------------------
    
    -- Capture input BSN at input sync and pass the captured input BSN it on to PFB output sync.
    -- The FFT output valid defines PFB output sync, sop, eop.

    fft_out_sosi.sync  <= r.in_sosi_arr(0).sync;  
    fft_out_sosi.bsn   <= r.in_sosi_arr(0).bsn;   
    fft_out_sosi.valid <= fft_out_val_arr(0);     
    
    wire_fft_out_sosi_arr : for I in 0 to g_wpfb.nof_wb_streams*g_wpfb.wb_factor-1 generate
      fft_out_sosi_arr(I).re    <= RESIZE_DP_DSP_DATA(fft_out_re_arr(I));
      fft_out_sosi_arr(I).im    <= RESIZE_DP_DSP_DATA(fft_out_im_arr(I));
      fft_out_sosi_arr(I).valid <=                    fft_out_val_arr(I);
    end generate;
    
    u_dp_block_gen_valid_arr : ENTITY work.dp_block_gen_valid_arr
    GENERIC MAP (
      g_nof_streams         => g_wpfb.nof_wb_streams*g_wpfb.wb_factor,
      g_nof_data_per_block  => c_nof_valid_per_block,
      g_nof_blk_per_sync    => g_wpfb.nof_blk_per_sync,
      g_check_input_sync    => false,
      g_nof_pages_bsn       => 1,
      g_restore_global_bsn  => true
    )
    PORT MAP (
      rst         => dp_rst,
      clk         => dp_clk,
      -- Streaming sink
      snk_in      => fft_out_sosi,
      snk_in_arr  => fft_out_sosi_arr,
      -- Streaming source
      src_out_arr => pfb_out_sosi_arr,
      -- Control
      enable      => '1'
    );
  end generate;

  ----------------------------------------------------------------------------
  -- Source: block generator
  ----------------------------------------------------------------------------
  gen_bg : if g_use_bg = TRUE generate
    u_bg : entity astron_diagnostics_lib.mms_diag_block_gen
    generic map(
      g_nof_streams      => g_wpfb.nof_wb_streams*g_wpfb.wb_factor,
      g_buf_dat_w        => c_nof_complex*g_wpfb.fft_out_dat_w,
      g_buf_addr_w       => c_bg_buf_adr_w,               -- Waveform buffer size 2**g_buf_addr_w nof samples
      g_file_index_arr   => c_bg_data_file_index_arr,
      g_file_name_prefix => c_bg_data_file_prefix
    )
    port map(
      -- System
      mm_rst           => mm_rst,
      mm_clk           => mm_clk,
      dp_rst           => dp_rst,
      dp_clk           => dp_clk,
      en_sync          => '0',
      -- MM interface
      reg_bg_ctrl_mosi => reg_bg_ctrl_mosi,
      reg_bg_ctrl_miso => reg_bg_ctrl_miso,
      ram_bg_data_mosi => ram_bg_data_mosi,
      ram_bg_data_miso => ram_bg_data_miso,
      -- ST interface
      out_sosi_arr     => pfb_out_sosi_arr
    );
  end generate;

 ---------------------------------------------------------------
  -- SUBBAND STATISTICS
  ---------------------------------------------------------------
  -- For all "wb_factor"x"nof_wb_streams" output streams of the
  -- wideband FFT a subband statistics unit is placed if the
  -- g_stats_ena is TRUE.
  -- Since the subband statistics module uses embedded DSP blocks
  -- for multiplication, the incoming data cannot be wider
  -- than 18 bit.
  gen_stats : if g_stats_ena = TRUE generate
    gen_stats_streams: for S in 0 to g_wpfb.nof_wb_streams-1 generate
      gen_stats_wideband: for P in 0 to g_wpfb.wb_factor-1 generate
        u_subband_stats : entity astron_statistics_lib.st_sst
        generic map(
          g_nof_stat      => c_nof_stats,
          g_in_data_w     => g_wpfb.fft_out_dat_w,
          g_stat_data_w   => g_wpfb.stat_data_w,
          g_stat_data_sz  => g_wpfb.stat_data_sz
        )
        port map (
          mm_rst          => mm_rst,
          mm_clk          => mm_clk,
          dp_rst          => dp_rst,
          dp_clk          => dp_clk,
          in_complex      => pfb_out_sosi_arr(S*g_wpfb.wb_factor+P),
          ram_st_sst_mosi => ram_st_sst_mosi_arr(S*g_wpfb.wb_factor+P),
          ram_st_sst_miso => ram_st_sst_miso_arr(S*g_wpfb.wb_factor+P)
        );
      end generate;
    end generate;
  end generate;

  -- Connect to the outside world
  out_sosi_arr <= pfb_out_sosi_arr;

end str;



