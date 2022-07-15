--------------------------------------------------------------------------------
--
-- Copyright 2020
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
-- 
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
--------------------------------------------------------------------------------

--
-- Purpose: Test bench for the rTwoSDF pipelined radix 2 FFT
--
-- Description: ASTRON-RP-755
--   The testbench can simulate (via g_use_uniNoise_file):
--
--   a) complex uniform noise input from a file generated by testFFT_input.m
--   b) impulse input from a manually created file
--
--   Stimuli b) are useful for visual interpretation of the FFT output, because
--   an impulse at the real input and zero at the imaginary inpu will result
--   in DC and zero if the pulse occurs at the first sample or in sinus and
--   cosinus wave if the impulse occurs at a later sample. However because the
--   imaginary input is zero this does not cover all internals of the PFT 
--   implementation. Therefore stimuli a) are needed to fully verify the PFT.
--
--   The rTwoSDF output can be verified in two ways:
--
--   1) The MATLAB testFFT_output.m can calculate the floating point FFT and
--      compare it with the rTwoSDF implementation output file result.
--   2) The rTwoSDF implementation output file is also kept in SVN as golden
--      reference result to allow verification using a file diff command like
--      e.g. WinMerge. This then avoids the need to run MATLAB to verify.
--
--   The tb asserts an error when the output does not match the expected output
--   that is read from the golden reference file. The output is also written
--   to a default output file to support offline analysis.     
--
-- Usage:
--   > vsim -vopt -voptargs=+acc work.tb_rtwosdf (double click tb_rtwosdf icon)
--   > run -all
--   > observe the *_re and *_im as radix decimal, format analogue format
--     signals in the Wave window
--
-- Remarks:
-- . The tb uses LRM 1076-1987 style for file IO. This implies that only
--   simulator start and quit can open and close the file. The output file
--   can be read in a file editor, but the SVN file icon indicates that the
--   file is modified even if the contents is not changed. Only after closing
--   the simulation (> quit -sim) does the SVN file icon indicate the true
--   state. Next time we better use LRM 1076-1993 style for file IO.

library ieee, common_pkg_lib;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_textio.all;
use STD.textio.all;
use common_pkg_lib.common_pkg.all;
use common_pkg_lib.common_lfsr_sequences_pkg.all;
use common_pkg_lib.tb_common_pkg.all;
use work.rTwoSDFPkg.all;


entity tb_rTwoSDF is
  generic(
    -- generics for tb
    g_use_uniNoise_file : boolean  := true;
    g_in_en             : natural  := 1;     -- 1 = always active, others = random control
    -- generics for rTwoSDF
    g_use_reorder       : boolean  := false;  -- tb supports both true and false
    g_nof_points        : natural  := 1024;
    g_in_dat_w          : natural  := 8;   
    g_out_dat_w         : natural  := 14;   
    g_guard_w           : natural  := 2;      -- guard bits are used to avoid overflow in single FFT stage.
    g_diff_margin       : natural  := 2;
    g_file_loc_prefix   : string   := "./";
    g_twid_file_stem    : string   := "UNUSED"
  );
  port(
    o_rst       : out std_logic;
    o_clk       : out std_logic;
    o_tb_end    : out std_logic;
    o_test_msg  : out string(1 to 80);
    o_test_pass : out boolean
  );
end entity tb_rTwoSDF;


