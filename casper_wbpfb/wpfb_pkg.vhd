-------------------------------------------------------------------------------
-- Author: Harm Jan Pepping : pepping at astron.nl: 2012
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
-------------------------------------------------------------------------------

library ieee, common_pkg_lib, astron_r2sdf_fft_lib, astron_wb_fft_lib, astron_filter_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use astron_r2sdf_fft_lib.rTwoSDFPkg.all;
use astron_wb_fft_lib.fft_pkg.all; 
use astron_filter_lib.fil_pkg.all; 

package wpfb_pkg is

  -- Parameters for the (wideband) poly phase filter. 
  type t_wpfb is record  
    -- General parameters for the wideband poly phase filter
    wb_factor         : natural;        -- = default 4, wideband factor
    nof_points        : natural;        -- = 1024, N point FFT (Also the number of subbands for the filter part)
    nof_chan          : natural;        -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan     
    nof_wb_streams    : natural;        -- = 1, the number of parallel wideband streams. The filter coefficients are shared on every wb-stream.
    
    -- Parameters for the poly phase filter
    nof_taps          : natural;        -- = 16, the number of FIR taps per subband
    fil_backoff_w     : natural;        -- = 0, number of bits for input backoff to avoid output overflow
    fil_in_dat_w      : natural;        -- = 8, number of input bits
    fil_out_dat_w     : natural;        -- = 16, number of output bits
    coef_dat_w        : natural;        -- = 16, data width of the FIR coefficients
                                      
    -- Parameters for the FFT         
    use_reorder       : boolean;        -- = false for bit-reversed output, true for normal output
    use_fft_shift     : boolean;        -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
    use_separate      : boolean;        -- = false for complex input, true for two real inputs
    fft_in_dat_w      : natural;        -- = 16, number of input bits
    fft_out_dat_w     : natural;        -- = 16, number of output bits >= (fil_in_dat_w=8) + log2(nof_points=1024)/2 = 13
    fft_out_gain_w    : natural;        -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
    stage_dat_w       : natural;        -- = 18, number of bits that are used inter-stage
    guard_w           : natural;  -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. 
                                  --   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section
                                  --   12.3.2], therefore use input guard_w = 2.
    guard_enable      : boolean;  -- = true when input needs guarding, false when input requires no guarding but scaling must be
                                  --   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section
                                  --   doing the input guard and par fft section doing the output compensation)
    
    -- Parameters for the statistics
    stat_data_w       : positive;       -- = 56
    stat_data_sz      : positive;       -- = 2
    nof_blk_per_sync  : natural;        -- = 800000, number of FFT output blocks per sync interval, used to pass on BSN

    -- Pipeline parameters for both poly phase filter and FFT. These are heritaged from the filter and fft libraries.  
    pft_pipeline      : t_fft_pipeline;     -- Pipeline settings for the pipelined FFT
    fft_pipeline      : t_fft_pipeline;     -- Pipeline settings for the parallel FFT
    fil_pipeline      : t_fil_ppf_pipeline; -- Pipeline settings for the filter units 
    
  end record;
  
  -----------------------------------------------------------------------------
  -- Apertif application specfic settings
  -----------------------------------------------------------------------------
  
  -- For reference Fsub, actual setting is done in the apertif_unb1_bn_filterbank design:
  -- * wb_factor        = 4      : wideband factor
  --   nof_points       = 1024   : N point FFT
  --   nof_chan         = 0      : nof channels = 2**nof_chan = 1
  --   nof_wb_streams   = 1      : 1 two real wb stream per WPFB, because the subband filterbank uses 2 independent instances of WPFB 
  -- * nof_taps         = 16     : number of FIR taps in the subband filterbank
  --   fil_backoff_w    = 1      : backoff input to fit temporary PFIR output overshoot that can occur even though DC gain is 1
  --   fil_in_dat_w     = 8      : ADC data width
  --   fil_out_dat_w    = 16     : = fft_in_dat_w
  --   coef_dat_w       = 16     : width of the subband FIR coefficients
  -- * use_reorder      = true   : must be true  for two real input FFT
  --   use_fft_shift    = false  : must be false for two real input FFT
  --   use_separate     = true   : must be true  for two real input FFT
  --   fft_in_dat_w     = 16     : = c_dsp_mult_w-guard_w = 18-2
  --   fft_out_dat_w    = 16     : subband data width in the transpose transport and at the BF input
  --   fft_out_gain_w   = 1      : compensate for divide by 2 in separate function for two real input FFT
  --   stage_dat_w      = 18     : = c_dsp_mult_w, number of bits that are used inter-stage
  --   guard_w          = 2      : must be 2 to avoid overflow in first FFT stage
  --   guard_enable     = true   : must be true to enable input guard_w
  -- * stat_data_w      = 56     : could be 52 = 2*16+1 - 1 + ceil_log2(781250)
  --                               . 2*fft_out_dat_w for product
  --                               . +1 for complex product
  --                               . -1 to skip double sign
  --                               . +ceil_log2(Nint) for accumlation bit growth
  --   stat_data_sz     = 2      : must be 2 to fit stat_data_w in two 32 bit words
  --   nof_blk_per_sync = 800000 : number of FFT output blocks per sync interval

  -- Fsub settings:
  -- . fil_backoff_w = 1 instead of 0 to avoid the overflow that occurs for WG with --ampl >= 119 and e.g. --sub 65, --chan 4,
  --   see svn -r 18800 log of node_apertif_unb1_bn_filterbank
  -- . fft_out_dat_w = 16 by internal dp_requantize will not overflow, so no need to use external dp_requantize with clipping
  -- . fft_out_gain_w = 1 instead of 0 to compensate for 1/2 in separate.
  constant c_wpfb_apertif_subbands : t_wpfb := (4, 1024, 0, 1,
                                                16, 1, 8, 16, 16,
                                                true, false, true, 16, 16, 1, c_dsp_mult_w, 2, true, 56, 2, 800000,
                                                c_fft_pipeline, c_fft_pipeline, c_fil_ppf_pipeline);
                                   
  -- For reference Fchan_x, actual setting is done in the apertif_unb1_correlator design:
  -- * wb_factor        = 1      : wideband factor
  --   nof_points       = 64     : N point FFT
  --   nof_chan         = 1      : nof channels = 2**nof_chan = 2 multiplex streams
  --   nof_wb_streams   = 12     : 12 complex streams per WPFB, that all share the FIR coefficients
  -- * nof_taps         = 8      : number of FIR taps in the channel filterbank
  --   fil_backoff_w    = 0      : backoff input to fit temporary PFIR output overshoot can occur even though DC gain is 1
  --   fil_in_dat_w     = 8      : keep at 8, also when Apertif BF outputs 6 bit beamlet data, because that is sign extended to 8b
  --   fil_out_dat_w    = 16     : = fft_in_dat_w
  --   coef_dat_w       = 9      : width of the channel FIR coefficients
  -- * use_reorder      = false  : use true to have [0, pos, neg] frequency bin order for complex input FFT
  --   use_fft_shift    = false  : use false to keep [0, pos, neg] frequency bin order
  --   use_separate     = false  : must be false for complex input FFT
  --   fft_in_dat_w     = 16     : = c_dsp_mult_w-guard_w = 18-2
  --   fft_out_dat_w    = 9      : to fit correlator input width
  --   fft_out_gain_w   = 0      : keep at 0 for complex input input FFT
  --   stage_dat_w      = 18     : = c_dsp_mult_w, number of bits that are used inter-stage
  --   guard_w          = 2      : must be 2 to avoid overflow in first FFT stage
  --   guard_enable     = true   : must be true to enable input guard_w
  -- * stat_data_w      = 56     : could be 32 = 2*9+1 - 1 + ceil_log2(781250/64):
  --                               . 2*fft_out_dat_w for product
  --                               . +1 for complex product
  --                               . -1 to skip double sign
  --                               . +ceil_log2(Nint) for accumlation bit growth
  --   stat_data_sz     = 2      : keep two 32b-word, even if stat_data_w could fit in one 32b-word
  --   nof_blk_per_sync = 12500  : = 800000/64, number of FFT output blocks per sync interval

  -- Fchan_x settings in node_apertif_unb1_correlator_processing.vhd:
  -- . fil_backoff_w = 0, because for the Fchan there appears no PFIR output overshoot in practise using WG data
  -- . use_reorder = false and use_fft_shift = false, because channel index bit flip and FFT shift are done in
  --   apertif_unb1_correlator_vis_offload
  -- . fft_out_dat_w = 18, because in there is a separate dp_requantize to get from 18b --> 9b in
  --   node_apertif_unb1_correlator_processing, this dp_requantize uses symmertical clipping.
  CONSTANT c_wpfb_apertif_channels : t_wpfb := (1, 64, 1, 12,
                                                8, 0, 8, 16, 9,
                                                false, false, false, 16, 18, 0, c_dsp_mult_w, 2, true, 56, 2, 12500,
                                                c_fft_pipeline, c_fft_pipeline, c_fil_ppf_pipeline);
                                                
  -- Fchan_sc3 settings:
  -- . Arts SC3 uses the Fchan fine channels from Apertif X. Therefore to allow commensal Arts SC3 the Apertif X
  --   will have to use use_reorder = true and use_fft_shift = true.
  -- . Arts SC4 at half Stokes rate, so with nof_blk_per_sync = 12500 and nof_points = 64, has same rate as
  --   Arts SC3. At full rate Arts SC4 would have nof_blk_per_sync = 25000 and nof_points = 32.
  -- . fft_out_dat_w = 9, because Arts SC3 uses the fine channels from Apertif X.
  constant c_wpfb_arts_channels_sc3 : t_wpfb := (1, 64, 1, 12,
                                                 8, 0, 8, 16, 9,
                                                 true, true, false, 16, 9, 0, c_dsp_mult_w, 2, true, 56, 2, 12500,
                                                 c_fft_pipeline, c_fft_pipeline, c_fil_ppf_pipeline);

  -- Fchan_sc4 settings in arts_unb1_sc4_processing.vhd svn -r 19337:
  -- . fft_out_dat_w = 9 for Arts SC3, but can be 12 to preserve more LSbit for SC4. However this is not necessary,
  --   because the 9b are already sufficient to maintain sensitivity
  -- . fft_out_gain_w = 2 to fit 2 more LSbits which is possible because fft_out_dat_w = 12. However if
  --   fft_out_dat_w = 9, then fft_out_gain_w must be 0 to avoid output overflow. Instead the factor 2**2
  --   then needs to be accommodated at the input of the subsequent IQUV, IAB or TAB processing.
  -- . Using fft_out_dat_w = 12 instead of 9 and fft_out_gain_w = 2 instead of 0 created 12 - 9 - 2 = 1 bit more
  --   dynamic range. Therefore it may not be necessary to use fine channel symmetrical clipping using an external
  --   dp_requantize, like in Apertif X.
  CONSTANT c_wpfb_arts_channels_sc4 : t_wpfb  := (1, 64, 1, 12,
                                                  8, 0, 8, 16, 9,
                                                  true, true, false, 16, 12, 2, c_dsp_mult_w, 2, true, 56, 2, 12500,
                                                  c_fft_pipeline, c_fft_pipeline, c_fil_ppf_pipeline);

  -- Conclusion:
  -- . To support fine channel offload to Arts SC3 the Apertif X settings will have to use use_reorder = true
  --   and use_fft_shift = true
  -- . It seems fine to keep the Arts SC4 settings fft_out_dat_w = 12 and fft_out_gain_w = 2 and no fine channel
  --   clipping.
  -- . Arts SC3 will use the same settings as Apertif X so fft_out_dat_w = 9 and fft_out_gain_w = 0 and fine 
  --   channel clipping. The input of the subsequent IQUV, IAB or TAB processing in arts_unb2b_sc3 may need to
  --   be shifted by fft_out_gain_w compared to how it is connected in Arts SC4.
  
  -- Estimate maximum number of blocks of latency between WPFB input and output
  function func_wpfb_maximum_sop_latency(wpfb : t_wpfb) return natural;
  function func_wpfb_set_nof_block_per_sync(wpfb : t_wpfb; nof_block_per_sync : NATURAL) return t_wpfb;

