-- Author: Harm Jan Pepping : hajee at astron.nl   : April 2012
--         Eric Kooistra    : kooistra at astron.nl: july 2016
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

--
-- Purpose: Test bench for fil_ppf_single.vhd
--
--   The DUT fil_ppf_single.vhd has wb_factor = 1 fixed. For wb_factor > 1 use
--   the tb of fil_ppf_wide.vhd.
--
--   The testbench reads the filter coefficients from the reference dat file
--   and verifies that these are the same as the coeff in the corresponding
--   set of mif files (p_verify_ref_coeff_versus_mif_files) and as read via
--   MM from the coeff memories (p_verify_ref_coeff_versus_mm_ram).
--
--   The testbench inserts an pulse during the first nof_bands. The output is
--   verified by checking if the output values equal the filter coefficients
--   (p_verify_output). The coefficients appear in the order of the taps, but
--   in reversed order per tap.
--
--   The fil_ppf_filter in fil_ppf_single multiplies the in_dat by the filter
--   coefficients. The product has a double sign bit, whereby one sign bit is
--   dropped, because it only is needed to represent the positive result of
--   the product of the most negative in_dat and coeff, which does never occur
--   (because the most negative value is not used in the coefficients).
--   Therefore the product has width prod_w = in_dat_w + coef_dat_w - 1.
--   The fil_ppf_single assumes that the coefficients have DC gain = 1, so the
--   nof_taps and adder tree do not cause bit growth, thus sum_w = prod_w.
--   Therefore the maximum out_dat_w = sum_w. If out_dat_w is less, then the
--   sum_w - out_dat_w = lsb_w LSbits are rounded in fil_ppf_filter. This tb
--   compensates for the LSbits by scaling the input pulse such that the
--   out_dat still contains the exact coefficient values. Therefore in this tb
--   out_dat_w must be >= coef_dat_w (and then lsb_w <= in_dat_w-1).
--
--   The filter can operate on one or more streams in parallel. These streams
--   all share the same coefficient memory. The same pulse is applied to each
--   input stream in in_dat[nof_streams*in_dat_w-1:0] and verified for each
--   output stream in out_dat[nof_streams*out_dat_w-1:0] (p_verify_output).
--
--   Via g_enable_in_val_gaps it is possible toggle in_val in a random way to
--   verify that the DUT can handle arbitray gaps in in_dat.
--
--   It is possible to vary wb_factor, nof_chan, nof_bands, nof_taps, coef_w
--   and nof_streams. The input dat file is different for nof_taps, nof_bands
--   and coef_w. In addition the MIF files are different for wb_factor.
--   The nof_chan and nof_streams do not affect the input and output files,
--   because all multiplexed channels and pallellel streams use the same
--   filter coefficients.
--
--   The reference dat file is generated by the Matlab program:
--
--     $RADIOHDL_WORK/applications/apertif/matlab/run_pfir_coeff.m
--
--   The MIF files are generated by the Python script:
--
--     $RADIOHDL_WORK/libraries/dsp/filter/src/python/fil_ppf_create_mifs.py
--
--   The reference dat file and the MIF files use the same g_coefs_file_prefix.
--   For the reference dat file this prefix is expanded by nof_taps, nof_bands
--   and coef_dat_w and the MIF files in addition also have the wb_factor and
--   the MIF file index.
--
--   The example below shows how the mif file index relates to the reference
--   coefficients:
--
--   <g_coefs_file_prefix>_2taps_8bands_16b.dat
--   <g_coefs_file_prefix>_2taps_8bands_16b_4wb_0.mif
--   <g_coefs_file_prefix>_2taps_8bands_16b_4wb_1.mif
--   <g_coefs_file_prefix>_2taps_8bands_16b_4wb_2.mif
--   <g_coefs_file_prefix>_2taps_8bands_16b_4wb_3.mif
--   <g_coefs_file_prefix>_2taps_8bands_16b_4wb_4.mif
--   <g_coefs_file_prefix>_2taps_8bands_16b_4wb_5.mif
--   <g_coefs_file_prefix>_2taps_8bands_16b_4wb_6.mif
--   <g_coefs_file_prefix>_2taps_8bands_16b_4wb_7.mif
--
--                            nof_taps = 2
--                            nof_points = 8
--   pfir coef reference    : 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15
--   pfir coef flip per tap : 7  6  5  4  3  2  1  0 15 14 13 12 11 10  9  8
--
--                            
--   wb_factor = 1:           7  6  5  4  3  2  1  0 15 14 13 12 11 10  9  8
--
--                            time sample:
--                            t0 t1 t2 t3 t4 t5 t6 t7t8 t9 t10t11t12t13t14t15
--
--                            mif index:
--                            0                      1
--
--                  wb_index:
--   wb_factor = 4:        0: 7  3                   15 11
--                         1: 6  2                   14 10
--                         2: 5  1                   13  9
--                         3: 4  0                   12  8
--
--                            time sample:
--                         0: t0 t4                  t8  t12  MSpart
--                         1: t1 t5                  t9  t13
--                         2: t2 t6                  t10 t14
--                         3: t3 t7                  t11 t15  LSpart
--
--                            mif index:
--                         0: 0                      1     first count taps
--                         1: 2                      3     then count wb
--                         2: 4                      5
--                         3: 6                      7
--
-- Usage:
--   > run -all
--   > observe out_dat in analogue format in Wave window
--   > testbench is selftesting.
--
library ieee, std, common_pkg_lib, casper_ram_lib, technology_lib; -- casper_mm_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.ALL;
use common_pkg_lib.common_lfsr_sequences_pkg.ALL;
use common_pkg_lib.tb_common_pkg.all;
-- use casper_mm_lib.tb_common_mem_pkg.ALL;
use technology_lib.technology_select_pkg.ALL;
use work.fil_pkg.all;

