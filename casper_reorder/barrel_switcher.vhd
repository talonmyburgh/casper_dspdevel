-- A VHDL implementation of the CASPER barrel_switcher block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, common_slv_arr_pkg_lib, casper_delay_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;

entity barrel_switcher is
  generic (
    g_async : BOOLEAN := FALSE
  );
  port (
    clk     : IN std_logic;
    ce      : IN std_logic;
    en      : IN std_logic := '1'; -- for supposed async mode, but really dubious reference implementation
    i_sel   : IN std_logic_vector; -- 'HIGH=MSB, 'LOW=LSB, regardless of direction (downto=LE, to=BE)
    i_sync  : IN std_logic;
    i_data  : IN t_slv_arr;
    o_sync  : OUT std_logic := '0';
    o_data  : OUT t_slv_arr
  );
end barrel_switcher;

architecture rtl of barrel_switcher is
  CONSTANT c_channels : INTEGER := i_data'length(1);
  CONSTANT c_channels_log2 : INTEGER := ceil_log2(c_channels);

  TYPE t_bs_layers_slv_arr IS ARRAY (0 to i_sel'LENGTH-2) OF t_slv_arr(i_data'range(1), i_data'range(2));
  SIGNAL s_bs_layers : t_bs_layers_slv_arr := (OTHERS => (OTHERS => (OTHERS => '0')));

	function index_wrapping(index: integer; len: natural) return integer is
	begin
		if index >= len then
      return index mod len;
    elsif index < 0 then
      return index_wrapping(index+len, len);
    else
      return index;
    end if;
	end;

begin

  gen_sync : IF not g_async GENERATE
    u_sync_delay : entity casper_delay_lib.delay_simple_sl
      generic map (
        g_delay => c_channels_log2
      )
      port map (
        clk => clk,
        ce => ce,
        i_data => i_sync,
        o_data => o_sync
      );
  end GENERATE;

  gen_async : IF g_async GENERATE
    o_sync <= i_sync;
  end GENERATE;

  gen_layer : FOR layer_index IN i_sel'range GENERATE
    SIGNAL s_bs_layer_in : t_slv_arr(i_data'range(1), i_data'range(2));
    CONSTANT c_layer_index_offset : NATURAL := pow2(layer_index-i_sel'LOW);
    SIGNAL s_sel_delayed : std_logic_vector(i_sel'range);
  BEGIN

    gen_layer_input : IF layer_index = i_sel'left GENERATE
      s_bs_layer_in <= i_data;
      s_sel_delayed <= i_sel;
    END GENERATE;
    gen_layer_cascade_in : IF layer_index /= i_sel'left GENERATE

      gen_layer_cascade_in_asc : IF i_sel'ASCENDING GENERATE
        u_sel_delay_asc : entity casper_delay_lib.delay_simple
        generic map (
          g_delay => layer_index-i_sel'LEFT
        )
        port map (
          clk => clk,
          ce => ce,
          i_data => i_sel,
          o_data => s_sel_delayed
        );

        s_bs_layer_in <= s_bs_layers((layer_index-i_sel'left)-1);
      END GENERATE;
      gen_layer_cascade_in_desc : IF not i_sel'ASCENDING GENERATE
        u_sel_delay_desc : entity casper_delay_lib.delay_simple
        generic map (
          g_delay => i_sel'LEFT-layer_index
        )
        port map (
          clk => clk,
          ce => ce,
          i_data => i_sel,
          o_data => s_sel_delayed
        );

        s_bs_layer_in <= s_bs_layers((i_sel'left-layer_index)-1);
      END GENERATE;
    END GENERATE;

    gen_chan : FOR channel_index IN s_bs_layer_in'range(1) GENERATE
      SIGNAL s_i_data_0, s_i_data_1, s_o_data : std_logic_vector(i_data'range(2));
    BEGIN
      s_i_data_0 <= slv_arr_index(s_bs_layer_in, channel_index);
      s_i_data_1 <= slv_arr_index(s_bs_layer_in, i_data'LOW(1) + index_wrapping(channel_index-i_data'LOW(1)+c_layer_index_offset, i_data'LENGTH(1)));
      
      gen_bit : FOR bit_index IN s_bs_layer_in'range(2) GENERATE
      BEGIN

        gen_layer_output : IF layer_index = i_sel'right GENERATE
          o_data(channel_index, bit_index) <= s_o_data(bit_index);
        END GENERATE;
        gen_layer_cascade_out : IF layer_index /= i_sel'right GENERATE
          gen_layer_cascade_out_asc : IF i_sel'ASCENDING GENERATE
            s_bs_layers(layer_index-i_sel'left)(channel_index, bit_index) <= s_o_data(bit_index);
          END GENERATE;
          gen_layer_cascade_out_desc : IF not i_sel'ASCENDING GENERATE
            s_bs_layers(i_sel'left-layer_index)(channel_index, bit_index) <= s_o_data(bit_index);
          END GENERATE;
        END GENERATE;
      END GENERATE;

      u_layerchan_mux : entity work.mux
        generic map (
          g_async => g_async
        )
        port map (
          clk => clk,
          ce => ce,
          en => en,
          i_sel => s_sel_delayed(layer_index),
          i_data_0 => s_i_data_0,
          i_data_1 => s_i_data_1,
          o_data => s_o_data
        );

    END GENERATE;
  END GENERATE;

end architecture;