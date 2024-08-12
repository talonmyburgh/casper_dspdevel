-- A VHDL implementation of the CASPER armed_trigger block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;

entity armed_trigger is
    port (
        clk         : IN std_logic;
        ce          : IN std_logic;
        arm         : IN std_logic;
        trig_in     : IN std_logic;
        trig_out    : OUT std_logic
    );
END armed_trigger;

architecture rtl of armed_trigger is
    SIGNAL s_reg_d : std_logic := '0';
    SIGNAL s_arm   : std_logic_vector(0 DOWNTO 0); 
    SIGNAL s_edge_out : std_logic_vector(0 DOWNTO 0);
    SIGNAL s_rst   : std_logic;
    SIGNAL s_q     : std_logic := '1';
    SIGNAL s_en    : std_logic := '0';
    SIGNAL s_trig_out : std_logic;
begin

--------------------------------------------------------------
-- rising edge detect on arm signal
--------------------------------------------------------------
rising_edge_det : entity work.edge_detect
generic map(
    g_edge_type => "rising",
    g_output_pol => "high"
)
port map(
    clk => clk,
    ce  => ce,
    in_sig => s_arm,
    out_sig => s_edge_out
);
--make std_logic_vector
s_arm(0) <= arm; 
--make std_logic
s_rst <= s_edge_out(0);

--------------------------------------------------------------
-- synchronous register to pass out triggered boolean value
--------------------------------------------------------------
registered_proc : process(clk, ce) 
BEGIN
    IF rising_edge(clk) AND ce = '1' THEN
        IF s_en = '1' THEN
            IF s_rst = '0' THEN
                s_q <= s_reg_d;
            ELSE
                s_q <= '1';
            END IF;
        END IF;
    END IF;
END PROCESS;

--------------------------------------------------------------
-- AND
--------------------------------------------------------------
s_trig_out <= trig_in AND s_q;

--------------------------------------------------------------
-- Feedback loop
--------------------------------------------------------------
s_en <= s_trig_out;
trig_out <= s_trig_out;

END architecture;