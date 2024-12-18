-- A VHDL testbench for CASPER bus_replicate block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.ALL;

ENTITY tb_bus_replicate is
  generic (
    g_replication_factor : NATURAL := 2;
    g_latency : NATURAL := 0;
    g_replicated_value : NATURAL := 6
  );
  port (
    o_clk   : out std_logic;
    o_tb_end : out std_logic;
    o_test_msg : out STRING(1 to 80);
    o_test_pass : out BOOLEAN  
  );
end ENTITY;

ARCHITECTURE rtl of tb_bus_replicate is
  CONSTANT clk_period : TIME    := 10 ns;
  
  SIGNAL clk : std_logic := '1';
  SIGNAL ce : std_logic := '1';
  SIGNAL tb_end  : STD_LOGIC := '0';

  CONSTANT bit_width : NATURAL := ceil_log2(g_replicated_value);

  SIGNAL s_in : std_logic_vector(bit_width-1 downto 0) := (others => '0');
  SIGNAL s_out : std_logic_vector((bit_width*g_replication_factor)-1 downto 0) := (others => '0');
begin

  clk  <= NOT clk OR tb_end AFTER clk_period / 2;

  o_clk <= clk;
  o_tb_end <= tb_end;

  u_bus_replicate : entity work.bus_replicate
    generic map (
      g_replication_factor => g_replication_factor,
      g_latency => g_latency
    )
    port map (
      clk => clk,
      ce => ce,
  
      i_data => s_in,
      o_data => s_out
    );

  p_stim: process
    variable v_din_index, v_dout_index: integer;
    VARIABLE v_test_pass : BOOLEAN := TRUE;
    VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
  begin
    ce <= '0';
    s_in <= std_logic_vector(to_unsigned(g_replicated_value, bit_width));
    
    wait until rising_edge(clk);
    wait for 3*clk_period;
    ce <= '1';
    wait for g_latency*clk_period;

    for r in 0 to g_replication_factor loop
      if g_replicated_value /= unsigned(s_out(
          ((r+1)*bit_width)-1 downto (r*bit_width)
      )) then
        v_test_msg := pad("Replication #"& integer'image(r) &" failed. Expected: " & integer'image(g_replicated_value) & " but got: " & integer'image(to_integer(unsigned(s_dout(
          ((r+1)*bit_width)-1 downto (r*bit_width)
        )))), o_test_msg'length, '.');
        v_test_pass := FALSE;
        REPORT v_test_msg severity failure;
      end if;
          
      o_test_msg <= v_test_msg;
      o_test_pass <= v_test_pass;
    end loop;

    tb_end <= '1';
    wait;
  end process;

end ARCHITECTURE;
