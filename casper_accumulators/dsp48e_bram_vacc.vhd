-- A VHDL implementation of the CASPER dsp48e_bram_vacc.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, UNISIM,
casper_misc_lib, common_components_lib,
casper_delay_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
use UNISIM.vcomponents.all;

entity dsp48e_bram_vacc is
    generic(
        g_vector_length : NATURAL := 16;
        g_dsp48_version : NATURAL := 1;
        g_bit_w         : NATURAL := 32
    );
    port (
        clk         : IN std_logic;
        ce          : IN std_logic;
        new_acc     : IN std_logic;
        din         : IN std_logic_vector;
        valid       : OUT std_logic;
        dout        : OUT std_logic_vector(g_bit_w - 1 DOWNTO 0) := (others=>'0')
    );
END dsp48e_bram_vacc;

architecture rtl of dsp48e_bram_vacc is
   CONSTANT c_concat_hi : std_logic_vector(4 DOWNTO 0) := TO_SVEC(3, 5);

   SIGNAL s_resized_din : std_logic_vector(47 DOWNTO 0);
   SIGNAL s_not_new_acc : std_logic;
   SIGNAL s_pulse_ext_out : std_logic;
   SIGNAL s_dout  : std_logic_vector(g_bit_w - 1 DOWNTO 0);
   SIGNAL s_dout_cast  : std_logic_vector(47 DOWNTO 0);
   SIGNAL s_a : std_logic_vector(29 DOWNTO 0);
   SIGNAL s_b : std_logic_vector(17 DOWNTO 0);
   SIGNAL s_p : std_logic_vector(47 DOWNTO 0);
   SIGNAL s_p_sliced : std_logic_vector(31 DOWNTO 0);
   SIGNAL s_delay_bram_out : std_logic_vector(31 DOWNTO 0);
   SIGNAL s_opmode1 : std_logic_vector(6 DOWNTO 0);
   SIGNAL s_opmode2 : std_logic_vector(8 DOWNTO 0);
   SIGNAL s_tmp_opmode : std_logic_vector(1 DOWNTO 0);

begin

--------------------------------------------------------------
-- pulse extend new_acc
--------------------------------------------------------------
pulse_ext : entity casper_misc_lib.pulse_ext
generic map(
    g_extension => g_vector_length
    )
    port map(
        clk => clk,
        ce  => ce,
        i_pulse => new_acc,
        o_pulse => s_pulse_ext_out
        );
        
--------------------------------------------------------------
-- reinterpret din to 48bits
--------------------------------------------------------------
s_resized_din <= RESIZE_SVEC(din, 48);

--------------------------------------------------------------
-- negate pulse_ext new_acc signal
--------------------------------------------------------------
s_not_new_acc <= not s_pulse_ext_out;

--------------------------------------------------------------
-- concatenate three signals
--------------------------------------------------------------
s_tmp_opmode <= s_not_new_acc & s_not_new_acc;
s_opmode1 <= c_concat_hi & s_tmp_opmode;
s_opmode2 <= "00" & s_opmode1; 
--------------------------------------------------------------
-- slice the output of the dsp48
--------------------------------------------------------------
s_p_sliced <= s_p(31 DOWNTO 0);

--------------------------------------------------------------
-- delay bram
--------------------------------------------------------------
delay_bram_blk : entity casper_delay_lib.delay_bram
generic map (
    g_delay => g_vector_length - 2,
    g_ram_primitive => "block",
    g_ram_latency => 2
)
port map (
    clk => clk,
    ce => ce,
    din => s_p_sliced,
    dout => s_delay_bram_out
);

--------------------------------------------------------------
-- slice the output of the delay bram
--------------------------------------------------------------
s_dout <= s_delay_bram_out(g_bit_w - 1 DOWNTO 0);

--------------------------------------------------------------
-- resize s_dout
--------------------------------------------------------------
s_dout_cast <= RESIZE_SVEC(s_dout, 48);

