LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

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
    SIGNAL s_rst   : std_logic;
    SIGNAL s_q     : std_logic := '1';
    SIGNAL s_en    : std_logic := '0';
    SIGNAL s_trig_out : std_logic;
begin

--------------------------------------------------------------
-- rising edge detect on arm signal
--------------------------------------------------------------
rising_edge_det : process(arm)
BEGIN
    IF rising_edge(arm) THEN
        s_rst <= '1';
    ELSE
        s_rst <= '0';
    END IF;
END PROCESS;

--------------------------------------------------------------
-- synchronous register to pass out triggered boolean value
--------------------------------------------------------------
registered_proc : process(clk, ce) 
BEGIN
    IF rising_edge(clk) AND ce = '1' THEN
        IF s_rst = '0' and s_en = '0' THEN
            s_q <= s_reg_d;
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