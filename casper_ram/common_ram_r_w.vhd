-------------------------------------------------------------------------------
--
-- Copyright 2020
-- ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
-- P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--     http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-------------------------------------------------------------------------------

LIBRARY IEEE, technology_lib;
USE IEEE.std_logic_1164.ALL;
USE work.common_ram_pkg.ALL;
USE technology_lib.technology_select_pkg.ALL;

ENTITY common_ram_r_w IS
    GENERIC(
        g_ram            : t_c_mem := c_mem_ram;
        g_init_file      : STRING  := "UNUSED";
        g_true_dual_port : BOOLEAN := TRUE;
        g_ram_primitive  : STRING  := "auto"
    );
    PORT(
        clk    : IN  STD_LOGIC;
        clken  : IN  STD_LOGIC                                  := '1';
        wr_en  : IN  STD_LOGIC                                  := '0';
        wr_adr : IN  STD_LOGIC_VECTOR(g_ram.adr_w - 1 DOWNTO 0) := (OTHERS => '0');
        wr_dat : IN  STD_LOGIC_VECTOR(g_ram.dat_w - 1 DOWNTO 0) := (OTHERS => '0');
        rd_en  : IN  STD_LOGIC                                  := '1';
        rd_adr : IN  STD_LOGIC_VECTOR(g_ram.adr_w - 1 DOWNTO 0);
        rd_dat : OUT STD_LOGIC_VECTOR(g_ram.dat_w - 1 DOWNTO 0);
        rd_val : OUT STD_LOGIC
    );
END common_ram_r_w;

ARCHITECTURE str OF common_ram_r_w IS

BEGIN

    -- Use port a only for write
    -- Use port b only for read

    u_rw_rw : ENTITY work.common_ram_rw_rw
        GENERIC MAP(
            g_ram            => g_ram,
            g_init_file      => g_init_file,
            g_true_dual_port => g_true_dual_port,
            g_ram_primitive  => g_ram_primitive
        )
        PORT MAP(
            clk      => clk,
            clken    => clken,
            wr_en_a  => wr_en,
            wr_en_b  => '0',
            wr_dat_a => wr_dat,
            --wr_dat_b  => (OTHERS=>'0'),
            adr_a    => wr_adr,
            adr_b    => rd_adr,
            rd_en_a  => '0',
            rd_en_b  => rd_en,
            rd_dat_a => OPEN,
            rd_dat_b => rd_dat,
            rd_val_a => OPEN,
            rd_val_b => rd_val
        );

END str;

