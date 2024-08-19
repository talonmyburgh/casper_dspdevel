-- Abstraction of sl_mat as an SLV array.
-- Inspired by https://stackoverflow.com/a/28514135
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE;
USE IEEE.std_logic_1164.all;

package common_slv_arr_pkg is
  type t_slv_arr is array(natural range <>, natural range <>) of std_logic;
  constant c_slv_arr_default : t_slv_arr := (others => (others => '0'));

  procedure slv_arr_set(signal slv_arr : out t_slv_arr; constant idx : natural; signal slv : in std_logic_vector);
  procedure slv_arr_set_variable(signal slv_arr : out t_slv_arr; constant idx : natural; variable slv : in std_logic_vector);
  procedure slv_arr_set(signal slv_arr : out t_slv_arr; constant out_idx : natural; signal slv_arr_in : in t_slv_arr; constant in_idx : natural);

  procedure slv_arr_get(signal slv : out std_logic_vector; signal slv_arr : in t_slv_arr; constant idx : natural);
  procedure slv_arr_get_variable(variable slv : out std_logic_vector; signal slv_arr : in t_slv_arr; constant idx : natural);
  function slv_arr_index(signal slv_arr : in t_slv_arr; constant idx : natural) return std_logic_vector;
end package;

package body common_slv_arr_pkg is
  procedure slv_arr_set(signal slv_arr : out t_slv_arr; constant idx : natural; signal slv : in std_logic_vector) is
	begin
		for i in slv'range loop
			slv_arr(idx, i) <= slv(i);
		end loop;
  end procedure;

  procedure slv_arr_set_variable(signal slv_arr : out t_slv_arr; constant idx : natural; variable slv : in std_logic_vector) is
  begin
    for i in slv'range loop
      slv_arr(idx, i) <= slv(i);
    end loop;
  end procedure;

  procedure slv_arr_set(signal slv_arr : out t_slv_arr; constant out_idx : natural; signal slv_arr_in : in t_slv_arr; constant in_idx : natural) is
  begin
    for i in slv_arr_in'range(2) loop
      slv_arr(out_idx, i) <= slv_arr_in(in_idx, i);
    end loop;
  end procedure;

  procedure slv_arr_get(signal slv : out std_logic_vector; signal slv_arr : in t_slv_arr; constant idx : natural) is
  begin
    for i in slv'range loop
      slv(i) <= slv_arr(idx, i);
    end loop;
  end procedure;

  procedure slv_arr_get_variable(variable slv : out std_logic_vector; signal slv_arr : in t_slv_arr; constant idx : natural) is
  begin
    for i in slv'range loop
      slv(i) := slv_arr(idx, i);
    end loop;
  end procedure;

  function slv_arr_index(signal slv_arr : in t_slv_arr; constant idx : natural) return std_logic_vector is
    variable result: STD_LOGIC_VECTOR(slv_arr'RANGE(2));
  begin
    for i in slv_arr'range(2) loop
      result(i) := slv_arr(idx, i);
    end loop;
    return result;
  end function;
end package body;