-- A VHDL testbench for the square-transposer block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, common_slv_arr_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE STD.TEXTIO.ALL;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;

entity tb_square_transposer is
  generic (
    g_inputs_2exp : NATURAL;
    g_input_bit_width : NATURAL
  );
  port (
    o_clk   : out std_logic;
    o_tb_end : out std_logic;
    o_test_msg : out STRING(1 to 80);
    o_test_pass : out BOOLEAN
  );
end tb_square_transposer;

architecture rtl of tb_square_transposer is
  CONSTANT clk_period : TIME    := 10 ns;
  CONSTANT g_inputs : NATURAL    := (2**g_inputs_2exp);

  SIGNAL clk : std_logic := '1';
  SIGNAL ce : std_logic := 'U';
  SIGNAL tb_end  : STD_LOGIC := '0';

  SIGNAL s_in, s_out, s_exp : t_slv_arr(
    0 to (2**g_inputs_2exp)-1,
    g_input_bit_width-1 downto 0
  ) := (OTHERS => (OTHERS => 'Z'));
  SIGNAL s_sync_in, s_sync_out : std_logic;

begin
    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

    o_clk <= clk;
    o_tb_end <= tb_end;

    u_square_transposer : ENTITY work.square_transposer
      port map (
        clk => clk,
        ce => ce,
        i_sync => s_sync_in,
        i_data => s_in,
        o_sync => s_sync_out,
        o_data => s_out
      );

    p_stimulate_then_verify : PROCESS
      VARIABLE v_test_pass : BOOLEAN := TRUE;
      VARIABLE v_index_pass : BOOLEAN := TRUE;
      VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
      VARIABLE v_s_val, v_s_out : STD_LOGIC_VECTOR(s_in'range(2));
    BEGIN

      WAIT FOR clk_period;
      WAIT UNTIL falling_edge(clk);
      ce          <= '1';
      s_sync_in   <= '0';
      WAIT FOR clk_period;
      WAIT UNTIL rising_edge(clk);

      -- set sync
      s_sync_in  <= '1';
      WAIT FOR clk_period;
      s_sync_in  <= '0';
        
      FOR time_index IN s_in'range(1) LOOP
        -- set inputs
        FOR channel IN s_in'range(1) LOOP
          v_s_val := STD_LOGIC_VECTOR(TO_UNSIGNED(
            channel*g_inputs_2exp + time_index,
            g_input_bit_width
          ));
          slv_arr_set_variable(
            s_in,
            channel,
            v_s_val
          );
        END LOOP;
        
        WAIT FOR 1*clk_period;
      END LOOP;

      -- wait for sync out
      WAIT UNTIL rising_edge(s_sync_out);
      WAIT UNTIL rising_edge(clk);
      WAIT FOR 1*clk_period;
      
      -- verify
      FOR time_index IN s_in'range(1) LOOP
        FOR channel IN s_in'range(1) LOOP
          v_s_val := STD_LOGIC_VECTOR(TO_UNSIGNED(
            -- input is transposed from
            -- channel*g_inputs_2exp + time_index,
            -- to
            time_index*g_inputs_2exp + channel,
            g_input_bit_width
          ));

          slv_arr_get_variable(v_s_out, s_out, channel);

          v_index_pass := v_s_out = v_s_val;
          if not v_index_pass then
            v_test_msg := pad("Square-Transposer failed. Time: " & integer'image(time_index) &", channel " & integer'image(channel) & ", expected: " & to_hstring(v_s_val) & " but got: " & to_hstring(v_s_out), o_test_msg'length, '.');
            v_test_pass := FALSE;
            REPORT v_test_msg severity warning;
          else
            v_test_msg := pad("Square-Transposer correct. Time: " & integer'image(time_index) &", channel " & integer'image(channel) & ", expected: " & to_hstring(v_s_val) & " got: " & to_hstring(v_s_out), o_test_msg'length, '.');
            REPORT v_test_msg severity note;
          end if;
        END LOOP;
        o_test_msg <= v_test_msg;
        o_test_pass <= v_test_pass;
        
        WAIT FOR 1*clk_period;
      END LOOP;
      if not v_test_pass then
        REPORT "Failed." severity failure;
      end if;

      -- wait some more
      WAIT for 5*clk_period;
      tb_end      <= '1';
      WAIT;
    END PROCESS;

end architecture;