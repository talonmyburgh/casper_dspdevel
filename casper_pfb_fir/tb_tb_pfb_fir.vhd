--------------------------------------------------------------------------------
--
-- Copyright (C) 2016
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

-- Purpose: Multi-testbench for pfb_fir
-- Description:
--   Verify pfb_fir
-- Usage:
--   > as 4
--   > run -all

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.all;
USE work.pfb_fir_pkg.all;

ENTITY tb_tb_pfb_fir IS
END tb_tb_pfb_fir;

ARCHITECTURE tb OF tb_tb_pfb_fir IS
  
  SIGNAL tb_end : STD_LOGIC := '0';  -- declare tb_end to avoid 'No objects found' error on 'when -label tb_end'

  CONSTANT c_pfb_fir_pipeline         : t_pfb_fir_pipeline := (1, 1, 1, 1);

  CONSTANT c_fil_ppf_1_act            : t_pfb_fir := (1, 0, 64, 8, 1, c_pfb_fir_din_w, c_pfb_fir_dout_w, c_pfb_fir_coef_w, 0);
  CONSTANT c_fil_ppf_1_rnd_quant      : t_pfb_fir := (1, 0, 64, 8, 1, c_pfb_fir_din_w, c_pfb_fir_dout_w, c_pfb_fir_coef_w, 0);
  CONSTANT c_fil_ppf_1_rnd_3streams   : t_pfb_fir := (1, 0, 64, 8, 3, c_pfb_fir_din_w, c_pfb_fir_dout_w, c_pfb_fir_coef_w, 0);
  CONSTANT c_fil_ppf_1_rnd_4channels  : t_pfb_fir := (1, 2, 64, 8, 3, c_pfb_fir_din_w, c_pfb_fir_dout_w, c_pfb_fir_coef_w, 0);
  CONSTANT c_fil_ppf_4_act            : t_pfb_fir := (4, 0, 64, 8, 1, c_pfb_fir_din_w, c_pfb_fir_dout_w, c_pfb_fir_coef_w, 0);
  CONSTANT c_fil_ppf_4_act_be_le      : t_pfb_fir := (4, 0, 64, 8, 1, c_pfb_fir_din_w, c_pfb_fir_dout_w, c_pfb_fir_coef_w, 0);
  CONSTANT c_fil_ppf_4_act_le_le      : t_pfb_fir := (4, 0, 64, 8, 1, c_pfb_fir_din_w, c_pfb_fir_dout_w, c_pfb_fir_coef_w, 0);
  CONSTANT c_fil_ppf_4_rnd_quant      : t_pfb_fir := (4, 0, 64, 8, 1, c_pfb_fir_din_w, c_pfb_fir_dout_w, c_pfb_fir_coef_w, 0);
  CONSTANT c_fil_ppf_4_rnd_3streams   : t_pfb_fir := (4, 0, 64, 8, 3, c_pfb_fir_din_w, c_pfb_fir_dout_w, c_pfb_fir_coef_w, 0);
  CONSTANT c_fil_ppf_4_rnd_4channels  : t_pfb_fir := (4, 2, 64, 8, 3, c_pfb_fir_din_w, c_pfb_fir_dout_w, c_pfb_fir_coef_w, 0);

  -- Inputs
  CONSTANT c_hanning_1_act            : string := "../../../../../data/hex/run_pfir_coeff_m_incrementing_8taps_64points_16b";
  CONSTANT c_hanning_1_rnd_quant      : string := "../../../../../data/hex/run_pfir_coeff_m_incrementing_8taps_64points_16b";
  CONSTANT c_hanning_1_rnd_3streams   : string := "../../../../../data/hex/run_pfir_coeff_m_incrementing_8taps_64points_16b";
  CONSTANT c_hanning_1_rnd_4channels  : string := "../../../../../data/hex/run_pfir_coeff_m_incrementing_8taps_64points_16b";
  CONSTANT c_hanning_4_act            : string := "../../../../../data/hex/run_pfir_coeff_m_incrementing_8taps_64points_16b";
  CONSTANT c_hanning_4_act_be_le      : string := "../../../../../data/hex/run_pfir_coeff_m_incrementing_8taps_64points_16b";
  CONSTANT c_hanning_4_act_le_le      : string := "../../../../../data/hex/run_pfir_coeff_m_incrementing_8taps_64points_16b";
  CONSTANT c_hanning_4_rnd_quant      : string := "../../../../../data/hex/run_pfir_coeff_m_incrementing_8taps_64points_16b";

    
