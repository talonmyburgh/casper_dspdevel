-- A VHDL implementation of the CASPER delay_bram_prog block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, casper_counter_lib, casper_ram_lib, casper_adder_lib, common_components_lib;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
USE common_pkg_lib.common_pkg.all;
USE casper_ram_lib.common_ram_pkg.all;
USE common_components_lib.common_components_pkg.all;

ENTITY delay_bram_prog is
  generic (
    g_max_delay : NATURAL := 7;             -- 2^g_max_delay
    g_ram_primitive : STRING  := "block";   -- bram primitive
    g_ram_latency: NATURAL := 2             -- bram latency. Anything in excess of 2 will be in a delay block
  );
  port (
    clk   : in std_logic;
    ce    : in std_logic;
    din   : in std_logic_vector;            -- signal to delay
    delay : in std_logic_vector;            -- variable delay
    dout  : out std_logic_vector            -- delayed signal
  );
end ENTITY;

ARCHITECTURE rtl of delay_bram_prog is
    CONSTANT c_dat_w       : NATURAL := din'LENGTH;
    CONSTANT c_mem_ram     : t_c_mem := (latency => g_ram_latency,
                                        adr_w => g_max_delay,
                                        dat_w => c_dat_w,
                                        nof_dat => 2**g_max_delay,
                                        init_sl => '0');
    
    SIGNAL s_count_val  : STD_LOGIC_VECTOR(g_max_delay - 1 DOWNTO 0);
    SIGNAL s_ram_out    : STD_LOGIC_VECTOR(din'RANGE);
    SIGNAL s_subtrahend : STD_LOGIC_VECTOR(g_max_delay - 1 DOWNTO 0) := TO_SVEC((g_ram_latency + 1), g_max_delay);
    SIGNAL s_minuend    : STD_LOGIC_VECTOR(g_max_delay - 1 DOWNTO 0);
    SIGNAL s_difference : STD_LOGIC_VECTOR(g_max_delay - 1 DOWNTO 0);
    SIGNAL s_count_rst  : STD_LOGIC := '0';
begin
s_minuend <= RESIZE_SVEC(delay,g_max_delay);
--   ASSERT c_max_cnt > 0 REPORT "Delay value must be greater than BRAM latency + 1!" severity FAILURE;

--------------------------------------------------------
-- Subtraction
--------------------------------------------------------
  delay_latency_diff : ENTITY casper_adder_lib.common_add_sub
  generic map (
      g_direction => "SUB",
      g_pipeline_output => 2,
      g_in_dat_w  => g_max_delay,
      g_out_dat_w => g_max_delay
  )
  port map (
      clk => clk,
      clken => ce,
      in_a => s_minuend,
      in_b => s_subtrahend,
      result => s_difference
  );

--------------------------------------------------------
-- a >= b
--------------------------------------------------------
s_count_rst <= '1' when unsigned(s_count_val) >= unsigned(s_difference) else '0';

--------------------------------------------------------
-- Counter
--------------------------------------------------------
  addr_cntr : ENTITY casper_counter_lib.free_run_counter
  GENERIC MAP (
      g_cnt_w => g_max_delay,
      g_cnt_signed => FALSE
  )
  PORT MAP (
      clk     => clk,
      ce      => ce,
      reset   => s_count_rst,
      count   => s_count_val
  );

--------------------------------------------------------
-- Single Port Ram
--------------------------------------------------------
  delay_spram : ENTITY casper_ram_lib.common_ram_r_w
    GENERIC MAP (
      g_ram            => c_mem_ram,
      g_init_file      => "",
      g_true_dual_port => FALSE,
      g_ram_primitive  => g_ram_primitive,
      g_write_mode_a   => "read_first",
      g_write_mode_b   => "read_first"
    )
    PORT MAP(
      clk     => clk,
      clken   => ce,
      wr_en   => '1',  
      wr_adr  => s_count_val,
      wr_dat  => din,
      rd_en   => '1',
      rd_adr  => s_count_val,
      rd_dat  => s_ram_out,
      rd_val  => open
    );

--------------------------------------------------------
-- Send value out
--------------------------------------------------------
  dout <= s_ram_out;
end ARCHITECTURE;