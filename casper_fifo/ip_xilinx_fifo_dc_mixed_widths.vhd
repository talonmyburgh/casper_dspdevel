Library IEEE, xpm, common_pkg_lib;
USE ieee.std_logic_1164.all;
USE common_pkg_lib.common_pkg.ALL;
USE xpm.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ip_xilinx_fifo_dc_mixed_widths is
	GENERIC(
		g_nof_words      : NATURAL;     -- FIFO size in nof wr_dat words
		g_wrdat_w        : NATURAL;
		g_rddat_w        : NATURAL;
		g_fifo_primitive : STRING := "auto"
	);
	PORT(
		aclr    : IN  STD_LOGIC := '0';
		data    : IN  STD_LOGIC_VECTOR(g_wrdat_w - 1 DOWNTO 0);
		rdclk   : IN  STD_LOGIC;
		rdreq   : IN  STD_LOGIC;
		wrclk   : IN  STD_LOGIC;
		wrreq   : IN  STD_LOGIC;
		q       : OUT STD_LOGIC_VECTOR(g_rddat_w - 1 DOWNTO 0);
		rdempty : OUT STD_LOGIC;
		rdusedw : OUT STD_LOGIC_VECTOR(ceil_log2(g_nof_words * g_wrdat_w / g_rddat_w) - 1 DOWNTO 0);
		wrfull  : OUT STD_LOGIC;
		wrusedw : OUT STD_LOGIC_VECTOR(ceil_log2(g_nof_words) - 1 DOWNTO 0)
	);
end entity ip_xilinx_fifo_dc_mixed_widths;

