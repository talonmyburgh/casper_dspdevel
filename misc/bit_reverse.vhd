-- A VHDL implementation of the CASPER bit_reverse block.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
LIBRARY IEEE, common_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.all;

entity bit_reverse is
    generic(
        g_async    : BOOLEAN := TRUE
    );
    port (
        clk     : IN std_logic;
        ce      : IN std_logic;
        in_val  : IN std_logic_vector;
        out_val : OUT std_logic_vector
    );
END bit_reverse;

architecture rtl of bit_reverse is
begin

--------------------------------------------------------------
-- asynchronous reversal
--------------------------------------------------------------
gen_async : IF g_async GENERATE
    out_val(in_val'RANGE) <= func_slv_reverse(in_val);
END GENERATE;

--------------------------------------------------------------
-- synchronous reversal
--------------------------------------------------------------
gen_sync : IF NOT g_async GENERATE 
    sync_rev : process(clk,ce)
        VARIABLE v_rev : STD_LOGIC_VECTOR(in_val'RANGE);
    BEGIN
        v_rev := func_slv_reverse(in_val);
        IF rising_edge(clk) and ce='1' then
            out_val <= v_rev;
        END IF;
    END PROCESS;
END GENERATE;

END architecture;