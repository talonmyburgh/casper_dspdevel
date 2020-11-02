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
-- Purpose: Test bench for fil_ppf_wide.vhd
--
--   The DUT fil_ppf_wide.vhd has wb_factor >= 1 and uses array types and 
--   wb_factor instances of fil_ppf_single.vhd.
--
--   See also description tb_fil_ppf_single.vhd.
--
-- Usage:
--   > run -all
--   > testbench is selftesting. 
--
library ieee, common_pkg_lib, dp_pkg_lib, astron_diagnostics_lib, astron_ram_lib, astron_mm_lib;
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

entity tb_fil_ppf_wide is
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
    g_fil_ppf : t_fil_ppf := (4, 1, 64, 8, 1, 0, 8, 23, 16); 
      -- type t_fil_ppf is record
      --   wb_factor      : natural; -- = 4, the wideband factor
      --   nof_chan       : natural; -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan 
      --   nof_bands      : natural; -- = 1024, the number of polyphase channels (= number of points of the FFT)
      --   nof_taps       : natural; -- = 16, the number of FIR taps per subband
      --   nof_streams    : natural; -- = 1, the number of streams that are served by the same coefficients. 
      --   backoff_w      : natural; -- = 0, number of bits for input backoff to avoid output overflow
      --   in_dat_w       : natural; -- = 8, number of input bits per stream
      --   out_dat_w      : natural; -- = 23, number of output bits (per stream). It is set to in_dat_w+coef_dat_w-1 = 23 to be sure the requantizer
      --                                  does not remove any of the data in order to be able to verify with the original coefficients values. 
      --   coef_dat_w     : natural; -- = 16, data width of the FIR coefficients
      -- end record;
    g_coefs_file_prefix  : string  := "hex/run_pfir_coeff_m_incrementing";
    g_enable_in_val_gaps : boolean := FALSE
  );
end entity tb_fil_ppf_wide;

architecture tb of tb_fil_ppf_wide is
  
  constant c_clk_period : time    := 10 ns;
  
  constant c_nof_channels        : natural := 2**g_fil_ppf.nof_chan;
  constant c_nof_coefs           : natural := g_fil_ppf.nof_taps * g_fil_ppf.nof_bands;       -- nof PFIR coef
  constant c_nof_coefs_per_wb    : natural := c_nof_coefs / g_fil_ppf.wb_factor;
  constant c_nof_data_in_filter  : natural := c_nof_coefs * c_nof_channels;                   -- nof PFIR coef expanded for all channels
  constant c_nof_data_per_tap    : natural := c_nof_data_in_filter / g_fil_ppf.nof_taps;
  constant c_nof_valid_in_filter : natural := c_nof_data_in_filter / g_fil_ppf.wb_factor;
  constant c_nof_valid_per_tap   : natural := c_nof_data_per_tap / g_fil_ppf.wb_factor;
  constant c_nof_bands_per_mif   : natural := g_fil_ppf.nof_bands / g_fil_ppf.wb_factor;
  constant c_mif_coef_mem_addr_w : natural := ceil_log2(g_fil_ppf.nof_bands);
  constant c_mif_coef_mem_span   : natural := 2**c_mif_coef_mem_addr_w;                       -- mif coef mem span for one tap

  constant c_coefs_file_prefix   : string  := g_coefs_file_prefix & "_" & integer'image(g_fil_ppf.nof_taps) & "taps" &
                                                                    "_" & integer'image(g_fil_ppf.nof_bands) & "points" &
                                                                    "_" & integer'image(g_fil_ppf.coef_dat_w) & "b";
  constant c_mif_file_prefix     : string  := c_coefs_file_prefix & "_" & integer'image(g_fil_ppf.wb_factor) & "wb";
  
  constant c_fil_prod_w          : natural := g_fil_ppf.in_dat_w + g_fil_ppf.coef_dat_w - 1;  -- skip double sign bit
  constant c_fil_sum_w           : natural := c_fil_prod_w;                                   -- DC gain = 1
  constant c_fil_lsb_w           : natural := c_fil_sum_w - g_fil_ppf.out_dat_w;              -- nof LSbits that get rounded for out_dat
  constant c_in_ampl             : natural := 2**c_fil_lsb_w;                                 -- scale in_dat to compensate for rounding
  
  constant c_gap_factor          : natural := sel_a_b(g_enable_in_val_gaps, 3, 1);
  
  -- input/output data width
  constant c_in_dat_w            : natural := g_fil_ppf.in_dat_w;   
  constant c_out_dat_w           : natural := g_fil_ppf.out_dat_w;

  type t_wb_integer_arr2 is array(integer range <>) of t_integer_arr(c_nof_valid_in_filter-1 downto 0);
  
  -- signal definitions
  signal tb_end         : std_logic := '0';
  signal tb_end_mm      : std_logic := '0';
  signal tb_end_almost  : std_logic := '0';
  signal clk            : std_logic := '0';
  signal rst            : std_logic := '0';
  signal random         : std_logic_vector(15 DOWNTO 0) := (OTHERS=>'0');  -- use different lengths to have different random sequences

  signal ram_coefs_mosi : t_mem_mosi := c_mem_mosi_rst;
  signal ram_coefs_miso : t_mem_miso;

  signal in_dat_arr      : t_fil_slv_arr(g_fil_ppf.wb_factor*g_fil_ppf.nof_streams-1 downto 0);  -- = t_slv_32_arr fits g_fil_ppf.in_dat_w <= 32
  signal in_val          : std_logic; 
  signal in_val_cnt      : natural := 0;
  signal in_gap          : std_logic := '0'; 
                         
  signal out_dat_arr     : t_fil_slv_arr(g_fil_ppf.wb_factor*g_fil_ppf.nof_streams-1 downto 0);  -- = t_slv_32_arr fits g_fil_ppf.out_dat_w <= 32
  signal out_val         : std_logic; 
  signal out_val_cnt     : natural := 0;
                         
  signal mif_coefs_arr   : t_integer_arr(c_nof_bands_per_mif-1 downto 0) := (OTHERS=>0);            -- = PFIR coef for 1 wb, 1 tap as read from 1 MIF file
  signal mif_dat_arr2    : t_wb_integer_arr2(0 to g_fil_ppf.wb_factor-1) := (OTHERS=>(OTHERS=>0));  -- = PFIR coef for all taps as read from all MIF files and expanded for all channels

  signal ref_coefs_arr   : t_integer_arr(c_nof_coefs-1 downto 0) := (OTHERS=>0);                    -- = PFIR coef for all taps as read from the coefs file
  signal ref_dat_arr2    : t_wb_integer_arr2(0 to g_fil_ppf.wb_factor-1) := (OTHERS=>(OTHERS=>0));  -- = PFIR coef for all taps as read from the coefs file expanded for all channels
  signal ref_dat_arr     : t_integer_arr(0 to g_fil_ppf.wb_factor-1) := (OTHERS=>0);

  signal read_coefs_arr  : t_integer_arr(c_nof_coefs-1 downto 0) := (OTHERS=>0);           -- = PFIR coef for all taps as read via MM from the coefs memories           
                         
