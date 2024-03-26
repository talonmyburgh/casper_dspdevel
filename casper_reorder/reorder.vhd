-- A VHDL implementation of the CASPER reorder block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, common_slv_arr_pkg_lib, casper_delay_lib, casper_ram_lib, casper_misc_lib, casper_bus_lib, casper_counter_lib;
USE IEEE.std_logic_1164.all;
use std.textio.all;
use ieee.std_logic_textio.all;

USE common_pkg_lib.common_pkg.all;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;
USE casper_ram_lib.common_ram_pkg.all;

ENTITY reorder is
  generic (
    g_reorder_order: NATURAL;
    g_reorder_length: NATURAL;
    g_map_latency: NATURAL;
    g_bram_latency: NATURAL;
    g_fanout_latency: NATURAL;
    g_double_buffer: BOOLEAN;
    g_block_ram: BOOLEAN;
    g_software_controlled: BOOLEAN;
    g_mem_filepath: STRING
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

ARCHITECTURE rtl of reorder is
  function setup_pre_delay(double_buffer : boolean; order, map_latency, mux_latency : NATURAL) return NATURAL is
    VARIABLE v_pre_delay : NATURAL := map_latency;
  begin
    if not double_buffer then
      v_pre_delay := v_pre_delay + mux_latency;
      if order /= 2 then
        v_pre_delay := v_pre_delay + 1;
      end if;
    end if;
    return v_pre_delay;
  end function;

  function setup_valid_delay(double_buffer : boolean; bram_latency, fanout_latency : NATURAL) return NATURAL is
    VARIABLE v_valid_delay : NATURAL := bram_latency + fanout_latency;
  begin
    if double_buffer then
      v_valid_delay := v_valid_delay + 2;
    end if;
    return v_valid_delay;
  end function;

  function setup_ram_type(ram_block_type : boolean) return STRING is
  begin
    if ram_block_type then
      return "block";
    else
      return "distributed";
    end if;
  end function;

  CONSTANT c_nof_inputs : NATURAL := i_data'LENGTH(1);
  CONSTANT c_map_bits : NATURAL := ceil_log2(g_reorder_length);

  CONSTANT c_map_memory_type : STRING := setup_ram_type(g_block_ram);

  -- make fanout as low as possible (2)
  CONSTANT c_rep_latency : NATURAL := ceil_log2(c_nof_inputs);
  CONSTANT c_mux_latency : NATURAL := 1;
  CONSTANT c_pre_delay : NATURAL := setup_pre_delay(g_double_buffer, g_reorder_order, g_map_latency, c_mux_latency);
  CONSTANT c_valid_delay : NATURAL := setup_valid_delay(g_double_buffer, g_map_latency, g_fanout_latency);

  -- universal signals
  SIGNAL s_pre_sync_delay_out, s_delay_we0_out, s_delay_we1_out, s_sync_delay_en_out, s_sync_delay_en : std_logic;
  SIGNAL s_delay_we2_out : std_logic_vector(0 downto 0);
  SIGNAL s_delayed_inputs : t_slv_arr(i_data'RANGE(1), i_data'RANGE(2));
  SIGNAL s_we_replicated : t_slv_arr(c_nof_inputs-1 downto 0, 0 downto 0);

BEGIN

  assert (2**c_map_bits) = g_reorder_length
  report "Reorder currently only supports maps which are 2^? long."
  severity failure;

  assert not (g_double_buffer and g_reorder_order >= 2)
  report "Double buffer requires the order to be 2."
  severity failure;

  assert not g_software_controlled or g_double_buffer
  report "Software control requires double buffer."
  severity failure;

  assert (g_software_controlled and g_map_latency = 3) or not g_software_controlled
  report "Software control requires map latency of 3."
  severity failure;

  u_pre_sync_delay : entity casper_delay_lib.delay_simple_sl -- universal component
  generic map (
    g_delay => c_rep_latency + c_pre_delay,
    g_initial_values => '0'
  )
  port map (
    clk => clk,
    ce => ce,
    i_data => i_sync,
    o_data => s_pre_sync_delay_out
  );

  u_delay_we0 : entity casper_delay_lib.delay_simple_sl -- universal component
  generic map (
    g_delay => c_pre_delay + c_rep_latency,
    g_initial_values => '0'
  )
  port map (
    clk => clk,
    ce => ce,
    i_data => i_en,
    o_data => s_delay_we0_out
  );

  u_delay_we1 : entity casper_delay_lib.delay_simple_sl -- universal component
  generic map (
    g_delay => c_pre_delay + c_rep_latency,
    g_initial_values => '0'
  )
  port map (
    clk => clk,
    ce => ce,
    i_data => i_en,
    o_data => s_delay_we1_out
  );

  u_delay_we2 : entity casper_delay_lib.delay_simple_sl -- universal component
  generic map (
    g_delay => c_pre_delay,
    g_initial_values => '0'
  )
  port map (
    clk => clk,
    ce => ce,
    i_data => i_en,
    o_data => s_delay_we2_out(0)
  );

  s_sync_delay_en <= s_pre_sync_delay_out or s_delay_we0_out;
  u_sync_delay_en : entity casper_misc_lib.sync_delay_en -- universal component
    generic map (
      g_delay => g_reorder_length
    )
    port map (
      clk => clk,
      ce => ce,
      i_sl => s_pre_sync_delay_out,
      i_en => s_sync_delay_en,
      o_sl => s_sync_delay_en_out
    );

  u_post_sync_delay : entity casper_delay_lib.delay_simple_sl -- universal component
  generic map (
    g_delay => c_valid_delay,
    g_initial_values => '0'
  )
  port map (
    clk => clk,
    ce => ce,
    i_data => s_sync_delay_en_out,
    o_data => o_sync
  );

  u_delay_valid : entity casper_delay_lib.delay_simple_sl -- universal component
  generic map (
    g_delay => c_valid_delay,
    g_initial_values => '0'
  )
  port map (
    clk => clk,
    ce => ce,
    i_data => s_delay_we1_out,
    o_data => o_valid
  );

  u_we_replicate : entity casper_bus_lib.bus_fill_slv_arr -- universal component
    generic map (
      g_latency => c_rep_latency
    )
    port map (
      clk => clk,
      ce => ce,

      i_data => s_delay_we2_out,
      o_data => s_we_replicated
    );

  -- universally, the inputs are delayed
  gen_in_delays : FOR i in i_data'RANGE(1) GENERATE
    SIGNAL s_din, s_in : std_logic_vector(i_data'RANGE(2));
  BEGIN
    s_in <= slv_arr_index(i_data, i);
    u_delay_din : entity casper_delay_lib.delay_simple
    generic map (
      g_delay => c_pre_delay + c_rep_latency,
      g_initial_values => '0'
    )
    port map (
      clk => clk,
      ce => ce,
      i_data => s_in,
      o_data => s_din
    );
    gen_in_delay_bits : FOR bit_i in s_din'RANGE GENERATE
      s_delayed_inputs(i, bit_i) <= s_din(bit_i);
    end GENERATE;
  end GENERATE;

  -- Special case for reorder of order 1 (just delay)
  gen_order_eq1 : if g_reorder_order = 1 GENERATE
    gen_delay_din_bram : FOR i in i_data'RANGE(1) GENERATE
      SIGNAL s_o_data, s_din : std_logic_vector(o_data'RANGE(2));
    BEGIN
    s_din <= slv_arr_index(i_data, i);
      u_delay_din_bram : entity casper_delay_lib.delay_bram_en_plus
        generic map (
          g_delay => g_reorder_length,
          g_ram_primitive => "block",
          g_latency => g_bram_latency + g_fanout_latency
        )
        port map (
          clk => clk,
          ce => ce,
          en  => s_we_replicated(i, 0),
          din => s_din,
          valid => open,
          dout => s_o_data
        );

      gen_out_bits : FOR bit_i in s_o_data'RANGE GENERATE
        o_data(i, bit_i) <= s_o_data(bit_i);
      end GENERATE;
    end GENERATE;
  end GENERATE;
  -- else order > 1
  gen_order_based_gt1 : if g_reorder_order /= 1 GENERATE
    SIGNAL s_addr_mux_d0, s_addr_mux_d1, s_addr_mux_out : std_logic_vector(c_map_bits-1 downto 0);
    SIGNAL s_addr_replicated : t_slv_arr(i_data'RANGE(1), s_addr_mux_out'RANGE);
    SIGNAL s_addr_mux_sel : std_logic;

    SIGNAL s_order2_counter_out : std_logic_vector(1+c_map_bits-1 downto 0);
  BEGIN

    u_addr_replicate : entity casper_bus_lib.bus_fill_slv_arr
    generic map (
      g_latency => c_rep_latency
    )
    port map (
      clk => clk,
      ce => ce,

      i_data => s_addr_mux_out,
      o_data => s_addr_replicated
    );

    gen_order_eq2_shared : if g_reorder_order = 2 GENERATE
      -- shared between (double_buffer=true) and (double_buffer=true, order > 2)...
      function setup_latency(double_buffer : boolean; order, map_latency, rep_latency : NATURAL) return NATURAL is
        VARIABLE v_latency : NATURAL := (order-1)*map_latency;
      begin
        if double_buffer then
          v_latency := v_latency + rep_latency;
        end if;
        return v_latency;
      end function;

      constant c_latency : NATURAL := setup_latency(g_double_buffer, g_reorder_order, g_map_latency, c_rep_latency);
    BEGIN

      u_counter : entity casper_counter_lib.free_run_up_counter
        generic map (
          g_cnt_w => s_order2_counter_out'LENGTH,
          g_cnt_signed => FALSE
        )
        port map (
          clk => clk,
          ce => ce,
          reset => i_sync,
          count => s_order2_counter_out
        );

      u_delay_sel : entity casper_delay_lib.delay_simple_sl
        generic map (
          g_delay => c_latency,
          g_initial_values => '0'
        )
        port map (
          clk => clk,
          ce => ce,
          i_data => s_order2_counter_out(s_order2_counter_out'HIGH),
          o_data => s_addr_mux_sel
        );

      u_delay_d0 : entity casper_delay_lib.delay_simple
        generic map (
          g_delay => c_latency,
          g_initial_values => '0'
        )
        port map (
          clk => clk,
          ce => ce,
          i_data => s_order2_counter_out(c_map_bits-1 downto 0),
          o_data => s_addr_mux_d0
        );
    end GENERATE;

    gen_non_double_buffer : if not g_double_buffer GENERATE
    BEGIN
      gen_buf_output_section : FOR i in i_data'RANGE(1) GENERATE
        SIGNAL s_data_out : std_logic_vector(i_data'RANGE(2));
      BEGIN

        u_generic_brams : IF TRUE GENERATE --g_nof_bits = 0 GENERATE
          CONSTANT c_mem_bram : t_c_mem := (
            g_bram_latency+g_fanout_latency, -- read latency
            c_map_bits, -- addr_w
            i_data'LENGTH(2), -- data_w
            g_reorder_length, -- nof_data
            'X' -- initial_sl
          );

          SIGNAL s_we: std_logic;
          SIGNAL s_wr_adr: std_logic_vector(s_addr_replicated'RANGE(2));
          SIGNAL s_wr_dat: std_logic_vector(s_delayed_inputs'RANGE(2));
        BEGIN
          s_we <= s_we_replicated(i, 0);
          s_wr_adr <= slv_arr_index(s_addr_replicated, i);
          s_wr_dat <= slv_arr_index(s_delayed_inputs, i);

          u_buf : ENTITY casper_ram_lib.common_ram_r_w
            GENERIC MAP (
              g_ram            => c_mem_bram,
              g_true_dual_port => FALSE,
              g_ram_primitive  => c_map_memory_type
            )
            PORT MAP(
              clk     => clk,
              clken   => ce,
              wr_en   => s_we,
              wr_adr  => s_wr_adr,
              wr_dat  => s_wr_dat,
              rd_en   => '1', -- ? perhaps not wr_en
              rd_adr  => s_addr_mux_d1,
              rd_dat  => s_data_out,
              rd_val  => open
            );
        end GENERATE;
        -- u_specific_brams : IF FALSE GENERATE -- g_nof_bits /= 0 GENERATE
        --   CONSTANT c_mem_bram : t_c_mem := (
        --     g_bram_latency+g_fanout_latency, -- read latency
        --     i_wr_addr'LENGTH, -- addr_w
        --     i_data'LENGTH(2), -- data_w
        --     2**c_map_bits, -- nof_data
        --     'X' -- initial_sl
        --   );
        -- BEGIN
        --   u_buf : ENTITY casper_bus_lib.bus_single_port_ram
        --   GENERIC MAP (
        --     g_ram            => c_mem_bram, -- !!!!!
        --     g_true_dual_port => FALSE,
        --     g_ram_primitive  => "block"
        --   )
        --   PORT MAP(
        --     clk     => clk,
        --     clken   => ce,
        --     wr_en   => s_we_replicated(i, 0),
        --     wr_adr  => slv_arr_index(s_addr_replicated, i),
        --     wr_dat  => slv_arr_index(s_delayed_inputs, i),
        --     rd_en   => not s_we_replicated(i, 0),
        --     rd_adr  => s_daddr0_out,
        --     rd_dat  => s_data_out,
        --     rd_val  => open
        --   );
        -- end GENERATE;

        gen_out_bits : FOR bit_i in s_data_out'RANGE GENERATE
          o_data(i, bit_i) <= s_data_out(bit_i);
        end GENERATE;
      end GENERATE;

      gen_non_double_buffer_order_eq2 : if g_reorder_order = 2 GENERATE
        CONSTANT c_mem_map_rom : t_c_mem := (
          g_map_latency, -- read latency
          c_map_bits, -- addr_w
          c_map_bits, -- data_w
          g_reorder_length, -- nof_data
          'X' -- initial_sl
        );
      BEGIN

        u_map1 : entity casper_ram_lib.common_rom_r
          generic map(
            g_ram => c_mem_map_rom,
            g_init_file  => g_mem_filepath,
            g_ram_primitive  =>  c_map_memory_type
          )
          port map(
            clk => clk,
            clken => ce,
            adr => s_order2_counter_out(c_map_bits-1 downto 0),
            rd_en => '1',
            rd_dat => s_addr_mux_d1,
            rd_val => open
          );

        u_map1_mux : entity work.mux
          generic map (
            g_async => FALSE
          )
          port map (
            clk => clk,
            ce => ce,
            i_sel => s_addr_mux_sel,
            i_data_0 => s_addr_mux_d0,
            i_data_1 => s_addr_mux_d1,
            o_data => s_addr_mux_out
          );
      end GENERATE;
      -- or order > 2
      gen_non_double_buffer_order_neq2 : if g_reorder_order > 2 GENERATE
        CONSTANT c_mem_map_ram : t_c_mem := (
          g_map_latency, -- read latency
          c_map_bits, -- addr_w
          c_map_bits, -- data_w
          g_reorder_length, -- nof_data
          'X' -- initial_sl
        );
        SIGNAL s_counter_out, s_daddr0_out, s_daddr1_out, s_current_map_out, s_map_mux_out, s_map_mod_out, s_dnew_map_out : std_logic_vector(c_map_bits-1 downto 0);
        SIGNAL s_dsync_out, s_dmap_src_out, s_den_out : std_logic;
        SIGNAL s_counter_msb_falling_edge, s_map_src_out : std_logic_vector(0 downto 0);
      BEGIN
        u_counter : entity casper_counter_lib.free_run_up_counter
          generic map (
            g_cnt_w => s_counter_out'LENGTH,
            g_cnt_signed => FALSE
          )
          port map (
            clk => clk,
            ce => ce,
            reset => i_sync,
            count => s_counter_out
          );

        u_dsync : entity casper_delay_lib.delay_simple_sl
          generic map (
            g_delay => 1,
            g_initial_values => '0'
          )
          port map (
            clk => clk,
            ce => ce,
            i_data => i_sync,
            o_data => s_dsync_out
          );

        u_counter_msb_edge_detect : entity casper_misc_lib.edge_detect
          generic map (
            g_edge_type => "falling",
            g_output_pol => "high"
          )
          port map (
            clk => clk,
            ce => ce,
            in_sig => s_counter_out(s_counter_out'LEFT downto s_counter_out'LEFT),
            out_sig => s_counter_msb_falling_edge
          );

        u_map_src : entity casper_misc_lib.reg
          generic map (
            g_initial_value => TO_UVEC(0, 1)
          )
          port map (
            clk => clk,
            ce => ce,
            i_reset => s_dsync_out,
            i_d => s_counter_msb_falling_edge,
            i_en => s_counter_msb_falling_edge(0),
            o_q => s_map_src_out
          );

        u_dmap_src : entity casper_delay_lib.delay_simple_sl
          generic map (
            g_delay => g_map_latency,
            g_initial_values => '0'
          )
          port map (
            clk => clk,
            ce => ce,
            i_data => s_map_src_out(0),
            o_data => s_dmap_src_out
          );

        u_daddr0 : entity casper_delay_lib.delay_simple
          generic map (
            g_delay => 1,
            g_initial_values => '0'
          )
          port map (
            clk => clk,
            ce => ce,
            i_data => s_counter_out,
            o_data => s_daddr0_out
          );

        assert FALSE
          report "Have not implemented. Enable double-buffer to circumvent"
          severity failure; 
        u_current_map : ENTITY casper_ram_lib.common_ram_r_w -- TODO should be bus_dual_port_ram
          GENERIC MAP (
            g_ram            => c_mem_map_ram,
            g_init_file      => g_mem_filepath, -- needs to be initialised with 0..g_reorder_length
            g_true_dual_port => FALSE,
            g_ram_primitive  => c_map_memory_type
          )
          PORT MAP(
            clk     => clk,
            clken   => ce,
            wr_en   => s_den_out,
            wr_adr  => s_daddr1_out,
            wr_dat  => s_dnew_map_out,
            rd_en   => '1', -- ? perhaps not wr_en
            rd_adr  => s_daddr0_out,
            rd_dat  => s_current_map_out,
            rd_val  => open
          );

        u_den : entity casper_delay_lib.delay_simple_sl
          generic map (
            g_delay => 2,
            g_initial_values => '0'
          )
          port map (
            clk => clk,
            ce => ce,
            i_data => i_sync,
            o_data => s_den_out
          );

        u_daddr1 : entity casper_delay_lib.delay_simple
          generic map (
            g_delay => 1,
            g_initial_values => '0'
          )
          port map (
            clk => clk,
            ce => ce,
            i_data => s_daddr0_out,
            o_data => s_daddr1_out
          );
      
        u_map_mod : entity casper_ram_lib.common_rom_r
          generic map(
            g_ram => c_mem_map_ram,
            g_init_file => g_mem_filepath,
            g_ram_primitive => c_map_memory_type
          )
          port map(
            clk => clk,
            clken => ce,
            adr => s_map_mux_out,
            rd_en => '1',
            rd_dat => s_map_mod_out,
            rd_val => open
          );
      
        u_dnew_map : entity casper_delay_lib.delay_simple
          generic map (
            g_delay => 1,
            g_initial_values => '0'
          )
          port map (
            clk => clk,
            ce => ce,
            i_data => s_map_mod_out,
            o_data => s_dnew_map_out
          );
      end GENERATE; -- gen_non_double_buffer_order_neq2
    end GENERATE; -- gen_non_double_buffer

    gen_double_buffer : if g_double_buffer GENERATE
      gen_software_controlled : if g_software_controlled GENERATE
        assert FALSE
          report "Software control implements a specific Xilinx 'shared_bram' block"
          severity failure;
      end GENERATE;
      -- else, not software controlled
      gen_non_software_controlled : if not g_software_controlled GENERATE
        CONSTANT c_mem_map_rom : t_c_mem := (
          g_map_latency, -- read latency
          c_map_bits, -- addr_w
          c_map_bits, -- data_w
          g_reorder_length, -- nof_data
          'X' -- initial_sl
        );
      BEGIN
        u_map1 : entity casper_ram_lib.common_rom_r
          generic map(
            g_ram => c_mem_map_rom,
            g_init_file => g_mem_filepath,
            g_ram_primitive => c_map_memory_type
          )
          port map(
            clk => clk,
            clken => ce,
            adr => s_order2_counter_out(c_map_bits-1 downto 0),
            rd_en => '1',
            rd_dat => s_addr_mux_out,
            rd_val => open
          );
      end GENERATE; -- gen_non_software_controlled

      gen_dblbuf_output_section : FOR i in i_data'RANGE(1) GENERATE
        SIGNAL s_data_out : std_logic_vector(i_data'RANGE(2));
        SIGNAL s_rd_addr : std_logic_vector(s_addr_replicated'RANGE(2));
        SIGNAL s_data : std_logic_vector(s_delayed_inputs'RANGE(2));
        SIGNAL s_we : std_logic;
      BEGIN

        s_rd_addr <= slv_arr_index(s_addr_replicated, i);
        s_data <= slv_arr_index(s_delayed_inputs, i);
        s_we <= s_we_replicated(i, 0);
        u_buf: entity work.dbl_buffer
          generic map (
            g_depth => g_reorder_length,
            g_ram_latency => g_bram_latency + g_fanout_latency
          )
          port map (
            clk => clk,
            ce => ce,
            i_rw_mode => s_addr_mux_sel,
            i_wr_addr => s_addr_mux_d0,
            i_rd_addr => s_rd_addr,
            i_data => s_data,
            i_we => s_we,
            o_data => s_data_out
          );

        gen_dblbuf_out_bits : FOR bit_i in s_data_out'RANGE GENERATE
          o_data(i, bit_i) <= s_data_out(bit_i);
        end GENERATE; -- gen_dblbuf_out_bits
      end GENERATE;-- gen_dblbuf_output_section

    end GENERATE; -- gen_double_buffer

  end GENERATE; -- gen_order_based_gt1

end ARCHITECTURE;