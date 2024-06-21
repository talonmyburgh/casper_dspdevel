-- A VHDL free-running up-counter module with asynch reset.
-- @author: Talon Myburgh
-- @company: Mydon Solutions
LIBRARY IEEE;
USE IEEE.std_logic_1164.all;
USE IEEE.numeric_std.all;

ENTITY free_run_up_counter is
    generic (
        g_cnt_w : NATURAL := 4
    );
    port (
        clk     : in std_logic;
        ce      : in std_logic;
        reset   : in std_logic;
        enable  : in std_logic := '1';
        count   : out std_logic_vector(g_cnt_w - 1 DOWNTO 0)
    );
END ENTITY;

ARCHITECTURE rtl of free_run_up_counter is
    CONSTANT c_max_count : NATURAL := 2**g_cnt_w - 1;

    SIGNAL s_count : STD_LOGIC_VECTOR(g_cnt_w - 1 DOWNTO 0);

BEGIN

    PROCESS (clk, reset)
        VARIABLE cnt : INTEGER RANGE 0 TO c_max_count;
    BEGIN
        IF (reset = '1') THEN
            cnt := 0;
        ELSIF (rising_edge(clk) and ce = '1' and enable = '1') THEN
            cnt := cnt + 1;
        END IF;
        s_count <= STD_LOGIC_VECTOR(TO_SIGNED(cnt, g_cnt_w));
    END PROCESS;

    count <= s_count;

END ARCHITECTURE;