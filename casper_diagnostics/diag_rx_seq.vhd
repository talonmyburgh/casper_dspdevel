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
 
-- Purpose: Verify received continuous test sequence data.
-- Description:
--   The diag_rx_seq can operate in one of two modes that depend on g_use_steps:
--
-- . g_use_steps = FALSE
--   The test data can be PRSG or COUNTER dependent on diag_sel.
--   The Rx is enabled by diag_en. Typically the Tx should already be running,
--   but it is also allowed to first enable the Rx.
--   The Rx is always ready to accept data, therefore it has no in_ready output.
--   Inititally when diag_en is low then diag_res = -1, when diag_en is high
--   then diag_res becomes valid, indicated by diag_res_val, after two test
--   data words have been received. The diag_res verifies per input dat bit,
--   when an in_dat bit goes wrong then the corresponding bit in diag_res goes
--   high and remains high until the Rx is restarted again. This is useful if
--   the test data bits go via separate physical lines (e.g. an LVDS bus).
--   When the Rx is disabled then diag_res = -1. Typically the g_diag_res_w >
--   g_dat_w:
--   . diag_res(g_diag_res_w-1:g_dat_w) => NOT diag_res_val
--   . diag_res(     g_dat_w-1:0      ) => aggregated diff of in_dat during
--                                         diag_en
--   It is possible to use g_diag_res_w=g_dat_w, but then it is not possible to
--   distinguish between whether the test has ran at all or whether all bits
--   got errors.
--   The diag_sample keeps the last valid in_dat value. When diag_en='0' it is
--   reset to 0. Reading diag_sample via MM gives an impression of the valid
--   in_dat activity. The diag_sample_diff shows the difference of the last and
--   the previous in_dat value. The diag_sample_diff can be useful to determine
--   or debug the values that are needed for diag_steps_arr.
--
-- . g_use_steps = TRUE
--   The test data is fixed to COUNTER and diag_sel is ignored. The rx_seq can
--   verify counter data that increments in steps that are specified via
--   diag_steps_arr[3:0]. Up to g_nof_steps <= c_diag_seq_rx_reg_nof_steps = 4
--   step sizes are supported. If all steps are set to 1 then there is no
--   difference compared using the COUNTER in g_use_steps = FALSE. Constant
--   value data can be verified by setting alls step to 0. Usinf different
--   steps is useful when the data is generated in linear incrementing order,
--   but received in a different order. Eg. like after a transpose operation
--   where blocks of data are written in row and and read in colums:
--   
--     tx:          0 1   2 3   4 5   6 7   8 9   10 11
--     transpose:   0 1   4 5   8 9   2 3   6 7   10 11
--     rx steps:     +1    +1    +1    +1    +1      +1
--                -11    +3    +3    -7    +3    +3
-- 
--   The step size value range is set by the 32 bit range of the VHDL integer.
--   Therefore typically g_dat_w should be <= 32 b. For a transpose that 
--   contains more than 2**32 data words this means that the COUNTER data 
--   wraps within the transpose. This is acceptable, because it use g_dat_w
--   <= 32 then still provides sufficient coverage to detect all errors.
--
--   Data errors that match a step size cannot be detected. However if such
--   an error occurs then typically the next increment will cause a mismatch.
--
-- Remarks:
-- . The feature of being able to detect errors per bit as with g_use_steps=
--   FALSE is not supported when g_use_steps=TRUE. Therefore the
--   diag_res[g_dat_w-1:0] = -1 (all '1') when a difference occurs that is no
--   in diag_steps_arr.
-- . The common_lfsr_nxt_seq() that is used when g_use_steps=FALSE uses the
--   in_dat_reg as initialization value for the reference sequence. All
--   subsequent values are derived when in_val_reg='1'. This is possible
--   because given a first value all subsequent values for PSRG or COUNTER
--   with +1 increment are known. For g_use_steps=TRUE the sequence is not
--   known in advance because different increment steps can occur at 
--   arbitrary instants. Therefore then the in_dat_reg input is also used 
--   during the sequence, to determine all g_nof_steps next values are correct
--   in case they occur.

LIBRARY IEEE, common_pkg_lib, common_components_lib, casper_counter_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.common_lfsr_sequences_pkg.ALL;
USE work.diag_pkg.ALL;

