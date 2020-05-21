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
-- Purpose: The fft_r2_wide unit performs a complex FFT that is partly pipelined 
--          and partly parallel. 
--
-- Description:
--  The fft_r2_wide supports:
--
--  * Complex input
--    For complex input use_separate = false.
--
--    When use_reorder=true then the output bins of the FFT are re-ordered to 
--    undo the bit-reversed (or bit-flipped) default radix 2 FFT output order.
--    The fft_r2_wide then outputs first 0 Hz and the positive frequencies
--    and then the negative frequencies. The use_reorder is performed at both
--    the pipelined stage and the parallel stage.
--
--    When use_fft_shift=true then the fft_r2_wide then outputs the frequency
--    bins in incrementing order, so first the negative frequencies, then 0 Hz
--    and then the positive frequencies.
--    When use_fft_shift = true then also use_reorder must be true.
--
--  * Two real inputs:
--    When use_separate=true then the fft_r2_wide can be used to process two
--    real streams. The first real stream (A) presented on the real input, the
--    second real stream (B) presented on the imaginary input. The separation
--    unit outputs the spectrum of A and B in an alternating way.
--    When use_separate = true then also use_reorder must be true.
--    When use_separate = true then the use_fft_shift must be false, because
--    fft_shift() only applies to spectra for complex input.
--
-- Remarks:
-- . This fft_r2_wide also support wb_factor = 1 (= only a fft_r2_pipe
--   instance) or wb_factor = g_fft.nof_points (= only a fft_r2_par instance).
--   Care must be taken to properly account for guard_w and out_gain_w,
--   therefore it is best to simply use a structural approach that generates
--   seperate instances for each case:
--   . wb_factor = 1                                  --> pipe
--   . wb_factor > 1 AND wb_factor < g_fft.nof_points --> wide
--   . wb_factor = g_fft.nof_points                   --> par
-- . This fft_r2_wide uses the use_reorder in the pipeline FFT, in the parallel
--   FFT and also has reorder memory in the fft_sepa_wide instance. The reorder
--   memories in the FFTs can maybe be saved by using only the reorder memory
--   in the fft_sepa_wide instance. This would require changing the indexing in
--   fft_sepa_wide instance.
-- . The reorder memory in the pipeline FFT, parallel FFT and in the
--   fft_sepa_wide could make reuse of a reorder component from the reorder
--   library instead of using a dedicated local solution.

library ieee, common_pkg_lib, common_components_lib, casper_requantize_lib, r2sdf_fft_lib;
use IEEE.std_logic_1164.all;
use common_pkg_lib.common_pkg.all;
use r2sdf_fft_lib.rTwoSDFPkg.all;
use work.fft_pkg.all; 

entity fft_r2_wide is
  generic (
    g_fft          : t_fft := c_fft;                   -- generics for the FFT
    g_pft_pipeline : t_fft_pipeline := c_fft_pipeline; -- For the pipelined part, from r2sdf_fft_lib.rTwoSDFPkg
    g_fft_pipeline : t_fft_pipeline := c_fft_pipeline  -- For the parallel part, from r2sdf_fft_lib.rTwoSDFPkg
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic := '0';
    in_re_arr  : in  t_fft_slv_arr(g_fft.wb_factor-1 downto 0); -- = time samples t3, t2, t1, t0
    in_im_arr  : in  t_fft_slv_arr(g_fft.wb_factor-1 downto 0);
    in_val     : in  std_logic := '1';
    out_re_arr : out t_fft_slv_arr(g_fft.wb_factor-1 downto 0);
    out_im_arr : out t_fft_slv_arr(g_fft.wb_factor-1 downto 0);
    out_val    : out std_logic
  );
end entity fft_r2_wide;

