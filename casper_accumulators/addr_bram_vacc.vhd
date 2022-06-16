LIBRARY IEEE, common_pkg_lib, 
casper_misc_lib, common_components_lib, casper_adder_lib,
casper_delay_lib, casper_counter_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

entity addr_bram_vacc is
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
        addr        : OUT std_logic_vector(ceil_log2(g_vector_length) - 1 DOWNTO 0) := (others=>'0');
        we          : OUT std_logic := '0';
        dout        : OUT std_logic_vector(g_bit_w - 1 DOWNTO 0) := (others=>'0')
    );
END addr_bram_vacc;

architecture rtl of addr_bram_vacc is
    SIGNAL s_delay_new_acc : std_logic :='0';
    SIGNAL s_delay_din : std_logic_vector(din'RANGE);
    SIGNAL s_pulse_ext_out : std_logic;
    SIGNAL s_dout  : std_logic_vector(g_bit_w - 1 DOWNTO 0);
    SIGNAL s_a : std_logic_vector(g_bit_w - 1 DOWNTO 0);
    SIGNAL s_b : std_logic_vector(g_bit_w - 1 DOWNTO 0);
    SIGNAL s_delay_bram_in : std_logic_vector(g_bit_w - 1 DOWNTO 0);
    SIGNAL s_delay_bram_out : std_logic_vector(g_bit_w - 1 DOWNTO 0);
    SIGNAL s_mux_out : std_logic_vector(g_bit_w - 1 DOWNTO 0);

begin

--------------------------------------------------------------
-- delay new_acc signal
--------------------------------------------------------------
delay_new_acc : process(clk, ce) 
BEGIN
    IF rising_edge(clk) AND ce = '1' THEN
        s_delay_new_acc <= new_acc;
    END IF;
END PROCESS;

--------------------------------------------------------------
-- delay din signal
--------------------------------------------------------------
delay_din : entity common_components_lib.common_delay
generic map(
    g_dat_w => din'LENGTH,
    g_depth => 2
)
port map(
    clk => clk,
    in_val => '1',
    in_dat => din,
    out_dat => s_delay_din
);

--------------------------------------------------------------
-- pulse extend
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
-- delay mux output
--------------------------------------------------------------
delay_mux_out : entity common_components_lib.common_delay
generic map(
    g_dat_w => g_bit_w,
    g_depth => 2
)
port map(
    clk => clk,
    in_val => '1',
    in_dat => s_mux_out,
    out_dat => s_b
);

--------------------------------------------------------------
-- resize din signal
--------------------------------------------------------------
s_a <= RESIZE_SVEC(s_delay_din, g_bit_w);

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
    in_b => s_b,
    result => s_delay_bram_in
);

--------------------------------------------------------------
-- delay bram
--------------------------------------------------------------
delay_bram_blk : entity casper_delay_lib.delay_bram
generic map (
    g_delay => g_vector_length - 4,
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
-- delay s_delay_bram_out signal
--------------------------------------------------------------
delay_bram_out : process(clk, ce) 
BEGIN
    IF rising_edge(clk) AND ce = '1' THEN
        dout <= s_delay_bram_out;
    END IF;
END PROCESS;

--------------------------------------------------------------
-- delay s_pulse_ext_out signal
--------------------------------------------------------------
delay_s_pulse_ext_out : process(clk, ce) 
BEGIN
    IF rising_edge(clk) AND ce = '1' THEN
        we <= s_pulse_ext_out;
    END IF;
END PROCESS;

--------------------------------------------------------------
-- counter - need a synchronous reset, hence use common_counter
--------------------------------------------------------------
addr_counter : entity casper_counter_lib.common_counter
	GENERIC MAP(
		g_width     => ceil_log2(g_vector_length)
	)
	PORT MAP(
		clk     => clk,        --! Clock signal
		clken   => ce,
        cnt_clr => s_delay_new_acc,
		count   => addr
	);

END rtl;