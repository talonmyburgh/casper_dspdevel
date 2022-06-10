-- A VHDL implementation of the CASPER pulse_ext block.
-- @author: Mydon Solutions.

LIBRARY IEEE, casper_counter_lib, common_pkg_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;

ENTITY pulse_ext is
  generic (
    g_extension : NATURAL := 4;
    g_rising_not_falling_edge_detect : BOOLEAN := TRUE
  );
  port (
    clk   : in std_logic := '1';
    ce    : in std_logic := '1';

    i_pulse   : in std_logic;
    o_pulse  : out std_logic
  );
end ENTITY;

ARCHITECTURE rtl of pulse_ext is
  CONSTANT c_counter_bit_w : NATURAL := ceil_log2(g_extension + 1);

  SIGNAL s_pulse : std_logic_vector(0 downto 0);
  SIGNAL s_count_rst : std_logic_vector(0 downto 0);
  
  SIGNAL s_count : std_logic_vector(c_counter_bit_w-1 downto 0);
  SIGNAL s_counted : std_logic;
BEGIN

  s_pulse(0) <= i_pulse;

  u_rising_edge : entity work.edge_detect
  generic map (
      g_edge_type => sel_a_b(g_rising_not_falling_edge_detect, "rising", "falling"),
      g_output_pol => "high"
  )
  port map (
      clk => clk,
      ce  => ce,
      in_sig => s_pulse,
      out_sig => s_count_rst
  );

  u_counter : ENTITY casper_counter_lib.free_run_up_counter
    generic map (
      g_cnt_w => c_counter_bit_w
    )
    port map (
      clk => clk,
      ce => s_counted,
		  reset => s_count_rst(0),
      count => s_count
    );
  
  gen_rising_edge_out : IF g_rising_not_falling_edge_detect GENERATE
    -- when extending rising_edge, o_pulse is forced to be g_extension clks long after edge
    s_counted <= '1' when s_count /= TO_UVEC(g_extension, c_counter_bit_w) else i_pulse;
  END GENERATE;
  gen_falling_edge_out : IF not g_rising_not_falling_edge_detect GENERATE
    -- when extending falling_edge, o_pulse is extended to be higher for g_extension clks longer after edge
    --  but counter has latency of 1, so account for it.
    s_counted <= '1' when s_count /= TO_UVEC(g_extension-1, c_counter_bit_w) else i_pulse;
  END GENERATE;
  o_pulse <= s_counted;

end ARCHITECTURE;
