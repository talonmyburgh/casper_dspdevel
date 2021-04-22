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

-- Usage:
-- > as 10
-- > run -all
-- . Observe in_data_arr_p and the expected result and the result of the DUT in the Wave window
-- . This TB verifies the DUT architecture that was compile last. Default after a fresh mk the (str)
--   is compiled last, to simulate the (recursive) manually compile it and the simulate again.
--   Within the recursive architecture it is not possible to explicitely configure it to recursively 
--   use the recursive architecture using FOR ALL : ENTITY because the instance label is within a
--   generate block.
-- . The p_verify makes the tb self checking and asserts when the results are not equal
  
LIBRARY IEEE, common_pkg_lib, common_components_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;


ENTITY tb_common_adder_tree IS
  GENERIC (
    g_representation : STRING  := "SIGNED";
    g_pipeline       : NATURAL := 1;  -- amount of pipelining per stage
    g_nof_inputs     : NATURAL := 31;  -- >= 1
    g_symbol_w       : NATURAL := 8;
    g_sum_w          : NATURAL := 8  -- worst case bit growth requires g_symbol_w + ceil_log2(g_nof_inputs);
  );
END tb_common_adder_tree;


ARCHITECTURE tb OF tb_common_adder_tree IS

  CONSTANT clk_period      : TIME := 10 ns;
  
  CONSTANT c_data_vec_w    : NATURAL := g_nof_inputs*g_symbol_w;
  CONSTANT c_nof_stages    : NATURAL := ceil_log2(g_nof_inputs);
  
  CONSTANT c_pipeline_tree : NATURAL := g_pipeline*c_nof_stages;
  
  TYPE t_symbol_arr IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(g_symbol_w-1 DOWNTO 0);  
  
  -- Use the same symbol value g_nof_inputs time in the data_vec
  FUNCTION func_data_vec(symbol : INTEGER) RETURN STD_LOGIC_VECTOR IS
    VARIABLE v_data_vec : STD_LOGIC_VECTOR(c_data_vec_w-1 DOWNTO 0);
  BEGIN
    FOR I IN 0 TO g_nof_inputs-1 LOOP
      v_data_vec((I+1)*g_symbol_w-1 DOWNTO I*g_symbol_w) := TO_UVEC(symbol, g_symbol_w);
    END LOOP;
    RETURN v_data_vec;
  END;
  
  -- Calculate the expected result of the sum of the symbols in the data_vec
  FUNCTION func_result(data_vec : STD_LOGIC_VECTOR) RETURN STD_LOGIC_VECTOR IS
    VARIABLE v_result : INTEGER;
  BEGIN
    v_result := 0;
    IF g_representation="SIGNED" THEN
      FOR I IN 0 TO g_nof_inputs-1 LOOP
        v_result := v_result + TO_SINT(data_vec((I+1)*g_symbol_w-1 DOWNTO I*g_symbol_w));
      END LOOP;
      v_result := RESIZE_SINT(v_result, g_sum_w);
      RETURN TO_SVEC(v_result, g_sum_w);
    ELSE
      FOR I IN 0 TO g_nof_inputs-1 LOOP
        v_result := v_result + TO_UINT(data_vec((I+1)*g_symbol_w-1 DOWNTO I*g_symbol_w));
      END LOOP;
      v_result := RESIZE_UINT(v_result, g_sum_w);
      RETURN TO_UVEC(v_result, g_sum_w);
    END IF;
  END;

  SIGNAL rst                : STD_LOGIC;
  SIGNAL clk                : STD_LOGIC := '1';
  SIGNAL tb_end             : STD_LOGIC := '0';
  
  SIGNAL result_comb        : STD_LOGIC_VECTOR(g_sum_w-1 DOWNTO 0);  -- expected combinatorial sum
  
  SIGNAL in_data_vec        : STD_LOGIC_VECTOR(c_data_vec_w-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL in_data_vec_p      : STD_LOGIC_VECTOR(c_data_vec_w-1 DOWNTO 0);
  SIGNAL in_data_arr_p      : t_symbol_arr(0 TO g_nof_inputs-1);
  
  SIGNAL result_expected    : STD_LOGIC_VECTOR(g_sum_w-1 DOWNTO 0);  -- expected pipelined sum
  SIGNAL result_dut         : STD_LOGIC_VECTOR(g_sum_w-1 DOWNTO 0);  -- DUT sum
  
BEGIN

  clk <= NOT clk OR tb_end AFTER clk_period/2;
  rst <= '1', '0' AFTER clk_period*3;
  
  p_stimuli : PROCESS
  BEGIN
    in_data_vec <= (OTHERS=>'0');
    proc_common_wait_until_low(clk, rst);
    proc_common_wait_some_cycles(clk, 5);

    -- Apply equal symbol value inputs
    FOR I IN 0 TO 2**g_symbol_w-1 LOOP
      in_data_vec <= func_data_vec(I);
      proc_common_wait_some_cycles(clk, 1);
    END LOOP;
    in_data_vec <= (OTHERS=>'0');
    proc_common_wait_some_cycles(clk, 50);
    tb_end <= '1';
        
    WAIT;
  END PROCESS;
  
  -- For easier manual analysis in the wave window:
  -- . Pipeline the in_data_vec to align with the result
  -- . Map the concatenated symbols in in_data_vec into an in_data_arr_p array 
  u_data_vec_p : ENTITY common_components_lib.common_pipeline
  GENERIC MAP (
    g_representation => g_representation,
    g_pipeline       => c_pipeline_tree,
    g_reset_value    => 0,
    g_in_dat_w       => c_data_vec_w,
    g_out_dat_w      => c_data_vec_w
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    clken   => '1',
    in_dat  => in_data_vec,
    out_dat => in_data_vec_p
  );
  
  p_data_arr : PROCESS(in_data_vec_p)
  BEGIN
    FOR I IN 0 TO g_nof_inputs-1 LOOP
      in_data_arr_p(I) <= in_data_vec_p((I+1)*g_symbol_w-1 DOWNTO I*g_symbol_w);
    END LOOP;
  END PROCESS;
  
  result_comb <= func_result(in_data_vec);
  
  u_result : ENTITY common_components_lib.common_pipeline
  GENERIC MAP (
    g_representation => g_representation,
    g_pipeline       => c_pipeline_tree,
    g_reset_value    => 0,
    g_in_dat_w       => g_sum_w,
    g_out_dat_w      => g_sum_w
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    clken   => '1',
    in_dat  => result_comb,
    out_dat => result_expected
  );
  
  -- Using work.common_adder_tree(recursive) will only invoke the recursive architecture once, because the next recursive level will default to using the last compiled architecture
  -- Therefore only instatiatiate the DUT once in this tb and use compile order to influence which architecture is used.
  dut : ENTITY work.common_adder_tree  -- uses last compile architecture
  GENERIC MAP (
    g_representation => g_representation,
    g_pipeline       => g_pipeline,
    g_nof_inputs     => g_nof_inputs,
    g_dat_w          => g_symbol_w,
    g_sum_w          => g_sum_w
  )
  PORT MAP (
    clk    => clk,
    in_dat => in_data_vec,
    sum    => result_dut
  );
      
  p_verify : PROCESS(rst, clk)
  BEGIN
    IF rst='0' THEN
      IF rising_edge(clk) THEN
        ASSERT result_dut = result_expected REPORT "Error: wrong result_dut" SEVERITY ERROR;
      END IF;
    END IF;
  END PROCESS;
  
END tb;
