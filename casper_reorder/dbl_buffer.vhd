-- A VHDL implementation of the CASPER dbl_buffer block.
-- @author: Ross Donnachie.
-- @company: Mydon Solutions.

LIBRARY IEEE, common_pkg_lib, casper_delay_lib, casper_ram_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;
USE casper_ram_lib.common_ram_pkg.all;

ENTITY dbl_buffer is
  generic (
    g_depth : NATURAL := 3;
    g_ram_latency: NATURAL := 2;
    g_ram_primitive: STRING := "block"
  );
  port (
    clk   : in std_logic;
    ce    : in std_logic;
    i_rw_mode   : in std_logic;
    i_wr_addr   : in std_logic_vector;
    i_rd_addr   : in std_logic_vector;
    i_data      : in std_logic_vector;
    i_we        : in std_logic;
    o_data      : out std_logic_vector
  );
end ENTITY;

ARCHITECTURE rtl of dbl_buffer is

  CONSTANT c_mem_ram : t_c_mem := (
    g_ram_latency, -- read latency
    i_wr_addr'LENGTH, -- addr_w
    i_data'LENGTH, -- data_w
    g_depth, -- nof_data
    'X' -- initial_sl
  );

  SIGNAL s_we_vector, s_bram0_we_vector, s_bram1_we_vector : std_logic_vector(0 downto 0);
  CONSTANT s_zero : std_logic_vector(0 downto 0) := (OTHERS => '0');

  SIGNAL s_rw_mode_delayed : std_logic;
  SIGNAL s_data_delayed : std_logic_vector(i_data'range);
  SIGNAL s_bram0_data, s_bram1_data : std_logic_vector(o_data'range);
  SIGNAL s_bram0_addr, s_bram1_addr : std_logic_vector(i_wr_addr'range);
begin

  s_we_vector(0) <= i_we;

  u_rw_delay : entity casper_delay_lib.delay_simple_sl
  generic map (
    g_delay => 1 + g_ram_latency
  )
  port map (
    clk => clk,
    ce => ce,
    i_data => i_rw_mode,
    o_data => s_rw_mode_delayed
  );

  u_data_mux : entity work.mux
    generic map (
      g_async => FALSE
    )
    port map (
      clk => clk,
      ce => ce,
      i_sel => s_rw_mode_delayed,
      i_data_0 => s_bram1_data,
      i_data_1 => s_bram0_data,
      o_data => o_data
    );

  u_data_delay : entity casper_delay_lib.delay_simple
  generic map (
    g_delay => 1
  )
  port map (
    clk => clk,
    ce => ce,
    i_data => i_data,
    o_data => s_data_delayed
  );

--------------------------------------------------------
-- BRAM buffer 0
--------------------------------------------------------
  u_bram0_addr_mux : entity work.mux
    generic map (
      g_async => FALSE
    )
    port map (
      clk => clk,
      ce => ce,
      i_sel => i_rw_mode,
      i_data_0 => i_wr_addr,
      i_data_1 => i_rd_addr,
      o_data => s_bram0_addr
    );

  u_bram0_we_mux : entity work.mux
    generic map (
      g_async => FALSE
    )
    port map (
      clk => clk,
      ce => ce,
      i_sel => i_rw_mode,
      i_data_0 => s_we_vector,
      i_data_1 => s_zero,
      o_data => s_bram0_we_vector
    );

  u_bram0 : ENTITY casper_ram_lib.common_ram_r_w
    GENERIC MAP (
      g_ram            => c_mem_ram,
      g_true_dual_port => FALSE,
      g_ram_primitive  => g_ram_primitive
    )
    PORT MAP(
      clk     => clk,
      clken   => ce,
      wr_en   => s_bram0_we_vector(0),  
      wr_adr  => s_bram0_addr,
      wr_dat  => s_data_delayed,
      rd_en   => '0',
      rd_adr  => s_bram0_addr,
      rd_dat  => s_bram0_data,
      rd_val  => open
    );

--------------------------------------------------------
-- BRAM buffer 1
--------------------------------------------------------
  u_bram1_addr_mux : entity work.mux
    generic map (
      g_async => FALSE
    )
    port map (
      clk => clk,
      ce => ce,
      i_sel => i_rw_mode,
      i_data_0 => i_rd_addr,
      i_data_1 => i_wr_addr,
      o_data => s_bram1_addr
    );

  u_bram1_we_mux : entity work.mux
    generic map (
      g_async => FALSE
    )
    port map (
      clk => clk,
      ce => ce,
      i_sel => i_rw_mode,
      i_data_0 => s_zero,
      i_data_1 => s_we_vector,
      o_data => s_bram1_we_vector
    );

  u_bram1 : ENTITY casper_ram_lib.common_ram_r_w
    GENERIC MAP (
      g_ram            => c_mem_ram,
      g_true_dual_port => FALSE,
      g_ram_primitive  => g_ram_primitive
    )
    PORT MAP(
      clk     => clk,
      clken   => ce,
      wr_en   => s_bram1_we_vector(0),  
      wr_adr  => s_bram1_addr,
      wr_dat  => s_data_delayed,
      rd_en   => '0',
      rd_adr  => s_bram1_addr,
      rd_dat  => s_bram1_data,
      rd_val  => open
    );

end ARCHITECTURE;