architecture tb of tb_rTwoSDF is

  constant c_clk_period : time    := 20 ns;      
  
  constant c_nof_points_w : natural := ceil_log2(g_nof_points);
  
  -- input/output data width
  constant c_stage_dat_w : natural := sel_a_b(g_out_dat_w > c_dsp_mult_w, g_out_dat_w, c_dsp_mult_w); -- number of bits used between the stages

  -- input/output files
  constant c_file_len   : natural := 8*g_nof_points;
  constant c_repeat     : natural := 2;  -- >= 2 to have sufficent frames for c_outputFile evaluation by testFFT_output.m

  -- input from uniform noise file created automatically by MATLAB testFFT_input.m
  constant c_noiseInputFile    : string := g_file_loc_prefix & "data/test/in/uniNoise_p"  & natural'image(g_nof_points)& "_b"& natural'image(g_in_dat_w) &"_in.txt";
  constant c_noiseGoldenFile   : string := g_file_loc_prefix & "data/test/out/uniNoise_p" & natural'image(g_nof_points)& "_in"& natural'image(g_in_dat_w) &"_out"&natural'image(g_out_dat_w) &"_out.txt";
  constant c_noiseOutputFile   : string := g_file_loc_prefix & "data/test/out/uniNoise_out.txt";

  -- input from manually created file
  constant c_impulseInputFile  : string := g_file_loc_prefix & "data/test/in/impulse_p"   & natural'image(g_nof_points)& "_b"& natural'image(g_in_dat_w)& "_in.txt";
  constant c_impulseGoldenFile : string := g_file_loc_prefix & "data/test/out/impulse_p"  & natural'image(g_nof_points)& "_b"& natural'image(g_in_dat_w)& "_out.txt";
  constant c_impulseOutputFile : string := g_file_loc_prefix & "data/test/out/impulse_out.txt";

  -- determine active stimuli and result files
  constant c_inputFile  : string := sel_a_b(g_use_uniNoise_file, c_noiseInputFile,  c_impulseInputFile);
  constant c_goldenFile : string := sel_a_b(g_use_uniNoise_file, c_noiseGoldenFile, c_impulseGoldenFile);
  constant c_outputFile : string := sel_a_b(g_use_uniNoise_file, c_noiseOutputFile, c_impulseOutputFile);

  -- signal definitions
  signal tb_end         : std_logic := '0';
  signal clk            : std_logic := '0';
  signal rst            : std_logic := '0';
  signal enable         : std_logic := '1';
  signal random         : std_logic_vector(15 downto 0) := (others=>'0');  -- use different lengths to have different random sequences
  signal in_en          : std_logic := '0';

  signal in_re          : std_logic_vector(g_in_dat_w-1 downto 0);
  signal in_im          : std_logic_vector(g_in_dat_w-1 downto 0);
  signal in_sync        : std_logic:= '0';
  signal in_val         : std_logic:= '0';

  signal out_re         : std_logic_vector(g_out_dat_w-1 downto 0);
  signal out_im         : std_logic_vector(g_out_dat_w-1 downto 0);
  signal out_sync       : std_logic:= '0';
  signal out_val        : std_logic:= '0';
  signal s_ovflw          : std_logic_vector(c_nof_points_w-1 downto 0);

  signal in_file_data   : t_integer_matrix(0 to c_file_len-1, 1 to 2) := (others=>(others=>0));  -- [re, im]
  signal in_file_sync   : std_logic_vector(0 to c_file_len-1):= (others=>'0');
  signal in_file_val    : std_logic_vector(0 to c_file_len-1):= (others=>'0');

  signal in_index       : natural := 0;
  signal in_repeat      : natural := 0;

  signal gold_file_data : t_integer_matrix(0 to c_file_len-1, 1 to 2) := (others=>(others=>0));  -- [re, im]
  signal gold_file_sync : std_logic_vector(0 to c_file_len-1):= (others=>'0');
  signal gold_file_val  : std_logic_vector(0 to c_file_len-1):= (others=>'0');
  
  signal gold_index_max : natural := c_file_len - 2*g_nof_points;
  signal gold_index     : natural;
  signal flip_index     : natural;
  signal gold_sync      : std_logic;
  signal gold_re        : integer;
  signal gold_im        : integer;

  signal diff_re        : integer;
  signal diff_im        : integer;
  signal sint_re        : integer;
  signal sint_im        : integer;
  
