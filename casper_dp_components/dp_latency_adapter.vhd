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

LIBRARY IEEE, common_pkg_lib, dp_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;

-- Purpose:
--   Adapt the g_in_latency input ready to the g_out_latency output latency.
--   A typical application is to use this latency adapter to provide a read
--   ahead interface to a default FIFO with e.g. read latency 1 or 2.
-- Description:
--   If g_in_latency > g_out_latency then the input latency is first adapted
--   to zero latency by means of a latency FIFO. After that a delay line for
--   src_in.ready yields the g_out_latency output latency.
--   If g_in_latency < g_out_latency, then a delay line for src_in.ready yields
--   the g_out_latency output latency.
--   The sync input is also passed on, only if it occurs during valid. The
--   constant c_pass_sync_during_not_valid is defined to preserve the
--   corresponding section of code for passing the sync also during not valid.
-- Remark:
-- . The snk_out.ready is derived combinatorially from the src_in.ready. If for
--   timing performance it is needed to register snk_out.ready, then this can
--   be done by first increasing the ready latency using this adapter with
--   g_in_latency = g_out_latency + 1, followed by a second adapter to reach
--   the required output ready latency latency.

ENTITY dp_latency_adapter IS
  GENERIC (
    g_in_latency   : NATURAL := 3;
    g_out_latency  : NATURAL := 1
  );
  PORT (
    rst          : IN  STD_LOGIC;
    clk          : IN  STD_LOGIC;
    -- Monitor internal FIFO filling
    fifo_usedw   : OUT STD_LOGIC_VECTOR(ceil_log2(2+g_in_latency)-1 DOWNTO 0);  -- see description of c_fifo_size, c_usedw_w for explanation of why +2
    fifo_ful     : OUT STD_LOGIC;
    fifo_emp     : OUT STD_LOGIC;
    -- ST sink
    snk_out      : OUT t_dp_siso;
    snk_in       : IN  t_dp_sosi;
    -- ST source
    src_in       : IN  t_dp_siso;
    src_out      : OUT t_dp_sosi
  );
END dp_latency_adapter;


ARCHITECTURE rtl OF dp_latency_adapter IS

  -- The difference between the input ready latency and the output ready latency
  CONSTANT c_diff_latency               : INTEGER := g_out_latency - g_in_latency;
  
  -- Define constant to preserve the corresponding section of code, but default keep it at FALSE
  CONSTANT c_pass_sync_during_not_valid : BOOLEAN := FALSE;
  
  -- Use g_in_latency+1 words for the FIFO data array, to go to zero latency
  CONSTANT c_high           : NATURAL := g_in_latency;
  CONSTANT c_fifo_size      : NATURAL := g_in_latency+1;            -- +1 because RL=0 also requires a word
  CONSTANT c_usedw_w        : NATURAL := ceil_log2(c_fifo_size+1);  -- +1 because to store value 2**n requires n+1 bits

  SIGNAL fifo_reg           : t_dp_sosi_arr(c_high DOWNTO 0);
  SIGNAL nxt_fifo_reg       : t_dp_sosi_arr(c_high DOWNTO 0);
  SIGNAL fifo_reg_valid     : STD_LOGIC_VECTOR(c_high DOWNTO 0);    -- debug signal for Wave window
  
  SIGNAL nxt_fifo_usedw     : STD_LOGIC_VECTOR(c_usedw_w-1 DOWNTO 0);
  SIGNAL nxt_fifo_ful       : STD_LOGIC;
  SIGNAL nxt_fifo_emp       : STD_LOGIC;

  SIGNAL ff_siso            : t_dp_siso;  -- SISO ready
  SIGNAL ff_sosi            : t_dp_sosi;  -- SOSI
  
  SIGNAL i_snk_out          : t_dp_siso := c_dp_siso_rdy;
  
