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

LIBRARY IEEE, common_pkg_lib, common_components_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;


ENTITY tb_st_acc IS
  GENERIC (
    g_dat_w            : NATURAL := 6;
    g_acc_w            : NATURAL := 9;
    g_hold_load        : BOOLEAN := TRUE;
    g_pipeline_input   : NATURAL := 0;
    g_pipeline_output  : NATURAL := 4
  );
END tb_st_acc;


ARCHITECTURE tb OF tb_st_acc IS

  CONSTANT clk_period    : TIME := 10 ns;
  
  CONSTANT c_pipeline    : NATURAL := g_pipeline_input + g_pipeline_output;
  
  FUNCTION func_acc(in_dat, in_acc  : STD_LOGIC_VECTOR;
                    in_val, in_load : STD_LOGIC) RETURN STD_LOGIC_VECTOR IS
    VARIABLE v_dat, v_acc, v_result : INTEGER;
  BEGIN
    -- Calculate expected result
    IF in_val='0' THEN              -- hold: out_acc = in_acc
      v_result := TO_SINT(in_acc);
    ELSIF in_load='1' THEN           -- force: out_acc = 0 + in_dat
      v_result := TO_SINT(in_dat);
    ELSE                            -- accumulate: out_acc = in_acc + in_dat
      v_result := TO_SINT(in_dat) + TO_SINT(in_acc);
    END IF;
    -- Wrap to avoid warning: NUMERIC_STD.TO_SIGNED: vector truncated
    IF v_result >  2**(g_acc_w-1)-1 THEN v_result := v_result - 2**g_acc_w; END IF;
    IF v_result < -2**(g_acc_w-1)   THEN v_result := v_result + 2**g_acc_w; END IF;
    RETURN TO_SVEC(v_result, g_acc_w);
  END;
  
  SIGNAL tb_end          : STD_LOGIC := '0';
  SIGNAL clk             : STD_LOGIC := '0';
  
  SIGNAL in_dat          : STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);
  SIGNAL in_acc          : STD_LOGIC_VECTOR(g_acc_w-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL in_val          : STD_LOGIC;
  SIGNAL in_load         : STD_LOGIC;
  SIGNAL out_val         : STD_LOGIC;
  SIGNAL out_acc         : STD_LOGIC_VECTOR(g_acc_w-1 DOWNTO 0);
  
  SIGNAL expected_acc_p  : STD_LOGIC_VECTOR(g_acc_w-1 DOWNTO 0);
  SIGNAL expected_acc    : STD_LOGIC_VECTOR(g_acc_w-1 DOWNTO 0);
  
BEGIN

  clk  <= NOT clk OR tb_end AFTER clk_period/2;
    
  ------------------------------------------------------------------------------
  -- Input stimuli
  ------------------------------------------------------------------------------
  
  -- run -all
  p_stimuli : PROCESS
  BEGIN
    in_load <= '0';
    in_dat <= TO_SVEC(0, g_dat_w);
    in_val <= '0';
    WAIT UNTIL rising_edge(clk);
    FOR I IN 0 TO 9 LOOP WAIT UNTIL rising_edge(clk); END LOOP;

    in_load <= '1';
    in_val <= '1';
    FOR R IN 0 TO 2 LOOP  -- Repeat some intervals marked by in_load = '1'
      in_load <= '1';
      -- All combinations
      FOR I IN -2**(g_dat_w-1) TO 2**(g_dat_w-1)-1 LOOP
        in_dat <= TO_SVEC(I, g_dat_w);
        WAIT UNTIL rising_edge(clk);
        -- keep in_load low during rest of period
        in_load <= '0';
--         -- keep in_val low during rest of st_acc latency, to ease manual interpretation of out_acc as in_acc
--         in_val <= '0';
--         FOR J IN 1 TO c_pipeline-1 LOOP WAIT UNTIL rising_edge(clk); END LOOP;
--         in_val <= '1';
      END LOOP;
    END LOOP;
    in_load <= '1';  -- keep '1' to avoid further toggling of out_acc (in a real design this would safe power)
    in_val <= '0';
    FOR I IN 0 TO 9 LOOP WAIT UNTIL rising_edge(clk); END LOOP;
    tb_end <= '1';
    WAIT;
  END PROCESS;
  
  
  ------------------------------------------------------------------------------
  -- DUT
  ------------------------------------------------------------------------------
  
  dut : ENTITY work.st_acc
  GENERIC MAP (
    g_dat_w            => g_dat_w,
    g_acc_w            => g_acc_w,
    g_hold_load        => g_hold_load,
    g_pipeline_input   => g_pipeline_input,
    g_pipeline_output  => g_pipeline_output
  )
  PORT MAP (
    clk        => clk,
    clken      => '1',
    in_load    => in_load,  -- start of accumulate period
    in_dat     => in_dat,
    in_acc     => in_acc,   -- use only one accumulator
    in_val     => in_val,
    out_acc    => out_acc,
    out_val    => out_val
  );
  
  in_acc <= out_acc WHEN c_pipeline>0 ELSE
            out_acc WHEN rising_edge(clk);  -- if DUT has no pipeline, then register feedback to avoid combinatorial loop
  
  
  ------------------------------------------------------------------------------
  -- Verify
  ------------------------------------------------------------------------------
  
  expected_acc <= func_acc(in_dat, in_acc, in_val, in_load);
  
  u_result : ENTITY common_components_lib.common_pipeline
  GENERIC MAP (
    g_representation => "SIGNED",
    g_pipeline       => c_pipeline,
    g_reset_value    => 0,
    g_in_dat_w       => g_acc_w,
    g_out_dat_w      => g_acc_w
  )
  PORT MAP (
    clk     => clk,
    clken   => '1',
    in_dat  => expected_acc,
    out_dat => expected_acc_p
  );
  
  p_verify : PROCESS(clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF out_val='1' THEN
        ASSERT out_acc  = expected_acc_p REPORT "Error: wrong result" SEVERITY ERROR;
      END IF;
    END IF;
  END PROCESS;
  
END tb;
