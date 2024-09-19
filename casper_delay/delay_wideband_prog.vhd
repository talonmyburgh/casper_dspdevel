-- A VHDL implementation of the CASPER delay_wideband_prog block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
library ieee, common_pkg_lib, casper_reorder_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package delay_wideband_prog_pkg is
    CONSTANT c_delay_wideband_prog_bit_width : natural := 16;
    type t_wideband_delay_prog_inout_bus is array (natural range <>) of std_logic_vector(c_delay_wideband_prog_bit_width - 1 downto 0);
end package delay_wideband_prog_pkg;

library ieee, common_pkg_lib, common_slv_arr_pkg_lib, casper_reorder_lib;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.delay_wideband_prog_pkg.all;
use common_pkg_lib.common_pkg.all;
USE common_slv_arr_pkg_lib.common_slv_arr_pkg.all;

entity delay_wideband_prog is
    generic(
        g_max_delay_bits          : natural := 10;
        g_simultaneous_input_bits : natural := 2;
        g_bram_latency            : natural := 2;
        g_true_dual_port          : boolean := true;
        g_ram_primitive           : string  := "block";
        g_async                   : boolean := false
    );
    port(
        clk      : in  std_logic;
        ce       : in  std_logic;
        sync     : in  std_logic;
        en       : in  std_logic := '1';
        delay    : in  std_logic_vector(g_max_delay_bits - 1 DOWNTO 0);
        ld_delay : in  std_logic;
        data_in  : in  t_wideband_delay_prog_inout_bus(0 to 2 ** g_simultaneous_input_bits - 1);
        sync_out : out std_logic;
        data_out : out t_wideband_delay_prog_inout_bus(0 to 2 ** g_simultaneous_input_bits - 1);
        dvalid   : out std_logic := '1'
    );
end entity delay_wideband_prog;

architecture RTL of delay_wideband_prog is

    constant c_nof_inputs   : natural := 2 ** g_simultaneous_input_bits;
    constant c_latency      : natural := sel_a_b(g_true_dual_port, g_bram_latency + 1, g_bram_latency + 2);
    constant c_ram_bits     : natural := ceil_log2(g_max_delay_bits / (2 ** g_simultaneous_input_bits));
    constant c_sync_latency : natural := sel_a_b(g_true_dual_port, c_latency + (g_bram_latency + 1) * 2 ** g_simultaneous_input_bits, c_latency);

    signal s_en                     : std_logic_vector(0 DOWNTO 0)                                                       := "1";
    signal s_en_delay               : std_logic_vector(0 DOWNTO 0)                                                       := "1";
    signal s_en_delay_sl            : std_logic                                                                          := '1';
    signal s_delay_reg              : std_logic_vector(g_max_delay_bits - 1 downto 0)                                    := (others => '0');
    signal s_shift_sel              : std_logic_vector(g_simultaneous_input_bits - 1 downto 0)                           := (others => '0');
    signal s_delay_sel              : std_logic_vector(g_simultaneous_input_bits - 1 downto 0)                           := (others => '0');
    signal s_sync                   : std_logic_vector(0 DOWNTO 0)                                                       := (others => '0');
    signal s_barrel_switcher_input  : t_slv_arr(c_nof_inputs - 1 DOWNTO 0, c_delay_wideband_prog_bit_width - 1 DOWNTO 0) := (others => (others => '0'));
    signal s_barrel_switcher_output : t_slv_arr(c_nof_inputs - 1 DOWNTO 0, c_delay_wideband_prog_bit_width - 1 DOWNTO 0) := (others => (others => '0'));
    signal s_barrel_switcher_sync   : std_logic_vector(0 DOWNTO 0)                                                       := (others => '0');
    signal s_bram_rd_addrs          : std_logic_vector(c_ram_bits - 1 downto 0)                                          := (others => '0');
    type t_signal_array is array (0 to c_nof_inputs - 1) of std_logic_vector(0 downto 0);
    signal s_a_g_b_value            : t_signal_array                                                                     := (others => (others => '0'));
    signal s_delay_a_g_b_value      : t_signal_array                                                                     := (others => (others => '0'));
    type t_ab_signal_array is array (1 to c_nof_inputs - 1) of std_logic_vector(c_ram_bits downto 0);
    signal s_delay_a_g_b_sum        : t_ab_signal_array                                                                  := (others => (others => '0'));
    signal s_delay_dout             : t_wideband_delay_prog_inout_bus(0 to c_nof_inputs - 1)                             := (others => (others => '0'));

