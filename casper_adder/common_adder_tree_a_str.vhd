-------------------------------------------------------------------------------
--
-- Copyright (C) 2009
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

LIBRARY IEEE, common_pkg_lib, common_components_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

ARCHITECTURE str OF common_adder_tree IS

  -- common_add_sub pipelining
  CONSTANT c_pipeline_in  : NATURAL := 0;
  CONSTANT c_pipeline_out : NATURAL := g_pipeline;
  
  -- There is no need to internally work with the adder tree sum width for
  -- worst case bit growth of c_sum_w = g_dat_w+ceil_log2(g_nof_inputs),
  -- because any MSbits that are not in the output sum do not need to be kept
  -- at the internal stages either. The worst case bit growth for
  -- g_nof_inputs = 1 still becomes ceil_log2(g_nof_inputs) = 1, which can be
  -- regarded as due to an adder stage that adds 0 to the single in_dat.
  -- However it also does not cause extra logic to internally account for bit
  -- growth at every stage, because synthesis will optimize unused MSbits away
  -- when g_sum_w < c_sum_w.
  
  CONSTANT c_w            : NATURAL := g_dat_w;                          -- input data width
  CONSTANT c_sum_w        : NATURAL := g_dat_w+ceil_log2(g_nof_inputs);  -- adder tree sum width
  
  CONSTANT c_N            : NATURAL := g_nof_inputs;            -- nof inputs to the adder tree
  CONSTANT c_nof_stages   : NATURAL := ceil_log2(c_N);          -- nof stages in the adder tree
  
  -- Allocate c_sum_w for each field and allocate c_N fields for the input
  -- stage and use this array for all stages. Hence the stage vectors
  -- are longer than necessary and wider than necessary, but that is OK, the
  -- important thing is that they are sufficiently long.
  TYPE t_stage_arr IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_N*c_sum_w-1 DOWNTO 0);
  
  SIGNAL adds    : t_stage_arr(-1 TO c_nof_stages-1);
  
BEGIN

  -- The tabel below lists how many two port adders (+) and one port pipes (.)
  -- to match the adder latency, there are at each stage of the adder tree.
  --
  --         nof +,.   nof +,.   nof +,.   nof +,.        nof +,.
  --         stage 0   stage 1   stage 2   stage 3   -->  total
  -- N =  2    1,0       -         -         -              1
  --      3    1,1       1,0       -         -              3
  --      4    2,0       1,0       -         -              3
  --      5    2,1       1,1       1,0       -              6
  --      6    3,0       1,1       1,0       -              6
  --      7    3,1       2,0       1,0       -              7
  --      8    4,0       2,0       1,0       -              7
  --      9    4,1       2,1       1,1       1,0           11  < N + nof stages
  --     10    5,0       2,1       1,1       1,0           11
  --     11    5,1       3,0       1,1       1,0           12
  --     12    6,0       3,0       1,1       1,0           12
  --     13    6,1       3,1       2,0       1,0           14
  --
  --                                                                   input     output   nof
  --  stage   nof +                     nof .                         width     width    input
  --    -     -                         -                              -         w+0     -
  --    0    (N+0)/2                  ((N+0)/1) MOD 2                  w+0       w+1     N
  --    1    (N+1)/4                  ((N+1)/2) MOD 2                  w+1       w+2    (N+0)/2  + ((N+0)/1) MOD 2
  --    2    (N+3)/8                  ((N+3)/4) MOD 2                  w+2       w+3    (N+3)/8  + ((N+3)/4) MOD 2
  --    3    (N+7)/16                 ((N+7)/8) MOD 2                  w+3       w+4    (N+7)/16 + ((N+7)/8) MOD 2
  --                                                                               
  --    j    (N+(2**j)-1)/(2**(j+1))  ((N+(2**j)-1)/(2**j)) MOD 2      w+j       w+j+1
  
  -- Keep in_dat in stage -1 of adds. Store each subsequent stage of the adder
  -- tree in into adds. Until finally the total sum in the last stage.
  
  gen_tree : IF g_nof_inputs > 1 GENERATE
    -- Input wires
    adds(-1)(in_dat'RANGE) <= in_dat;
    
    -- Adder tree
    gen_stage : FOR j IN 0 TO c_nof_stages-1 GENERATE
      gen_add : FOR i IN 0 TO (c_N+(2**j)-1)/(2**(j+1)) - 1 GENERATE
        u_addj : ENTITY work.common_add_sub
        GENERIC MAP (
          g_direction       => "ADD",
          g_representation  => g_representation,
          g_pipeline_input  => c_pipeline_in,
          g_pipeline_output => c_pipeline_out,
          g_in_dat_w        => c_w+j,
          g_out_dat_w       => c_w+j+1
        )
        PORT MAP (
          clk     => clk,
          clken   => clken,
          in_a    => adds(j-1)((2*i+1)*(c_w+j)-1 DOWNTO (2*i+0)*(c_w+j)),
          in_b    => adds(j-1)((2*i+2)*(c_w+j)-1 DOWNTO (2*i+1)*(c_w+j)),
          result  => adds(j)((i+1)*(c_w+j+1)-1 DOWNTO i*(c_w+j+1))
        );
      END GENERATE;
      
      gen_pipe : IF ((c_N+(2**j)-1)/(2**j)) MOD 2 /= 0 GENERATE
        u_pipej : ENTITY common_components_lib.common_pipeline
        GENERIC MAP (
          g_representation => g_representation,
          g_pipeline       => g_pipeline,
          g_in_dat_w       => c_w+j,
          g_out_dat_w      => c_w+j+1
        )
        PORT MAP (
          clk     => clk,
          clken   => clken,
          in_dat  => adds(j-1)((2*((c_N+(2**j)-1)/(2**(j+1)))+1)*(c_w+j)-1 DOWNTO
                               (2*((c_N+(2**j)-1)/(2**(j+1)))+0)*(c_w+j)),
          out_dat => adds(j)(((c_N+(2**j)-1)/(2**(j+1))+1)*(c_w+j+1)-1 DOWNTO
                             ((c_N+(2**j)-1)/(2**(j+1))  )*(c_w+j+1))
        );
      END GENERATE;
    END GENERATE;
    
    -- Map final sum to larger output vector using sign extension or to smaller width output vector preserving the LS part
    sum <= RESIZE_SVEC(adds(c_nof_stages-1)(c_sum_w-1 DOWNTO 0), g_sum_w) WHEN g_representation="SIGNED" ELSE
           RESIZE_UVEC(adds(c_nof_stages-1)(c_sum_w-1 DOWNTO 0), g_sum_w);
  END GENERATE;  -- gen_tree

  no_tree : IF g_nof_inputs = 1 GENERATE
    -- For g_nof_inputs = 1 gen_tree yields wires sum <= in_dat, therefore
    -- here use common_pipeline to support g_pipeline. Note c_sum_w =
    -- g_dat_w+1 also for g_nof_inputs = 1, because we assume an adder stage
    -- that adds 0 to the single in_dat.
    u_reg : ENTITY common_components_lib.common_pipeline
    GENERIC MAP (
      g_representation => g_representation,
      g_pipeline       => g_pipeline,
      g_in_dat_w       => g_dat_w,
      g_out_dat_w      => g_sum_w
    )
    PORT MAP (
      clk     => clk,
      clken   => clken,
      in_dat  => in_dat,
      out_dat => sum
    );  
  END GENERATE;  -- no_tree
  
END str;
