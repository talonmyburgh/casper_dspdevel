-- A VHDL testbench for the reorder block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, common_slv_arr_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;

entity tb_reorder is
  generic (
    g_input_bit_width: NATURAL;
    g_nof_inputs: NATURAL;
    g_reorder_map: t_nat_natural_arr;

    g_reorder_order: NATURAL;
    g_map_latency: NATURAL;
    g_bram_latency: NATURAL;
    g_fanout_latency: NATURAL;
    g_double_buffer: BOOLEAN;
    g_block_ram: BOOLEAN;
    g_software_controlled: BOOLEAN;
    g_mem_filepath: STRING
  );
  port (
    o_clk   : out std_logic;
    o_tb_end : out std_logic;
    o_test_msg : out STRING(1 to 80);
    o_test_pass : out BOOLEAN
  );
end tb_reorder;

architecture rtl of tb_reorder is
  CONSTANT clk_period : TIME := 10 ns;
  CONSTANT g_reorder_length : NATURAL := g_reorder_map'length;

  SIGNAL clk : std_logic := '1';
  SIGNAL ce : std_logic := 'U';
  SIGNAL en : std_logic := '1';
  SIGNAL tb_end  : STD_LOGIC := '0';

  SIGNAL s_in, s_out : t_slv_arr(
    0 to g_nof_inputs-1,
    g_input_bit_width-1 downto 0
  ) := (OTHERS => (OTHERS => 'Z'));
  SIGNAL s_sync_in, s_sync_out, s_valid_out : std_logic;

begin
    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

    o_clk <= clk;
    o_tb_end <= tb_end;

    u_reorder : ENTITY work.reorder
      generic map (
        g_reorder_order => g_reorder_order,
        g_reorder_length => g_reorder_length,
        g_map_latency => g_map_latency,
        g_bram_latency => g_bram_latency,
        g_fanout_latency => g_fanout_latency,
        g_double_buffer => g_double_buffer,
        g_block_ram => g_block_ram,
        g_software_controlled => g_software_controlled,
        g_mem_filepath => g_mem_filepath
      )
      port map (
        clk => clk,
        ce => ce,
        i_sync => s_sync_in,
        i_en => '1',
        i_data => s_in,
        o_sync => s_sync_out,
        o_valid => s_valid_out,
        o_data => s_out
      );

    p_stimulate : PROCESS
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
        
      FOR time_index IN 0 to g_reorder_length-1 LOOP
        v_s_val := STD_LOGIC_VECTOR(TO_UNSIGNED(
          time_index,
          g_input_bit_width
        ));
        -- set inputs
        FOR channel IN s_in'range(1) LOOP
          slv_arr_set_variable(
            s_in,
            channel,
            v_s_val
          );
        END LOOP;
        
        WAIT FOR 1*clk_period;
      END LOOP;

      WAIT;
    END PROCESS;

      
  p_verify : PROCESS
    VARIABLE v_test_pass : BOOLEAN := TRUE;
    VARIABLE v_index_pass : BOOLEAN := TRUE;
    VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
    VARIABLE s_out_i, s_exp_i : STD_LOGIC_VECTOR(s_out'range(2));
  BEGIN
    wait until rising_edge(s_valid_out);
    wait for 1*clk_period;

    FOR time_index IN 0 to g_reorder_length-1 LOOP
      FOR channel IN s_out'RANGE(1) LOOP
        slv_arr_get_variable(s_out_i, s_out, channel);
        s_exp_i := TO_SVEC(g_reorder_map(time_index), s_exp_i'length);

        v_index_pass := s_out_i = s_exp_i;

        if not v_index_pass then
          v_test_msg := pad("Reorder failed. Input: " & integer'image(channel) &", Time: " & integer'image(time_index) &" -> index " & integer'image(g_reorder_map(time_index)) & ", expected: " & to_hstring(s_exp_i) & " but got: " & to_hstring(s_out_i), o_test_msg'length, '.');
          v_test_pass := FALSE;
          REPORT v_test_msg severity warning;
        else
          v_test_msg := pad("Reorder correct. Input: " & integer'image(channel) &", Time: " & integer'image(time_index) &" -> index " & integer'image(g_reorder_map(time_index)) & ", expected: " & to_hstring(s_exp_i) & " got: " & to_hstring(s_out_i), o_test_msg'length, '.');
          REPORT v_test_msg severity note;
        end if;
      end loop;

      o_test_msg <= v_test_msg;
      o_test_pass <= v_test_pass;
      
      wait for 1*clk_period;
    end loop;
    if not v_test_pass then
      REPORT "Failed." severity failure;
    end if;
    
    tb_end <= '1';
    wait;
  END PROCESS;

end architecture;