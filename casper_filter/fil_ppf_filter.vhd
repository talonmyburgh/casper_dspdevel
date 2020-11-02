-------------------------------------------------------------------------------
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
-------------------------------------------------------------------------------
-- Purpose: A FIR filter implementation. 
--
-- Description: This unit instantiates a multiplier for every tap. 
--              All output of the mutipliers are added using an 
--              adder-tree structure. 
--              
-- Remarks:    .
--              

library IEEE, common_pkg_lib, astron_multiplier_lib, astron_requantize_lib, astron_adder_lib;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;
--USE technology_lib.technology_select_pkg.ALL;
use common_pkg_lib.common_pkg.ALL; 
use work.fil_pkg.ALL;

entity fil_ppf_filter is
  generic (
    g_technology       : NATURAL := 0;
    g_fil_ppf          : t_fil_ppf; 
    g_fil_ppf_pipeline : t_fil_ppf_pipeline
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;
    taps       : in  std_logic_vector;   
    coefs      : in  std_logic_vector;
    result     : out std_logic_vector
  ); 
end fil_ppf_filter;

architecture rtl of fil_ppf_filter is 

  constant c_in_dat_w       : natural := g_fil_ppf.backoff_w + g_fil_ppf.in_dat_w;        -- add optional input backoff to fit output overshoot
  constant c_prod_w         : natural := c_in_dat_w + g_fil_ppf.coef_dat_w - c_sign_w;    -- skip double sign bit
  constant c_gain_w         : natural := 0;   -- no need for adder bit growth so fixed 0, because filter coefficients should have DC gain <= 1.
                                              -- The adder tree bit growth depends on DC gain of FIR coefficients, not on ceil_log2(g_fil_ppf.nof_taps).
  constant c_sum_w          : natural := c_prod_w + c_gain_w;
  constant c_ppf_lsb_w      : natural := c_sum_w - g_fil_ppf.out_dat_w;
  
  signal prod_vec     : std_logic_vector(g_fil_ppf.nof_taps*c_prod_w-1 downto 0);
  signal adder_out    : std_logic_vector(c_sum_w-1 downto 0) := (others => '0');
  signal requant_out  : std_logic_vector(g_fil_ppf.out_dat_w-1 downto 0); 
  
  signal in_taps         : std_logic_vector(g_fil_ppf.in_dat_w*g_fil_ppf.nof_taps-1 downto 0);  -- taps input data as stored in RAM
  signal in_taps_backoff : std_logic_vector(        c_in_dat_w*g_fil_ppf.nof_taps-1 downto 0);  -- taps input data with backoff as use in FIR
  
begin 
    
  in_taps <= taps;  -- Use this help signal to create a 'HIGH downto 0 vector again.   
  ---------------------------------------------------------------
  -- GENERATE THE MUTIPLIERS
  ---------------------------------------------------------------
  -- For every tap a unique multiplier is instantiated that 
  -- multiplies the data tap with the corresponding filter coefficient
  gen_multipliers : for I in 0 to g_fil_ppf.nof_taps-1 generate
    in_taps_backoff((I+1)*c_in_dat_w-1 downto I*c_in_dat_w) <= resize_svec(in_taps((I+1)*g_fil_ppf.in_dat_w-1 downto I*g_fil_ppf.in_dat_w), c_in_dat_w);
    
    u_multiplier : entity astron_multiplier_lib.common_mult
    generic map (
      g_technology       => g_technology,
      g_variant          => "IP",
      g_in_a_w           => c_in_dat_w,   
      g_in_b_w           => g_fil_ppf.coef_dat_w, 
      g_out_p_w          => c_prod_w,           
      g_nof_mult         => 1,                    
      g_pipeline_input   => g_fil_ppf_pipeline.mult_input,
      g_pipeline_product => g_fil_ppf_pipeline.mult_product,  
      g_pipeline_output  => g_fil_ppf_pipeline.mult_output, 
      g_representation   => "SIGNED"            
    )
    port map (
      rst      => rst,
      clk      => clk,
      clken    => '1',
      in_a     => in_taps_backoff((I+1)*c_in_dat_w-1 downto I*c_in_dat_w),
      in_b     => coefs((I+1)*g_fil_ppf.coef_dat_w-1 downto I*g_fil_ppf.coef_dat_w),
      out_p    => prod_vec((I+1)*c_prod_w-1 downto I*c_prod_w)
    );
  end generate; 

  ---------------------------------------------------------------
  -- ADDER TREE
  ---------------------------------------------------------------  
  -- The adder tree summarizes the outputs of all multipliers.
  u_adder_tree : entity astron_adder_lib.common_adder_tree(str) 
  generic map (
    g_representation => "SIGNED",
    g_pipeline       => g_fil_ppf_pipeline.adder_stage,          
    g_nof_inputs     => g_fil_ppf.nof_taps,
    g_dat_w          => c_prod_w,
    g_sum_w          => c_sum_w 
  )
  port map (
    clk    => clk,
    in_dat => prod_vec,
    sum    => adder_out
  );
  
  u_requantize_addeer_output : entity astron_requantize_lib.common_requantize
  generic map (
    g_representation      => "SIGNED",      
    g_lsb_w               => c_ppf_lsb_w,  
    g_lsb_round           => TRUE,           
    g_lsb_round_clip      => FALSE,      
    g_msb_clip            => FALSE,            
    g_msb_clip_symmetric  => FALSE,  
    g_pipeline_remove_lsb => g_fil_ppf_pipeline.requant_remove_lsb, 
    g_pipeline_remove_msb => g_fil_ppf_pipeline.requant_remove_msb, 
    g_in_dat_w            => c_sum_w,            
    g_out_dat_w           => g_fil_ppf.out_dat_w
  )
  port map (
    clk        => clk,
    clken      => '1',
    in_dat     => adder_out,
    out_dat    => requant_out, 
    out_ovr    => open
  );                  
  
  result <= RESIZE_SVEC(requant_out, result'LENGTH); 

end rtl; 

