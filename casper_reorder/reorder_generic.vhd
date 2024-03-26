-- A VHDL wrap-up of the CASPER reorder block, that takes the reorder
-- mapping as a generic, writes that to a .mem file and then instantiates
-- the 'reorder' unit.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, common_slv_arr_pkg_lib, casper_delay_lib, casper_ram_lib, casper_misc_lib, casper_bus_lib, casper_counter_lib;
USE IEEE.std_logic_1164.all;
use std.textio.all;
use ieee.std_logic_textio.all;

USE common_pkg_lib.common_pkg.all;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;
USE casper_ram_lib.common_ram_pkg.all;

ENTITY reorder_generic is
  generic (
    g_reorder_map: t_nat_natural_arr;
    g_map_latency: NATURAL;
    g_bram_latency: NATURAL;
    g_fanout_latency: NATURAL;
    g_double_buffer: BOOLEAN;
    g_block_ram: BOOLEAN;
    g_software_controlled: BOOLEAN;
    g_mem_filepath_prefix: STRING := "./"
  );
  port (
    clk   : in std_logic;
    ce    : in std_logic;
    i_sync  : in std_logic;
    i_en    : in std_logic;
    i_data  : in t_slv_arr;
    o_sync  : out std_logic;
    o_valid : out std_logic;
    o_data  : out t_slv_arr
  );
end ENTITY;

ARCHITECTURE rtl of reorder_generic is
  function gcd (a, b : natural) return natural is
    variable v_a : natural := a;
    variable v_b : natural := b;
  begin
    while (v_a /= 0) and (v_b /= 0) and (v_a /= v_b) loop
      if a > b then
        v_a := a-b;
      else
        v_b := b-a;
      end if;
    end loop;

    -- REPORT "gcd(" & natural'image(a) & ", " & natural'image(b) & "): " & natural'image(v_a) & ", " & natural'image(v_b) severity note;
    if v_a = 0 then
      return v_a;
    else
      return v_b;
    end if;
  end function;

  function lcm (a, b : natural) return natural is
  begin
    return (a * b) / gcd(a, b);
  end function;

  function compute_order (double_buffer: BOOLEAN; reorder_map : t_nat_natural_arr) return natural is
    variable order, cur_order, count : NATURAL := 1;
    variable j : integer := -1;
  begin
    if double_buffer then
      return 2;
    end if;

    -- algorithm comes from Matlab code which is 1-indexed,
    -- so indices are decremented
    assert reorder_map'ASCENDING
      report "This algorithm is made for an ascending vector."
      severity error;
    
    FOR i in 1 to reorder_map'LENGTH loop
      j := -1;
      cur_order := 1;
      count := 1;
      while j + 1 /= i loop
        assert reorder_map'length >= count
        report "Reorder map seems to have an interminable order"
        severity error;

        if j < 0 then
          j := reorder_map(i-1);
        else
          j := reorder_map(j+1-1);
          cur_order := cur_order + 1;
        end if;
        count := count + 1;
      END loop;
      order := lcm(order, cur_order);
    END loop;
    REPORT "order = " & natural'image(order) severity note;
    return order;
  end function;

  impure function create_reorder_mem_file(content : t_nat_natural_arr; filepath : string) RETURN STRING is
    file file_handler     : text open write_mode is filepath;
    variable row          : line;

    variable v_svec : std_logic_vector(ceil_log2(content'length)-1 downto 0);
  begin
    for i in content'range loop
      v_svec := TO_SVEC(content(i), v_svec'length);
      hwrite(row, v_svec, RIGHT, v_svec'length);
      writeline(file_handler, row);
    end loop;

    return filepath;
  end function;

  impure function create_counter_mem_file(len: natural; filepath : string) RETURN STRING is
    variable v_content : t_nat_natural_arr(0 to len-1);
  begin
    for i in v_content'range loop
      v_content(i) := i;
    end loop;

    return create_reorder_mem_file(v_content, filepath);
  end function;

  impure function setup_reorder_mem_filepath(order: natural; content: t_nat_natural_arr; filepath_prefix: string) return STRING is
    constant c_mem_filepath : string := filepath_prefix & "reorder.mem";
  begin
    if order = 1 then
      return "UNUSED";
    end if;
    return c_mem_filepath; --create_reorder_mem_file(content, c_mem_filepath);
  end function;

  CONSTANT c_order : NATURAL := compute_order(g_double_buffer, g_reorder_map);
  CONSTANT c_reorder_mem_filepath : STRING := setup_reorder_mem_filepath(c_order, g_reorder_map, g_mem_filepath_prefix);
BEGIN

  u_reorder : entity work.reorder
    generic map (
      g_reorder_order => c_order,
      g_reorder_length => g_reorder_map'length,
      g_map_latency => g_map_latency,
      g_bram_latency => g_bram_latency,
      g_fanout_latency => g_fanout_latency,
      g_double_buffer => g_double_buffer,
      g_block_ram => g_block_ram,
      g_software_controlled => g_software_controlled,
      g_mem_filepath => c_reorder_mem_filepath
    )
    port map (
      clk => clk,
      ce => ce,
      i_sync => i_sync,
      i_en => i_en,
      i_data => i_data,
      o_sync => o_sync,
      o_valid => o_valid,
      o_data => o_data
    );
end ARCHITECTURE;