BEGIN

  -- Use i_snk_out with defaults to force unused snk_out bits and fields to '0'
  snk_out <= i_snk_out;
  
  gen_wires : IF c_diff_latency = 0 GENERATE  -- g_out_latency = g_in_latency
    i_snk_out <= src_in;  -- SISO
    src_out   <= snk_in;  -- SOSI
  END GENERATE gen_wires;


  no_fifo : IF c_diff_latency > 0 GENERATE  -- g_out_latency > g_in_latency
    -- Go from g_in_latency to required larger g_out_latency
    u_latency : ENTITY work.dp_latency_increase
    GENERIC MAP (
      g_in_latency   => g_in_latency,
      g_incr_latency => c_diff_latency
    )
    PORT MAP (
      rst       => rst,
      clk       => clk,
      -- ST sink
      snk_out   => i_snk_out,
      snk_in    => snk_in,
      -- ST source
      src_in    => src_in,
      src_out   => src_out
    );
  END GENERATE no_fifo;
  
  
  gen_fifo : IF c_diff_latency < 0 GENERATE  -- g_out_latency < g_in_latency
    -- Register [0] contains the FIFO output with zero ready latency
    ff_sosi <= fifo_reg(0);
  
    p_clk_fifo : PROCESS(rst, clk)
    BEGIN
      IF rst='1' THEN
        fifo_reg   <= (OTHERS=>c_dp_sosi_rst);
        fifo_usedw <= (OTHERS=>'0');
        fifo_ful   <= '0';
        fifo_emp   <= '1';
      ELSIF rising_edge(clk) THEN
        fifo_reg   <= nxt_fifo_reg;
        fifo_usedw <= nxt_fifo_usedw;
        fifo_ful   <= nxt_fifo_ful;
        fifo_emp   <= nxt_fifo_emp;
      END IF;
    END PROCESS;
    
    -- Pass on frame level flow control
    i_snk_out.xon <= src_in.xon;
    
    p_snk_out_ready : PROCESS(fifo_reg, ff_siso, snk_in)
    BEGIN
      i_snk_out.ready <= '0';
      IF ff_siso.ready='1' THEN
        -- Default snk_out ready when the source is ready.
        i_snk_out.ready <= '1';
      ELSE
        -- Extra snk_out ready to look ahead for src_in RL = 0.
        -- The fifo_reg[h:0] size is g_in_latency+1 number of SOSI values.
        -- . The fifo_reg[h:1] provide free space for h=g_in_latency nof data
        --   when snk_out.ready is pulled low, because then there can still
        --   arrive g_in_latency nof new data with snk_in.valid asserted.
        -- . The [0] is the registered output SOSI value with RL=0. Therefore
        --   fifo_reg[0] can still accept a new input when ff_siso.ready is
        --   low. If this assignment is omitted then the functionallity is
        --   still OK, but the throughtput sligthly reduces.
        IF fifo_reg(0).valid='0' THEN
          i_snk_out.ready <= '1';
        ELSIF fifo_reg(1).valid='0' THEN
          i_snk_out.ready <= NOT(snk_in.valid);
        END IF;
      END IF;
    END PROCESS;
  
    p_fifo_reg : PROCESS(fifo_reg, ff_siso, snk_in)
    BEGIN
      -- Keep or shift the fifo_reg dependent on ff_siso.ready, no need to explicitly check fifo_reg().valid
      nxt_fifo_reg <= fifo_reg;
      IF ff_siso.ready='1' THEN
        nxt_fifo_reg(c_high-1 DOWNTO 0) <= fifo_reg(c_high DOWNTO 1);
        nxt_fifo_reg(c_high).valid <= '0';
        nxt_fifo_reg(c_high).sync  <= '0';
        nxt_fifo_reg(c_high).sop   <= '0';
        nxt_fifo_reg(c_high).eop   <= '0';
        -- Forcing the nxt_fifo_reg[h] control fields to '0' is robust, but not
        -- strictly necessary, because the control fields in fifo_reg[h] will
        -- have been set to '0' already earlier due to the snk_in when
        -- ff_siso.ready was '0'.
      END IF;
  
      -- Put input data at the first available location dependent on ff_siso.ready, no need to explicitly check snk_in.valid
      IF fifo_reg(0).valid='0' THEN
        nxt_fifo_reg(0) <= snk_in;               -- fifo_reg is empty
      ELSE
        -- The fifo_reg is not empty, so filled to some extend
        FOR I IN 1 TO c_high LOOP
          IF fifo_reg(I).valid='0' THEN
            IF ff_siso.ready='0' THEN
              nxt_fifo_reg(I)   <= snk_in;
            ELSE
              nxt_fifo_reg(I-1) <= snk_in;
            END IF;
            EXIT;
          END IF;
        END LOOP;
        
        -- Default the input sync during input data valid is only passed on with the valid input data.
        -- When c_pass_sync_during_not_valid is enabled then the input sync during input data not valid is passed on via the head fifo_reg(0) if the fifo_reg is empty.
        IF c_pass_sync_during_not_valid=TRUE AND snk_in.sync='1' AND snk_in.valid='0' THEN
          -- Otherwise for input sync during input data not valid we need to insert the input sync at the last location with valid data independent of ff_siso.ready, to avoid that it gets lost.
          -- For streams that do not use the sync this logic will be void and optimize away by synthesis, because then snk_in.sync = '0' fixed.
          IF fifo_reg(c_high).valid='1' THEN     -- fifo_reg is full
            nxt_fifo_reg(c_high).sync <= '1';    -- insert input sync
          ELSE
            FOR I IN c_high-1 DOWNTO 0 LOOP      -- fifo_reg is filled to some extend, so not full and not empty
              IF fifo_reg(I).valid='1' THEN
                nxt_fifo_reg(I+1).sync <= '0';   -- overrule default sync assignment
                nxt_fifo_reg(I).sync   <= '1';   -- insert input sync
                EXIT;
              END IF;
            END LOOP;
          END IF;
        END IF;
      END IF;
    END PROCESS;
    
    p_fifo_usedw : PROCESS(nxt_fifo_reg)
    BEGIN
      nxt_fifo_usedw <= (OTHERS=>'0');
      FOR I IN c_high DOWNTO 0 LOOP
        IF nxt_fifo_reg(I).valid='1' THEN
          nxt_fifo_usedw <= TO_UVEC(I+1, c_usedw_w);
          EXIT;
        END IF;
      END LOOP;
    END PROCESS;
    
    fifo_reg_valid <= func_dp_stream_arr_get(fifo_reg, "VALID");
    
    nxt_fifo_ful <= '1' WHEN TO_UINT(nxt_fifo_usedw)>=c_high+1 ELSE '0';  -- using >= or = is equivalent here
    nxt_fifo_emp <= '1' WHEN TO_UINT(nxt_fifo_usedw) =0        ELSE '0';
    
    -- Go from 0 FIFO latency to required g_out_latency (only wires when g_out_latency=0)
    u_latency : ENTITY work.dp_latency_increase
    GENERIC MAP (
      g_in_latency   => 0,
      g_incr_latency => g_out_latency
    )
    PORT MAP (
      rst       => rst,
      clk       => clk,
      -- ST sink
      snk_out   => ff_siso,
      snk_in    => ff_sosi,
      -- ST source
      src_in    => src_in,
      src_out   => src_out
    );
  END GENERATE gen_fifo;

END rtl;
