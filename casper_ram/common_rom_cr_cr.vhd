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

LIBRARY IEEE, common_pkg_lib, common_components_lib;
USE IEEE.std_logic_1164.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE work.common_ram_pkg.ALL;

ENTITY common_rom_cr_cr IS
	GENERIC(
		g_technology     : NATURAL := 0; --0 for Xilinx, 1 for Alterra
		g_ram            : t_c_mem := c_mem_ram;
		g_init_file      : STRING  := "UNUSED";
		g_ram_primitive  : STRING  := "auto"
	);
	PORT(
		clk      : IN  STD_LOGIC;
		clken    : IN  STD_LOGIC                                  := '1';
		adr_a    : IN  STD_LOGIC_VECTOR(g_ram.adr_w - 1 DOWNTO 0) := (OTHERS => '0');
		adr_b    : IN  STD_LOGIC_VECTOR(g_ram.adr_w - 1 DOWNTO 0) := (OTHERS => '0');
		rd_en    : IN  STD_LOGIC                                  := '1';
		rd_dat_a : OUT STD_LOGIC_VECTOR(g_ram.dat_w - 1 DOWNTO 0);
		rd_dat_b : OUT STD_LOGIC_VECTOR(g_ram.dat_w - 1 DOWNTO 0);
		rd_val   : OUT STD_LOGIC
	);
END common_rom_cr_cr;

ARCHITECTURE str OF common_rom_cr_cr IS

	CONSTANT c_rd_latency : NATURAL := sel_a_b(g_ram.latency < 2, g_ram.latency, 2); -- handle read latency 1 or 2 in RAM
	CONSTANT c_pipeline   : NATURAL := sel_a_b(g_ram.latency > c_rd_latency, g_ram.latency - c_rd_latency, 0); -- handle rest of read latency > 2 in pipeline

	-- Intermediate signal for extra pipelining
	SIGNAL ram_rd_dat_a : STD_LOGIC_VECTOR(rd_dat'RANGE);
	SIGNAL ram_rd_dat_b : STD_LOGIC_VECTOR(rd_dat'RANGE);

	-- Map sl to single bit slv for rd_val pipelining
	SIGNAL ram_rd_en_a  : STD_LOGIC_VECTOR(0 DOWNTO 0);
	SIGNAL ram_rd_en_b  : STD_LOGIC_VECTOR(0 DOWNTO 0);
	SIGNAL ram_rd_val_a : STD_LOGIC_VECTOR(0 DOWNTO 0);
	SIGNAL ram_rd_val_b : STD_LOGIC_VECTOR(0 DOWNTO 0);

BEGIN

	ASSERT g_ram.latency >= 1
	REPORT "common_rom_cr_cr : only support read latency >= 1"
	SEVERITY FAILURE;

	-- memory access
	u_ram : ENTITY work.tech_memory_rom_cr_cr
		GENERIC MAP(
			g_technology    => g_technology,
			g_adr_a_w       => g_ram.adr_w,
			g_adr_b_w       => g_ram.adr_w,
			g_dat_w         => g_ram.dat_w,
			g_nof_words     => g_ram.nof_dat,
			g_rd_latency    => c_rd_latency,
			g_init_file     => g_init_file,
			g_ram_primitive => g_ram_primitive
		)
		PORT MAP(
			rdaddress_a => adr_a,
			rdaddress_b => adr_b,
			rdclock     => clk,
			rdclocken   => clken,
			q_a         => ram_rd_dat_a,
			q_b         => ram_rd_dat_b
		);

    -- rd_val control
	ram_rd_en_a(0) <= rd_en_a;
	ram_rd_en_b(0) <= rd_en_b;

	rd_val_a <= ram_rd_val_a(0);
	rd_val_b <= ram_rd_val_b(0);

	-- read output a
	u_pipe_a : ENTITY common_components_lib.common_pipeline
		GENERIC MAP(
			g_pipeline  => c_pipeline,
			g_in_dat_w  => g_ram.dat_w,
			g_out_dat_w => g_ram.dat_w
		)
		PORT MAP(
			clk     => clk,
			clken   => clken,
			in_dat  => ram_rd_dat_a,
			out_dat => rd_dat_a
		);

        u_rd_val_a : ENTITY common_components_lib.common_pipeline
		GENERIC MAP(
			g_pipeline  => g_ram.latency,
			g_in_dat_w  => 1,
			g_out_dat_w => 1
		)
		PORT MAP(
			clk     => clk_a,
			clken   => clken_a,
			in_dat  => ram_rd_en_a,
			out_dat => ram_rd_val_a
		);

	-- read output b
	u_pipe_b: ENTITY common_components_lib.common_pipeline
		GENERIC MAP(
			g_pipeline  => c_pipeline,
			g_in_dat_w  => g_ram.dat_w,
			g_out_dat_w => g_ram.dat_w
		)
		PORT MAP(
			clk     => clk,
			clken   => clken,
			in_dat  => ram_rd_dat,
			out_dat => rd_dat
		);

	u_rd_val_b : ENTITY common_components_lib.common_pipeline
		GENERIC MAP(
			g_pipeline  => g_ram.latency,
			g_in_dat_w  => 1,
			g_out_dat_w => 1
		)
		PORT MAP(
			clk     => clk_b,
			clken   => clken_b,
			in_dat  => ram_rd_en_b,
			out_dat => ram_rd_val_b
		);

END str;
