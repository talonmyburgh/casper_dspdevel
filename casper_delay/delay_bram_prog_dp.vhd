-- A VHDL implementation of the CASPER delay_bram_prog_dp block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, casper_counter_lib, casper_ram_lib, casper_adder_lib, common_components_lib;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
USE common_pkg_lib.common_pkg.all;
USE casper_ram_lib.common_ram_pkg.all;
USE common_components_lib.common_components_pkg.all;

ENTITY delay_bram_prog_dp is
  generic(
    g_max_delay     : NATURAL := 7;     -- 2^g_max_delay
    g_ram_primitive : STRING  := "block"; -- bram primitive
    g_ram_latency   : NATURAL := 2      -- bram latency. Anything in excess of 1 will be in a delay block
  );
  port(
    clk   : in  std_logic;
    ce    : in  std_logic;
    din   : in  std_logic_vector;       -- signal to delay
    delay : in  std_logic_vector;       -- variable delay
    en    : in  std_logic := '1';
    dout  : out std_logic_vector        -- delayed signal
  );
end ENTITY;

ARCHITECTURE rtl of delay_bram_prog_dp is
  CONSTANT c_dat_w   : NATURAL := din'LENGTH;
  CONSTANT c_mem_ram : t_c_mem := (latency => g_ram_latency,
                                   adr_w   => g_max_delay,
                                   dat_w   => c_dat_w,
                                   nof_dat => 2 ** g_max_delay,
                                   init_sl => '0');

  SIGNAL s_count_val  : STD_LOGIC_VECTOR(g_max_delay - 1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_ram_out    : STD_LOGIC_VECTOR(din'RANGE)                := (OTHERS => '0');
  SIGNAL s_subtrahend : STD_LOGIC_VECTOR(g_max_delay - 1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_minuend    : STD_LOGIC_VECTOR(g_max_delay - 1 DOWNTO 0) := (OTHERS => '0');
  SIGNAL s_difference : STD_LOGIC_VECTOR(g_max_delay - 1 DOWNTO 0) := (OTHERS => '0');

begin
  s_subtrahend <= RESIZE_UVEC(delay, g_max_delay);
  s_minuend    <= s_count_val;
  --------------------------------------------------------
  -- Subtraction
  --------------------------------------------------------
  delay_latency_diff : ENTITY casper_adder_lib.common_add_sub
    generic map(
      g_direction       => "SUB",
      g_pipeline_output => 1,
      g_in_dat_w        => g_max_delay,
      g_out_dat_w       => g_max_delay,
      g_representation  => "UNSIGNED",
      g_pipeline_input  => 0
    )
    port map(
      clk    => clk,
      clken  => ce,
      in_a   => s_minuend,
      in_b   => s_subtrahend,
      result => s_difference
    );

  --------------------------------------------------------
  -- Counter
  --------------------------------------------------------
  addr_cntr : entity casper_counter_lib.free_run_up_counter
    generic map(
      g_cnt_w             => g_max_delay,
      g_cnt_up_not_down   => TRUE,
      g_cnt_initial_value => 0,
      g_cnt_signed        => FALSE
    )
    port map(
      clk    => clk,
      ce     => ce,
      reset  => '0',
      enable => en,
      count  => s_count_val
    );

  --------------------------------------------------------
  -- Dual Port Ram
  --------------------------------------------------------
  delay_dpram : ENTITY casper_ram_lib.common_ram_rw_rw
    GENERIC MAP(
      g_ram            => c_mem_ram,
      g_ram_primitive  => g_ram_primitive,
      g_write_mode_a   => "write_first",
      g_write_mode_b   => "read_first",
      g_init_file      => "UNUSED",
      g_true_dual_port => TRUE
    )
    PORT MAP(
      clk      => clk,
      clken    => ce,
      wr_en_a  => '1',
      wr_en_b  => '0',
      wr_dat_a => din,
      wr_dat_b => din,
      adr_a    => s_count_val,
      adr_b    => s_difference,
      rd_en_a  => '1',
      rd_en_b  => '1',
      rd_dat_a => open,
      rd_dat_b => s_ram_out,
      rd_val_a => open,
      rd_val_b => open
    );

  dout <= s_ram_out;
end ARCHITECTURE;
