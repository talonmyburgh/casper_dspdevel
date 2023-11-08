-- Author: Harm Jan Pepping : hajee at astron.nl   : April 2012
--         Eric Kooistra    : kooistra at astron.nl: july 2016
--         Andrew Martens   : martens.andrew at gmail.com : june 2023
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
-- Purpose: Test bench for pfb_fir.vhd. Modified from tb_fil_ppf_wide.vhd
--
--
-- Usage:
--   > run -all
--   > testbench is selftesting. 
--
library ieee, common_pkg_lib, casper_ram_lib, technology_lib;-- astron_mm_lib;
use IEEE.std_logic_1164.all;                                            
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use std.textio.all;
use common_pkg_lib.common_pkg.all;
use casper_ram_lib.common_ram_pkg.ALL;
use common_pkg_lib.common_lfsr_sequences_pkg.ALL;
use common_pkg_lib.tb_common_pkg.all;
--use casper_mm_lib.tb_common_mem_pkg.ALL;
use technology_lib.technology_select_pkg.ALL;
use work.pfb_fir_pkg.all;

entity tb_pfb_fir is
  generic(
    -- generics for tb
    g_big_endian_wb_in  : boolean := true;
    g_big_endian_wb_out : boolean := true;
    g_pfb_fir : t_pfb_fir := (4, 0, 64, 8, 1, 8, 23, 16, 0);
    g_pfb_fir_pipeline : t_pfb_fir_pipeline := (1,1,1,1); 
    --type t_pfb_fir is record
    --  wb_factor       : natural; -- = 1, the wideband factor
    --  n_chans         : natural; -- = 0, number of time multiplexed input signals
    --  n_bins          : natural; -- = 1024, the number of polyphase channels (= number of FFT bins)
    --  n_taps          : natural; -- = 16, the number of FIR taps per subband
    --  n_streams       : natural; -- = 1, the number of streams that are served by the same coefficients.
    --  din_w           : natural; -- = 8, number of input bits per stream
    --  dout_w          : natural; -- = 16, number of output bits per stream
    --  coef_w          : natural; -- = 16, data width of the FIR coefficients
    --  padding         : natural; -- = 0, padding bits to prevent arithmetic overflow
    --  mem_latency     : natural; -- = 2, latency through taps and coeff lookup
    --  mult_latency    : natural; -- = 3, multiplier latency
    --  add_latency     : natural; -- = 1, adder latency
    --  conv_latency    : natural; -- = 1, type conversion latency
    --end record;
    g_coefs_file_prefix  : string  := "run_pfir_coeff_m_incrementing_8taps_64points_16b";
    g_enable_in_val_gaps : boolean := FALSE
  );
  PORT   (
    o_rst       : out std_logic;
    o_clk       : out std_logic;
    o_tb_end    : out std_logic;
    o_test_msg  : out string(1 to 80);
    o_test_pass : out boolean
  );
end entity tb_pfb_fir;

