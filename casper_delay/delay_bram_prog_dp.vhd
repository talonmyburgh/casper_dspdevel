-- A VHDL implementation of the CASPER delay_bram_prog_dp block.
-- @author: Mydon Solutions.

LIBRARY IEEE, common_pkg_lib, casper_counter_lib, casper_ram_lib, casper_adder_lib, common_components_lib;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;
USE common_pkg_lib.common_pkg.all;
USE casper_ram_lib.common_ram_pkg.all;
USE common_components_lib.common_components_pkg.all;

ENTITY delay_bram_prog_dp is
  generic (
    g_max_delay : NATURAL := 7;             -- 2^g_max_delay
    g_ram_primitive : STRING  := "block";   -- bram primitive
    g_ram_latency : NATURAL := 2            -- bram latency. Anything in excess of 1 will be in a delay block
  );
  port (
    clk   : in std_logic;
    ce    : in std_logic;
    din   : in std_logic_vector;            -- signal to delay
    delay : in std_logic_vector;            -- variable delay
    en    : in std_logic := '1';
    dout  : out std_logic_vector            -- delayed signal
  );
end ENTITY;

ARCHITECTURE rtl of delay_bram_prog_dp is
    CONSTANT c_dat_w       : NATURAL := din'LENGTH;
    CONSTANT c_delay_w     : NATURAL := delay'LENGTH;
    CONSTANT c_cnt_max_val : NATURAL := 2**g_max_delay -1;
    CONSTANT c_mem_ram     : t_c_mem := (1, g_max_delay, c_dat_w, c_cnt_max_val, '0');
    
    SIGNAL s_count_val  : STD_LOGIC_VECTOR(g_max_delay - 1 DOWNTO 0);
    SIGNAL s_ram_out    : STD_LOGIC_VECTOR(din'RANGE) := (others=>'0');
    SIGNAL s_subtrahend : STD_LOGIC_VECTOR(g_max_delay - 1 DOWNTO 0);
    SIGNAL s_minuend    : STD_LOGIC_VECTOR(g_max_delay - 1 DOWNTO 0);
    SIGNAL s_difference : STD_LOGIC_VECTOR(g_max_delay - 1 DOWNTO 0);

begin
s_subtrahend <= RESIZE_SVEC(delay,g_max_delay);
s_minuend <= s_count_val;
--------------------------------------------------------
-- Subtraction
--------------------------------------------------------
  delay_latency_diff : ENTITY casper_adder_lib.common_add_sub
  generic map (
      g_direction => "SUB",
      g_pipeline_output => 1,
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
-- Counter
--------------------------------------------------------
  addr_cntr : ENTITY casper_counter_lib.common_counter
    GENERIC MAP(
      g_latency   => 1,
      g_width     => g_max_delay
    )
    PORT MAP(
      rst     => '0',
      clk     => clk,
      clken   => ce,
      cnt_en  => en,
      count   => s_count_val
    );

--------------------------------------------------------
-- Dual Port Ram
--------------------------------------------------------
  delay_dpram : ENTITY casper_ram_lib.common_ram_rw_rw
    GENERIC MAP (
      g_ram            => c_mem_ram,
      g_ram_primitive  => g_ram_primitive
    )
    PORT MAP(
      clk       => clk,
      clken     => ce,
      wr_en_a   => '1',  
      wr_en_b   => '0',  
      wr_dat_a  => din,
      wr_dat_b  => din,
      adr_a     => s_count_val,
      adr_b     => s_difference,
      rd_en_a   => '0',
      rd_en_b   => '1',
      rd_dat_a  => open,
      rd_dat_b  => s_ram_out,
      rd_val_a  => open,
      rd_val_b  => open
    );

--------------------------------------------------------
-- Send value out
--------------------------------------------------------
    bram_value_delay : ENTITY common_components_lib.common_delay
    generic map (
        g_dat_w => c_dat_w,
        g_depth => g_ram_latency - 2 -- subtract difference latency and bram latency
    )
    port map (
        clk     => clk,
        in_val  => '1',
        in_dat  => s_ram_out,
        out_dat => dout
    );
end ARCHITECTURE;