begin

  clk <= (not clk) or tb_end after c_clk_period/2;
  rst <= '1', '0' after c_clk_period*7;
  random <= func_common_random(random) WHEN rising_edge(clk);
  in_gap <= random(random'HIGH) WHEN g_enable_in_val_gaps=TRUE ELSE '0';

  ---------------------------------------------------------------
  -- SEND IMPULSE TO THE DATA INPUT
  ---------------------------------------------------------------  
  p_send_impulse : process                                                     
  begin
    tb_end <= '0';                            
    in_dat_arr <= (others=>(others=>'0')); 
    in_val <= '0';
    proc_common_wait_until_low(clk, rst);         -- Wait until reset has finished
    proc_common_wait_some_cycles(clk, 10);        -- Wait an additional amount of cycles
                                              
    -- The impulse is high during the entire tap, so g_big_endian_wb_in has no impact on the wideband input order of index P
    
    -- Pulse during first tap of all channels
    for I in 0 to c_nof_valid_per_tap-1 loop
      for P in 0 to g_fil_ppf.wb_factor-1 loop
        for S in 0 to g_fil_ppf.nof_streams-1 loop
          in_dat_arr(P*g_fil_ppf.nof_streams + S) <= TO_UVEC(c_in_ampl, c_fil_slv_w); 
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
    FOR J IN 0 TO g_fil_ppf.nof_taps-2 +1 +1  LOOP
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
    proc_common_wait_until_high(clk, tb_end_mm);                          -- MM read done
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
    -- Distribute over wb_factor and expand the channels (for one stream)
    for I in 0 to c_nof_coefs_per_wb-1 loop
      for P in 0 to g_fil_ppf.wb_factor-1 loop
        for K in 0 to c_nof_channels-1 loop
          ref_dat_arr2(P)(I*c_nof_channels + K) <= TO_SINT(TO_SVEC(v_coefs_flip_arr(I*g_fil_ppf.wb_factor + P), g_fil_ppf.coef_dat_w));
        end loop;
      end loop;
    end loop;
    wait;
  end process;

  p_create_ref_from_mif_file : PROCESS
  begin
    for P in 0 to g_fil_ppf.wb_factor-1 loop
      for J in 0 to g_fil_ppf.nof_taps-1 loop
        -- Read coeffs per wb and per tap from MIF file
        proc_common_read_mif_file(c_mif_file_prefix & "_" & integer'image(P*g_fil_ppf.nof_taps+J) & ".mif", mif_coefs_arr);
        wait for 1 ns;
        -- Expand the channels (for one stream)
        for I in 0 to c_nof_bands_per_mif-1 loop
          for K in 0 to c_nof_channels-1 loop
            mif_dat_arr2(P)(J*c_nof_valid_per_tap + I*c_nof_channels + K) <= TO_SINT(TO_SVEC(mif_coefs_arr(I), g_fil_ppf.coef_dat_w));
          end loop;
        end loop;
      end loop;
    end loop;
    wait;
  end process;

  p_coefs_memory_read : process
    variable v_mif_index   : natural;
    variable v_mif_base    : natural;
    variable v_coef_offset : natural;
    variable v_coef_index  : natural;
  begin
    ram_coefs_mosi <= c_mem_mosi_rst;
    for P in 0 to g_fil_ppf.wb_factor-1 loop
      for J in 0 to g_fil_ppf.nof_taps-1 loop
        v_mif_index := P*g_fil_ppf.nof_taps+J;
        v_mif_base  := v_mif_index*c_mif_coef_mem_span;
        v_coef_offset := g_fil_ppf.nof_bands*(J+1)-1-P;  -- coeff in MIF are in flipped order, unflip this in v_coef_index
        for I in 0 to c_nof_bands_per_mif-1 loop
          proc_mem_mm_bus_rd(v_mif_base+I, clk, ram_coefs_miso, ram_coefs_mosi);
          proc_mem_mm_bus_rd_latency(1, clk);
          v_coef_index := v_coef_offset - I*g_fil_ppf.wb_factor;
          read_coefs_arr(v_coef_index) <= TO_SINT(ram_coefs_miso.rddata(g_fil_ppf.coef_dat_w-1 DOWNTO 0));
        end loop;
      end loop;
    end loop;
    proc_common_wait_some_cycles(clk, 1);
    tb_end_mm <= '1';
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
    g_coefs_file_prefix => c_mif_file_prefix 
  )
  port map (
    dp_clk         => clk,
    dp_rst         => rst,
    mm_clk         => clk,
    mm_rst         => rst,
    ram_coefs_mosi => ram_coefs_mosi, 
    ram_coefs_miso => ram_coefs_miso, 
    in_dat_arr     => in_dat_arr,
    in_val         => in_val,
    out_dat_arr    => out_dat_arr,
    out_val        => out_val
  ); 
    
  -- Verify the output of the DUT with the expected output from the reference array
  p_verify_out_dat_width : process
  begin
    -- Wait until tb_end_almost to avoid that the Error message gets lost in earlier messages
    proc_common_wait_until_high(clk, tb_end_almost);
    assert g_fil_ppf.out_dat_w >= g_fil_ppf.coef_dat_w report "Output data width too small for coefficients" severity error;
    wait;
  end process;
  
  p_verify_out_val_cnt : process
  begin
    -- Wait until tb_end_almost
    proc_common_wait_until_high(clk, tb_end_almost);
    -- The filter has a latency of 1 tap, so there remains in_dat for tap in the filter
    assert in_val_cnt > 0                               report "Test did not run, no valid input data" severity error;
    assert out_val_cnt = in_val_cnt-c_nof_valid_per_tap report "Unexpected number of valid output data coefficients" severity error;
    wait;
  end process;
  
  in_val_cnt  <= in_val_cnt+1  when rising_edge(clk) and in_val='1'  else in_val_cnt;
  out_val_cnt <= out_val_cnt+1 when rising_edge(clk) and out_val='1' else out_val_cnt;
  
  gen_ref_dat_arr : for P in 0 to g_fil_ppf.wb_factor-1 generate
    ref_dat_arr(P) <= ref_dat_arr2(P)(out_val_cnt) when out_val_cnt < c_nof_valid_in_filter else 0;
  end generate;
    
  p_verify_out_dat : process(clk)
    variable v_coeff : integer;
    variable vP      : natural;
  begin
    if rising_edge(clk) then
      if out_val='1' then
        for P in 0 to g_fil_ppf.wb_factor-1 loop
          -- Adjust index for v_coeff dependend on g_big_endian_wb_out over all wb and streams for out_dat_arr,
          -- because ref_dat_arr for 1 stream uses little endian time [0,1,2,3] to P [0,1,2,3] index mapping
          if g_big_endian_wb_out=false then
            vP := P;
          else
            vP := g_fil_ppf.wb_factor-1-P;
          end if;
          
          -- Output data width must be large enough to fit the coefficients width, this is verified by p_verify_out_dat_width
          -- If g_fil_ppf.out_dat_w = g_fil_ppf.coef_dat_w then full scale input is simulated as negative due to that +2**(w-1)
          -- wraps to -2**(w-1), so then compensate for that here.
          if g_fil_ppf.out_dat_w > g_fil_ppf.coef_dat_w then
            v_coeff :=  ref_dat_arr(vP);  -- positive input pulse
          else
            v_coeff := -ref_dat_arr(vP);  -- compensate for full scale negative input pulse
          end if;
          for S in 0 to g_fil_ppf.nof_streams-1 loop
            -- all streams carry the same data
            assert TO_SINT(out_dat_arr(P*g_fil_ppf.nof_streams + S)) = v_coeff report "Output data error" severity error;
          end loop;
        end loop;
      end if;
    end if;
  end process;

end tb;
