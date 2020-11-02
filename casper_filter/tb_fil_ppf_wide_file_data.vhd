-- Author: Eric Kooistra    : kooistra at astron.nl: july 2016
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
--
-- Purpose: Test bench for fil_ppf_wide.vhd using file data
--
--   The DUT fil_ppf_wide.vhd has wb_factor >= 1 and uses array types and
--   wb_factor instances of fil_ppf_single.vhd.
--
-- Usage:
--   The g_coefs_file_prefix dat-file and g_data_file dat-file are created by
--   the Matlab script:
--
--     $RADIOHDL_WORK/applications/apertif/matlab/run_pfir.m
--
--   yields:
--
--   . g_coefs_file_prefix : run_pfir_m_pfir_coeff_fircls1_16taps_128points_16b.dat
--   . g_data_file         : run_pfir_m_sinusoid_chirp_8b_16taps_128points_16b_16b.dat
--
--   The g_fil_ppf parameters nof_taps, nof_bands (= nof polyphase), c_in_dat_w,
--   out_dat_w and coef_dat_w must match the settings in run_pfir.m.
--
--   The g_fil_ppf.in_dat_w = 8 bit to fit run_pfir_m_sinusoid_chirp_wg_8b.dat. The
--   g_fil_ppf.backoff_w = 1 is necessary to accommodate the factor 2 overshoot that
--   the PFIR output can have.
--
--   The g_data_file contains a header followed by the PFIR coefficients, WG
--   data, PFIR data and PFFT data. The tb verifies that the PFIR coefficients
--   are the same as in the dat-fil indicated by g_coefs_file_prefix. The PFFT
--   data is not used in this tb.
--
--   The MIF files are generated from the g_coefs_file_prefix dat-file by
--   the Python script:
--
--     $RADIOHDL_WORK/libraries/dsp/filter/src/python/
--      python fil_ppf_create_mifs.py -f ../hex/run_pfir_m_pfir_coeff_fircls1_16taps_128points_16b.dat -t 16 -p 128 -w 1 -c 16
--      python fil_ppf_create_mifs.py -f ../hex/run_pfir_m_pfir_coeff_fircls1_16taps_128points_16b.dat -t 16 -p 128 -w 4 -c 16
--
--   yields:
--
--   . run_pfir_m_pfir_coeff_fircls1_16taps_128points_16b_1wb_#.mif, where # = 0:15
--   . run_pfir_m_pfir_coeff_fircls1_16taps_128points_16b_4wb_#.mif, where # = 0:64
--
--   The PFIR coefficient dat and mif files are kept in local ../hex
--   The input and expected output dat files are kept in local ../data.
--
--   The dat files that are created by Matlab first need to be copied manually
--   to these local directories and then the mif files need to be generated.
--   The modelsim_copy_files key in the hdllib.cfg will copy these files to the
--   build directory from where they are loaded by Modelsim.
--
--   > run -all
--   > testbench is selftesting.
--   > observe the *_scope as radix decimal, format analogue format signals
--     in the Wave window
--
library ieee, common_pkg_lib, dp_pkg_lib, astron_diagnostics_lib, astron_ram_lib, astron_mm_lib, astron_sim_tools_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use common_pkg_lib.common_pkg.all;
use astron_ram_lib.common_ram_pkg.ALL;
use common_pkg_lib.common_lfsr_sequences_pkg.ALL;
use common_pkg_lib.tb_common_pkg.all;
use astron_mm_lib.tb_common_mem_pkg.ALL;
use dp_pkg_lib.dp_stream_pkg.ALL;
use work.fil_pkg.all;

