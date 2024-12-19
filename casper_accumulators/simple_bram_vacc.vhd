-- A VHDL implementation of the CASPER simple_bram_vacc.
-- @author: Talon Myburgh
-- @company: Mydon Solutions

LIBRARY IEEE, common_pkg_lib, 
casper_misc_lib, common_components_lib, casper_adder_lib,
casper_delay_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

entity simple_bram_vacc is
    generic(
        g_vector_length : NATURAL := 16;
        g_output_type   : STRING  := "SIGNED";
        g_bit_w         : NATURAL := 32
    );
    port (
        clk         : IN std_logic;
        ce          : IN std_logic;
        new_acc     : IN std_logic;
        din         : IN std_logic_vector;
        valid       : OUT std_logic := '0';
        dout        : OUT std_logic_vector(g_bit_w - 1 DOWNTO 0) := (others=>'0')
    );
END simple_bram_vacc;

architecture rtl of simple_bram_vacc is
    SIGNAL s_pulse_ext_out : std_logic;
    SIGNAL s_a : std_logic_vector(g_bit_w - 1 DOWNTO 0);
    SIGNAL s_delay_bram_in : std_logic_vector(g_bit_w - 1 DOWNTO 0);
    SIGNAL s_delay_bram_out : std_logic_vector(g_bit_w - 1 DOWNTO 0);
    SIGNAL s_mux_out : std_logic_vector(g_bit_w - 1 DOWNTO 0);

begin

--------------------------------------------------------------
-- pulse extend new_acc signal
--------------------------------------------------------------
pulse_ext : entity casper_misc_lib.pulse_ext
generic map(
    g_extension => g_vector_length
)
port map(
    clk => clk,
    ce  => ce,
    i_pulse => new_acc,
    o_pulse => s_pulse_ext_out
);

--------------------------------------------------------------
-- mux block
--------------------------------------------------------------
s_mux_out <=  s_delay_bram_out when s_pulse_ext_out = '0' else
        (others=>'0') when  s_pulse_ext_out = '1' else
        (others=>'X');

--------------------------------------------------------------
-- resize din signal
--------------------------------------------------------------
s_a <= RESIZE_SVEC(din, g_bit_w) when g_output_type = "SIGNED" else RESIZE_UVEC(din, g_bit_w);

--------------------------------------------------------------
-- adder block
--------------------------------------------------------------
add_a_b : entity casper_adder_lib.common_add_sub
generic map(
    g_direction => "ADD",
    g_representation => g_output_type,
    g_pipeline_input => 0,
    g_pipeline_output => 2,
    g_in_dat_w => g_bit_w,
    g_out_dat_w => g_bit_w
)
port map(
    clk => clk,
    clken => ce,
    in_a => s_a,
    in_b => s_mux_out,
    result => s_delay_bram_in
);

--------------------------------------------------------------
-- delay bram
--------------------------------------------------------------
delay_bram_blk : entity casper_delay_lib.delay_bram
generic map (
    g_delay => g_vector_length - 2,
    g_ram_primitive => "block",
    g_ram_latency => 2
)
port map (
    clk => clk,
    ce => ce,
    din => s_delay_bram_in,
    dout => s_delay_bram_out
);

--------------------------------------------------------------
-- set up output signals
--------------------------------------------------------------
dout <= s_delay_bram_out;
valid <= s_pulse_ext_out;

END rtl;