architecture tb of tb_pfb_fir is
  
  constant c_clk_period : time    := 10 ns;
  
  constant c_nof_channels         : natural := 2**g_pfb_fir.n_chans;
  constant c_nof_coefs            : natural := g_pfb_fir.n_taps * g_pfb_fir.n_bins;       -- nof PFIR coef
  constant c_nof_coefs_per_wb     : natural := c_nof_coefs / g_pfb_fir.wb_factor;
  constant c_nof_data_in_filter   : natural := c_nof_coefs * c_nof_channels;                   -- nof PFIR coef expanded for all channels
  constant c_nof_data_per_tap     : natural := c_nof_data_in_filter / g_pfb_fir.n_taps;
  constant c_nof_valid_in_filter  : natural := c_nof_data_in_filter / g_pfb_fir.wb_factor;
  constant c_nof_valid_per_tap    : natural := c_nof_data_per_tap / g_pfb_fir.wb_factor;
  constant c_nof_bands_per_file   : natural := g_pfb_fir.n_bins / g_pfb_fir.wb_factor;

  constant c_coefs_file_prefix    : string  := g_coefs_file_prefix;
  constant c_memory_file_prefix   : string  := c_coefs_file_prefix & "_" & integer'image(g_pfb_fir.wb_factor) & "wb";
  
  constant c_in_ampl              : natural := 1; -- for now 2**c_fil_lsb_w;                                 -- scale in_dat to compensate for rounding
  
  constant c_gap_factor           : natural := sel_a_b(g_enable_in_val_gaps, 3, 1);
  
  type t_wb_integer_arr2 is array(integer range <>) of t_integer_arr(c_nof_valid_in_filter-1 downto 0);
  
  -- signal definitions
  signal tb_end         : std_logic := '0';
  -- signal tb_end_mm      : std_logic := '0';
  signal tb_end_almost  : std_logic := '0';
  signal clk, rst       : std_logic := '0';
  signal random         : std_logic_vector(15 DOWNTO 0) := (OTHERS=>'0');  -- use different lengths to have different random sequences

--  signal ram_coefs_mosi : t_mem_mosi := c_mem_mosi_rst;
--  signal ram_coefs_miso : t_mem_miso;

  signal sync_in         : std_logic := '0';
  signal in_dat_arr      : t_pfb_fir_array_in(g_pfb_fir.wb_factor*g_pfb_fir.n_streams-1 downto 0);  -- = t_slv_32_arr fits g_fil_ppf.in_dat_w <= 32
  signal in_val          : std_logic; 
  signal in_val_cnt      : natural := 0;
  signal in_gap          : std_logic := '0'; 
  
  signal sync_out        : std_logic;                       
  signal out_dat_arr     : t_pfb_fir_array_out(g_pfb_fir.wb_factor*g_pfb_fir.n_streams-1 downto 0);  -- = t_slv_32_arr fits g_fil_ppf.out_dat_w <= 32
  signal out_val         : std_logic; 
  signal out_val_cnt     : natural := 0;
                         
  signal memory_coefs_arr   : t_integer_arr(c_nof_bands_per_file-1 downto 0) := (OTHERS=>0);            -- = PFIR coef for 1 wb, 1 tap as read from 1 MIF file
  signal memory_dat_arr2    : t_wb_integer_arr2(0 to g_pfb_fir.wb_factor-1) := (OTHERS=>(OTHERS=>0));  -- = PFIR coef for all taps as read from all MIF files and expanded for all channels

  signal ref_coefs_arr   : t_integer_arr(c_nof_coefs-1 downto 0) := (OTHERS=>0);                    -- = PFIR coef for all taps as read from the coefs file
  signal ref_dat_arr2    : t_wb_integer_arr2(0 to g_pfb_fir.wb_factor-1) := (OTHERS=>(OTHERS=>0));  -- = PFIR coef for all taps as read from the coefs file expanded for all channels
  signal ref_dat_arr     : t_integer_arr(0 to g_pfb_fir.wb_factor-1) := (OTHERS=>0);           
                         
