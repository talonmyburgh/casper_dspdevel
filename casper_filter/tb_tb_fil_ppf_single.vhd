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

-- Purpose: Multi-testbench for fil_ppf_single
-- Description:
--   Verify fil_ppf_single
-- Usage:
--   > as 4
--   > run -all

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.all;
USE work.fil_pkg.all;

ENTITY tb_tb_fil_ppf_single IS
END tb_tb_fil_ppf_single;

ARCHITECTURE tb OF tb_tb_fil_ppf_single IS
  
  CONSTANT c_fil_ppf_pipeline : t_fil_ppf_pipeline := (1, 1, 1, 1, 1, 1, 0);
  CONSTANT c_prefix           : string  := c_coefs_file;
  
  SIGNAL tb_end : STD_LOGIC := '0';  -- declare tb_end to avoid 'No objects found' error on 'when -label tb_end'
  
BEGIN

--g_fil_ppf_pipeline : t_fil_ppf_pipeline := (1, 1, 1, 1, 1, 1, 0);
--  -- type t_fil_pipeline is record
--  --   -- generic for the taps and coefficients memory
--  --   mem_delay      : natural;  -- = 2
--  --   -- generics for the multiplier in in the filter unit
--  --   mult_input     : natural;  -- = 1
--  --   mult_product   : natural;  -- = 1
--  --   mult_output    : natural;  -- = 1
--  --   -- generics for the adder tree in in the filter unit
--  --   adder_stage    : natural;  -- = 1
--  --   -- generics for the requantizer in the filter unit
--  --   requant_remove_lsb : natural;  -- = 1
--  --   requant_remove_msb : natural;  -- = 0
--  -- end record;
--g_fil_ppf : t_fil_ppf := (1, 1, 64, 8, 1, 8, 20, 16);
--  -- type t_fil_ppf is record
--  --   wb_factor      : natural; -- = 1, the wideband factor
--  --   nof_chan       : natural; -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan
--  --   nof_bands      : natural; -- = 128, the number of polyphase channels (= number of points of the FFT)
--  --   nof_taps       : natural; -- = 16, the number of FIR taps per subband
--  --   nof_streams    : natural; -- = 1, the number of streams that are served by the same coefficients.
--  --   backoff_w      : natural; -- = 0, number of bits for input backoff to avoid output overflow
--  --   in_dat_w       : natural; -- = 8, number of input bits per stream
--  --   out_dat_w      : natural; -- = 23, number of output bits (per stream). It is set to in_dat_w+coef_dat_w-1 = 23 to be sure the requantizer
--  --                                  does not remove any of the data in order to be able to verify with the original coefficients values.
--  --   coef_dat_w     : natural; -- = 16, data width of the FIR coefficients
--  -- end record;
--g_coefs_file_prefix  : string  := "hex/run_pfir_coeff_m_incrementing";
--g_enable_in_val_gaps : boolean := FALSE

  u_act           : ENTITY work.tb_fil_ppf_single GENERIC MAP ((1, 1, 1, 1, 1, 1, 0), (1, 0, 64, 8, 1, 0, 8, 23, 16), c_prefix, FALSE);
  u_rnd_quant     : ENTITY work.tb_fil_ppf_single GENERIC MAP ((1, 1, 1, 1, 1, 1, 0), (1, 0, 64, 8, 1, 0, 8, 16, 16), c_prefix, TRUE);
  u_rnd_9taps     : ENTITY work.tb_fil_ppf_single GENERIC MAP ((1, 1, 1, 1, 1, 1, 0), (1, 0, 64, 9, 1, 0, 8, 17, 16), c_prefix, TRUE);
  u_rnd_3streams  : ENTITY work.tb_fil_ppf_single GENERIC MAP ((1, 1, 1, 1, 1, 1, 0), (1, 0, 64, 9, 3, 0, 8, 18, 16), c_prefix, TRUE);
  u_rnd_4channels : ENTITY work.tb_fil_ppf_single GENERIC MAP ((1, 1, 1, 1, 1, 1, 0), (1, 2, 64, 9, 3, 0, 8, 22, 16), c_prefix, TRUE);
  
END tb;
