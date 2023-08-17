--------------------------------------------------------------------------------------------------------------
--Modification of the wpfb_unit_dev module by Talon Myburgh.
--This is the current PFB top module. It differs from the wbpfb_unit.vhd module by not using the 
--wideband_fft control module.
--------------------------------------------------------------------------------------------------------------
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

library ieee, common_pkg_lib, r2sdf_fft_lib, casper_filter_lib, wb_fft_lib, casper_diagnostics_lib, casper_ram_lib;
use IEEE.std_logic_1164.all;
use STD.textio.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;
use casper_filter_lib.all;
use casper_filter_lib.fil_pkg.all;
use wb_fft_lib.all;
use wb_fft_lib.fft_gnrcs_intrfcs_pkg.all;
use work.wbpfb_gnrcs_intrfcs_pkg.all;

entity wbpfb_unit_dev is
    generic(
        g_big_endian_wb_in   : boolean         := true;
        g_wpfb               : t_wpfb          := c_wpfb;
        g_dont_flip_channels : boolean         := false; -- True preserves channel interleaving for pipelined FFT
        g_use_prefilter      : boolean         := TRUE;
        g_coefs_file_prefix  : string          := c_coefs_file; -- File prefix for the coefficients files.
        g_alt_output         : boolean         := FALSE; -- Governs the ordering of the output samples. False = ArBrArBr;AiBiAiBi, True = AiArAiAr;BiBrBiBr
        g_fil_ram_primitive  : string          := "block";
        g_use_variant        : string          := "4DSP"; --! = "4DSP" or "3DSP" for 3 or 4 mult cmult.
        g_use_dsp            : string          := "yes"; --! = "yes" or "no"
        g_ovflw_behav        : string          := "WRAP"; --! = "WRAP" or "SATURATE" will default to WRAP if invalid option used
        g_round              : t_rounding_mode := ROUND; --! = ROUND, ROUNDINF or TRUNCATE - defaults to ROUND if not specified
        g_fft_ram_primitive  : string          := "block"; --! = "auto", "distributed", "block" or "ultra" for RAM architecture
        g_twid_file_stem     : string          := c_twid_file_stem --! file stem for the twiddle coefficients                  
    );
    port(
        rst          : in  std_logic                                                   := '0';
        clk          : in  std_logic                                                   := '0';
        ce           : in  std_logic                                                   := '1';
        shiftreg     : in  std_logic_vector(ceil_log2(g_wpfb.nof_points) - 1 DOWNTO 0) := (others => '1'); --! Shift register
        in_sosi_arr  : in  t_fil_sosi_arr_in(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
        fil_sosi_arr : out t_fil_sosi_arr_out(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
        ovflw        : out std_logic_vector(ceil_log2(g_wpfb.nof_points) - 1 DOWNTO 0); --! Ovflw register
        out_sosi_arr : out t_fft_sosi_arr_out(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0)
    );
end entity wbpfb_unit_dev;

architecture str of wbpfb_unit_dev is

    constant c_nof_channels : natural := 2 ** g_wpfb.nof_chan;

    constant c_nof_stages : natural := ceil_log2(g_wpfb.nof_points);

    constant c_nof_data_per_block  : natural := c_nof_channels * g_wpfb.nof_points;
    constant c_nof_valid_per_block : natural := c_nof_data_per_block / g_wpfb.wb_factor;

    constant c_fil_ppf : t_fil_ppf := (g_wpfb.wb_factor,
                                       g_wpfb.nof_chan,
                                       g_wpfb.nof_points,
                                       g_wpfb.nof_taps,
                                       c_nof_complex * g_wpfb.nof_wb_streams, -- Complex FFT always requires 2 filter streams: real and imaginary
                                       g_wpfb.fil_backoff_w,
                                       g_wpfb.fil_in_dat_w,
                                       g_wpfb.fil_out_dat_w,
                                       g_wpfb.coef_dat_w);

    constant c_fft : t_fft := (g_wpfb.use_reorder,
                               g_wpfb.use_fft_shift,
                               g_wpfb.use_separate,
                               g_wpfb.nof_chan,
                               g_wpfb.wb_factor,
                               g_wpfb.nof_points,
                               g_wpfb.fft_in_dat_w,
                               g_wpfb.fft_out_dat_w,
                               g_wpfb.fft_out_gain_w,
                               g_wpfb.stage_dat_w,
                               g_wpfb.twiddle_dat_w,
                               g_wpfb.max_addr_w,
                               g_wpfb.guard_w,
                               g_wpfb.guard_enable,
                               g_wpfb.stat_data_w,
                               g_wpfb.stat_data_sz,
                               g_wpfb.pipe_reo_in_place);
    -- Parameters for the (wideband) poly phase filter. 

    type t_ovflw_array is ARRAY (INTEGER RANGE <>) OF std_logic_vector(c_nof_stages - 1 DOWNTO 0);
    type t_ovflw_array_trans is ARRAY (INTEGER RANGE <>) OF std_logic_vector(g_wpfb.nof_wb_streams - 1 DOWNTO 0);

    signal ovflw_array : t_ovflw_array(g_wpfb.nof_wb_streams - 1 DOWNTO 0);
    signal trans_ovflw_array : t_ovflw_array_trans(c_nof_stages - 1 DOWNTO 0);

    signal fil_in_arr  : t_fil_slv_arr_in(c_nof_complex * g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
    signal fil_in_val  : std_logic                                                                                := '0';
    signal fil_out_arr : t_fil_slv_arr_out(c_nof_complex * g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0) := (others => (others => '0'));
    signal fil_out_val : std_logic                                                                                := '0';

    signal fft_in_re_arr : t_slv_44_arr(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
    signal fft_in_im_arr : t_slv_44_arr(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
    signal fft_in_val    : std_logic := '0';

    signal fft_out_re_arr  : t_slv_64_arr(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0); --(g_wpfb.fft_out_dat_w-1 downto 0);
    signal fft_out_im_arr  : t_slv_64_arr(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0); --(g_wpfb.fft_out_dat_w-1 downto 0);
    signal fft_out_val_arr : std_logic_vector(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0) := (others => '0');

    signal fft_out_sosi     : t_fft_sosi_out;
    signal fft_out_sosi_arr : t_fft_sosi_arr_out(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0) := (others => c_fft_sosi_rst_out);

    signal pfb_out_sosi_arr : t_fft_sosi_arr_out(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0) := (others => c_fft_sosi_rst_out);

    type reg_type is record
        in_sosi_arr : t_fil_sosi_arr_in(g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 downto 0);
    end record;

    signal r, rin : reg_type := (others => (others => c_fil_sosi_rst_in));

begin

    -- The complete input sosi arry is registered.
    comb : process(r, in_sosi_arr)
        variable v : reg_type;
    begin
        v             := r;
        v.in_sosi_arr := in_sosi_arr;
        rin           <= v;
    end process comb;

    regs : process(clk)
    begin
        if rising_edge(clk) then
            r <= rin;
        end if;
    end process;

    ---------------------------------------------------------------
    -- REWIRE THE DATA FOR WIDEBAND POLY PHASE FILTER
    ---------------------------------------------------------------

    -- Wire in_sosi_arr --> fil_in_arr
    wire_fil_in_wideband : for P in 0 to g_wpfb.wb_factor - 1 generate
        wire_fil_in_streams : for S in 0 to g_wpfb.nof_wb_streams - 1 generate
            fil_in_arr(P * g_wpfb.nof_wb_streams * c_nof_complex + S * c_nof_complex)     <= r.in_sosi_arr(S * g_wpfb.wb_factor + P).re(g_wpfb.fil_in_dat_w - 1 downto 0);
            fil_in_arr(P * g_wpfb.nof_wb_streams * c_nof_complex + S * c_nof_complex + 1) <= r.in_sosi_arr(S * g_wpfb.wb_factor + P).im(g_wpfb.fil_in_dat_w - 1 downto 0);
        end generate;
    end generate;
    fil_in_val <= r.in_sosi_arr(0).valid;

    -- Wire fil_out_arr --> fil_sosi_arr
    wire_fil_sosi_streams : for S in 0 to g_wpfb.nof_wb_streams - 1 generate
        wire_fil_sosi_wideband : for P in 0 to g_wpfb.wb_factor - 1 generate
            fil_sosi_arr(S * g_wpfb.wb_factor + P).valid <= fil_out_val;
            fil_sosi_arr(S * g_wpfb.wb_factor + P).re    <= fil_out_arr(P * g_wpfb.nof_wb_streams * c_nof_complex + S * c_nof_complex);
            fil_sosi_arr(S * g_wpfb.wb_factor + P).im    <= fil_out_arr(P * g_wpfb.nof_wb_streams * c_nof_complex + S * c_nof_complex + 1);
        end generate;
    end generate;

    -- Wire fil_out_arr --> fft_in_re_arr, fft_in_im_arr
    wire_fft_in_streams : for S in 0 to g_wpfb.nof_wb_streams - 1 generate
        wire_fft_in_wideband : for P in 0 to g_wpfb.wb_factor - 1 generate
            assert g_wpfb.fft_in_dat_w = g_wpfb.fil_out_dat_w report "wbpfb: Taking highest bits from filter because FFT is different size than Filter output, no rounding is implemented." severity warning;
            assert g_wpfb.fft_in_dat_w <= g_wpfb.fil_out_dat_w report "wbpfb: FFT input must be smaller or equal to FILter output" severity failure;
            fft_in_re_arr(S * g_wpfb.wb_factor + P) <= RESIZE_SVEC(fil_out_arr(P * g_wpfb.nof_wb_streams * c_nof_complex + S * c_nof_complex)(g_wpfb.fil_out_dat_w - 1 downto g_wpfb.fil_out_dat_w - g_wpfb.fft_in_dat_w), 44);
            fft_in_im_arr(S * g_wpfb.wb_factor + P) <= RESIZE_SVEC(fil_out_arr(P * g_wpfb.nof_wb_streams * c_nof_complex + S * c_nof_complex + 1)(g_wpfb.fil_out_dat_w - 1 downto g_wpfb.fil_out_dat_w - g_wpfb.fft_in_dat_w), 44);
        end generate;
    end generate;

    ---------------------------------------------------------------
    -- THE POLY PHASE FILTER
    ---------------------------------------------------------------
    gen_prefilter : IF g_use_prefilter generate
        u_filter : entity casper_filter_lib.fil_ppf_wide
            generic map(
                g_big_endian_wb_in  => g_big_endian_wb_in,
                g_big_endian_wb_out => false, -- reverse wideband order from big-endian [3:0] = [t0,t1,t2,t3] in fil_ppf_wide to little-endian [3:0] = [t3,t2,t1,t0] in fft_r2_wide
                g_fil_ppf           => c_fil_ppf,
                g_fil_ppf_pipeline  => g_wpfb.fil_pipeline,
                g_coefs_file_prefix => g_coefs_file_prefix,
                g_ram_primitive     => g_fil_ram_primitive
            )
            port map(
                clk         => clk,
                ce          => ce,
                rst         => rst,
                in_dat_arr  => fil_in_arr,
                in_val      => fil_in_val,
                out_dat_arr => fil_out_arr,
                out_val     => fil_out_val
            );
    end generate;

    -- Bypass filter
    no_prefilter : if g_use_prefilter = FALSE generate
        resize_fil_arr : for I in 0 TO c_nof_complex * g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 generate
            fil_out_arr(I) <= RESIZE_SVEC(fil_in_arr(I), g_wpfb.fil_out_dat_w);
        end generate;
        fil_out_val <= fil_in_val;
    end generate;

    fft_in_val <= fil_out_val;

    ---------------------------------------------------------------
    -- THE WIDEBAND FFT
    ---------------------------------------------------------------
    gen_wideband_fft : if g_wpfb.wb_factor > 1 generate
        gen_fft_r2_wide_streams : for S in 0 to g_wpfb.nof_wb_streams - 1 generate
            u_fft_r2_wide : entity wb_fft_lib.fft_r2_wide
                generic map(
                    g_fft            => c_fft, -- generics for the WFFT
                    g_pft_pipeline   => g_wpfb.pft_pipeline,
                    g_fft_pipeline   => g_wpfb.fft_pipeline,
                    g_alt_output     => g_alt_output,
                    g_use_variant    => g_use_variant,
                    g_use_dsp        => g_use_dsp,
                    g_ovflw_behav    => g_ovflw_behav,
                    g_round          => g_round,
                    g_ram_primitive  => g_fft_ram_primitive,
                    g_twid_file_stem => g_twid_file_stem
                )
                port map(
                    clken      => ce,
                    clk        => clk,
                    rst        => rst,
                    shiftreg   => shiftreg,
                    in_re_arr  => fft_in_re_arr((S + 1) * g_wpfb.wb_factor - 1 downto S * g_wpfb.wb_factor),
                    in_im_arr  => fft_in_im_arr((S + 1) * g_wpfb.wb_factor - 1 downto S * g_wpfb.wb_factor),
                    in_val     => fft_in_val,
                    out_re_arr => fft_out_re_arr((S + 1) * g_wpfb.wb_factor - 1 downto S * g_wpfb.wb_factor),
                    out_im_arr => fft_out_im_arr((S + 1) * g_wpfb.wb_factor - 1 downto S * g_wpfb.wb_factor),
                    ovflw      => ovflw_array(S)(c_nof_stages - 1 DOWNTO 0),
                    out_val    => fft_out_val_arr(S)
                );
        end generate;
    end generate;

    ---------------------------------------------------------------
    -- THE PIPELINED FFT
    ---------------------------------------------------------------
    gen_pipeline_fft : if g_wpfb.wb_factor = 1 generate
        gen_fft_r2_pipe_streams : for S in 0 to g_wpfb.nof_wb_streams - 1 generate
            signal temp_re : std_logic_vector(c_fft.out_dat_w - 1 downto 0);
            signal temp_im : std_logic_vector(c_fft.out_dat_w - 1 downto 0);

        begin
            u_fft_r2_pipe : entity wb_fft_lib.fft_r2_pipe
                generic map(
                    g_fft                => c_fft,
                    g_dont_flip_channels => g_dont_flip_channels,
                    g_pipeline           => g_wpfb.fft_pipeline,
                    g_use_variant        => g_use_variant,
                    g_use_dsp            => g_use_dsp,
                    g_ovflw_behav        => g_ovflw_behav,
                    g_round              => g_round,
                    g_ram_primitive      => g_fft_ram_primitive,
                    g_twid_file_stem     => g_twid_file_stem
                )
                port map(
                    clken    => ce,
                    clk      => clk,
                    rst      => rst,
                    shiftreg => shiftreg,
                    in_re    => fft_in_re_arr(S)(c_fft.in_dat_w - 1 downto 0),
                    in_im    => fft_in_im_arr(S)(c_fft.in_dat_w - 1 downto 0),
                    in_val   => fft_in_val,
                    out_re   => temp_re,
                    out_im   => temp_im,
                    ovflw    => ovflw_array(S)(c_nof_stages - 1 DOWNTO 0),
                    out_val  => fft_out_val_arr(S)
                );
            fft_out_re_arr(S) <= RESIZE_SVEC(temp_re, 64);
            fft_out_im_arr(S) <= RESIZE_SVEC(temp_im, 64);
        end generate;

    end generate;

    ---------------------------------------------------------------
    -- COLLAPSE OVERFLOW ARRAY
    ---------------------------------------------------------------
    gen_collapse_per_stage_ovflw_array : FOR I IN c_nof_stages - 1 DOWNTO 0 GENERATE
        gen_transpose_ovflw_array : FOR J IN g_wpfb.nof_wb_streams - 1 DOWNTO 0 GENERATE
            trans_ovflw_array(I)(J) <= ovflw_array(J)(I);
        END GENERATE;
        ovflw(I) <= sel_a_b(TO_UINT(trans_ovflw_array(I)) = 0, '0', '1');
    end generate;

    ---------------------------------------------------------------
    -- FFT CONTROL UNIT
    ---------------------------------------------------------------

    -- Capture input BSN at input sync and pass the captured input BSN it on to PFB output sync.
    -- The FFT output valid defines PFB output sync, sop, eop.

    fft_out_sosi.sync  <= r.in_sosi_arr(0).sync;
    fft_out_sosi.bsn   <= r.in_sosi_arr(0).bsn;
    fft_out_sosi.valid <= fft_out_val_arr(0);

    wire_fft_out_sosi_arr : for I in 0 to g_wpfb.nof_wb_streams * g_wpfb.wb_factor - 1 generate
        fft_out_sosi_arr(I).re    <= fft_out_re_arr(I)(c_fft.out_dat_w - 1 downto 0);
        fft_out_sosi_arr(I).im    <= fft_out_im_arr(I)(c_fft.out_dat_w - 1 downto 0);
        fft_out_sosi_arr(I).valid <= fft_out_val_arr(I);
    end generate;

    u_dp_block_gen_valid_arr : ENTITY work.dp_block_gen_valid_arr
        GENERIC MAP(
            g_nof_streams        => g_wpfb.nof_wb_streams * g_wpfb.wb_factor,
            g_nof_data_per_block => c_nof_valid_per_block,
            g_nof_blk_per_sync   => g_wpfb.nof_blk_per_sync,
            g_check_input_sync   => false,
            g_nof_pages_bsn      => 1,
            g_restore_global_bsn => true
        )
        PORT MAP(
            rst         => rst,
            clk         => clk,
            -- Streaming sink
            snk_in      => fft_out_sosi,
            snk_in_arr  => fft_out_sosi_arr,
            -- Streaming source
            src_out_arr => pfb_out_sosi_arr,
            -- Control
            enable      => '1'
        );

    -- Connect to the outside world
    out_sosi_arr <= pfb_out_sosi_arr;

end str;