entity tb_fil_ppf_single is
  generic(
    g_fil_ppf_pipeline : t_fil_ppf_pipeline := (1, 1, 1, 1, 1, 1, 0);
      -- type t_fil_pipeline is record
      --   -- generic for the taps and coefficients memory
      --   mem_delay      : natural;  -- = 2
      --   -- generics for the multiplier in in the filter unit
      --   mult_input     : natural;  -- = 1
      --   mult_product   : natural;  -- = 1
      --   mult_output    : natural;  -- = 1
      --   -- generics for the adder tree in in the filter unit
      --   adder_stage    : natural;  -- = 1
      --   -- generics for the requantizer in the filter unit
      --   requant_remove_lsb : natural;  -- = 1
      --   requant_remove_msb : natural;  -- = 0
      -- end record;
    g_fil_ppf : t_fil_ppf := (1, 1, 64, 8, 1, 0, 8, 16, 16);
      -- type t_fil_ppf is record
      --   wb_factor      : natural; -- = 1, the wideband factor
      --   nof_chan       : natural; -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan
      --   nof_bands      : natural; -- = 128, the number of polyphase channels (= number of points of the FFT)
      --   nof_taps       : natural; -- = 16, the number of FIR taps per subband
      --   nof_streams    : natural; -- = 1, the number of streams that are served by the same coefficients.
      --   backoff_w      : natural; -- = 0, number of bits for input backoff to avoid output overflow
      --   in_dat_w       : natural; -- = 8, number of input bits per stream
      --   out_dat_w      : natural; -- = 23, number of output bits (per stream). It is set to in_dat_w+coef_dat_w-1 = 23 to be sure the requantizer
      --                                  does not remove any of the data in order to be able to verify with the original coefficients values.
      --   coef_dat_w     : natural; -- = 16, data width of the FIR coefficients
      -- end record;
    g_coefs_file_prefix  : string  := "run_pfir_coeff_m_incrementing_8taps_64points_16b";
    g_enable_in_val_gaps : boolean := FALSE
  );
  PORT
  (
    o_rst       : out std_logic;
    o_clk       : out std_logic;
    o_tb_end    : out std_logic;
    o_test_msg  : out string(1 to 80);
    o_test_pass : out boolean
  );
end entity tb_fil_ppf_single;