architecture rtl of fft_r2_wide is

  type t_fft_arr is array(integer range <> ) of t_fft;  -- An array of t_fft's generics. 
  
  ----------------------------------------------------------
  -- This function creates an array of t_fft generics 
  -- for the pipelined fft's of the first stage.The array is 
  -- based on the g_fft generic that belongs to the 
  -- fft_r2_wide entity. 
  -- Most imortant in the settings are twiddle_offset and 
  -- the nof_points.
  ----------------------------------------------------------
  function func_create_generic_for_pipe_fft(input : t_fft) return t_fft_arr is
    variable v_nof_points : natural := input.nof_points/input.wb_factor;                 -- The nof_points for the pipelined fft stages
    variable v_return     : t_fft_arr(input.wb_factor-1 downto 0) := (others => input);  -- Variable that holds the return values
  begin
    for I in 0 to input.wb_factor-1 loop
      v_return(I).use_reorder    := input.use_reorder; -- Pass on use_reorder
      v_return(I).use_fft_shift  := false;             -- FFT shift function is forced to false
      v_return(I).use_separate   := false;             -- Separate function is forced to false. 
      v_return(I).twiddle_offset := I;                 -- Twiddle offset is set to the order number of the pipelined fft. 
      v_return(I).nof_points     := v_nof_points;      -- Set the nof points 
      v_return(I).in_dat_w       := input.stage_dat_w; -- Set the input width  
      v_return(I).out_dat_w      := input.stage_dat_w; -- Set the output width. 
      v_return(I).out_gain_w     := 0;                 -- Output gain is forced to 0
      v_return(I).guard_w        := 0;                 -- Set the guard_w to 0 to enable scaling at every stage. 
      v_return(I).guard_enable   := false;             -- No input guard. 
    end loop;                               
    return v_return; 
  end;

  ----------------------------------------------------------
  -- This function creates t_fft generic for the 
  -- parallel fft stage, based on the g_fft generic that 
  -- belongs to the fft_r2_wide entity. 
  ----------------------------------------------------------
  function func_create_generic_for_par_fft(input : t_fft) return t_fft is
    variable v_return         : t_fft   := input;  -- Variable that holds the return value
  begin                                     
      v_return.use_reorder    := input.use_reorder;    -- Pass on use_reorder
      v_return.use_fft_shift  := input.use_fft_shift;  -- Pass on use_fft_shift
      v_return.use_separate   := false;                -- Separate function is forced to false, because it is handled outside the parallel fft
      v_return.twiddle_offset := 0;                    -- Twiddle offset is forced to 0, which is also the input.twiddle_offset default
      v_return.nof_points     := input.wb_factor;      -- Set the number of points to wb_factor
      v_return.in_dat_w       := input.stage_dat_w;    -- Specify the input width
      v_return.out_dat_w      := input.stage_dat_w;    -- Output width 
      v_return.out_gain_w     := 0;                    -- Output gain is forced to 0, because it is handled outside the parallel fft
      v_return.guard_w        := input.guard_w;        -- Set the guard_w here to skip the scaling on the last stages
      v_return.guard_enable   := false;                -- No input guard. 
    return v_return; 
  end;
  
  constant c_pipeline_remove_lsb : natural := 0;
  
  constant c_fft_r2_pipe_arr  : t_fft_arr(g_fft.wb_factor-1 downto 0) := func_create_generic_for_pipe_fft(g_fft); 
  constant c_fft_r2_par       : t_fft                                 := func_create_generic_for_par_fft(g_fft);
  
  constant c_in_scale_w       : natural := g_fft.stage_dat_w - g_fft.in_dat_w - sel_a_b(g_fft.guard_enable, g_fft.guard_w, 0);              
  
  constant c_out_scale_w      : integer := c_fft_r2_par.out_dat_w - g_fft.out_dat_w - g_fft.out_gain_w;  -- Estimate number of LSBs to throw away when > 0 or insert when < 0

  signal in_fft_pipe_re_arr   : t_fft_slv_arr(g_fft.wb_factor-1 downto 0);
  signal in_fft_pipe_im_arr   : t_fft_slv_arr(g_fft.wb_factor-1 downto 0);
    
  signal out_fft_pipe_re_arr  : t_fft_slv_arr(g_fft.wb_factor-1 downto 0);
  signal out_fft_pipe_im_arr  : t_fft_slv_arr(g_fft.wb_factor-1 downto 0);

  signal in_fft_par_re_arr    : t_fft_slv_arr(g_fft.wb_factor-1 downto 0);
  signal in_fft_par_im_arr    : t_fft_slv_arr(g_fft.wb_factor-1 downto 0);

  signal fft_pipe_out_re      : std_logic_vector(g_fft.out_dat_w-1 downto 0);
  signal fft_pipe_out_im      : std_logic_vector(g_fft.out_dat_w-1 downto 0);
  
  signal fft_out_re_arr       : t_fft_slv_arr(g_fft.wb_factor-1 downto 0);
  signal fft_out_im_arr       : t_fft_slv_arr(g_fft.wb_factor-1 downto 0);
  signal fft_out_val          : std_logic;                                   
  
  signal sep_out_re_arr       : t_fft_slv_arr(g_fft.wb_factor-1 downto 0);   
  signal sep_out_im_arr       : t_fft_slv_arr(g_fft.wb_factor-1 downto 0);   
  signal sep_out_val          : std_logic;                                   

  signal int_val              : std_logic_vector(g_fft.wb_factor-1 downto 0);
  
  signal out_cplx             : std_logic_vector(c_nof_complex*g_fft.stage_dat_w-1 downto 0);
  signal in_cplx              : std_logic_vector(c_nof_complex*g_fft.stage_dat_w-1 downto 0);

