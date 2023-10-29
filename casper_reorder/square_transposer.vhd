-- A VHDL implementation of the CASPER square_transposer block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, common_slv_arr_pkg_lib, casper_delay_lib, casper_counter_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;

entity square_transposer is
  generic (
    g_async : BOOLEAN := FALSE
  );
  port (
    clk     : IN std_logic;
    ce      : IN std_logic;
    i_sync  : IN std_logic;
    i_data  : IN t_slv_arr;
    o_sync  : OUT std_logic := '0';
    o_data  : OUT t_slv_arr
  );
end square_transposer;

architecture rtl of square_transposer is
  CONSTANT c_inputs_log2 : INTEGER := ceil_log2(i_data'LENGTH(1));

  SIGNAL s_delayed_in, s_out : t_slv_arr(i_data'RANGE(1), i_data'RANGE(2)) := (OTHERS => (OTHERS => '0'));
  SIGNAL s_sync_out, s_sync_out_pre : std_logic_vector(0 downto 0) := (OTHERS => '0');
  SIGNAL s_sel_counting_desc : std_logic_vector(c_inputs_log2-1 downto 0) := (OTHERS => '0');
begin
  
  u_barrel_switcher : ENTITY work.barrel_switcher
  generic map (
    g_async => g_async
  )
  port map (
    clk => clk,
    ce => ce,
    i_sel => s_sel_counting_desc,
    i_sync => i_sync,
    i_data => s_delayed_in,
    o_sync => s_sync_out(0),
    o_data => s_out
  );
  
  u_sync_delay : entity casper_delay_lib.delay_simple
    generic map (
      g_delay => i_data'LENGTH(1)-1
    )
    port map (
      clk => clk,
      ce => ce,
      i_data => s_sync_out,
      o_data => s_sync_out_pre
  );
  o_sync <= s_sync_out_pre(0);
  
  u_counter : entity casper_counter_lib.free_run_up_counter
    generic map (
      g_cnt_w => c_inputs_log2,
      g_cnt_up_not_down => FALSE,
      g_cnt_initial_value => 0,
      g_cnt_signed => FALSE
    )
    port map (
      clk => clk,
      ce => ce,
      reset => i_sync,
      count => s_sel_counting_desc
  );

  gen_in : FOR i in i_data'RANGE(1) GENERATE
    SIGNAL s_i_data, s_o_data : std_logic_vector(i_data'range(2));
  BEGIN
    
    gen_no_delay : IF i = i_data'LEFT(1) GENERATE
      -- zero delays
      s_i_data <= slv_arr_index(i_data, i_data'LEFT(1));
      s_o_data <= slv_arr_index(s_out, s_out'RIGHT(1));
    END GENERATE;
    gen_delayed : IF i /= i_data'LEFT(1) GENERATE
      SIGNAL s_i_data_in, s_o_data_in : std_logic_vector(i_data'range(2));
    BEGIN
      s_i_data_in <= slv_arr_index(
        i_data,
        i
      );

      s_o_data_in <= slv_arr_index(
        s_out,
        s_out'RIGHT(1)-(i-i_data'LEFT(1))*(
          (s_out'RIGHT(1)-s_out'LEFT(1))/(s_out'LENGTH(1)-1)
        )
      );

      u_in_delay : entity casper_delay_lib.delay_simple
        generic map (
          g_delay => abs(i-i_data'LEFT(1))
        )
        port map (
          clk => clk,
          ce => ce,
          i_data => s_i_data_in,
          o_data => s_i_data
      );

      u_out_delay : entity casper_delay_lib.delay_simple
        generic map (
          g_delay => abs(i-i_data'LEFT(1))
        )
        port map (
          clk => clk,
          ce => ce,
          i_data => s_o_data_in,
          o_data => s_o_data
      );
    END GENERATE;

    gen_bit_stitch : for bit_index in s_i_data'range GENERATE
      s_delayed_in(
        i_data'LEFT(1) + 
          ((i_data'LENGTH(1)-(i-i_data'LEFT(1))) mod i_data'LENGTH(1))*(
            (i_data'RIGHT(1)-i_data'LEFT(1))/(i_data'LENGTH(1)-1)
          ),
        bit_index
      ) <= s_i_data(bit_index);
      o_data(
        s_out'RIGHT(1)-(i-i_data'LEFT(1))*(
          (s_out'RIGHT(1)-s_out'LEFT(1))/(s_out'LENGTH(1)-1)
        ),
        bit_index
      ) <= s_o_data(bit_index);
    END GENERATE;
  END GENERATE;

end architecture;