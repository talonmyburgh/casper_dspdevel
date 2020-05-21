--------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------

-- Purpose: Wrapper of dp_fifo_fill_sc.vhd
-- Description: See dp_fifo_fill_core.vhd
-- Remark:
--   This wrapper is for backwards compatibility, better use dp_fifo_fill_sc.vhd
--   for new designs.

LIBRARY IEEE, common_pkg_lib, dp_pkg_lib;
USE IEEE.std_logic_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE dp_pkg_lib.dp_stream_pkg.ALL;
--USE technology_lib.technology_select_pkg.ALL;

ENTITY dp_fifo_fill IS
  GENERIC (
    g_technology     : NATURAL := 0;
    g_data_w         : NATURAL := 16;
    g_bsn_w          : NATURAL := 1;
    g_empty_w        : NATURAL := 1;
    g_channel_w      : NATURAL := 1;
    g_error_w        : NATURAL := 1;
    g_use_bsn        : BOOLEAN := FALSE;
    g_use_empty      : BOOLEAN := FALSE;
    g_use_channel    : BOOLEAN := FALSE;
    g_use_error      : BOOLEAN := FALSE;
    g_use_sync       : BOOLEAN := FALSE;
    g_use_complex    : BOOLEAN := FALSE;  -- TRUE feeds the concatenated complex fields (im & re) through the FIFO instead of the data field.
    g_fifo_fill      : NATURAL := 0;
    g_fifo_size      : NATURAL := 256;    -- (32+2) * 256 = 1 M9K, g_data_w+2 for sop and eop
    g_fifo_af_margin : NATURAL := 4;      -- Nof words below max (full) at which fifo is considered almost full
    g_fifo_rl        : NATURAL := 1       -- use RL=0 for internal show ahead FIFO, default use RL=1 for internal normal FIFO
  );
  PORT (
    rst         : IN  STD_LOGIC;
    clk         : IN  STD_LOGIC;
    
    -- Monitor FIFO filling
    wr_ful      : OUT STD_LOGIC;
    usedw       : OUT STD_LOGIC_VECTOR(ceil_log2(largest(g_fifo_size, g_fifo_fill + g_fifo_af_margin + 2))-1 DOWNTO 0);  -- = ceil_log2(c_fifo_size)-1 DOWNTO 0
    rd_emp      : OUT STD_LOGIC;

    -- MM control FIFO filling (assume 32 bit MM interface)
    wr_usedw_32b : OUT STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0);  -- = wr_usedw
    rd_usedw_32b : OUT STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0);  -- = rd_usedw
    rd_fill_32b  : IN  STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0) := TO_UVEC(g_fifo_fill, c_word_w);

    -- ST sink
    snk_out     : OUT t_dp_siso;
    snk_in      : IN  t_dp_sosi;
    -- ST source
    src_in      : IN  t_dp_siso;
    src_out     : OUT t_dp_sosi
  );
END dp_fifo_fill;


ARCHITECTURE str OF dp_fifo_fill IS
BEGIN

  u_dp_fifo_fill_sc : ENTITY work.dp_fifo_fill_sc
  GENERIC MAP (
    g_technology     => g_technology,
    g_data_w         => g_data_w,
    g_bsn_w          => g_bsn_w,
    g_empty_w        => g_empty_w,
    g_channel_w      => g_channel_w,
    g_error_w        => g_error_w,
    g_use_bsn        => g_use_bsn,
    g_use_empty      => g_use_empty,
    g_use_channel    => g_use_channel,
    g_use_error      => g_use_error,
    g_use_sync       => g_use_sync,
    g_use_complex    => g_use_complex,
    g_fifo_fill      => g_fifo_fill,
    g_fifo_size      => g_fifo_size,
    g_fifo_af_margin => g_fifo_af_margin,
    g_fifo_rl        => g_fifo_rl
  )
  PORT MAP (
    rst         => rst,
    clk         => clk,

    -- Monitor FIFO filling
    wr_ful      => wr_ful,
    usedw       => usedw,
    rd_emp      => rd_emp,

    -- MM control FIFO filling (assume 32 bit MM interface)
    wr_usedw_32b => wr_usedw_32b,
    rd_usedw_32b => rd_usedw_32b,
    rd_fill_32b  => rd_fill_32b,

    -- ST sink
    snk_out     => snk_out,
    snk_in      => snk_in,
    -- ST source
    src_in      => src_in,
    src_out     => src_out
  );

END str;