ENTITY diag_rx_seq IS
  GENERIC (
    g_input_reg  : BOOLEAN := FALSE;  -- Use unregistered input to save logic, use registered input to ease achieving timing constrains.
    g_use_steps  : BOOLEAN := FALSE;
    g_nof_steps  : NATURAL := c_diag_seq_rx_reg_nof_steps;
    g_sel        : STD_LOGIC := '1';  -- '0' = PRSG, '1' = COUNTER
    g_cnt_incr   : INTEGER := 1;
    g_cnt_w      : NATURAL := c_word_w;
    g_dat_w      : NATURAL := 12;
    g_diag_res_w : NATURAL := 16
  );
  PORT (
    rst            : IN  STD_LOGIC;
    clk            : IN  STD_LOGIC;
    clken          : IN  STD_LOGIC := '1';
    
    -- Static control input (connect via MM or leave open to use default)
    diag_en        : IN  STD_LOGIC;                                  -- '0' = init and disable, '1' = enable
    diag_sel       : IN  STD_LOGIC := g_sel;
    diag_steps_arr : t_integer_arr(g_nof_steps-1 DOWNTO 0) := (OTHERS=>1);
    diag_res       : OUT STD_LOGIC_VECTOR(g_diag_res_w-1 DOWNTO 0);  -- diag_res valid indication bits & aggregate diff of in_dat during diag_en
    diag_res_val   : OUT STD_LOGIC;
    diag_sample      : OUT STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);  -- monitor last valid in_dat
    diag_sample_diff : OUT STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);  -- monitor difference between last valid in_dat and previous valid in_dat
    diag_sample_val  : OUT STD_LOGIC;
    
    -- ST input
    in_cnt         : OUT STD_LOGIC_VECTOR(g_cnt_w-1 DOWNTO 0);  -- count valid input test sequence data
    in_dat         : IN  STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);  -- input test sequence data
    in_val         : IN  STD_LOGIC    -- gaps are allowed, however diag_res requires at least 2 valid in_dat to report a valid result
  );
END diag_rx_seq;


