-- A VHDL implementation of a mux block.
-- @author: Ross Donnachie
-- @company: Mydon Solutions

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;

entity mux is
    generic(
        g_async : BOOLEAN := FALSE
    );
    port (
        clk : IN std_logic := '0';
        ce :  IN std_logic := '0';
        i_sel : IN std_logic;
        i_data_0 : IN std_logic_vector;
        i_data_1 : IN std_logic_vector;
        o_data : out std_logic_vector
    );
end mux;

architecture rtl of mux is
begin
    --------------------------------------------------------
    -- Asynchronous operation
    --------------------------------------------------------
    async : IF g_async = TRUE GENERATE
        o_data <= i_data_1 when i_sel = '1' else i_data_0;
    END GENERATE;

    --------------------------------------------------------
    -- Synchronous operation
    --------------------------------------------------------
    sync : IF g_async = FALSE GENERATE
        sync_process: PROCESS (clk, ce, i_sel)
        begin
            if rising_edge(clk) and ce='1' THEN
              if i_sel = '1' then
                o_data <= i_data_1;
              else
                o_data <= i_data_0;
              end if;
            end if;
        end PROCESS;
    END GENERATE;

end architecture;