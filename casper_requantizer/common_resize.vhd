-------------------------------------------------------------------------------
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
-------------------------------------------------------------------------------

LIBRARY ieee, common_pkg_lib, common_components_lib;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;

ENTITY common_resize IS
  GENERIC (
    g_representation  : STRING  := "SIGNED";  -- SIGNED or UNSIGNED resizing
    g_clip            : BOOLEAN := FALSE;     -- when TRUE clip input if it is outside the output range, else wrap
    g_clip_symmetric  : BOOLEAN := FALSE;     -- when TRUE clip signed symmetric to +c_smax and -c_smax, else to +c_smax and c_smin_symm
                                              -- for wrapping when g_clip=FALSE the g_clip_symmetric is ignored, so signed wrapping is done asymmetric
    g_pipeline_input  : NATURAL := 0;         -- >= 0
    g_pipeline_output : NATURAL := 1;         -- >= 0
    g_in_dat_w        : INTEGER := 36;
    g_out_dat_w       : INTEGER := 18
  );
  PORT (
    clk        : IN  STD_LOGIC;
    clken      : IN  STD_LOGIC := '1';
    in_dat     : IN  STD_LOGIC_VECTOR(g_in_dat_w-1 DOWNTO 0);
    out_dat    : OUT STD_LOGIC_VECTOR(g_out_dat_w-1 DOWNTO 0);
    out_ovr    : OUT STD_LOGIC
  );
END;


ARCHITECTURE rtl OF common_resize IS

  -- Clipping is only necessary when g_out_dat_w<g_in_dat_w.
  CONSTANT c_clip      : BOOLEAN := g_clip AND (g_out_dat_w<g_in_dat_w);

  -- Use SIGNED, UNSIGNED to avoid NATURAL (32 bit range) overflow error
  CONSTANT c_umax      : UNSIGNED(out_dat'RANGE) := UNSIGNED(      c_slv1(g_out_dat_w-1 DOWNTO 0));  -- =  2** g_out_dat_w   -1
  CONSTANT c_smax      :   SIGNED(out_dat'RANGE) :=   SIGNED('0' & c_slv1(g_out_dat_w-2 DOWNTO 0));  -- =  2**(g_out_dat_w-1)-1
  CONSTANT c_smin_most :   SIGNED(out_dat'RANGE) :=   SIGNED('1' & c_slv0(g_out_dat_w-2 DOWNTO 0));  -- = -2**(c_in_dat_w-1)
  CONSTANT c_smin_symm :   SIGNED(out_dat'RANGE) := -c_smax;                                         -- = -2**(c_in_dat_w-1)+1
  CONSTANT c_smin      :   SIGNED(out_dat'RANGE) := sel_a_b(g_clip_symmetric, c_smin_symm, c_smin_most);
  
  SIGNAL reg_dat     : STD_LOGIC_VECTOR(in_dat'RANGE);
  SIGNAL wrap        : STD_LOGIC;
  SIGNAL clip        : STD_LOGIC;
  SIGNAL sign        : STD_LOGIC;
  SIGNAL res_ovr     : STD_LOGIC;
  SIGNAL res_dat     : STD_LOGIC_VECTOR(out_dat'RANGE);
  SIGNAL res_vec     : STD_LOGIC_VECTOR(g_out_dat_w DOWNTO 0);
  SIGNAL out_vec     : STD_LOGIC_VECTOR(g_out_dat_w DOWNTO 0);

BEGIN

  u_input_pipe : ENTITY common_components_lib.common_pipeline  -- pipeline input
  GENERIC MAP (
    g_representation => "SIGNED",
    g_pipeline       => g_pipeline_input,
    g_in_dat_w       => g_in_dat_w,
    g_out_dat_w      => g_in_dat_w
  )
  PORT MAP (
    clk     => clk,
    clken   => clken,
    in_dat  => in_dat,
    out_dat => reg_dat
  );
  
  no_clip : IF c_clip=FALSE GENERATE
    -- Note that g_pipeline_input=0 AND g_clip=FALSE is equivalent to using RESIZE_SVEC or RESIZE_UVEC directly.
    gen_s : IF g_representation="SIGNED" GENERATE
      -- If g_out_dat_w>g_in_dat_w then IEEE resize extends the sign bit,
      -- else IEEE resize preserves the sign bit and keeps the low part.
      wrap <= '1' WHEN SIGNED(reg_dat)>c_smax OR SIGNED(reg_dat)< c_smin_most ELSE '0';
      res_dat <= RESIZE_SVEC(reg_dat, g_out_dat_w);
      res_ovr <= wrap;
    END GENERATE;
    
    gen_u : IF g_representation="UNSIGNED" GENERATE
      -- If g_out_dat_w>g_in_dat_w then IEEE resize sign extends with '0',
      -- else IEEE resize keeps the low part.
      wrap <= '1' WHEN UNSIGNED(reg_dat)>c_umax ELSE '0';
      res_dat <= RESIZE_UVEC(reg_dat, g_out_dat_w);
      res_ovr <= wrap;
    END GENERATE;
  END GENERATE;
  
  gen_clip : IF c_clip=TRUE GENERATE
    gen_s_clip : IF g_representation="SIGNED" GENERATE
      clip <= '1' WHEN SIGNED(reg_dat)>c_smax OR SIGNED(reg_dat)< c_smin ELSE '0';
      sign <= reg_dat(reg_dat'HIGH);
      res_dat <= reg_dat(out_dat'RANGE) WHEN clip='0' ELSE STD_LOGIC_VECTOR( c_smax) WHEN sign='0' ELSE STD_LOGIC_VECTOR(c_smin);
      res_ovr <= clip;
    END GENERATE;
    
    gen_u_clip : IF g_representation="UNSIGNED" GENERATE
      clip <= '1' WHEN UNSIGNED(reg_dat)>c_umax ELSE '0';
      res_dat <= reg_dat(out_dat'RANGE) WHEN clip='0' ELSE STD_LOGIC_VECTOR(c_umax);
      res_ovr <= clip;
    END GENERATE;
  END GENERATE;
  
  res_vec <= res_ovr & res_dat;

  u_output_pipe : ENTITY common_components_lib.common_pipeline  -- pipeline output
  GENERIC MAP (
    g_representation => "SIGNED",
    g_pipeline       => g_pipeline_output,
    g_in_dat_w       => g_out_dat_w+1,
    g_out_dat_w      => g_out_dat_w+1
  )
  PORT MAP (
    clk     => clk,
    clken   => clken,
    in_dat  => res_vec,
    out_dat => out_vec
  );
  
  out_ovr <= out_vec(g_out_dat_w);
  out_dat <= out_vec(g_out_dat_w-1 DOWNTO 0);
  
END rtl;