ARCHITECTURE rtl OF diag_rx_seq IS

  CONSTANT c_lfsr_nr          : NATURAL := g_dat_w - c_common_lfsr_first;
  
  CONSTANT c_diag_res_latency : NATURAL := 3;
  
  -- Used special value to signal invalid diag_res, unique assuming g_diag_res_w > g_dat_w
  CONSTANT c_diag_res_invalid : STD_LOGIC_VECTOR(diag_res'RANGE) := (OTHERS=>'1');
  
  SIGNAL in_val_reg      : STD_LOGIC;
  SIGNAL in_dat_reg      : STD_LOGIC_VECTOR(in_dat'RANGE);
  
  SIGNAL in_dat_dly1     : STD_LOGIC_VECTOR(in_dat'RANGE);  -- latency common_lfsr_nxt_seq
  SIGNAL in_dat_dly2     : STD_LOGIC_VECTOR(in_dat'RANGE);  -- latency ref_dat
  SIGNAL in_val_dly1     : STD_LOGIC;                       -- latency common_lfsr_nxt_seq
  SIGNAL in_val_dly2     : STD_LOGIC;                       -- latency ref_dat
  
  SIGNAL prsg            : STD_LOGIC_VECTOR(in_dat'RANGE);
  SIGNAL nxt_prsg        : STD_LOGIC_VECTOR(in_dat'RANGE);
  SIGNAL cntr            : STD_LOGIC_VECTOR(in_dat'RANGE);
  SIGNAL nxt_cntr        : STD_LOGIC_VECTOR(in_dat'RANGE);
    
  SIGNAL diag_dis        : STD_LOGIC;
  SIGNAL ref_en          : STD_LOGIC;
  SIGNAL diff_dis        : STD_LOGIC;
  SIGNAL diag_res_en     : STD_LOGIC;
  SIGNAL nxt_diag_res_en : STD_LOGIC;
  SIGNAL nxt_diag_res_val: STD_LOGIC;
  
  SIGNAL in_val_1        : STD_LOGIC;
  SIGNAL in_val_act      : STD_LOGIC;
  SIGNAL in_val_2        : STD_LOGIC;
  SIGNAL in_val_2_dly    : STD_LOGIC_VECTOR(0 TO c_diag_res_latency-1) := (OTHERS=>'0');
  SIGNAL in_val_2_act    : STD_LOGIC;
  
  SIGNAL ref_dat         : STD_LOGIC_VECTOR(in_dat'RANGE);
  SIGNAL nxt_ref_dat     : STD_LOGIC_VECTOR(in_dat'RANGE);
  SIGNAL diff_dat        : STD_LOGIC_VECTOR(in_dat'RANGE) := (OTHERS=>'0');
  SIGNAL nxt_diff_dat    : STD_LOGIC_VECTOR(in_dat'RANGE);
  SIGNAL diff_res        : STD_LOGIC_VECTOR(in_dat'RANGE);
  SIGNAL nxt_diag_res    : STD_LOGIC_VECTOR(diag_res'RANGE);
  
  SIGNAL diag_res_int    : STD_LOGIC_VECTOR(diag_res'RANGE) := c_diag_res_invalid;
  
  SIGNAL i_diag_sample        : STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);
  SIGNAL nxt_diag_sample      : STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);
  SIGNAL i_diag_sample_diff   : STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);
  SIGNAL nxt_diag_sample_diff : STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);
  SIGNAL nxt_diag_sample_val  : STD_LOGIC;

  TYPE t_dat_arr IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);
  
  SIGNAL ref_dat_arr      : t_dat_arr(g_nof_steps-1 DOWNTO 0) := (OTHERS=>(OTHERS=>'0'));
  SIGNAL nxt_ref_dat_arr  : t_dat_arr(g_nof_steps-1 DOWNTO 0);
  SIGNAL diff_arr         : STD_LOGIC_VECTOR(g_nof_steps-1 DOWNTO 0) := (OTHERS=>'0');
  SIGNAL nxt_diff_arr     : STD_LOGIC_VECTOR(g_nof_steps-1 DOWNTO 0);
  SIGNAL diff_detect      : STD_LOGIC := '0';
  SIGNAL nxt_diff_detect  : STD_LOGIC;
  SIGNAL diff_hold        : STD_LOGIC;
  
BEGIN

  diag_dis <= NOT diag_en;
  diag_sample <= i_diag_sample;
  diag_sample_diff <= i_diag_sample_diff;
  
  gen_input_reg : IF g_input_reg=TRUE GENERATE
    p_reg : PROCESS (clk)
    BEGIN
      IF rising_edge(clk) THEN
        IF clken='1' THEN
          in_val_reg  <= in_val;
          in_dat_reg  <= in_dat;
        END IF;
      END IF;
    END PROCESS;
  END GENERATE;
  no_input_reg : IF g_input_reg=FALSE GENERATE
    in_val_reg  <= in_val;
    in_dat_reg  <= in_dat;
  END GENERATE;
  
  -- Use initialisation to set initial diag_res to invalid
  diag_res <= diag_res_int;  -- use initialisation of internal signal diag_res_int rather than initialisation of entity output diag_res
  
--   -- Use rst to set initial diag_res to invalid
--   p_rst_clk : PROCESS (rst, clk)
--   BEGIN
--     IF rst='1' THEN
--       diag_res     <= c_diag_res_invalid;
--     ELSIF rising_edge(clk) THEN
--       IF clken='1' THEN
--         -- Internal.
--         diag_res     <= nxt_diag_res;
--         -- Outputs.
--       END IF;
--     END IF;
--   END PROCESS;
  
  p_clk : PROCESS (clk)
  BEGIN
    IF rising_edge(clk) THEN
      IF clken='1' THEN
        -- Inputs.
        in_dat_dly1  <= in_dat_reg;
        in_dat_dly2  <= in_dat_dly1;
        in_val_dly1  <= in_val_reg;
        in_val_dly2  <= in_val_dly1;
        -- Internal.
        in_val_2_dly <= in_val_2 & in_val_2_dly(0 TO c_diag_res_latency-2);
        diag_res_int <= nxt_diag_res;
        diag_res_en  <= nxt_diag_res_en;
        diag_res_val <= nxt_diag_res_val;
        -- . g_use_steps=FALSE
        prsg         <= nxt_prsg;
        cntr         <= nxt_cntr;
        ref_dat      <= nxt_ref_dat;
        diff_dat     <= nxt_diff_dat;
        -- . g_use_steps=TRUE
        ref_dat_arr  <= nxt_ref_dat_arr;
        diff_arr     <= nxt_diff_arr;
        diff_detect  <= nxt_diff_detect;
        -- Outputs.
        i_diag_sample      <= nxt_diag_sample;
        i_diag_sample_diff <= nxt_diag_sample_diff;
        diag_sample_val    <= nxt_diag_sample_val;
      END IF;
    END IF;
  END PROCESS;
  
  ------------------------------------------------------------------------------
  -- Keep last valid in_dat value for MM monitoring
  ------------------------------------------------------------------------------
  nxt_diag_sample      <= (OTHERS=>'0') WHEN diag_en='0' ELSE in_dat_reg                          WHEN in_val_reg='1' ELSE i_diag_sample;
  nxt_diag_sample_diff <= (OTHERS=>'0') WHEN diag_en='0' ELSE SUB_UVEC(in_dat_reg, i_diag_sample) WHEN in_val_reg='1' ELSE i_diag_sample_diff;
  nxt_diag_sample_val  <=          '0'  WHEN diag_en='0' ELSE in_val_reg;
  
  ------------------------------------------------------------------------------
  -- Detect that there has been valid input data for at least two clock cycles
  ------------------------------------------------------------------------------
  
  u_in_val_1 : ENTITY common_components_lib.common_switch
  PORT MAP(
    clk         => clk,
    rst         => rst,
    switch_high => in_val_reg,
    switch_low  => diag_dis,
    out_level   => in_val_1  -- first in_val has been detected, but this one was used as seed for common_lfsr_nxt_seq
  );
  
  in_val_act <= in_val_1 AND in_val_reg;      -- Signal the second valid in_dat after diag_en='1'
  
  u_in_val_2 : ENTITY common_components_lib.common_switch
  PORT MAP(
    clk         => clk,
    rst         => rst,
    switch_high => in_val_act,
    switch_low  => diag_dis,
    out_level   => in_val_2  -- second in_val has been detected, representing a true next sequence value
  );
  
  -- Use in_val_2_act instead of in_val_2 to have stable start in case diag_dis takes just a pulse and in_val is continue high
  in_val_2_act <= vector_and(in_val_2 & in_val_2_dly);
  
  -- Use the first valid in_dat after diag_en='1' to initialize the reference data sequence
  ref_en <= in_val_1;
  
  -- Use the detection of second valid in_dat after diag_en='1' to start detection of differences
  diff_dis <= NOT in_val_2_act;
    
  no_steps : IF g_use_steps=FALSE GENERATE
    -- Determine next reference dat based on current input dat
    common_lfsr_nxt_seq(c_lfsr_nr,    -- IN
                        g_cnt_incr,   -- IN
                        ref_en,       -- IN
                        in_val_reg,   -- IN, use in_val_reg to allow gaps in the input data valid stream
                        in_dat_reg,   -- IN, used only to init nxt_prsg and nxt_cntr when ref_en='0'
                        prsg,         -- IN
                        cntr,         -- IN
                        nxt_prsg,     -- OUT
                        nxt_cntr);    -- OUT
      
    nxt_ref_dat <= prsg WHEN diag_sel='0' ELSE cntr;
  
    -- Detect difference per bit. The ref_dat has latency 2 compared to the in_dat, because of the register stage in psrg/cntr and the register stage in ref_dat.
    p_diff_dat : PROCESS (diff_dat, ref_dat, in_val_dly2, in_dat_dly2)
    BEGIN
      nxt_diff_dat <= diff_dat;
      IF in_val_dly2='1' THEN
        FOR I IN in_dat'RANGE LOOP
          nxt_diff_dat(I) <= ref_dat(I) XOR in_dat_dly2(I);
        END LOOP;
      END IF;
    END PROCESS;
    
    gen_verify_dat : FOR I IN in_dat'RANGE GENERATE
      -- Detect and report undefined diff input 'X', which in simulation leaves diff_res at OK, because switch_high only acts on '1'
      p_sim_only : PROCESS(clk)
      BEGIN
        IF rising_edge(clk) THEN
          IF diff_dat(I)/='0' AND diff_dat(I)/='1' THEN
            REPORT "diag_rx_seq : undefined input" SEVERITY FAILURE;
          END IF;
        END IF;
      END PROCESS;
      
      -- Hold any difference on the in_dat bus lines
      u_dat : ENTITY common_components_lib.common_switch
      PORT MAP(
        clk         => clk,
        rst         => rst,
        switch_high => diff_dat(I),
        switch_low  => diff_dis,
        out_level   => diff_res(I)
      );
    END GENERATE;
  END GENERATE;
  
  use_steps : IF g_use_steps=TRUE GENERATE
    -- Determine next reference data for all steps increments of current input dat
    p_ref_dat_arr : PROCESS(in_dat_reg, in_val_reg, ref_dat_arr)
    BEGIN
      nxt_ref_dat_arr <= ref_dat_arr;
      IF in_val_reg='1' THEN
        FOR I IN g_nof_steps-1 DOWNTO 0 LOOP
          nxt_ref_dat_arr(I) <= INCR_UVEC(in_dat_reg, diag_steps_arr(I));
        END LOOP;
      END IF;
    END PROCESS;
        
    -- Detect difference for each allowed reference data.
    p_diff_arr : PROCESS(diff_arr, in_val_reg, in_dat_reg, ref_dat_arr)
    BEGIN
      nxt_diff_arr <= diff_arr;
      IF in_val_reg='1' THEN
        nxt_diff_arr <= (OTHERS=>'1');
        FOR I IN g_nof_steps-1 DOWNTO 0 LOOP
          IF UNSIGNED(ref_dat_arr(I))=UNSIGNED(in_dat_reg) THEN
            nxt_diff_arr(I) <= '0';
          END IF;
        END LOOP;
      END IF;
    END PROCESS;
    
    -- detect diff when none of the step counter value matches
    p_diff_detect : PROCESS(diff_detect, diff_arr, in_val_dly1)
    BEGIN
      nxt_diff_detect <= diff_detect;
      IF in_val_dly1='1' THEN
        nxt_diff_detect <= '0';
        IF vector_and(diff_arr)='1' THEN
          nxt_diff_detect <= '1';
        END IF;
      END IF;
    END PROCESS;
    
    -- hold detected diff detect
    u_dat : ENTITY common_components_lib.common_switch
    PORT MAP(
      clk         => clk,
      rst         => rst,
      switch_high => diff_detect,
      switch_low  => diff_dis,
      out_level   => diff_hold
    );
    
    diff_res <= (OTHERS=> diff_hold);  -- convert diff_hold to diff_res slv format as used for g_use_steps=FALSE
  END GENERATE;
  
  
  ------------------------------------------------------------------------------
  -- Report valid diag_res  
  ------------------------------------------------------------------------------
  
  nxt_diag_res_en  <= diag_en AND in_val_2_act;
  nxt_diag_res_val <= diag_res_en;
  
  p_diag_res : PROCESS (diff_res, diag_res_en)
  BEGIN
    nxt_diag_res <= c_diag_res_invalid;
    IF diag_res_en='1' THEN
      -- The test runs AND there have been valid input samples to verify
      nxt_diag_res                 <= (OTHERS=>'0');  -- MSBits of valid diag_res are 0
      nxt_diag_res(diff_res'RANGE) <= diff_res;       -- diff_res of dat[]
    END IF;
  END PROCESS;
  
  
  ------------------------------------------------------------------------------
  -- Count number of valid input data
  ------------------------------------------------------------------------------
  u_common_counter : ENTITY casper_counter_lib.common_counter
  GENERIC MAP (
    g_latency   => 1,  -- default 1 for registered count output, use 0 for immediate combinatorial count output
    g_width     => g_cnt_w
  )
  PORT MAP (
    rst     => rst,
    clk     => clk,
    clken   => clken,
    cnt_clr => diag_dis,    -- synchronous cnt_clr is only interpreted when clken is active
    cnt_en  => in_val,
    count   => in_cnt
  );
END rtl;