begin
    s_sync(0) <= sync;
    s_en(0)   <= en;
    --------------------------REGISTER DELAY VALUE-----------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if ce = '1' then
                if ld_delay = '1' then
                    s_delay_reg <= delay;
                end if;
            end if;
        end if;
    end process;

    s_shift_sel     <= s_delay_reg(g_simultaneous_input_bits - 1 downto 0);
    s_bram_rd_addrs <= s_delay_reg(c_ram_bits + g_simultaneous_input_bits - 1 DOWNTO g_simultaneous_input_bits);

    ---------------DELAY SHIFT SELECT BY g_simultaneous_inputs-----------------------
    delay_simple_inst : entity work.delay_simple
        generic map(
            g_delay => g_simultaneous_input_bits
        )
        port map(
            clk    => clk,
            ce     => ce,
            i_data => s_shift_sel,
            o_data => s_delay_sel
        );

    -------------DELAY SYNC BY g_simultaneous_inputs---------------------------------
    delay_sync_inst : entity work.delay_simple
        generic map(
            g_delay => c_sync_latency
        )
        port map(
            clk    => clk,
            ce     => ce,
            i_data => s_sync,
            o_data => s_barrel_switcher_sync
        );

    -------------DELAY SYNC BY g_simultaneous_inputs---------------------------------
    delay_en_inst : entity work.delay_simple
        generic map(
            g_delay => c_sync_latency
        )
        port map(
            clk    => clk,
            ce     => ce,
            i_data => s_en,
            o_data => s_en_delay
        );

    ------------------GENERATE BARREL SWITCHER INPUTS--------------------------------
    gen_delay_input_2_onwards : for i in 1 to c_nof_inputs - 1 generate
        s_a_g_b_value(i)     <= "1" when unsigned(s_shift_sel) > to_unsigned(i, g_simultaneous_input_bits) else "0";
        -- now delay s_a_g_b_value by 1 clock cycle:
        process(clk)
        begin
            if rising_edge(clk) then
                if ce = '1' then
                    s_delay_a_g_b_value <= s_a_g_b_value;
                end if;
            end if;
        end process;
        s_delay_a_g_b_sum(i) <= std_logic_vector(unsigned(s_delay_a_g_b_value(i)) + unsigned(s_bram_rd_addrs));
    end generate gen_delay_input_2_onwards;

    gen_delays : for i in 0 to c_nof_inputs - 1 generate
        gen_din_0 : if i = 0 generate
            gen_dp_bram_delay : if g_true_dual_port generate
                delay_bram_prog_dp_inst : entity work.delay_bram_prog_dp
                    generic map(
                        g_max_delay     => c_ram_bits,
                        g_ram_primitive => g_ram_primitive,
                        g_ram_latency   => g_bram_latency
                    )
                    port map(
                        clk   => clk,
                        ce    => ce,
                        din   => data_in(c_nof_inputs - 1 - i),
                        delay => s_bram_rd_addrs,
                        en    => en,
                        dout  => s_delay_dout(i)
                    );
            end generate gen_dp_bram_delay;
            gen_sp_bram_delay : if not g_true_dual_port generate
                delay_bram_prog_inst : entity work.delay_bram_prog
                    generic map(
                        g_max_delay     => c_ram_bits,
                        g_ram_primitive => g_ram_primitive,
                        g_ram_latency   => g_bram_latency
                    )
                    port map(
                        clk   => clk,
                        ce    => ce,
                        din   => data_in(c_nof_inputs - 1 - i),
                        delay => s_bram_rd_addrs,
                        dout  => s_delay_dout(i)
                    );
            end generate gen_sp_bram_delay;
        end generate gen_din_0;

        gen_din_others : if i > 0 generate
            gen_dp_bram_delay : if g_true_dual_port generate
                delay_bram_prog_dp_inst : entity work.delay_bram_prog_dp
                    generic map(
                        g_max_delay     => c_ram_bits,
                        g_ram_primitive => g_ram_primitive,
                        g_ram_latency   => g_bram_latency
                    )
                    port map(
                        clk   => clk,
                        ce    => ce,
                        din   => data_in(c_nof_inputs - 1 - i),
                        delay => s_delay_a_g_b_sum(i),
                        en    => en,
                        dout  => s_delay_dout(i)
                    );
            end generate gen_dp_bram_delay;
            gen_sp_bram_delay : if not g_true_dual_port generate
                delay_bram_prog_inst : entity work.delay_bram_prog
                    generic map(
                        g_max_delay     => c_ram_bits,
                        g_ram_primitive => g_ram_primitive,
                        g_ram_latency   => g_bram_latency
                    )
                    port map(
                        clk   => clk,
                        ce    => ce,
                        din   => data_in(c_nof_inputs - 1 - i),
                        delay => s_delay_a_g_b_sum(i),
                        dout  => s_delay_dout(i)
                    );
            end generate gen_sp_bram_delay;
        end generate gen_din_others;
        -- slv_arr_set(s_barrel_switcher_input, i, s_delay_dout(i));
    end generate gen_delays;

    gen_map_barrel_switcher_input : for i in 0 to c_nof_inputs - 1 generate
        gen_map_bits_to_slv : for j in 0 to c_delay_wideband_prog_bit_width - 1 generate
            s_barrel_switcher_input(i, j) <= s_delay_dout(i)(j);
        end generate gen_map_bits_to_slv;
    end generate gen_map_barrel_switcher_input;

    s_en_delay_sl <= s_en_delay(0);

    barrel_switcher_inst : entity casper_reorder_lib.barrel_switcher
        generic map(
            g_async => g_async
        )
        port map(
            clk    => clk,
            ce     => ce,
            en     => s_en_delay_sl,
            i_sel  => s_delay_sel,
            i_sync => s_barrel_switcher_sync(0),
            i_data => s_barrel_switcher_input,
            o_data => s_barrel_switcher_output,
            o_sync => sync_out,
            dvalid => dvalid
        );

    gen_reorder_output : for i in 0 to c_nof_inputs - 1 generate
        data_out(i) <= slv_arr_index(s_barrel_switcher_output, c_nof_inputs - 1 - i);
    end generate gen_reorder_output;

end architecture RTL;

