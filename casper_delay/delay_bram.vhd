-- A VHDL implementation of the CASPER delay_bram (sync) block.
-- @author: Mydon Solutions.
-- TODO: add ability to implement counter using dsp48 blocks.

LIBRARY IEEE, common_pkg_lib, casper_counter_lib, casper_ram_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;
USE casper_ram_lib.common_ram_pkg.all;

ENTITY delay_bram is
  generic (
    g_delay : NATURAL := 3;
    g_ram_primitive : STRING  := "block";
    g_ram_latency: NATURAL := 2
  );
  port (
    clk   : in std_logic;
    ce    : in std_logic;
    din   : in std_logic_vector;
    dout  : out std_logic_vector
  );
end ENTITY;

ARCHITECTURE rtl of delay_bram is

  CONSTANT c_cntr_width: NATURAL := ceil_log2(g_delay);
  CONSTANT c_dat_w : NATURAL := din'LENGTH;
  CONSTANT c_mem_ram : t_c_mem := (g_ram_latency, c_cntr_width, c_dat_w, g_delay, 'X');
  CONSTANT c_max_cnt : NATURAL := g_delay - g_ram_latency - 1;
  
  SIGNAL s_count_val : STD_LOGIC_VECTOR(c_cntr_width - 1 DOWNTO 0) := (others => '0');
  SIGNAL s_ram_out   : STD_LOGIC_VECTOR(din'RANGE);

begin

  ASSERT c_max_cnt > 0 REPORT "Delay value must be greater than BRAM latency + 1!" severity FAILURE;

--------------------------------------------------------
-- Counter
--------------------------------------------------------
  addr_cntr : ENTITY casper_counter_lib.common_counter
    GENERIC MAP(
      g_latency   => 0,
      g_init      => 0,
      g_width     => c_cntr_width,
      g_max       => c_max_cnt, 
      g_step_size => 1
    )
    PORT MAP(
      rst     => '0',
      clk     => clk,
      clken   => ce,
      count   => s_count_val
    );

--------------------------------------------------------
-- Single Port Ram
--------------------------------------------------------
  delay_spram : ENTITY casper_ram_lib.common_ram_r_w
    GENERIC MAP (
      g_ram            => c_mem_ram,
      g_true_dual_port => FALSE,
      g_ram_primitive  => g_ram_primitive
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
-- Register the output signal for one cycle - This seems
-- to introduce 1 too many delays... so we do without it.
--------------------------------------------------------
  -- single_delay: PROCESS (clk, ce)
  -- begin
  --   if(rising_edge(clk) and ce = '1') then
  --     dout <= s_ram_out;
  --   end if;
  -- end PROCESS;
  dout <= s_ram_out;

end ARCHITECTURE;

-------------------------------------------------------------------------
-- A VHDL implementation of the CASPER delay_bram_async block.
-- @author: Mydon Solutions.
-- TODO: add ability to implement counter using dsp48 blocks.

LIBRARY IEEE, common_pkg_lib, casper_counter_lib, casper_ram_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;
USE casper_ram_lib.common_ram_pkg.all;

ENTITY delay_bram_async is
  generic (
    g_delay : NATURAL := 3;
    g_ram_primitive : STRING  := "block";
    g_ram_latency: NATURAL := 2
  );
  port (
    clk   : in std_logic;
    ce    : in std_logic;
    en    : in std_logic;
    din   : in std_logic_vector;
    dout  : out std_logic_vector
  );
end ENTITY;

ARCHITECTURE rtl of delay_bram_async is

  CONSTANT c_cntr_width: NATURAL := ceil_log2(g_delay);
  CONSTANT c_dat_w : NATURAL := din'LENGTH;
  CONSTANT c_mem_ram : t_c_mem := (g_ram_latency, c_cntr_width, c_dat_w, g_delay, 'X');
  CONSTANT c_max_cnt : NATURAL := g_delay - g_ram_latency - 1;

  -- GHDL is picky about unconstrained Std_logic_vectors by defining a zero constant we resolve a GHDL error about unconstrained std_logic_vector and others below.
  CONSTANT c_zero_din : STD_LOGIC_VECTOR(din'RANGE) := (others => '0');

  SIGNAL s_count_val : STD_LOGIC_VECTOR(c_cntr_width - 1 DOWNTO 0) := (others=>'0');
  SIGNAL s_ram_out   : STD_LOGIC_VECTOR(din'RANGE);

begin

  ASSERT c_max_cnt > 0 REPORT "Delay value must be greater than BRAM latency + 1!" severity FAILURE;

--------------------------------------------------------
-- Counter
--------------------------------------------------------
  addr_cntr : ENTITY casper_counter_lib.common_counter
    GENERIC MAP(
      g_latency   => 0,
      g_init      => 0,
      g_width     => c_cntr_width,
      g_max       => c_max_cnt, 
      g_step_size => 1
    )
    PORT MAP(
      rst     => '0',
      clk     => clk,
      clken   => ce,
      cnt_en  => en,
      count   => s_count_val
    );

--------------------------------------------------------
-- Single Port Ram
--------------------------------------------------------
  delay_spram : ENTITY casper_ram_lib.common_ram_r_w
    GENERIC MAP (
      g_ram            => c_mem_ram,
      g_true_dual_port => FALSE,
      g_ram_primitive  => g_ram_primitive
    )
    PORT MAP(
      clk     => clk,
      clken   => ce,
      wr_en   => en,  
      wr_adr  => s_count_val,
      wr_dat  => din,
      rd_en   => en,
      rd_adr  => s_count_val,
      rd_dat  => s_ram_out,
      rd_val  => open
    );

--------------------------------------------------------
-- Register the output signal for one cycle - This seems
-- to introduce 1 too many delays... so we do without it.
--------------------------------------------------------
  -- single_delay: PROCESS (clk, ce)
  -- begin
  --   if(rising_edge(clk) and ce = '1') then
  --     if(en = '1') then
  --       dout <= s_ram_out;
  --     else
  --       dout <= (others =>'0');
  --     end if;
  --   end if;
  -- end PROCESS;
  
  --GHDL does not like unconstrained arrays and using others.  Work around using a constant
  dout <= s_ram_out when en = '1' else (c_zero_din);

end ARCHITECTURE;