end package wpfb_pkg;

package body wpfb_pkg is

  function func_wpfb_maximum_sop_latency(wpfb : t_wpfb) return natural is
    constant c_nof_channels : natural := 2**wpfb.nof_chan;
    constant c_block_size   : natural := c_nof_channels * wpfb.nof_points / wpfb.wb_factor;
    constant c_block_dly    : natural := 10;
  begin
    -- The prefilter, pipelined FFT, pipelined reorder and the wideband separate reorder
    -- cause block latency.
    -- The parallel FFT has no block latency.
    -- The parallel FFT reorder is merely a rewiring and causes no latency.
    -- ==> This yields maximim 4 block latency
    -- ==> Add one extra block latency to round up
    -- Each block in the Wideband FFT also introduces about c_block_dly clock cycles of
    -- pipeline latency.
    -- ==> This yields maximum ( 5 * c_block_dly ) / c_block_size of block latency
    return 4 + 1 + (5 * c_block_dly) / c_block_size;
  end func_wpfb_maximum_sop_latency;
  
  -- Overwrite nof_block_per_sync field in wpfb (typically for faster simulation)
  function func_wpfb_set_nof_block_per_sync(wpfb : t_wpfb; nof_block_per_sync : NATURAL) return t_wpfb is
    variable v_wpfb : t_wpfb;
  begin
    v_wpfb := wpfb;
    v_wpfb.nof_blk_per_sync := nof_block_per_sync;
    return v_wpfb;
  end func_wpfb_set_nof_block_per_sync;  
  
end wpfb_pkg;

