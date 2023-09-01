-- A VHDL testbench for the barrel-switcher block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, common_slv_arr_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.all;
USE STD.TEXTIO.ALL;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;

entity tb_barrel_switcher is
  generic (
    g_barrel_switch_inputs : NATURAL;
    g_barrel_switcher_division_bit_width : NATURAL
  );
  port (
    o_clk   : out std_logic;
    o_tb_end : out std_logic;
    o_test_msg : out STRING(1 to 80);
    o_test_pass : out BOOLEAN
  );
end tb_barrel_switcher;

architecture rtl of tb_barrel_switcher is
  CONSTANT clk_period : TIME    := 10 ns;

  SIGNAL clk : std_logic := '1';
  SIGNAL ce : std_logic := 'U';
  SIGNAL tb_end  : STD_LOGIC := '0';

  SIGNAL s_in, s_out, s_exp : t_slv_arr(
    0 to g_barrel_switch_inputs-1,
    g_barrel_switcher_division_bit_width-1 downto 0
  );
  SIGNAL s_sync_in, s_sync_out : std_logic;
  SIGNAL s_sel : std_logic_vector(ceil_log2(g_barrel_switch_inputs)-1 downto 0);

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
    clk  <= NOT clk OR tb_end AFTER clk_period / 2;

    o_clk <= clk;
    o_tb_end <= tb_end;

    u_barrel_switcher : ENTITY work.barrel_switcher
      port map (
        clk => clk,
        ce => ce,
        i_sel => s_sel,
        i_sync => s_sync_in,
        i_data => s_in,
        o_sync => s_sync_out,
        o_data => s_out
      );

    p_stimuli : PROCESS
      VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
      VARIABLE v_test_pass : BOOLEAN := TRUE;
      VARIABLE v_s_in : STD_LOGIC_VECTOR(s_in'range(2));
    BEGIN

      WAIT FOR clk_period;
      WAIT UNTIL falling_edge(clk);
      ce          <= '1';
      s_sync_in   <= '0';
      WAIT FOR clk_period;
      WAIT UNTIL rising_edge(clk);

      FOR shift IN 0 to s_in'LENGTH+5 LOOP
        -- set inputs
        FOR channel IN s_in'range(1) LOOP
          v_s_in := TO_SVEC(channel+(shift mod 2), g_barrel_switcher_division_bit_width);
          slv_arr_set_variable(
            s_in,
            channel,
            v_s_in
          );
        END LOOP;
        
        -- set sel
        s_sel  <= TO_SVEC(shift mod s_in'LENGTH, s_sel'LENGTH);

        -- pulse sync in
        s_sync_in   <= '1';
        WAIT FOR 1*clk_period;
        s_sync_in   <= '0';

        -- set exp
        FOR channel IN 0 to s_in'LENGTH-1 LOOP
          slv_arr_set(
            s_exp,
            channel,
            s_in,
            index_wrapping(channel+shift, s_in'LENGTH(1))
          );
        END LOOP;

        -- wait for sync out
        WAIT UNTIL rising_edge(s_sync_out);
        -- wait some more
        WAIT FOR 5*clk_period;
      END LOOP;

      WAIT for clk_period * 2;
      tb_end      <= '1';
      WAIT;
    END PROCESS;

    p_verify : PROCESS(s_sync_out)
        VARIABLE v_test_pass : BOOLEAN := TRUE;
        VARIABLE v_index_pass : BOOLEAN := TRUE;
        VARIABLE v_test_msg  : STRING(1 to o_test_msg'length) := (OTHERS => '.');
        VARIABLE s_out_i, s_exp_i : STD_LOGIC_VECTOR(s_out'range(2));
    BEGIN
        if rising_edge(s_sync_out) then
          for i in s_in'RANGE LOOP
            slv_arr_get_variable(s_out_i, s_out, i);
            slv_arr_get_variable(s_exp_i, s_exp, i);
            v_index_pass := s_out_i = s_exp_i;
            if not v_index_pass then
              v_test_msg := pad("Barrel-shift failed. Sel: " & to_hstring(s_sel) &". At index " & integer'image(i) & ", expected: " & to_hstring(s_exp_i) & " but got: " & to_hstring(s_out_i), o_test_msg'length, '.');
              v_test_pass := FALSE;
              REPORT v_test_msg severity warning;
            else
              v_test_msg := pad("Barrel-shift correct. Sel: " & to_hstring(s_sel) &". At index " & integer'image(i) & ", expected: " & to_hstring(s_exp_i) & " got: " & to_hstring(s_out_i), o_test_msg'length, '.');
              REPORT v_test_msg severity note;
            end if;
          end loop;
          o_test_msg <= v_test_msg;
          o_test_pass <= v_test_pass;
          if not v_test_pass then
            REPORT "Failed." severity failure;
          end if;
        end if;
    END PROCESS;

end architecture;