architecture tb of tb_fil_ppf_single is

  constant c_clk_period          : time    := 10 ns;

  constant c_nof_channels           : natural := 2**g_fil_ppf.nof_chan;
  constant c_nof_coefs              : natural := g_fil_ppf.nof_taps * g_fil_ppf.nof_bands;       -- nof PFIR coef
  constant c_nof_data_in_filter     : natural := c_nof_coefs * c_nof_channels;                   -- nof PFIR coef expanded for all channels
  constant c_nof_data_per_tap       : natural := g_fil_ppf.nof_bands * c_nof_channels;
  constant c_nof_bands_per_file     : natural := g_fil_ppf.nof_bands;
  constant c_nof_memory_files       : natural := g_fil_ppf.nof_taps;
  constant c_file_coef_mem_addr_w   : natural := ceil_log2(g_fil_ppf.nof_bands);
  constant c_file_coef_mem_span     : natural := 2**c_file_coef_mem_addr_w;                       -- file coef mem span for one tap
  constant c_coefs_file_prefix      : string  := g_coefs_file_prefix;
  constant c_memory_file_prefix     : string  := c_coefs_file_prefix & "_" & "1wb";
  constant c_file_index_arr         : t_nat_natural_arr := array_init(0, c_nof_memory_files, 1);
  
  constant c_fil_prod_w          : natural := g_fil_ppf.in_dat_w + g_fil_ppf.coef_dat_w - 1;  -- skip double sign bit
  constant c_fil_sum_w           : natural := c_fil_prod_w;                                   -- DC gain = 1
  constant c_fil_lsb_w           : natural := c_fil_sum_w - g_fil_ppf.out_dat_w;              -- nof LSbits that get rounded for out_dat
  constant c_in_ampl             : natural := 2**c_fil_lsb_w;                                 -- scale in_dat to compensate for rounding

  constant c_gap_factor          : natural := sel_a_b(g_enable_in_val_gaps, 3, 1);
  
  -- input/output data width
  constant c_in_dat_w            : natural := g_fil_ppf.in_dat_w;
  constant c_out_dat_w           : natural := g_fil_ppf.out_dat_w;  -- must be >= coef_dat_w to be able to show the coeff in out_dat

  -- signal definitions
  signal tb_end         : std_logic := '0';
  signal tb_end_almost  : std_logic := '0';
  signal clk            : std_logic := '0';
  signal rst            : std_logic := '0';
  signal random         : std_logic_vector(15 DOWNTO 0) := (OTHERS=>'0');  -- use different lengths to have different random sequences

  -- signal ram_coefs_mosi : t_mem_mosi := c_mem_mosi_rst;
  -- signal ram_coefs_miso : t_mem_miso;

  signal in_dat         : std_logic_vector(g_fil_ppf.nof_streams*c_in_dat_w-1 downto 0);
  signal in_val         : std_logic;
  signal in_val_cnt     : natural := 0;
  signal in_gap         : std_logic := '0';

  signal out_dat        : std_logic_vector(g_fil_ppf.nof_streams*c_out_dat_w-1 downto 0);
  signal out_val        : std_logic;
  signal out_val_cnt    : natural := 0;

  signal memory_coefs_arr  : t_integer_arr(g_fil_ppf.nof_bands-1 downto 0) := (OTHERS=>0);   -- = PFIR coef for 1 tap as read from 1 MIF file
  signal file_dat_arr    : t_integer_arr(c_nof_data_in_filter-1 downto 0) := (OTHERS=>0);  -- = PFIR coef for all taps as read from all MIF files and expanded for all channels

  signal ref_coefs_arr  : t_integer_arr(c_nof_coefs-1 downto 0) := (OTHERS=>0);           -- = PFIR coef for all taps as read from the coefs file
  signal ref_dat_arr    : t_integer_arr(c_nof_data_in_filter-1 downto 0) := (OTHERS=>0);  -- = PFIR coef for all taps as read from the coefs file expanded for all channels
  signal ref_dat        : integer := 0;

  signal read_coefs_arr : t_integer_arr(c_nof_coefs-1 downto 0) := (OTHERS=>0);           -- = PFIR coef for all taps as read via MM from the coefs memories

