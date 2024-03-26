-- A VHDL implementation of the CASPER delay_bram_en_plus block.
-- @author: Mydon Solutions.

LIBRARY IEEE, common_pkg_lib, common_components_lib, casper_counter_lib, casper_ram_lib;
USE IEEE.std_logic_1164.all;
USE common_pkg_lib.common_pkg.all;
USE casper_ram_lib.common_ram_pkg.all;
USE common_components_lib.common_components_pkg.all;

ENTITY delay_bram_en_plus is
    generic (
      g_delay : NATURAL := 3;
      g_ram_primitive : STRING  := "block";
      g_latency: NATURAL := 2
    );
    port (
      clk   : in std_logic;
      ce    : in std_logic;
      en    : in std_logic;
      din   : in std_logic_vector;
      valid : out std_logic;
      dout  : out std_logic_vector
    );
  end ENTITY;
  
  ARCHITECTURE rtl of delay_bram_en_plus is
  
    CONSTANT c_cntr_width: NATURAL := ceil_log2(g_delay);
    CONSTANT c_dat_w : NATURAL := din'LENGTH;
    CONSTANT c_mem_ram : t_c_mem := (2, c_cntr_width, c_dat_w, g_delay, 'X');
    CONSTANT c_max_cnt : NATURAL := g_delay - 1;
    
    SIGNAL s_count_val : STD_LOGIC_VECTOR(c_cntr_width - 1 DOWNTO 0) := (others => '0');
    SIGNAL s_ram_out   : STD_LOGIC_VECTOR(din'RANGE);
    SIGNAL s_en        : STD_LOGIC_VECTOR(0 DOWNTO 0);
    SIGNAL s_valid     : STD_LOGIC_VECTOR(0 DOWNTO 0);
  
  begin
    s_en(0) <= en;
    valid <= s_valid(0);
  
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
        rd_en   => '1',
        rd_adr  => s_count_val,
        rd_dat  => s_ram_out,
        rd_val  => open
    );

-------------------------------------------------------
-- Bram_latency delay
-------------------------------------------------------
    bram_latency_delay : ENTITY common_components_lib.common_delay
    generic map (
        g_dat_w => 1,
        g_depth => g_latency
    )
    port map (
        clk     => clk,
        in_val  => '1',
        in_dat  => s_en,
        out_dat => s_valid
    );
    
    -------------------------------------------------------
    -- Bram_value delay
    -------------------------------------------------------
    gen_ram_out_direct : IF g_latency < 2 GENERATE
        dout <= s_ram_out;
    end GENERATE;
    gen_ram_out_delay : IF g_latency >= 2 GENERATE
        bram_value_delay : ENTITY common_components_lib.common_delay
        generic map (
            g_dat_w => c_dat_w,
            g_depth => g_latency - 2
        )
        port map (
            clk     => clk,
            in_val  => '1',
            in_dat  => s_ram_out,
            out_dat => dout
        );
    end GENERATE;

end ARCHITECTURE;