entity tb_fil_ppf_wide_file_data is
  generic(
    -- generics for tb
    g_big_endian_wb_in  : boolean := true;
    g_big_endian_wb_out : boolean := true;
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
    g_fil_ppf : t_fil_ppf := (4, 0, 128, 16, 2, 1, 8, 16, 16);
      -- type t_fil_ppf is record
      --   wb_factor      : natural; -- = 4, the wideband factor
      --   nof_chan       : natural; -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan
      --   nof_bands      : natural; -- = 1024, the number of polyphase channels (= number of points of the FFT)
      --   nof_taps       : natural; -- = 16, the number of FIR taps per subband
      --   nof_streams    : natural; -- = 1, the number of streams that are served by the same coefficients.
      --   backoff_w      : natural; -- = 0, number of bits for input backoff to avoid output overflow
      --   in_dat_w       : natural; -- = 8, number of input bits per stream
      --   out_dat_w      : natural; -- = 16, number of output bits (per stream)
      --   coef_dat_w     : natural; -- = 16, data width of the FIR coefficients
      -- end record;
    g_coefs_file_prefix   : string := "hex/run_pfir_m_pfir_coeff_fircls1";
    g_data_file           : string := "data/run_pfir_m_sinusoid_chirp_8b_16taps_128points_16b_16b.dat";  -- coefs, input and output data for 1 stream
    g_data_file_nof_lines : natural := 25600;  -- number of lines with input data that is available in the g_data_file

    g_data_file_nof_read  : natural := 5000;   -- number of lines with input data to read and simulate, must be <= g_data_file_nof_lines
    g_enable_in_val_gaps  : boolean := FALSE
  );
end entity tb_fil_ppf_wide_file_data;

architecture tb of tb_fil_ppf_wide_file_data is

  constant c_clk_period          : time := 10 ns;
  constant c_sclk_period         : time := c_clk_period / g_fil_ppf.wb_factor;

  constant c_diff_margin         : integer := 0;  -- maximum difference between PFIR HDL output and expected output (> 0 to allow minor rounding differences)

  constant c_nof_channels        : natural := 2**g_fil_ppf.nof_chan;
  constant c_nof_coefs           : natural := g_fil_ppf.nof_taps * g_fil_ppf.nof_bands;       -- nof PFIR coef
  constant c_nof_data_per_block  : natural := g_fil_ppf.nof_bands * c_nof_channels;           -- 1 block corresponds to 1 tap
  constant c_nof_valid_per_block : natural := c_nof_data_per_block / g_fil_ppf.wb_factor;

  constant c_rnd_factor          : natural := sel_a_b(g_enable_in_val_gaps, 3, 1);
  constant c_dut_block_latency   : natural := 2;
  constant c_dut_clk_latency     : natural := c_nof_valid_per_block * c_dut_block_latency * c_rnd_factor;  -- worst case

  -- input/output data width
  constant c_in_dat_w            : natural := g_fil_ppf.in_dat_w;
  constant c_out_dat_w           : natural := g_fil_ppf.out_dat_w;

  -- PFIR coefficients file access
  constant c_coefs_dat_file_prefix    : string  := g_coefs_file_prefix & "_" & integer'image(g_fil_ppf.nof_taps) & "taps" &
                                                                         "_" & integer'image(g_fil_ppf.nof_bands) & "points" &
                                                                         "_" & integer'image(g_fil_ppf.coef_dat_w) & "b";
  constant c_coefs_mif_file_prefix    : string  := c_coefs_dat_file_prefix & "_" & integer'image(g_fil_ppf.wb_factor) & "wb";

  -- Data file access
  constant c_nof_lines_pfir_coefs  : natural := c_nof_coefs;
  constant c_nof_lines_wg_dat      : natural := g_data_file_nof_lines;
  constant c_nof_lines_pfir_dat    : natural := c_nof_lines_wg_dat;
  constant c_nof_lines_header      : natural := 4;
  constant c_nof_lines_header_wg   : natural := c_nof_lines_header + c_nof_lines_pfir_coefs;
  constant c_nof_lines_header_pfir : natural := c_nof_lines_header + c_nof_lines_pfir_coefs + c_nof_lines_wg_dat;
  
  -- signal definitions
  signal tb_end            : std_logic := '0';
  signal tb_end_almost     : std_logic := '0';
  signal clk               : std_logic := '0';
  signal sclk              : std_logic := '1';
  signal rst               : std_logic := '0';
  signal random            : std_logic_vector(15 DOWNTO 0) := (OTHERS=>'0');  -- use different lengths to have different random sequences

  signal coefs_dat_arr     : t_integer_arr(c_nof_coefs-1 downto 0) := (OTHERS=>0);           -- = PFIR coef for all taps as read from via c_coefs_dat_file_prefix
  signal coefs_ref_arr     : t_integer_arr(c_nof_coefs-1 downto 0) := (OTHERS=>0);           -- = PFIR coef for all taps as read from via g_data_file
  
  signal expected_data_arr : t_integer_arr(0 to g_data_file_nof_read-1) := (OTHERS=>0);
  signal input_data_arr    : t_integer_arr(0 to g_data_file_nof_read-1) := (OTHERS=>0);
  signal input_data        : std_logic_vector(g_fil_ppf.wb_factor*c_in_dat_w-1 DOWNTO 0);
  signal input_data_scope  : integer;

  signal in_dat_arr        : t_fil_slv_arr(g_fil_ppf.wb_factor*g_fil_ppf.nof_streams-1 downto 0);  -- = t_slv_32_arr fits g_fil_ppf.in_dat_w <= 32
  signal in_val            : std_logic;
  signal in_val_cnt        : natural := 0;
  signal in_sub_val        : std_logic;
  signal in_sub_val_cnt    : natural := 0;
  signal in_gap            : std_logic := '0';

  signal tsub              : integer := 0;  -- subband time counter
  signal exp_data          : std_logic_vector(g_fil_ppf.wb_factor*c_out_dat_w-1 DOWNTO 0);
  signal exp_data_scope    : integer;
  signal diff_data_scope   : integer;
  signal output_data_scope : integer;
  signal output_data       : std_logic_vector(g_fil_ppf.wb_factor*c_out_dat_w-1 DOWNTO 0);
  signal out_dat_arr       : t_fil_slv_arr(g_fil_ppf.wb_factor*g_fil_ppf.nof_streams-1 downto 0);  -- = t_slv_32_arr fits g_fil_ppf.out_dat_w <= 32
  signal out_val           : std_logic;
  signal out_val_cnt       : natural := 0;
  signal out_sub_val       : std_logic;
  signal out_sub_val_cnt   : natural := 0;

