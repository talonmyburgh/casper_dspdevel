-- A VHDL implementation of the CASPER barrel_switcher block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, common_slv_arr_pkg_lib, casper_delay_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;

entity barrel_switcher is
  generic (
    g_barrel_switcher_division_bit_width : NATURAL := 4
  );
  port (
    clk     : IN std_logic;
    ce      : IN std_logic;
    i_sync  : IN std_logic;
    i_sel   : IN std_logic_vector;
    i_data  : IN t_slv_arr;
    o_sync  : OUT std_logic;
    o_data  : OUT t_slv_arr
  );
end barrel_switcher;

architecture rtl of barrel_switcher is
  CONSTANT c_channels : INTEGER := i_data'length;
  CONSTANT c_channels_log2 : INTEGER := ceil_log2(c_channels);

  SIGNAL s_sync_in, s_sync_out : std_logic_vector(0 to 0);
  SIGNAL s_sel_layerdelayed : std_logic_vector(i_sel'range);
  
  TYPE t_bs_layers_slv_arr IS ARRAY (0 to c_channels_log2) OF t_slv_arr(i_data'range(1), i_data'range(2));
  SIGNAL s_bs_layers : t_bs_layers_slv_arr;
  
	function leftindex_wrapping(index, top : integer) return integer is
	begin
		if index < 0 then
      return top + 1 + index;
    else
      return index;
    end if;
	end;

begin

  s_sel_layerdelayed(i_sel'LOW) <= i_sel(i_sel'LOW);
  gen_selbit_delay : FOR sel_bit_index IN 1 to i_sel'LENGTH-1 GENERATE
    u_selbit_delay : entity casper_delay_lib.delay_simple
      generic map (
        g_delay => sel_bit_index
      )
      port map (
        clk => clk,
        ce => ce,
        i_data => i_sel(i_sel'LOW + sel_bit_index to i_sel'LOW + sel_bit_index),
        o_data => s_sel_layerdelayed(i_sel'LOW + sel_bit_index to i_sel'LOW + sel_bit_index)
      );
  END GENERATE;

  s_sync_in(0) <= i_sync;
  o_sync <= s_sync_out(0);
  u_sync_delay : entity casper_delay_lib.delay_simple
    generic map (
      g_delay => c_channels_log2
    )
    port map (
      clk => clk,
      ce => ce,
      i_data => s_sync_in,
      o_data => s_sync_out
    );

  s_bs_layers(0) <= i_data;
  o_data <= s_bs_layers(c_channels_log2);
  -- gen_bs_layers : FOR channel_index IN i_data'RANGE GENERATE
  --   s_bs_layers(0, channel_index) <= i_data(channel_index);
  --   o_data(channel_index) <= s_bs_layers(c_channels_log2, channel_index);
  -- END GENERATE;

  gen_layer : FOR layer_index IN 0 to c_channels_log2-1 GENERATE
    gen_chan : FOR channel_index IN 0 to i_data'LENGTH-1 GENERATE
      SIGNAL i_data_0, i_data_1, o_data : std_logic_vector(i_data'range(2));
    BEGIN
      slv_arr_get(i_data_0, s_bs_layers(layer_index), channel_index);
      slv_arr_get(i_data_1, s_bs_layers(layer_index), leftindex_wrapping(channel_index-pow2(c_channels_log2-1-layer_index), i_data'HIGH));

      u_layerchan_mux : entity work.mux
        port map (
          clk => clk,
          ce => ce,
          i_sel => s_sel_layerdelayed(layer_index),
          i_data_0 => i_data_0,
          i_data_1 => i_data_1,
          -- o_data => s_bs_layers(layer_index+1, i_data'LOW + channel_index)
          o_data => o_data
        );
      
      slv_arr_set(s_bs_layers(layer_index+1), channel_index, o_data);
      -- s_bs_layers(layer_index+1, i_data'LOW + channel_index)
    END GENERATE;
  END GENERATE;

end architecture;