architecture RTL of ip_xilinx_fifo_dc_mixed_widths is
	CONSTANT c_cnt_w   : NATURAL := ceil_log2(g_nof_words * g_wrdat_w / g_rddat_w) + 1;
	CONSTANT c_w_depth : NATURAL := ceil_log2(g_nof_words) + 1;
	SIGNAL sub_wire0   : STD_LOGIC;
	SIGNAL sub_wire1   : STD_LOGIC_VECTOR(q'RANGE);
	SIGNAL sub_wire2   : STD_LOGIC;
	SIGNAL sub_wire3   : STD_LOGIC_VECTOR(wrusedw'RANGE);
	SIGNAL sub_wire4   : STD_LOGIC_VECTOR(rdusedw'RANGE);

begin

	wrfull  <= sub_wire0;
	q       <= sub_wire1(q'RANGE);
	rdempty <= sub_wire2;
	wrusedw <= sub_wire3(wrusedw'RANGE);
	rdusedw <= sub_wire4(rdusedw'RANGE);

	xpm_fifo_async_inst : xpm_fifo_async
		generic map(
			CDC_SYNC_STAGES     => 5,   -- DECIMAL
			DOUT_RESET_VALUE    => "0", -- String
			ECC_MODE            => "no_ecc", -- String
			FIFO_MEMORY_TYPE    => g_fifo_primitive, -- String
			FIFO_READ_LATENCY   => 1,   -- DECIMAL
			FIFO_WRITE_DEPTH    => g_nof_words, -- DECIMAL
			FULL_RESET_VALUE    => 0,   -- DECIMAL
			PROG_EMPTY_THRESH   => 10,  -- DECIMAL
			PROG_FULL_THRESH    => 10,  -- DECIMAL
			RD_DATA_COUNT_WIDTH => c_cnt_w, -- DECIMAL
			READ_DATA_WIDTH     => g_rddat_w, -- DECIMAL
			READ_MODE           => "std", -- String
			RELATED_CLOCKS      => 0,   -- DECIMAL
			USE_ADV_FEATURES    => "0707", -- String
			WAKEUP_TIME         => 0,   -- DECIMAL
			WRITE_DATA_WIDTH    => g_wrdat_w, -- DECIMAL
			WR_DATA_COUNT_WIDTH => c_w_depth -- DECIMAL
		)
		port map(
			almost_empty  => open,      -- 1-bit output: Almost Empty : When asserted, this signal indicates that
			-- only one more read can be performed before the FIFO goes to empty.
			almost_full   => open,      -- 1-bit output: Almost Full: When asserted, this signal indicates that
			-- only one more write can be performed before the FIFO is full.
			data_valid    => open,      -- 1-bit output: Read Data Valid: When asserted, this signal indicates
			-- that valid data is available on the output bus (dout).
			dbiterr       => open,      -- 1-bit output: Double Bit Error: Indicates that the ECC decoder
			-- detected a double-bit error and data in the FIFO core is corrupted.
			dout          => sub_wire1, -- READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
			-- when reading the FIFO.
			empty         => sub_wire2, -- 1-bit output: Empty Flag: When asserted, this signal indicates that
			-- the FIFO is empty. Read requests are ignored when the FIFO is empty,
			-- initiating a read while empty is not destructive to the FIFO.
			full          => sub_wire0,
			-- 1-bit output: Full Flag: When asserted, this signal indicates that the
			-- FIFO is full. Write requests are ignored when the FIFO is full,
			-- initiating a write when the FIFO is full is not destructive to the
			-- contents of the FIFO.
			overflow      => open,
			-- 1-bit output: Overflow: This signal indicates that a write request
			-- (wren) during the prior clock cycle was rejected, because the FIFO is
			-- full. Overflowing the FIFO is not destructive to the contents of the
			-- FIFO.
			prog_empty    => open,
			-- 1-bit output: Programmable Empty: This signal is asserted when the
			-- number of words in the FIFO is less than or equal to the programmable
			-- empty threshold value. It is de-asserted when the number of words in
			-- the FIFO exceeds the programmable empty threshold value.
			prog_full     => open,
			-- 1-bit output: Programmable Full: This signal is asserted when the
			-- number of words in the FIFO is greater than or equal to the
			-- programmable full threshold value. It is de-asserted when the number
			-- of words in the FIFO is less than the programmable full threshold
			-- value.
			rd_data_count => sub_wire4, -- RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates
			-- the number of words read from the FIFO.
			rd_rst_busy   => open,      -- 1-bit output: Read Reset Busy: Active-High indicator that the FIFO
			-- read domain is currently in a reset state.
			sbiterr       => open,      -- 1-bit output: Single Bit Error: Indicates that the ECC decoder
			-- detected and fixed a single-bit error.
			underflow     => open,
			-- 1-bit output: Underflow: Indicates that the read request (rd_en)
			-- during the previous clock cycle was rejected because the FIFO is
			-- empty. Under flowing the FIFO is not destructive to the FIFO.
			wr_ack        => open,
			-- 1-bit output: Write Acknowledge: This signal indicates that a write
			-- request (wr_en) during the prior clock cycle is succeeded.
			wr_data_count => sub_wire3, -- WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
			-- the number of words written into the FIFO.
			wr_rst_busy   => open,      -- 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
			-- write domain is currently in a reset state.
			din           => data,      -- WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
			-- writing the FIFO.
			injectdbiterr => '0',       -- 1-bit input: Double Bit Error Injection: Injects a double bit error if
			-- the ECC feature is used on block RAMs or UltraRAM macros.
			injectsbiterr => '0',       -- 1-bit input: Single Bit Error Injection: Injects a single bit error if
			-- the ECC feature is used on block RAMs or UltraRAM macros.
			rd_clk        => rdclk,     -- 1-bit input: Read clock: Used for read operation. rd_clk must be a
			-- free running clock.
			rd_en         => rdreq,     -- 1-bit input: Read Enable: If the FIFO is not empty, asserting this
			-- signal causes data (on dout) to be read from the FIFO. Must be held
			-- active-low when rd_rst_busy is active high.
			rst           => aclr,
			-- 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
			-- unstable at the time of applying reset, but reset must be released
			-- only after the clock(s) is/are stable.
			sleep         => '0',       -- 1-bit input: Dynamic power saving: If sleep is High, the memory/fifo
			-- block is in power saving mode.
			wr_clk        => wrclk,     -- 1-bit input: Write clock: Used for write operation. wr_clk must be a
			-- free running clock.
			wr_en         => wrreq      -- 1-bit input: Write Enable: If the FIFO is not full, asserting this
			-- signal causes data (on din) to be written to the FIFO. Must be held
			-- active-low when rst or wr_rst_busy is active high.
		);
		-- End of xpm_fifo_async_inst instantiation

end architecture RTL;