begin

  clk <= (not clk) or tb_end after c_clk_period/2;
  rst <= '1', '0' after c_clk_period*7;
  random <= func_common_random(random) WHEN rising_edge(clk);
  in_gap <= random(random'HIGH) WHEN g_enable_in_val_gaps=TRUE ELSE '0';

  o_clk <= clk;
  o_rst <= rst;
  o_tb_end <= tb_end;

  ---------------------------------------------------------------
  -- SEND PULSE TO THE DATA INPUT
  ---------------------------------------------------------------
  p_send_impulse : PROCESS
  BEGIN
    tb_end <= '0';
    in_dat <= (OTHERS=>'0');
    in_val <= '0';
    proc_common_wait_until_low(clk, rst);         -- Wait until reset has finished
    proc_common_wait_some_cycles(clk, 10);        -- Wait an additional amount of cycles

    -- Pulse during first tap of all channels
    FOR I IN 0 TO c_nof_data_per_tap-1 LOOP
      FOR S IN 0 To g_fil_ppf.nof_streams-1 LOOP
        in_dat((S+1)*c_in_dat_w-1 DOWNTO S*c_in_dat_w) <= TO_UVEC(c_in_ampl, c_in_dat_w);
      END LOOP;
      in_val <= '1';
      proc_common_wait_some_cycles(clk, 1);
      IF in_gap='1' THEN
        in_val <= '0';
        proc_common_wait_some_cycles(clk, 1);
      END IF;
    END LOOP;

    -- Zero during next nof_taps-1 blocks, +1 more to account for block latency of PPF and +1 more to have zeros output in last block
    in_dat <= (OTHERS=>'0');
    FOR J IN 0 TO g_fil_ppf.nof_taps-2 +1 +1  LOOP
      FOR I IN 0 TO c_nof_data_per_tap-1 LOOP
        in_val <= '1';
        proc_common_wait_some_cycles(clk, 1);
        IF in_gap='1' THEN
          in_val <= '0';
          proc_common_wait_some_cycles(clk, 1);
        END IF;
      END LOOP;
    END LOOP;
    in_val <= '0';

    -- Wait until done
    proc_common_wait_some_cycles(clk, c_gap_factor*c_nof_data_per_tap);  -- PPF latency of 1 tap
    tb_end_almost <= '1';
    proc_common_wait_some_cycles(clk, 10);
    tb_end <= '1';
    WAIT;
  END PROCESS;

  ---------------------------------------------------------------
  -- CREATE REFERENCE ARRAY
  ---------------------------------------------------------------
  p_create_ref_from_coefs_file : PROCESS
    variable v_coefs_flip_arr : t_integer_arr(c_nof_coefs-1 downto 0) := (OTHERS=>0);
  begin
    -- Read all coeffs from coefs file
    proc_common_read_integer_file(c_coefs_file_prefix & ".dat", 0, c_nof_coefs, 1, ref_coefs_arr);
    wait for 1 ns;
    -- Reverse the coeffs per tap
    for J in 0 to g_fil_ppf.nof_taps-1 loop
      for I in 0 to g_fil_ppf.nof_bands-1 loop
        v_coefs_flip_arr(J*g_fil_ppf.nof_bands + g_fil_ppf.nof_bands-1-I) := ref_coefs_arr(J*g_fil_ppf.nof_bands+I);
      end loop;
    end loop;
    -- Expand the channels (for one stream)
    for I in 0 to c_nof_coefs-1 loop
      for K in 0 to c_nof_channels-1 loop
        ref_dat_arr(I*c_nof_channels + K) <= TO_SINT(TO_SVEC(v_coefs_flip_arr(I), g_fil_ppf.coef_dat_w));
      end loop;
    end loop;
    wait;
  end process;

  p_create_ref_from_memory_file : PROCESS
  begin
    for J in 0 to g_fil_ppf.nof_taps-1 loop
      -- Read coeffs per tap from MEMORY file
      if c_tech_select_default = c_tech_stratixiv or c_tech_select_default=c_tech_agilex  then
        proc_common_read_mif_file(c_memory_file_prefix & "_" & integer'image(J) & ".mif", memory_coefs_arr);
      elsif (c_tech_select_default = c_tech_xpm or c_tech_select_default=c_tech_versal) then
        proc_common_read_mem_file(c_memory_file_prefix & "_" & integer'image(J) & ".mem", memory_coefs_arr);
      end if;
      wait for 1 ns;
      -- Expand the channels (for one stream)
      for I in 0 to g_fil_ppf.nof_bands-1 loop
        for K in 0 to c_nof_channels-1 loop
          file_dat_arr(J*c_nof_data_per_tap + I*c_nof_channels + K) <= TO_SINT(TO_SVEC(memory_coefs_arr(I), g_fil_ppf.coef_dat_w));
        end loop;
      end loop;
    end loop;
    wait;
  end process;

--   p_coefs_memory_read : process
--     variable v_mif_base    : natural;
--     variable v_coef_offset : natural;
--     variable v_coef_index  : natural;
--   begin
--     ram_coefs_mosi <= c_mem_mosi_rst;
--     for J in 0 to g_fil_ppf.nof_taps-1 loop
--       v_mif_base  := J*c_mif_coef_mem_span;
--       v_coef_offset := g_fil_ppf.nof_bands*(J+1)-1;
--       for I in 0 to c_nof_bands_per_mif-1 loop
-- --        proc_mem_mm_bus_rd(v_mif_base+I, clk, ram_coefs_miso, ram_coefs_mosi);
-- --        proc_mem_mm_bus_rd_latency(1, clk);
--         v_coef_index := v_coef_offset - I;
--         read_coefs_arr(v_coef_index) <= TO_SINT(ram_coefs_miso.rddata(g_fil_ppf.coef_dat_w-1 DOWNTO 0));
--       end loop;
--     end loop;
--     proc_common_wait_some_cycles(clk, 1);
--     tb_end_mm <= '1';
--     wait;
--   end process;

  p_verify_ref_coeff_versus_coef_files : PROCESS
  begin
    -- Wait until the coeff dat file and coeff MIF files have been read
    proc_common_wait_until_low(clk, rst);
    assert file_dat_arr = ref_dat_arr   report "Coefs file does not match coefs memory files"   severity failure;
    wait;
  end process;

  -- p_verify_ref_coeff_versus_mm_ram : PROCESS
  -- begin
  --   -- Wait until the coeff dat file has been read and the coeff have been read via MM
  --   proc_common_wait_until_high(clk, tb_end_almost);
  --   assert read_coefs_arr = ref_coefs_arr report "Coefs file does not match coefs read via MM" severity failure;
  --   wait;
  -- end process;

  ---------------------------------------------------------------
  -- DUT = Device Under Test
  ---------------------------------------------------------------
  u_dut : entity work.fil_ppf_single
  generic map (
    g_fil_ppf           => g_fil_ppf,
    g_fil_ppf_pipeline  => g_fil_ppf_pipeline,
    g_file_index_arr    => c_file_index_arr,
    g_coefs_file_prefix => c_coefs_file_prefix
  )
  port map (
    clk         => clk,
    rst         => rst,
    ce          => '1',
    -- mm_clk         => clk,
    -- mm_rst         => rst,
    -- ram_coefs_mosi => ram_coefs_mosi,
    -- ram_coefs_miso => ram_coefs_miso,
    in_dat         => in_dat,
    in_val         => in_val,
    out_dat        => out_dat,
    out_val        => out_val
  );

  ---------------------------------------------------------------
  -- VERIFY THE OUTPUT
  ---------------------------------------------------------------
  p_verify_out_dat_width : process
  begin
    -- Wait until tb_end_almost to avoid that the Error message gets lost in earlier messages
    proc_common_wait_until_high(clk, tb_end_almost);
    assert g_fil_ppf.out_dat_w >= g_fil_ppf.coef_dat_w report "Output data width too small for coefficients" severity failure;
    wait;
  end process;
  
  p_verify_out_val_cnt : process
  begin
    -- Wait until tb_end_almost
    proc_common_wait_until_high(clk, tb_end_almost);
    -- The filter has a latency of 1 tap, so there remains in_dat for tap in the filter
    assert in_val_cnt > 0                              report "Test did not run, no valid input data" severity failure;
    assert out_val_cnt = in_val_cnt-c_nof_data_per_tap report "Unexpected number of valid output data coefficients" severity failure;
    wait;
  end process;
  
  in_val_cnt  <= in_val_cnt+1  when rising_edge(clk) and in_val='1'  else in_val_cnt;
  out_val_cnt <= out_val_cnt+1 when rising_edge(clk) and out_val='1' else out_val_cnt;
  
  ref_dat    <= ref_dat_arr(out_val_cnt) WHEN out_val_cnt < c_nof_data_in_filter ELSE 0;

  p_verify_out_dat : process(clk)
    variable v_coeff : integer;
    variable v_test_pass : BOOLEAN := TRUE;
    variable v_test_msg : STRING(1 to 80);
    variable v_tmp_val : integer;
  begin
    if out_val='1' then
      if rising_edge(clk) then
        if g_fil_ppf.out_dat_w >= g_fil_ppf.coef_dat_w then
          if g_fil_ppf.out_dat_w > g_fil_ppf.coef_dat_w then
            v_coeff := ref_dat;  -- positive input pulse
          else
            v_coeff := -ref_dat;  -- compensate for full scale negative input pulse
          end if;
          for S in 0 to g_fil_ppf.nof_streams-1 loop
            -- all streams carry the same data
            v_tmp_val := TO_SINT(out_dat((S+1)*g_fil_ppf.out_dat_w-1 downto S*g_fil_ppf.out_dat_w));
            v_test_pass := v_tmp_val = v_coeff;
            if not v_test_pass then
              v_test_msg := pad("Output data error, expected: " & integer'image(v_tmp_val) & " but got: " & integer'image(v_coeff),o_test_msg'length,'.');
            end if;
            assert v_test_pass report v_test_msg severity error;
          end loop;
        end if;
      end if;
    end if;
    o_test_msg <= v_test_msg;
    o_test_pass <= v_test_pass;
  end process;

end tb;
