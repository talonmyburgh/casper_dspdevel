-- A VHDL implementation of the CASPER bus_mux block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, common_slv_arr_pkg_lib, casper_delay_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;

entity bus_mux is
  generic (
    g_delay : NATURAL := 1
  );
  port (
    clk     : IN std_logic;
    ce      : IN std_logic;
    i_sel   : IN std_logic_vector; -- 'HIGH=MSB, 'LOW=LSB, regardless of direction (downto=LE, to=BE)
    i_data  : IN t_slv_arr;
    o_data  : OUT std_logic_vector
  );
end bus_mux;

architecture rtl of bus_mux is
  SIGNAL s_data_selected : std_logic_vector(i_data'range(2));
  SIGNAL s_sel :  NATURAL RANGE i_data'range(1);
begin

  s_sel <= TO_UINT(i_sel);

  g_bits_selection : FOR bit_index in i_data'range(2) GENERATE
    s_data_selected(bit_index) <= i_data(s_sel, bit_index);
  END GENERATE;

  g_comb : IF g_delay = 0 GENERATE
    o_data <= s_data_selected;
  END GENERATE;

  g_delayed : IF g_delay /= 0 GENERATE
    u_data_delay : entity casper_delay_lib.delay_simple
      generic map (
        g_delay => g_delay
      )
      port map (
        clk => clk,
        ce => ce,
        i_data => s_data_selected,
        o_data => o_data
      );
  END GENERATE;
end architecture;