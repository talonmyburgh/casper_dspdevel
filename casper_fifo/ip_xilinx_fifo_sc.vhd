Library IEEE, xpm, common_pkg_lib;
USE ieee.std_logic_1164.all;
use xpm.vcomponents.all;
USE IEEE.numeric_std.ALL;
use common_pkg_lib.common_pkg.all;

entity ip_xilinx_fifo_sc is
	generic(
		g_dat_w          : NATURAL;
		g_nof_words      : NATURAL;
		g_fifo_primitive : STRING := "auto"
	);
	port(
		aclr  : IN  STD_LOGIC;
		clock : IN  STD_LOGIC;
		data  : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		rdreq : IN  STD_LOGIC;
		wrreq : IN  STD_LOGIC;
		empty : OUT STD_LOGIC;
		full  : OUT STD_LOGIC;
		q     : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		usedw : OUT STD_LOGIC_VECTOR(ceil_log2(g_nof_words) - 1 DOWNTO 0)
	);
end entity ip_xilinx_fifo_sc;

architecture RTL of ip_xilinx_fifo_sc is
	CONSTANT c_cnt_w : NATURAL := ceil_log2(g_nof_words) + 1;

	SIGNAL sub_wire0 : STD_LOGIC_VECTOR(usedw'RANGE);
	SIGNAL sub_wire1 : STD_LOGIC;
	SIGNAL sub_wire2 : STD_LOGIC;
	SIGNAL sub_wire3 : STD_LOGIC_VECTOR(data'RANGE);

	SIGNAL num_rw : STD_LOGIC_VECTOR(c_cnt_w - 1 DOWNTO 0);
	SIGNAL num_ww : STD_LOGIC_VECTOR(c_cnt_w - 1 DOWNTO 0);

begin
	usedw <= sub_wire0;
	empty <= sub_wire1;
	full  <= sub_wire2;
	q     <= sub_wire3;

	sub_wire0 <= std_logic_vector(unsigned(num_ww) - unsigned(num_rw));

	xpm_fifo_sync_inst : xpm_fifo_sync
		generic map(
			DOUT_RESET_VALUE    => "0", -- String
			ECC_MODE            => "no_ecc", -- String
			FIFO_MEMORY_TYPE    => g_fifo_primitive, -- String
			FIFO_READ_LATENCY   => 1,   -- DECIMAL
			FIFO_WRITE_DEPTH    => g_nof_words, -- DECIMAL
			FULL_RESET_VALUE    => 0,   -- DECIMAL
			RD_DATA_COUNT_WIDTH => c_cnt_w, -- DECIMAL
			READ_DATA_WIDTH     => g_dat_w, -- DECIMAL
			READ_MODE           => "std", -- String
			USE_ADV_FEATURES    => "0707", -- String
			WAKEUP_TIME         => 0,   -- DECIMAL
			WRITE_DATA_WIDTH    => g_dat_w, -- DECIMAL
			WR_DATA_COUNT_WIDTH => c_cnt_w -- DECIMAL
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

			dout          => sub_wire3, -- READ_DATA_WIDTH-bit output: Read Data: The output data bus is driven
			-- when reading the FIFO.

			empty         => sub_wire1, -- 1-bit output: Empty Flag: When asserted, this signal indicates that
			-- the FIFO is empty. Read requests are ignored when the FIFO is empty,
			-- initiating a read while empty is not destructive to the FIFO.

			full          => sub_wire2, -- 1-bit output: Full Flag: When asserted, this signal indicates that the
			-- FIFO is full. Write requests are ignored when the FIFO is full,
			-- initiating a write when the FIFO is full is not destructive to the
			-- contents of the FIFO.

			overflow      => open,      -- 1-bit output: Overflow: This signal indicates that a write request
			-- (wren) during the prior clock cycle was rejected, because the FIFO is
			-- full. Overflowing the FIFO is not destructive to the contents of the
			-- FIFO.

			prog_empty    => open,      -- 1-bit output: Programmable Empty: This signal is asserted when the
			-- number of words in the FIFO is less than or equal to the programmable
			-- empty threshold value. It is de-asserted when the number of words in
			-- the FIFO exceeds the programmable empty threshold value.

			prog_full     => open,      -- 1-bit output: Programmable Full: This signal is asserted when the
			-- number of words in the FIFO is greater than or equal to the
			-- programmable full threshold value. It is de-asserted when the number
			-- of words in the FIFO is less than the programmable full threshold
			-- value.

			rd_data_count => num_rw,    -- RD_DATA_COUNT_WIDTH-bit output: Read Data Count: This bus indicates
			-- the number of words read from the FIFO.

			rd_rst_busy   => open,      -- 1-bit output: Read Reset Busy: Active-High indicator that the FIFO
			-- read domain is currently in a reset state.

			sbiterr       => open,      -- 1-bit output: Single Bit Error: Indicates that the ECC decoder
			-- detected and fixed a single-bit error.

			underflow     => open,      -- 1-bit output: Underflow: Indicates that the read request (rd_en)
			-- during the previous clock cycle was rejected because the FIFO is
			-- empty. Under flowing the FIFO is not destructive to the FIFO.

			wr_ack        => open,      -- 1-bit output: Write Acknowledge: This signal indicates that a write
			-- request (wr_en) during the prior clock cycle is succeeded.

			wr_data_count => num_ww,    -- WR_DATA_COUNT_WIDTH-bit output: Write Data Count: This bus indicates
			-- the number of words written into the FIFO.

			wr_rst_busy   => open,      -- 1-bit output: Write Reset Busy: Active-High indicator that the FIFO
			-- write domain is currently in a reset state.

			din           => data,      -- WRITE_DATA_WIDTH-bit input: Write Data: The input data bus used when
			-- writing the FIFO.

			injectdbiterr => '0',       -- 1-bit input: Double Bit Error Injection: Injects a double bit error if
			-- the ECC feature is used on block RAMs or UltraRAM macros.

			injectsbiterr => '0',       -- 1-bit input: Single Bit Error Injection: Injects a single bit error if
			-- the ECC feature is used on block RAMs or UltraRAM macros.

			rd_en         => rdreq,     -- 1-bit input: Read Enable: If the FIFO is not empty, asserting this
			                            -- signal causes data (on dout) to be read from the FIFO. Must be held
			                            -- active-low when rd_rst_busy is active high.

			rst           => aclr,      -- 1-bit input: Reset: Must be synchronous to wr_clk. The clock(s) can be
			-- unstable at the time of applying reset, but reset must be released
			-- only after the clock(s) is/are stable.

			sleep         => '0',       -- 1-bit input: Dynamic power saving- If sleep is High, the memory/fifo
			-- block is in power saving mode.

			wr_clk        => clock,     -- 1-bit input: Write clock: Used for write operation. wr_clk must be a
			-- free running clock.

			wr_en         => wrreq      -- 1-bit input: Write Enable: If the FIFO is not full, asserting this
			                            -- signal causes data (on din) to be written to the FIFO Must be held
			                            -- active-low when rst or wr_rst_busy or rd_rst_busy is active high

		);

		-- End of xpm_fifo_sync_inst instantiation

end architecture RTL;

