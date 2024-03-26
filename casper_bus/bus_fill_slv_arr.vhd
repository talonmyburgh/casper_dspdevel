-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_slv_arr_pkg_lib, casper_delay_lib;
USE IEEE.std_logic_1164.all;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;

ENTITY bus_fill_slv_arr is
  generic (
    g_latency : NATURAL
  );
  port (
    clk   : in std_logic := '1';
    ce    : in std_logic := '1';

    i_data  : in std_logic_vector;
    o_data  : out t_slv_arr
  );
end ENTITY;

ARCHITECTURE rtl of bus_fill_slv_arr is
  SIGNAL s_in : t_slv_arr(o_data'RANGE(1), i_data'RANGE);
begin
  o_data <= s_in;

  g_concat : FOR I IN s_in'RANGE(1) GENERATE
    SIGNAL s_in_i : std_logic_vector(s_in'RANGE(2));
  begin
    g_delay : IF g_latency > 0 GENERATE
      u_data_delay : entity casper_delay_lib.delay_simple
        generic map (
          g_delay => g_latency
        )
        port map (
          clk => clk,
          ce => ce,
          i_data => i_data,
          o_data => s_in_i
        );
    end GENERATE;
    g_no_delay : IF g_latency = 0 GENERATE
      s_in_i <= i_data;
    end GENERATE;

    g_concat_bits : FOR bit_i IN s_in_i'RANGE GENERATE
      s_in(i, bit_i) <= s_in_i(bit_i);
    end GENERATE;
  end GENERATE;

end ARCHITECTURE;
