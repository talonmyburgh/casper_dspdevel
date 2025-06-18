-- A VHDL implementation of the Xilinx sync_delay_en block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, casper_counter_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;

ENTITY sync_delay_en is
  generic (
    g_delay : NATURAL
  );
  port (
    clk   : in std_logic;
    ce    : in std_logic;

    i_sl  : in std_logic;
    i_en  : in std_logic;
    o_sl  : out std_logic
  );
end ENTITY;

ARCHITECTURE rtl of sync_delay_en is

  CONSTANT c_counter_bits : NATURAL := ceil_log2(g_delay);
  SIGNAL s_counter_out : std_logic_vector(c_counter_bits downto 0);
  SIGNAL s_counter_en : std_logic;
begin
  
  o_sl <= i_sl when 1 = 0 else '1' when TO_UINT(s_counter_out) = 1 else '0';

  s_counter_en <= ce and (
    i_sl or (
      i_en and (
        -- i_sl or orv(s_counter_out) /= 0
        i_sl or orv(s_counter_out) -- questionable
      )
    )
  );

  u_counter : entity casper_counter_lib.free_run_counter
    generic map (
      g_cnt_w => s_counter_out'length,
      g_cnt_up_not_down => FALSE,
      g_cnt_initial_value => g_delay,
      g_cnt_signed => FALSE
    )
    port map (
      clk => clk,
      ce => s_counter_en,
      reset => i_sl,
      count => s_counter_out
  );

end ARCHITECTURE;