begin

  clk <= (not clk) or tb_end after c_clk_period/2;
  rst <= '1', '0' after c_clk_period*7;
  random <= func_common_random(random) WHEN rising_edge(clk);
  in_gap <= random(random'HIGH) WHEN g_enable_in_val_gaps=TRUE ELSE '0';

  o_clk <= clk;
  o_tb_end <= tb_end;

  ---------------------------------------------------------------
  -- SEND IMPULSE TO THE DATA INPUT
  ---------------------------------------------------------------  
  p_send_impulse : process                                                     
  begin
    tb_end <= '0';                            
    in_dat_arr <= (others=>(others=>'0')); 
    in_val <= '0';
    sync_in <= '0';
    proc_common_wait_until_low(clk, rst);         -- Wait until reset has finished
    proc_common_wait_some_cycles(clk, 9);        -- Wait an additional amount of cycles
    sync_in <= '1';
    proc_common_wait_some_cycles(clk, 1);        -- hold sync high for one cycle
    sync_in <= '0';                              -- lower sync at the same time as data becomes valid
                                              
    -- Pulse during first tap of all bins
    for I in 0 to c_nof_valid_per_tap-1 loop
      for P in 0 to g_pfb_fir.wb_factor-1 loop
        for S in 0 to g_pfb_fir.n_streams-1 loop
          in_dat_arr(P*g_pfb_fir.n_streams + S) <= TO_UVEC(c_in_ampl, g_pfb_fir.din_w); 
          in_val                                  <= '1';                      
        end loop;
      end loop;
      in_val <= '1';
      proc_common_wait_some_cycles(clk, 1);
      if in_gap='1' then
        in_val <= '0';
        proc_common_wait_some_cycles(clk, 1);
      end if;
    end loop;

    -- Zero during next nof_taps-1 blocks, +1 more to account for block latency of PPF and +1 more to have zeros output in last block
    in_dat_arr <= (others=>(others=>'0')); 
    FOR J IN 0 TO g_pfb_fir.n_taps-2 +1 +1  LOOP
      FOR I IN 0 TO c_nof_valid_per_tap-1 LOOP
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
    proc_common_wait_some_cycles(clk, c_gap_factor*c_nof_valid_per_tap);  -- PPF latency of 1 tap
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
    for J in 0 to g_pfb_fir.n_taps-1 loop
      for I in 0 to g_pfb_fir.n_bins-1 loop
        v_coefs_flip_arr(J*g_pfb_fir.n_bins + g_pfb_fir.n_bins-1-I) := ref_coefs_arr(J*g_pfb_fir.n_bins+I);
      end loop;
    end loop;
    -- Distribute over wb_factor and expand the channels (for one stream)
    for I in 0 to c_nof_coefs_per_wb-1 loop
      for P in 0 to g_pfb_fir.wb_factor-1 loop
        for K in 0 to c_nof_channels-1 loop
          ref_dat_arr2(P)(I*c_nof_channels + K) <= TO_SINT(TO_SVEC(v_coefs_flip_arr(I*g_pfb_fir.wb_factor + P), g_pfb_fir.coef_w));
        end loop;
      end loop;
    end loop;
    wait;
  end process;

  p_create_ref_from_memory_file : PROCESS
  begin
    for P in 0 to g_pfb_fir.wb_factor-1 loop
      for J in 0 to g_pfb_fir.n_taps-1 loop
        -- Read coeffs per wb and per tap from MEMORY file
        if c_tech_select_default = c_tech_stratixiv then
          proc_common_read_mif_file(c_memory_file_prefix & "_" & integer'image(P*g_pfb_fir.n_taps+J) & ".mif", memory_coefs_arr);
        elsif c_tech_select_default = c_tech_xpm then
          proc_common_read_mem_file(c_memory_file_prefix & "_" & integer'image(P*g_pfb_fir.n_taps+J) & ".mem", memory_coefs_arr);
        end if;
        wait for 1 ns;
        -- Expand the channels (for one stream)
        for I in 0 to c_nof_bands_per_file-1 loop
          for K in 0 to c_nof_channels-1 loop
            memory_dat_arr2(P)(J*c_nof_valid_per_tap + I*c_nof_channels + K) <= TO_SINT(TO_SVEC(memory_coefs_arr(I), g_pfb_fir.coef_w));
          end loop;
        end loop;
      end loop;
    end loop;
    wait;
  end process;

  ---------------------------------------------------------------  
  -- DUT = Device Under Test
  ---------------------------------------------------------------  
  u_dut : entity work.pfb_fir 
  generic map (
    g_pfb_fir           => g_pfb_fir,
    g_coefs_file        => c_coefs_file_prefix
  )
  port map (
    clk            => clk,
    sync_in        => sync_in,
    din            => in_dat_arr,
    en             => in_val,
    sync_out       => sync_out,
    dout           => out_dat_arr,
    dvalid         => out_val
  ); 
    
  -- Verify the output of the DUT with the expected output from the reference array
  p_verify_out_dat_width : process
  begin
    -- Wait until tb_end_almost to avoid that the Error message gets lost in earlier messages
    proc_common_wait_until_high(clk, tb_end_almost);
    assert g_pfb_fir.dout_w >= g_pfb_fir.coef_w report "Output data width too small for coefficients" severity failure;
    wait;
  end process;
  
  p_verify_out_val_cnt : process
  begin
    -- Wait until tb_end_almost
    proc_common_wait_until_high(clk, tb_end_almost);
    -- The filter has a latency of 1 tap, so there remains in_dat for tap in the filter
    assert in_val_cnt > 0                               report "Test did not run, no valid input data" severity failure;
--    assert out_val_cnt = in_val_cnt-c_nof_valid_per_tap report "Unexpected number of valid output data coefficients" severity failure;
    wait;
  end process;
  
  in_val_cnt  <= in_val_cnt+1  when rising_edge(clk) and in_val='1'  else in_val_cnt;
  -- we wait on the sync and then count the outputs
  p_gen_out_val_cnt : process(clk)
  begin
    if rising_edge(clk) then
      if sync_out = '1' then
        out_val_cnt <= 0;
      else
        if out_val = '1' then
          out_val_cnt <= out_val_cnt+1;
        end if;
      end if;
    end if;
  end process;
  
  gen_ref_dat_arr : for P in 0 to g_pfb_fir.wb_factor-1 generate
    ref_dat_arr(P) <= ref_dat_arr2(P)(out_val_cnt) when out_val_cnt < c_nof_valid_in_filter else 0;
  end generate;
    
  p_verify_out_dat : process(clk)
    variable v_coeff : integer;
    variable vP      : natural;
    variable v_test_pass : BOOLEAN := TRUE;
    variable v_test_msg : STRING(1 to 80);
    variable v_tmp_val : integer;
  begin
    if rising_edge(clk) then
      if out_val='1' then
        for P in 0 to g_pfb_fir.wb_factor-1 loop
          -- Adjust index for v_coeff dependend on g_big_endian_wb_out over all wb and streams for out_dat_arr,
          -- because ref_dat_arr for 1 stream uses little endian time [0,1,2,3] to P [0,1,2,3] index mapping
          if g_big_endian_wb_out=false then
            vP := P;
          else
            vP := g_pfb_fir.wb_factor-1-P;
          end if;
          
          -- Output data width must be large enough to fit the coefficients width, this is verified by p_verify_out_dat_width
          -- If g_fil_ppf.out_dat_w = g_fil_ppf.coef_dat_w then full scale input is simulated as negative due to that +2**(w-1)
          -- wraps to -2**(w-1), so then compensate for that here.
          if g_pfb_fir.dout_w > g_pfb_fir.coef_w then
            v_coeff :=  ref_dat_arr(vP);  -- positive input pulse
          else
            v_coeff := -ref_dat_arr(vP);  -- compensate for full scale negative input pulse
          end if;
          for S in 0 to g_pfb_fir.n_streams-1 loop
            v_tmp_val := TO_SINT(out_dat_arr(P*g_pfb_fir.n_streams + S));
            v_test_pass := v_tmp_val = v_coeff;
            -- all streams carry the same data
            if not v_test_pass then
              v_test_msg := pad("Output data error, expected: " & integer'image(v_tmp_val) & " but got: " & integer'image(v_coeff),o_test_msg'length,'.');
            end if;
            assert v_test_pass report v_test_msg;
          end loop;
        end loop;
      end if;
    end if;
    o_test_msg <= v_test_msg;
    o_test_pass <= v_test_pass;
  end process;

end tb;