begin

  -- Default to fft_r2_pipe when g_fft.wb_factor=1
  gen_fft_r2_pipe : if g_fft.wb_factor=1 generate
    u_fft_r2_pipe : entity work.fft_r2_pipe
    generic map (
      g_fft      => g_fft,
      g_pipeline => g_pft_pipeline
    )
    port map (
      clk        => clk,
      rst        => rst,
      in_re      => in_re_arr(0)(g_fft.in_dat_w-1 downto 0),
      in_im      => in_im_arr(0)(g_fft.in_dat_w-1 downto 0),
      in_val     => in_val,
      out_re     => fft_pipe_out_re,
      out_im     => fft_pipe_out_im,
      out_val    => out_val
    );
    
    out_re_arr(0) <= resize_fft_svec(fft_pipe_out_re);
    out_im_arr(0) <= resize_fft_svec(fft_pipe_out_im);
  end generate;
  
  -- Default to fft_r2_par when g_fft.wb_factor=g_fft.nof_points
  gen_fft_r2_par : if g_fft.wb_factor=g_fft.nof_points generate
    u_fft_r2_par : entity work.fft_r2_par
    generic map (
      g_fft      => g_fft,
      g_pipeline => g_fft_pipeline
    )
    port map (
      clk        => clk,
      rst        => rst,
      in_re_arr  => in_re_arr,
      in_im_arr  => in_im_arr,
      in_val     => in_val,
      out_re_arr => out_re_arr,
      out_im_arr => out_im_arr,
      out_val    => out_val
    );
  end generate;
  
  -- Create wideband FFT as combinination of g_fft.wb_factor instances of fft_r2_pipe with one instance of fft_r2_par
  gen_fft_r2_wide : if g_fft.wb_factor>1 and g_fft.wb_factor<g_fft.nof_points generate
  
    ---------------------------------------------------------------
    -- PIPELINED FFT STAGE
    ---------------------------------------------------------------

    -- Inputs are prepared/scaled for the pipelined ffts
    gen_fft_pipe_inputs : for I in 0 to g_fft.wb_factor-1 generate
      in_fft_pipe_re_arr(I) <= scale_and_resize_svec(in_re_arr(I), c_in_scale_w, c_fft_slv_w);
      in_fft_pipe_im_arr(I) <= scale_and_resize_svec(in_im_arr(I), c_in_scale_w, c_fft_slv_w);
    end generate;   
    
    -- The first stage of the wideband fft consist of the generation of g_fft.wb_factor
    -- pipelined fft's. These pipelines fft's operate in parallel.   
    gen_pipelined_ffts : for I in g_fft.wb_factor-1 downto 0 generate
      u_pft : entity work.fft_r2_pipe
      generic map (
        g_fft      => c_fft_r2_pipe_arr(I),   -- generics for the pipelined FFTs
        g_pipeline => g_pft_pipeline          -- pipeline generics for the pipelined FFTs
      )
      port map (
        clk       => clk,
        rst       => rst,
        in_re     => in_fft_pipe_re_arr(I)(c_fft_r2_pipe_arr(I).in_dat_w-1 downto 0),
        in_im     => in_fft_pipe_im_arr(I)(c_fft_r2_pipe_arr(I).in_dat_w-1 downto 0),
        in_val    => in_val,
        out_re    => out_fft_pipe_re_arr(I)(c_fft_r2_pipe_arr(I).out_dat_w-1 downto 0),
        out_im    => out_fft_pipe_im_arr(I)(c_fft_r2_pipe_arr(I).out_dat_w-1 downto 0),
        out_val   => int_val(I)
      );     
    end generate;       
    
    
    ---------------------------------------------------------------
    -- PARALLEL FFT STAGE
    ---------------------------------------------------------------

    -- Create input for parallel FFT
    gen_inputs_for_par : for I in g_fft.wb_factor-1 downto 0 generate
      in_fft_par_re_arr(I) <= resize_fft_svec(out_fft_pipe_re_arr(I)(c_fft_r2_pipe_arr(I).out_dat_w-1 downto 0));
      in_fft_par_im_arr(I) <= resize_fft_svec(out_fft_pipe_im_arr(I)(c_fft_r2_pipe_arr(I).out_dat_w-1 downto 0));
    end generate;
  
    -- The g_fft.wb_factor outputs of the pipelined fft's are offered
    -- to the input of a single parallel FFT. 
    u_fft : entity work.fft_r2_par
    generic map (
      g_fft      => c_fft_r2_par,           -- generics for the FFT
      g_pipeline => g_fft_pipeline          -- pipeline generics for the parallel FFT
    )
    port map (
      clk        => clk,
      rst        => rst,
      in_re_arr  => in_fft_par_re_arr,
      in_im_arr  => in_fft_par_im_arr,
      in_val     => int_val(0),
      out_re_arr => fft_out_re_arr,
      out_im_arr => fft_out_im_arr,
      out_val    => fft_out_val
    );
    
    ---------------------------------------------------------------
    -- OPTIONAL: SEPARATION STAGE
    ---------------------------------------------------------------
    -- When the separate functionality is required:
    gen_separate : if g_fft.use_separate generate 
      u_separator : entity work.fft_sepa_wide
      generic map (
        g_fft      => g_fft
      )
      port map (
        clk        => clk,
        rst        => rst,
        in_re_arr  => fft_out_re_arr, 
        in_im_arr  => fft_out_im_arr, 
        in_val     => fft_out_val,     
        out_re_arr => sep_out_re_arr, 
        out_im_arr => sep_out_im_arr, 
        out_val    => sep_out_val     
      );
    end generate;
    
     -- In case no separtion is required, the output of the parallel fft is used. 
    no_separate : if g_fft.use_separate=false generate 
      sep_out_re_arr <= fft_out_re_arr;    
      sep_out_im_arr <= fft_out_im_arr;    
      sep_out_val    <= fft_out_val;
    end generate;  
    
    ---------------------------------------------------------------
    -- OUTPUT QUANTIZER
    ---------------------------------------------------------------
    gen_output_requantizers : for I in g_fft.wb_factor-1 downto 0 generate
      u_requantize_output_re : entity casper_requantize_lib.common_requantize
      generic map (
        g_representation      => "SIGNED",      
        g_lsb_w               => c_out_scale_w,               
        g_lsb_round           => TRUE,           
        g_lsb_round_clip      => FALSE,      
        g_msb_clip            => FALSE,            
        g_msb_clip_symmetric  => FALSE,  
        g_pipeline_remove_lsb => c_pipeline_remove_lsb, 
        g_pipeline_remove_msb => 0, 
        g_in_dat_w            => g_fft.stage_dat_w,            
        g_out_dat_w           => g_fft.out_dat_w
      )
      port map (
        clk        => clk,
        in_dat     => sep_out_re_arr(I),
        out_dat    => out_re_arr(I), 
        out_ovr    => open
      );  
  
      u_requantize_output_im : entity casper_requantize_lib.common_requantize
      generic map (
        g_representation      => "SIGNED",      
        g_lsb_w               => c_out_scale_w,               
        g_lsb_round           => TRUE,           
        g_lsb_round_clip      => FALSE,      
        g_msb_clip            => FALSE,            
        g_msb_clip_symmetric  => FALSE,  
        g_pipeline_remove_lsb => c_pipeline_remove_lsb, 
        g_pipeline_remove_msb => 0, 
        g_in_dat_w            => g_fft.stage_dat_w,            
        g_out_dat_w           => g_fft.out_dat_w
      )
      port map (
        clk        => clk,
        in_dat     => sep_out_im_arr(I),
        out_dat    => out_im_arr(I), 
        out_ovr    => open
      );  
    end generate;     

    u_out_val : entity common_components_lib.common_pipeline_sl
    generic map (
      g_pipeline => c_pipeline_remove_lsb
    )
    port map (
      rst     => rst,
      clk     => clk,
      in_dat  => sep_out_val,
      out_dat => out_val
    );
    
  end generate;  
end rtl;