begin

  clk <= (not clk) or tb_end after c_clk_period/2;
  rst <= '1', '0' after c_clk_period*7;
  o_clk <= clk;
  o_rst <= rst;
  o_tb_end <= tb_end;

  enable <= '0', '1' after c_clk_period*23;
  random <= func_common_random(random) when rising_edge(clk);
  in_en <= '1' when g_in_en=1 else random(random'HIGH);
  

  p_read_input_file : process
    file v_input : TEXT open READ_MODE is c_inputFile;  -- this is LRM 1076-1987 style and implies that only simulator start and quit can open and close the file
    variable v_log_line    : LINE;
    variable v_input_line  : LINE;
    variable v_index       : integer :=0;
    variable v_comma       : character;
    variable v_sync        : std_logic_vector(0 to c_file_len-1):=(others=>'0');
    variable v_val         : std_logic_vector(0 to c_file_len-1):=(others=>'0');
    variable v_data        : t_integer_matrix(0 to c_file_len-1, 1 to 2) := (others=>(others=>0));
  begin
    -- wait 1 clock cycle to avoid that the output messages in the transcript window get lost in the 0 ps start up messages 
    proc_common_wait_some_cycles(clk, 1);
    -- combinatorially read the file into the array
    write(v_log_line, string'("reading stimuli file : "));
    write(v_log_line, c_inputFile);
    writeline(output, v_log_line);
    loop
      exit when endfile(v_input);
      readline(v_input, v_input_line);

      read(v_input_line, v_sync(v_index));    -- sync
      read(v_input_line, v_comma);

      read(v_input_line, v_val(v_index));     -- valid
      read(v_input_line, v_comma);

      read(v_input_line, v_data(v_index,1));  -- real
      read(v_input_line, v_comma);

      read(v_input_line, v_data(v_index,2));  -- imag
      v_index := v_index + 1;
    end loop;
    write(v_log_line, string'("finished reading stimuli file"));
    writeline(output, v_log_line);

    in_file_data <= v_data;
    in_file_sync <= v_sync;
    in_file_val  <= v_val;
    wait;
  end process;

  p_in_stimuli : process(clk, rst)
  begin
    if rst='1' then
      in_re   <= (others=>'0');
      in_im   <= (others=>'0');
      in_sync <= '0';
      in_val  <= '0';

      in_index  <=  0;
      in_repeat <=  0;
    elsif rising_edge(clk) then

      in_sync <= '0';
      in_val  <= '0';

      -- start stimuli some arbitrary time after rst release to ensure that the proper behaviour of the DUT does not depend on that time
      if enable='1' then
        -- use always active input (the in_file contents may still contain blocks with in_val='0') or use random active input
        if in_en='1' then
          if in_index<c_file_len-1 then
            in_index <= in_index+1;
          else
            in_index <= 0;
            in_repeat <= in_repeat + 1;
          end if;
    
          if in_repeat < c_repeat then
            in_re   <= std_logic_vector(to_signed(in_file_data(in_index, 1), g_in_dat_w));
            in_im   <= std_logic_vector(to_signed(in_file_data(in_index, 2), g_in_dat_w));
            in_sync <= std_logic(in_file_sync(in_index));
            in_val  <= std_logic(in_file_val(in_index));
          end if;
          
          if in_repeat > c_repeat then
            tb_end <= '1';
          end if;
        end if;
      end if;
      
    end if;
  end process;

  -- DUT = Device Under Test
  u_rTwoSDF : entity work.rTwoSDF
  generic map(
    -- generics for the FFT
    g_use_reorder => g_use_reorder,
    g_in_dat_w    => g_in_dat_w,
    g_out_dat_w   => g_out_dat_w, 
    g_stage_dat_w => c_stage_dat_w,
    g_guard_w     => g_guard_w,
    g_nof_points  => g_nof_points,
    -- generics for rTwoSDFStage
    g_variant     => "4DSP",   -- Use 3DSP or 4DSP for multiplication
    g_twid_file_stem => g_twid_file_stem
  )
  port map(
    clk       => clk,
    rst       => rst,
    in_re     => in_re,
    in_im     => in_im,
    in_val    => in_val,
    shiftreg  => (0=>'0', 1=>'0', others=>'1'),
    out_re    => out_re,
    out_im    => out_im,
    out_val   => out_val,
    ovflw     => s_ovflw
  );   

  -- Read golden file with the expected DUT output
  p_read_golden_file : process
    file v_golden : TEXT open READ_MODE is c_goldenFile;  -- this is LRM 1076-1987 style and implies that only simulator start and quit can open and close the file
    variable v_log_line    : LINE;
    variable v_golden_line : LINE;
    variable v_index       : integer :=0;
    variable v_comma       : character;
    variable v_sync        : std_logic_vector(0 to c_file_len-1):=(others=>'0');
    variable v_val         : std_logic_vector(0 to c_file_len-1):=(others=>'0');
    variable v_data        : t_integer_matrix(0 to c_file_len-1, 1 to 2) := (others=>(others=>0));
  begin
    -- wait 1 clock cycle to avoid that the output messages in the transcript window get lost in the 0 ps start up messages 
    proc_common_wait_some_cycles(clk, 1);
    -- combinatorially read the file into the array
    write(v_log_line, string'("reading golden file : "));
    write(v_log_line, c_goldenFile);
    writeline(output, v_log_line);
    loop
      exit when endfile(v_golden);
      readline(v_golden, v_golden_line);

      read(v_golden_line, v_sync(v_index));    -- sync
      read(v_golden_line, v_comma);

      read(v_golden_line, v_val(v_index));     -- valid
      read(v_golden_line, v_comma);

      read(v_golden_line, v_data(v_index,1));  -- real
      read(v_golden_line, v_comma);

      read(v_golden_line, v_data(v_index,2));  -- imag
      v_index := v_index + 1;
    end loop;
    write(v_log_line, string'("finished reading golden file"));
    writeline(output, v_log_line);

    gold_file_data <= v_data;
    gold_file_sync <= v_sync;
    gold_file_val  <= v_val;
    wait;
  end process;
  
  -- Show read data in Wave Window for debug purposes
  gold_index <= gold_index + 1 when rising_edge(clk) and out_val='1';
  flip_index <= (gold_index / g_nof_points) * g_nof_points + flip(gold_index mod g_nof_points, c_nof_points_w);
  gold_sync  <= gold_file_sync(gold_index);
  gold_re    <= gold_file_data(gold_index,1) when g_use_reorder=true else gold_file_data(flip_index,1);
  gold_im    <= gold_file_data(gold_index,2) when g_use_reorder=true else gold_file_data(flip_index,2);
  sint_re <= TO_SINT(out_re);
  sint_im <= TO_SINT(out_im);
  diff_re <= (sint_re - gold_re);
  diff_im <= (sint_im - gold_im);

  -- Verify the output of the DUT with the expected output from the golden reference file
  p_verify_output : process(clk)
  VARIABLE v_test_pass_sync : BOOLEAN := TRUE;
  VARIABLE v_test_pass_re : BOOLEAN := TRUE;
  VARIABLE v_test_pass_im : BOOLEAN := TRUE;
  begin
    -- Compare
    if rising_edge(clk) then
      if out_val='1' and gold_index <= gold_index_max then
        -- only write when out_val='1', because then the file is independent of cycles with invalid out_dat
        v_test_pass_sync := out_sync = gold_sync;
        if not v_test_pass_sync then
          o_test_msg <= pad("Output sync error",o_test_msg'length,'.');
          report "Output sync error"      severity failure;
        end if;
        v_test_pass_re := diff_re >= -g_diff_margin and diff_re <= g_diff_margin;
        if not v_test_pass_re then
          o_test_msg <= pad("Output real data error, expected: " & integer'image(gold_re) & " but got: " & integer'image(sint_re),o_test_msg'length,'.');
          report "Output real data error, expected: " & integer'image(gold_re) & " but got: " & integer'image(sint_re) severity failure;
        end if;
        v_test_pass_im := diff_im >= -g_diff_margin and diff_im <= g_diff_margin;
        if not v_test_pass_im then
          o_test_msg <= pad("Output imag data error, expected: " & integer'image(gold_im) & " but got: " & integer'image(sint_im),o_test_msg'length,'.');
          report "Output imag data error, expected: " & integer'image(gold_im) & " but got: " & integer'image(sint_im) severity failure;
        end if;
      end if;
    end if;
    o_test_pass <= v_test_pass_sync or v_test_pass_re or v_test_pass_im;
  end process;
  
  -- Write to default output file, this allows using command line diff or graphical diff viewer to compare it with the golden result file
  p_write_output_file : process(clk)
    file     v_output : TEXT open WRITE_MODE is c_outputFile;  -- this is LRM 1076-1987 style and implies that only simulator start and quit can open and close the file
    variable v_line   : LINE;
  begin
    if rising_edge(clk) then
      if out_val='1' then
        -- only write when out_val='1', because then the file is independent of cycles with invalid out_dat
        write(v_line, out_sync);
        write(v_line, string'(","));
        write(v_line, out_val);
        write(v_line, string'(","));
        write(v_line, to_integer(signed(out_re)));
        write(v_line, string'(","));
        write(v_line, to_integer(signed(out_im)));
        writeline(v_output, v_line);
      end if;
    end if;
  end process;

end tb;