BEGIN

    --type t_pfb_fir is record
    --  wb_factor       : natural; -- = 1, the wideband factor
    --  n_chans         : natural; -- = 0, number of time multiplexed input signals
    --  n_bins          : natural; -- = 1024, the number of polyphase channels (= number of FFT bins)
    --  n_taps          : natural; -- = 16, the number of FIR taps per subband
    --  n_streams       : natural; -- = 1, the number of streams that are served by the same coefficients.
    --  din_w           : natural; -- = 8, number of input bits per stream
    --  dout_w          : natural; -- = 16, number of output bits per stream
    --  coef_w          : natural; -- = 16, data width of the FIR coefficients
    --  padding         : natural; -- = 0, input padding to prevent overrange
    --  mem_latency     : natural; -- = 2, latency through taps and coeff lookup
    --  mult_latency    : natural; -- = 3, multiplier latency
    --  add_latency     : natural; -- = 1, adder latency
    --  conv_latency    : natural; -- = 1, type conversion latency
    --end record;
    --g_coefs_file_prefix  : string  := "run_pfir_coeff_m_incrementing_8taps_64points_16b";
    --g_enable_in_val_gaps : boolean := FALSE

  -- verify fil_ppf_wide for wb_factor=1, so effectively same as using fil_ppf_single directly
  --u1_act         : ENTITY work.tb_pfb_fir GENERIC MAP (TRUE, TRUE, c_fil_ppf_1_act, c_pfb_fir_pipeline, c_hanning_1_act, FALSE);
  --u1_rnd_quant       : ENTITY work.tb_pfb_fir GENERIC MAP (TRUE, TRUE, c_fil_ppf_1_rnd_quant, c_pfb_fir_pipeline, c_hanning_1_rnd_quant, TRUE);
  --u1_rnd_3streams    : ENTITY work.tb_pfb_fir GENERIC MAP (TRUE, TRUE, c_fil_ppf_1_rnd_3streams, c_pfb_fir_pipeline, c_hanning_1_rnd_3streams, TRUE);
  --u1_rnd_4channels   : ENTITY work.tb_pfb_fir GENERIC MAP (TRUE, TRUE, c_fil_ppf_1_rnd_4channels, c_pfb_fir_pipeline, c_hanning_1_rnd_4channels, TRUE);
  
  -- verify fil_ppf_wide for wb_factor>1
  --u4_act            :  ENTITY work.tb_pfb_fir GENERIC MAP (TRUE,  TRUE, c_fil_ppf_4_act, c_pfb_fir_pipeline, c_hanning_4_act, TRUE);
  --u4_act_be_le       : ENTITY work.tb_pfb_fir GENERIC MAP ( TRUE, FALSE, c_fil_ppf_4_act_be_le, c_pfb_fir_pipeline, c_hanning_4_act_be_le, FALSE);
  --u4_act_le_le       : ENTITY work.tb_pfb_fir GENERIC MAP ( FALSE, FALSE, c_fil_ppf_4_act_le_le, c_pfb_fir_pipeline, c_hanning_4_act_le_le, FALSE);
  --u4_rnd_quant       : ENTITY work.tb_pfb_fir GENERIC MAP ( TRUE,  TRUE, c_fil_ppf_4_rnd_quant, c_pfb_fir_pipeline, c_hanning_4_rnd_quant, TRUE);
  --u4_rnd_3streams    : ENTITY work.tb_pfb_fir GENERIC MAP ( TRUE,  TRUE, c_fil_ppf_4_rnd_3streams, c_pfb_fir_pipeline,  c_hanning_1_rnd_3streams, TRUE);
  u4_rnd_4channels   : ENTITY work.tb_pfb_fir GENERIC MAP ( TRUE,  TRUE, c_fil_ppf_4_rnd_4channels, c_pfb_fir_pipeline, c_hanning_1_rnd_4channels, TRUE); 
  
END tb;