--------------------------------------------------------------
-- populate s_a and s_b
--------------------------------------------------------------
s_a <= s_dout_cast(47 DOWNTO 18);
s_b <= s_dout_cast(17 DOWNTO 0);

--------------------------------------------------------------
-- populate outports
--------------------------------------------------------------
dout <= s_dout;
valid <= s_pulse_ext_out;

--------------------------------------------------------------
-- DSP48 blocks
--------------------------------------------------------------
use_dsp48e1 : IF g_dsp48_version = 1 GENERATE 
DSP48E1_inst : DSP48E1
   generic map (
      -- Feature Control Attributes: Data Path Selection
      A_INPUT => "DIRECT",               -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
      B_INPUT => "DIRECT",               -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
      USE_DPORT => FALSE,                -- Select D port usage (TRUE or FALSE)
      USE_MULT => "MULTIPLY",            -- Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
      USE_SIMD => "ONE48",               -- SIMD selection ("ONE48", "TWO24", "FOUR12")
      -- Pattern Detector Attributes: Pattern Detection Configuration
      AUTORESET_PATDET => "NO_RESET",    -- "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH" 
      MASK => X"3fffffffffff",           -- 48-bit mask value for pattern detect (1=ignore)
      PATTERN => X"000000000000",        -- 48-bit pattern match for pattern detect
      SEL_MASK => "MASK",                -- "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2" 
      SEL_PATTERN => "PATTERN",          -- Select pattern value ("PATTERN" or "C")
      USE_PATTERN_DETECT => "NO_PATDET", -- Enable pattern detect ("PATDET" or "NO_PATDET")
      -- Register Control Attributes: Pipeline Register Configuration
      ACASCREG => 1,                     -- Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
      ADREG => 1,                        -- Number of pipeline stages for pre-adder (0 or 1)
      ALUMODEREG => 1,                   -- Number of pipeline stages for ALUMODE (0 or 1)
      AREG => 1,                         -- Number of pipeline stages for A (0, 1 or 2)
      BCASCREG => 1,                     -- Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
      BREG => 1,                         -- Number of pipeline stages for B (0, 1 or 2)
      CARRYINREG => 1,                   -- Number of pipeline stages for CARRYIN (0 or 1)
      CARRYINSELREG => 1,                -- Number of pipeline stages for CARRYINSEL (0 or 1)
      CREG => 1,                         -- Number of pipeline stages for C (0 or 1)
      DREG => 1,                         -- Number of pipeline stages for D (0 or 1)
      INMODEREG => 1,                    -- Number of pipeline stages for INMODE (0 or 1)
      MREG => 1,                         -- Number of multiplier pipeline stages (0 or 1)
      OPMODEREG => 1,                    -- Number of pipeline stages for OPMODE (0 or 1)
      PREG => 1                          -- Number of pipeline stages for P (0 or 1)
   )
   port map (
      -- Cascade: 30-bit (each) output: Cascade Ports
      ACOUT => open,                  -- 30-bit output: A port cascade output
      BCOUT => open,                  -- 18-bit output: B port cascade output
      CARRYCASCOUT => open,           -- 1-bit output: Cascade carry output
      MULTSIGNOUT => open,            -- 1-bit output: Multiplier sign cascade output
      PCOUT => open,                  -- 48-bit output: Cascade output
      -- Control: 1-bit (each) output: Control Inputs/Status Bits
      OVERFLOW => open,               -- 1-bit output: Overflow in add/acc output
      PATTERNBDETECT => open,         -- 1-bit output: Pattern bar detect output
      PATTERNDETECT => open,          -- 1-bit output: Pattern detect output
      UNDERFLOW => open,              -- 1-bit output: Underflow in add/acc output
      -- Data: 4-bit (each) output: Data Ports
      CARRYOUT => open,               -- 4-bit output: Carry output
      P => s_p,                       -- 48-bit output: Primary data output
      -- Cascade: 30-bit (each) input: Cascade Ports
      ACIN => (others => '0'),        -- 30-bit input: A cascade data input
      BCIN => (others => '0'),        -- 18-bit input: B cascade input
      CARRYCASCIN => '0',             -- 1-bit input: Cascade carry input
      MULTSIGNIN => '0',              -- 1-bit input: Multiplier sign input
      PCIN => (others => '0'),        -- 48-bit input: P cascade input
      -- Control: 4-bit (each) input: Control Inputs/Status Bits
      ALUMODE => (others => '0'),     -- 4-bit input: ALU control input
      CARRYINSEL => (others =>'0'),   -- 3-bit input: Carry select input
      CLK => clk,                     -- 1-bit input: Clock input
      INMODE => (others => '0'),      -- 5-bit input: INMODE control input
      OPMODE => s_opmode1,             -- 7-bit input: Operation mode input
      -- Data: 30-bit (each) input: Data Ports
      A => s_a,                       -- 30-bit input: A data input
      B => s_b,                       -- 18-bit input: B data input
      C => s_resized_din,             -- 48-bit input: C data input
      CARRYIN => '0',                 -- 1-bit input: Carry input signal
      D => (others=>'0'),             -- 25-bit input: D data input
      -- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
      CEA1 => ce,                     -- 1-bit input: Clock enable input for 1st stage AREG
      CEA2 => ce,                     -- 1-bit input: Clock enable input for 2nd stage AREG
      CEAD => ce,                     -- 1-bit input: Clock enable input for ADREG
      CEALUMODE => ce,                -- 1-bit input: Clock enable input for ALUMODE
      CEB1 => ce,                     -- 1-bit input: Clock enable input for 1st stage BREG
      CEB2 => ce,                     -- 1-bit input: Clock enable input for 2nd stage BREG
      CEC => ce,                      -- 1-bit input: Clock enable input for CREG
      CECARRYIN => ce,                -- 1-bit input: Clock enable input for CARRYINREG
      CECTRL => ce,                   -- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
      CED => ce,                      -- 1-bit input: Clock enable input for DREG
      CEINMODE => ce,                 -- 1-bit input: Clock enable input for INMODEREG
      CEM => ce,                      -- 1-bit input: Clock enable input for MREG
      CEP => ce,                      -- 1-bit input: Clock enable input for PREG
      RSTA => '0',                    -- 1-bit input: Reset input for AREG
      RSTALLCARRYIN => '0',           -- 1-bit input: Reset input for CARRYINREG
      RSTALUMODE => '0',              -- 1-bit input: Reset input for ALUMODEREG
      RSTB => '0',                    -- 1-bit input: Reset input for BREG
      RSTC => '0',                    -- 1-bit input: Reset input for CREG
      RSTCTRL => '0',                 -- 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
      RSTD => '0',                    -- 1-bit input: Reset input for DREG and ADREG
      RSTINMODE => '0',               -- 1-bit input: Reset input for INMODEREG
      RSTM => '0',                    -- 1-bit input: Reset input for MREG
      RSTP => '0'                     -- 1-bit input: Reset input for PREG
   );