begin

  sclk <= (not sclk) or tb_end after c_sclk_period/2;
  clk <= (not clk) or tb_end after c_clk_period/2;
  rst <= '1', '0' after c_clk_period*7;
  random <= func_common_random(random) WHEN rising_edge(clk);
  in_gap <= random(random'HIGH) WHEN g_enable_in_val_gaps=TRUE ELSE '0';

  ---------------------------------------------------------------
  -- DATA INPUT
  ---------------------------------------------------------------
  --
  -- In this testbench use:
  --
  --              parallel                 serial             type
  --   in_dat_arr [wb_factor][nof_streams] [t][nof_channels]  int
  -- 
  -- The time to wb_factor mapping for the fil_ppf_wide is big endian,
  -- so [3:0] = [t0,t1,t2,t3], when g_big_endian_wb_in = TRUE.
  -- When wb_factor = 4 and nof_streams = 2 then the mapping is as
  -- follows (S = stream index, P = wideband factor index):
  --
  --     t      P S   
  --     0      3 0
  --     0      3 1
  --     1      2 0
  --     1      2 1
  --     2      1 0
  --     2      1 1
  --     3      0 0
  --     3      0 1
  p_input_stimuli : process
    variable vP : natural;
  begin
    -- read input data from file
    proc_common_read_integer_file(g_data_file, c_nof_lines_header_wg, g_data_file_nof_read, 1, input_data_arr);
    wait for 1 ns;
    tb_end <= '0';
    in_dat_arr <= (others=>(others=>'0'));
    in_val <= '0';
    proc_common_wait_until_low(clk, rst);         -- Wait until reset has finished
    proc_common_wait_some_cycles(clk, 10);        -- Wait an additional amount of cycles

    -- apply stimuli
    for I in 0 to g_data_file_nof_read/g_fil_ppf.wb_factor-1 loop  -- serial
      for K in 0 to c_nof_channels-1 loop  -- serial
        for P in 0 to g_fil_ppf.wb_factor-1 loop  -- parallel
          if g_big_endian_wb_in=TRUE then
            vP := g_fil_ppf.wb_factor-1-P;        -- time to wideband big endian
          else
            vP := P;                              -- time to wideband little endian
          end if;
          for S in 0 to g_fil_ppf.nof_streams-1 loop  -- parallel
            if S=1 then
              -- if present then stream 1 carries zero data to be able to recognize the stream order in the wave window
              in_dat_arr(vP*g_fil_ppf.nof_streams + S) <= (OTHERS=>'0');
            else
              -- stream 0 and if present the other streams >= 2 carry the same input reference data to verify the filter function
              in_dat_arr(vP*g_fil_ppf.nof_streams + S) <= TO_SVEC(input_data_arr(I*g_fil_ppf.wb_factor + P), c_fil_slv_w);
            end if;
            in_val <= '1';
          end loop;
        end loop;
        in_val <= '1';
        proc_common_wait_some_cycles(clk, 1);
        if in_gap='1' then
          in_val <= '0';
          proc_common_wait_some_cycles(clk, 1);
        end if;
      end loop;
    end loop;

    -- Wait until done
    in_val <= '0';
    proc_common_wait_some_cycles(clk, c_dut_clk_latency);  -- wait for at least PPF latency of 1 tap
    tb_end_almost <= '1';
    proc_common_wait_some_cycles(clk, 100);
    tb_end <= '1';
    wait;
  end process;

  ---------------------------------------------------------------
  -- DUT = Device Under Test
  ---------------------------------------------------------------
  u_dut : entity work.fil_ppf_wide
  generic map (
    g_big_endian_wb_in  => g_big_endian_wb_in,
    g_big_endian_wb_out => g_big_endian_wb_out,
    g_fil_ppf           => g_fil_ppf,
    g_fil_ppf_pipeline  => g_fil_ppf_pipeline,
    g_coefs_file_prefix => c_coefs_mif_file_prefix
  )
  port map (
    dp_clk         => clk,
    dp_rst         => rst,
    mm_clk         => clk,
    mm_rst         => rst,
    ram_coefs_mosi => c_mem_mosi_rst,
    ram_coefs_miso => OPEN,
    in_dat_arr     => in_dat_arr,
    in_val         => in_val,
    out_dat_arr    => out_dat_arr,
    out_val        => out_val
  );

  ---------------------------------------------------------------
  -- Verify PFIR coefficients
  ---------------------------------------------------------------
  p_verify_pfir_coefs_files : PROCESS
  begin
    -- Verify that the PFIR coefficients in g_data_file are the same as those in c_coefs_dat_file_prefix.dat
    -- Just assume that the c_coefs_dat_file_prefix.dat is the same as the PFIR coefficients that are loaded via the MIFs,
    -- so do not read back the PFIR coefficients via MM.
    proc_common_read_integer_file(c_coefs_dat_file_prefix & ".dat", 0, c_nof_coefs, 1, coefs_dat_arr);
    proc_common_read_integer_file(g_data_file, c_nof_lines_header, c_nof_coefs, 1, coefs_ref_arr);
    wait for 1 ns;
    -- Wait until tb_end_almost to avoid that the Error message gets lost in earlier messages
    proc_common_wait_until_high(clk, tb_end_almost);
    assert coefs_dat_arr = coefs_ref_arr report "Unexpected PFIR coefficients." severity error;
    wait;
  end process;

  ---------------------------------------------------------------
  -- VERIFY OUTPUT
  ---------------------------------------------------------------
  p_verify_out_val_cnt : process
  begin
    -- Wait until tb_end_almost
    proc_common_wait_until_high(clk, tb_end_almost);
    -- The filter has a latency of 1 tap, so there remains in_dat for tap in the filter
    assert in_val_cnt > 0                                 report "Test did not run, no valid input data" severity error;
    assert out_val_cnt = in_val_cnt-c_nof_valid_per_block report "Unexpected number of valid output data" severity error;
    wait;
  end process;

  tsub <= tsub+1 when rising_edge(clk) and in_sub_val='1' and in_sub_val_cnt > 0 and (in_sub_val_cnt MOD c_nof_valid_per_block = 0);

  in_sub_val  <= '1' when in_val='1'  and (in_val_cnt  mod c_nof_channels)=0 else '0';
  out_sub_val <= '1' when out_val='1' and (out_val_cnt mod c_nof_channels)=0 else '0';
  in_sub_val_cnt  <= in_val_cnt/c_nof_channels;
  out_sub_val_cnt <= out_val_cnt/c_nof_channels;

  in_val_cnt  <= in_val_cnt+1  when rising_edge(clk) and in_val='1'  else in_val_cnt;
  out_val_cnt <= out_val_cnt+1 when rising_edge(clk) and out_val='1' else out_val_cnt;

  p_expected_output : process
  begin
    -- read expected output data from file
    proc_common_read_integer_file(g_data_file, c_nof_lines_header_pfir, g_data_file_nof_read, 1, expected_data_arr);
    wait;
  end process;

  p_verify_output : process(clk)
    variable vI            : natural := 0;
    variable vK            : natural := 0;
    variable vP            : natural;
    variable v_out_dat     : integer;
    variable v_exp_dat     : integer;
  begin
    if rising_edge(clk) then
      if out_val='1' then
        for P in 0 to g_fil_ppf.wb_factor-1 loop  -- parallel
          if g_big_endian_wb_out=true then
            vP := g_fil_ppf.wb_factor-1-P;        -- time to wideband big endian
          else
            vP := P;                              -- time to wideband little endian
          end if;
          for S in 0 to g_fil_ppf.nof_streams-1 loop  -- parallel
            v_out_dat := TO_SINT(out_dat_arr(vP*g_fil_ppf.nof_streams + S));
            if S=1 then
              -- stream 1 carries zero data
              v_exp_dat := 0;
              assert v_out_dat = v_exp_dat report "Output data error (stream 1 not zero)" severity error;
            else
              -- stream 0 and all other streams >= 2 carry the same data
              v_exp_dat := expected_data_arr(vI*g_fil_ppf.wb_factor + P);
              assert v_out_dat <= v_exp_dat + c_diff_margin and
                     v_out_dat >= v_exp_dat - c_diff_margin report "Output data error" severity error;
            end if;
          end loop;
        end loop;
        if vK < c_nof_channels-1 then  -- serial
          vK := vK + 1;
        else
          vK := 0;
          vI := vI + 1;
        end if;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------
  -- DATA SCOPES
  ---------------------------------------------------------------
  p_input_data : process(in_dat_arr)
    constant cS : natural := 0;  -- tap the input_data from stream 0
  begin
    for P in 0 to g_fil_ppf.wb_factor-1 loop
      input_data((P+1)*c_in_dat_w-1 downto P*c_in_dat_w) <= in_dat_arr(P*g_fil_ppf.nof_streams + cS)(c_in_dat_w-1 downto 0);
    end loop;
  end process;

  p_output_data : process(out_dat_arr)
    variable cS : natural;  -- tap the output_data from stream 0
  begin
    for P in 0 to g_fil_ppf.wb_factor-1 loop
      output_data((P+1)*c_out_dat_w-1 DOWNTO P*c_out_dat_w) <= out_dat_arr(P*g_fil_ppf.nof_streams + cS)(c_out_dat_w-1 downto 0);
    end loop;
  end process;

  p_exp_data : process(expected_data_arr, out_sub_val_cnt)
    variable vP : natural;
  begin
    for P in 0 to g_fil_ppf.wb_factor-1 loop
      if g_big_endian_wb_out=true then
        vP := g_fil_ppf.wb_factor-1-P;
      else
        vP := P;
      end if;
      exp_data((vP+1)*c_out_dat_w-1 DOWNTO vP*c_out_dat_w) <= TO_SVEC(expected_data_arr(out_sub_val_cnt*g_fil_ppf.wb_factor + P), c_out_dat_w);
    end loop;
  end process;

  u_input_data_scope : entity astron_sim_tools_lib.common_wideband_data_scope
  generic map (
    g_sim                 => TRUE,
    g_wideband_factor     => g_fil_ppf.wb_factor,  -- Wideband rate factor = 4 for dp_clk processing frequency is 200 MHz frequency and SCLK sample frequency Fs is 800 MHz
    g_wideband_big_endian => g_big_endian_wb_in,   -- When true in_data[3:0] = sample[t0,t1,t2,t3], else when false : in_data[3:0] = sample[t3,t2,t1,t0]
    g_dat_w               => c_in_dat_w            -- Actual width of the data samples
  )
  port map (
    -- Sample clock
    SCLK      => sclk,  -- sample clk, use only for simulation purposes

    -- Streaming input data
    in_data   => input_data,
    in_val    => in_val,

    -- Scope output samples
    out_dat   => OPEN,
    out_int   => input_data_scope
  );

  u_exp_data_scope : entity astron_sim_tools_lib.common_wideband_data_scope
  generic map (
    g_sim                 => TRUE,
    g_wideband_factor     => g_fil_ppf.wb_factor,  -- Wideband rate factor = 4 for dp_clk processing frequency is 200 MHz frequency and SCLK sample frequency Fs is 800 MHz
    g_wideband_big_endian => g_big_endian_wb_out,  -- When true in_data[3:0] = sample[t0,t1,t2,t3], else when false : in_data[3:0] = sample[t3,t2,t1,t0]
    g_dat_w               => c_out_dat_w            -- Actual width of the data samples
  )
  port map (
    -- Sample clock
    SCLK      => sclk,  -- sample clk, use only for simulation purposes

    -- Streaming input data
    in_data   => exp_data,
    in_val    => out_val,

    -- Scope output samples
    out_dat   => OPEN,
    out_int   => exp_data_scope
  );

  u_output_data_scope : entity astron_sim_tools_lib.common_wideband_data_scope
  generic map (
    g_sim                 => TRUE,
    g_wideband_factor     => g_fil_ppf.wb_factor,  -- Wideband rate factor = 4 for dp_clk processing frequency is 200 MHz frequency and SCLK sample frequency Fs is 800 MHz
    g_wideband_big_endian => g_big_endian_wb_out,  -- When true in_data[3:0] = sample[t0,t1,t2,t3], else when false : in_data[3:0] = sample[t3,t2,t1,t0]
    g_dat_w               => c_out_dat_w            -- Actual width of the data samples
  )
  port map (
    -- Sample clock
    SCLK      => sclk,  -- sample clk, use only for simulation purposes

    -- Streaming input data
    in_data   => output_data,
    in_val    => out_val,

    -- Scope output samples
    out_dat   => OPEN,
    out_int   => output_data_scope
  );

  diff_data_scope <= exp_data_scope - output_data_scope;

  -- Equivalent to p_verify_output, but using the sclk scope data
  p_verify_data_scope : process(sclk)
  begin
    if rising_edge(clk) then
      assert diff_data_scope <=  c_diff_margin and
             diff_data_scope >= -c_diff_margin report "Output data scope error" severity error;
    end if;
  end process;

end tb;
