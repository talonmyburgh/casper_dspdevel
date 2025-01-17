-- A VHDL implementation of the CASPER bus_replicate block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_slv_arr_pkg_lib, casper_flow_control_lib;
USE IEEE.std_logic_1164.all;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;

ENTITY bus_replicate is
  generic (
    g_replication_factor : NATURAL;
    g_latency : NATURAL
  );
  port (
    clk   : in std_logic := '1';
    ce    : in std_logic := '1';

    i_data  : in std_logic_vector;
    o_data  : out std_logic_vector
  );
end ENTITY;

ARCHITECTURE rtl of bus_replicate is
  SIGNAL s_in : t_slv_arr(0 to g_replication_factor-1, i_data'RANGE);
begin
  u_bus_fill_slv_arr : entity work.bus_fill_slv_arr
    generic map (
      g_latency => g_latency
    )
    port map (
      clk => clk,
      ce => ce,
  
      i_data => i_data,
      o_data => s_in
    );

  u_bus_create : entity casper_flow_control_lib.bus_create
  port map (
      clk => clk,
      ce => ce,
      din => s_in,
      dout => o_data
  );

end ARCHITECTURE;