END GENERATE;

use_dsp48e2 : IF g_dsp48_version = 2 GENERATE 
   DSP48E2_inst : DSP48E2
   generic map (
      -- Feature Control Attributes: Data Path Selection
      AMULTSEL => "A",                   -- Selects A input to multiplier (A, AD)
      A_INPUT => "DIRECT",               -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
      BMULTSEL => "B",                   -- Selects B input to multiplier (AD, B)
      B_INPUT => "DIRECT",               -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
      PREADDINSEL => "A",                -- Selects input to pre-adder (A, B)
      RND => X"000000000000",            -- Rounding Constant
      USE_MULT => "NONE",                -- Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
      USE_SIMD => "ONE48",               -- SIMD selection (FOUR12, ONE48, TWO24)
      USE_WIDEXOR => "FALSE",            -- Use the Wide XOR function (FALSE, TRUE)
      XORSIMD => "XOR24_48_96",          -- Mode of operation for the Wide XOR (XOR12, XOR24_48_96)
      -- Pattern Detector Attributes: Pattern Detection Configuration
      AUTORESET_PATDET => "NO_RESET",    -- NO_RESET, RESET_MATCH, RESET_NOT_MATCH
      AUTORESET_PRIORITY => "RESET",     -- Priority of AUTORESET vs. CEP (CEP, RESET).
      MASK => X"3fffffffffff",           -- 48-bit mask value for pattern detect (1=ignore)
      PATTERN => X"000000000000",        -- 48-bit pattern match for pattern detect
      SEL_MASK => "MASK",                -- C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
      SEL_PATTERN => "PATTERN",          -- Select pattern value (C, PATTERN)
      USE_PATTERN_DETECT => "NO_PATDET", -- Enable pattern detect (NO_PATDET, PATDET)
      -- Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
      IS_ALUMODE_INVERTED => "0000",     -- Optional inversion for ALUMODE
      IS_CARRYIN_INVERTED => '0',        -- Optional inversion for CARRYIN
      IS_CLK_INVERTED => '0',            -- Optional inversion for CLK
      IS_INMODE_INVERTED => "00000",     -- Optional inversion for INMODE
      IS_OPMODE_INVERTED => "000000000", -- Optional inversion for OPMODE
      IS_RSTALLCARRYIN_INVERTED => '0',  -- Optional inversion for RSTALLCARRYIN
      IS_RSTALUMODE_INVERTED => '0',     -- Optional inversion for RSTALUMODE
      IS_RSTA_INVERTED => '0',           -- Optional inversion for RSTA
      IS_RSTB_INVERTED => '0',           -- Optional inversion for RSTB
      IS_RSTCTRL_INVERTED => '0',        -- Optional inversion for RSTCTRL
      IS_RSTC_INVERTED => '0',           -- Optional inversion for RSTC
      IS_RSTD_INVERTED => '0',           -- Optional inversion for RSTD
      IS_RSTINMODE_INVERTED => '0',      -- Optional inversion for RSTINMODE
      IS_RSTM_INVERTED => '0',           -- Optional inversion for RSTM
      IS_RSTP_INVERTED => '0',           -- Optional inversion for RSTP
      -- Register Control Attributes: Pipeline Register Configuration
      ACASCREG => 1,                     -- Number of pipeline stages between A/ACIN and ACOUT (0-2)
      ADREG => 1,                        -- Pipeline stages for pre-adder (0-1)
      ALUMODEREG => 1,                   -- Pipeline stages for ALUMODE (0-1)
      AREG => 1,                         -- Pipeline stages for A (0-2)
      BCASCREG => 1,                     -- Number of pipeline stages between B/BCIN and BCOUT (0-2)
      BREG => 1,                         -- Pipeline stages for B (0-2)
      CARRYINREG => 1,                   -- Pipeline stages for CARRYIN (0-1)
      CARRYINSELREG => 1,                -- Pipeline stages for CARRYINSEL (0-1)
      CREG => 1,                         -- Pipeline stages for C (0-1)
      DREG => 1,                         -- Pipeline stages for D (0-1)
      INMODEREG => 1,                    -- Pipeline stages for INMODE (0-1)
      MREG => 1,                         -- Multiplier pipeline stages (0-1)
      OPMODEREG => 1,                    -- Pipeline stages for OPMODE (0-1)
      PREG => 1                          -- Number of pipeline stages for P (0-1)
   )
   port map (
      -- Cascade outputs: Cascade Ports
      ACOUT => open,                    -- 30-bit output: A port cascade
      BCOUT => open,                    -- 18-bit output: B cascade
      CARRYCASCOUT => open,             -- 1-bit output: Cascade carry
      MULTSIGNOUT => open,              -- 1-bit output: Multiplier sign cascade
      PCOUT => open,                    -- 48-bit output: Cascade output
      -- Control outputs: Control Inputs/Status Bits
      OVERFLOW => open,                 -- 1-bit output: Overflow in add/acc
      PATTERNBDETECT => open,           -- 1-bit output: Pattern bar detect
      PATTERNDETECT => open,            -- 1-bit output: Pattern detect
      UNDERFLOW => open,                -- 1-bit output: Underflow in add/acc
      -- Data outputs:Data Ports
      CARRYOUT => open,                 -- 4-bit output: Carry
      P => s_p,                         -- 48-bit output: Primary data
      XOROUT => open,                   -- 8-bit output: XOR data
      -- Cascade inputs: Cascade Ports
      ACIN => (others => '0'),          -- 30-bit input: A cascade data
      BCIN => (others => '0'),          -- 18-bit input: B cascade
      CARRYCASCIN => '0',               -- 1-bit input: Cascade carry
      MULTSIGNIN => '0',                -- 1-bit input: Multiplier sign cascade
      PCIN => (others => '0'),          -- 48-bit input: P cascade
      -- Control inputs: Control Inputs/Status Bits
      ALUMODE => (others => '0'),       -- 4-bit input: ALU control
      CARRYINSEL => (others => '0'),    -- 3-bit input: Carry select
      CLK => clk,                       -- 1-bit input: Clock
      INMODE => (others => '0'),        -- 5-bit input: INMODE control
      OPMODE => s_opmode2,               -- 9-bit input: Operation mode
      -- Data inputs: Data Ports
      A => s_a,                         -- 30-bit input: A data
      B => s_b,                         -- 18-bit input: B data
      C => s_resized_din,               -- 48-bit input: C data
      CARRYIN => '0',                   -- 1-bit input: Carry-in
      D => (others => '0'),             -- 27-bit input: D data
      -- Reset/Clock Enable inputs: Reset/Clock Enable Inputs
      CEA1 => ce,                       -- 1-bit input: Clock enable for 1st stage AREG
      CEA2 => ce,                       -- 1-bit input: Clock enable for 2nd stage AREG
      CEAD => ce,                       -- 1-bit input: Clock enable for ADREG
      CEALUMODE => ce,                  -- 1-bit input: Clock enable for ALUMODE
      CEB1 => ce,                       -- 1-bit input: Clock enable for 1st stage BREG
      CEB2 => ce,                       -- 1-bit input: Clock enable for 2nd stage BREG
      CEC => ce,                        -- 1-bit input: Clock enable for CREG
      CECARRYIN => ce,                  -- 1-bit input: Clock enable for CARRYINREG
      CECTRL => ce,                     -- 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
      CED => ce,                        -- 1-bit input: Clock enable for DREG
      CEINMODE => ce,                   -- 1-bit input: Clock enable for INMODEREG
      CEM => ce,                        -- 1-bit input: Clock enable for MREG
      CEP => ce,                        -- 1-bit input: Clock enable for PREG
      RSTA => '0',                      -- 1-bit input: Reset for AREG
      RSTALLCARRYIN => '0',             -- 1-bit input: Reset for CARRYINREG
      RSTALUMODE => '0',                -- 1-bit input: Reset for ALUMODEREG
      RSTB => '0',                      -- 1-bit input: Reset for BREG
      RSTC => '0',                      -- 1-bit input: Reset for CREG
      RSTCTRL => '0',                   -- 1-bit input: Reset for OPMODEREG and CARRYINSELREG
      RSTD => '0',                      -- 1-bit input: Reset for DREG and ADREG
      RSTINMODE => '0',                 -- 1-bit input: Reset for INMODEREG
      RSTM => '0',                      -- 1-bit input: Reset for MREG
      RSTP => '0'                       -- 1-bit input: Reset for PREG
   );
END GENERATE;

END rtl;