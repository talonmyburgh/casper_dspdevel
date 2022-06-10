-- A VHDL implementation of the CASPER pulse_ext block.
-- @author: Mydon Solutions.

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;

ENTITY tb_pulse_ext is
  GENERIC(
    g_extension : NATURAL := 4;
    g_rising_not_falling_edge_detect : BOOLEAN := TRUE
  );
  PORT(
    o_rst       : out std_logic;
    o_clk       : out std_logic;
    o_tb_end    : out std_logic;
    o_test_pass : out boolean;
    o_test_msg  : out string(1 to 80)
  );
end ENTITY;

ARCHITECTURE rtl of tb_pulse_ext is
  CONSTANT clk_period   : TIME := 10 ns;

  SIGNAL tb_end   : STD_LOGIC := '0';
  SIGNAL rst      : STD_LOGIC;
  SIGNAL clk      : STD_LOGIC := '1';

  SIGNAL s_pulse_in     : STD_LOGIC;
  SIGNAL s_pulse_out    : STD_LOGIC;
  SIGNAL s_pulse_exp    : STD_LOGIC;
BEGIN

  clk <= (NOT clk) OR tb_end AFTER clk_period/2;
  rst <= '1', '0' AFTER clk_period*3;
  o_clk <= clk;
  o_rst <= rst;
  o_tb_end <= tb_end;

  p_stimuli : PROCESS
  BEGIN
  
    -- setup and reset hold
    s_pulse_in <= '0';
    s_pulse_exp <= '1';
    wait until rst = '0';
    
    for repeat in 0 to 1 loop
      s_pulse_in <= '1';
      s_pulse_exp <= '1';

      -- o_pulse extended high for...
      IF g_rising_not_falling_edge_detect then
        wait for 1*clk_period;
      else
        wait for 3*clk_period;
      end if;
      s_pulse_in <= '0';

      -- o_pulse goes low after...
      IF g_rising_not_falling_edge_detect then
        -- g_extension+1 clks after rising_edge
        wait for g_extension*clk_period;
      else
        wait for g_extension*clk_period;
      end if;
      s_pulse_exp <= '0';

      -- stability for...
      wait for 10*clk_period;
    end loop;
    tb_end <= '1';
    wait;
  END PROCESS;

  p_verify : PROCESS(clk)
    VARIABLE v_test_pass : BOOLEAN := TRUE;
    VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
  BEGIN
    v_test_pass := s_pulse_out = s_pulse_exp;
    if not v_test_pass then
      v_test_msg := pad("Pulse extension failed. Expected: " & std_logic'image(s_pulse_exp) & " but got: " & std_logic'image(s_pulse_out), o_test_msg'length,'.');
      REPORT "Pulse extension failed. Expected: " & std_logic'image(s_pulse_exp) & " but got: " & std_logic'image(s_pulse_out) severity failure;
    end if;
    o_test_msg <= v_test_msg;
    o_test_pass <= v_test_pass;
  END PROCESS;

  u_dut : ENTITY work.pulse_ext
    generic map (
      g_extension => g_extension,
      g_rising_not_falling_edge_detect => g_rising_not_falling_edge_detect
    )
    port map(
      clk => clk,
      ce => not rst,
  
      i_pulse => s_pulse_in,
      o_pulse => s_pulse_out
    );
end ARCHITECTURE;
