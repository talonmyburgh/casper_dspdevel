Library IEEE, UNISIM, common_pkg_lib;
USE ieee.std_logic_1164.all;
use UNISIM.vcomponents.all;
library UNIMACRO;
use unimacro.Vcomponents.all;
USE common_pkg_lib.common_pkg.ALL;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ip_xilinx_fifo_dc is
	generic(
		g_device    : string  := "7SERIES";
		g_dat_w     : natural := 18;
		g_nof_words : natural := 1024
	);
	port(
		rdclk   : in  std_logic;
		wrclk   : in  std_logic;
		aclr    : in  std_logic;
		data    : in  std_logic_vector;
		rdreq   : in  std_logic;
		wrreq   : in  std_logic;
		q       : out std_logic_vector;
		rdempty : out std_logic;
		rdusedw : out std_logic_vector;
		wrfull  : out std_logic;
		wrusedw : out std_logic_vector
	);
end entity ip_xilinx_fifo_dc;

architecture RTL of ip_xilinx_fifo_dc is
	constant rwcntw : natural := ceil_log2(g_nof_words);

begin
	gen36KbFifo : if ((rwcntw = 9 and (g_dat_w <= 72) and (g_dat_w >= 37)) or (rwcntw = 10 and (g_dat_w <= 36) and (g_dat_w >= 19)) 
		or (rwcntw = 11 and (g_dat_w <= 18) and (g_dat_w >= 10)) or (rwcntw = 12 and (g_dat_w <= 9) and (g_dat_w >= 5)) 
		or (rwcntw = 13 and (g_dat_w <= 4) and (g_dat_w >= 1))
	) generate
	begin
		FIFO_DUALCLOCK_MACRO_inst : FIFO_DUALCLOCK_MACRO
			generic map(
				DEVICE                  => g_device, -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES"
				DATA_WIDTH              => g_dat_w, -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
				FIFO_SIZE               => "36Kb",
				-- Target BRAM, "18Kb" or "36Kb"
				FIRST_WORD_FALL_THROUGH => FALSE) -- Sets the FIFO FWFT to TRUE or FALSE
			port map(
				ALMOSTEMPTY => open,    -- 1-bit output almost empty
				ALMOSTFULL  => open,    -- 1-bit output almost full
				DO          => q,       -- Output data, width defined by DATA_WIDTH parameter
				EMPTY       => rdempty, -- 1-bit output empty
				FULL        => wrfull,  -- 1-bit output full
				RDCOUNT     => rdusedw, -- Output read count, width determined by FIFO depth
				RDERR       => open,   -- 1-bit output read error
				WRCOUNT     => wrusedw, -- Output write count, width determined by FIFO depth
				WRERR       => open,   -- 1-bit output write error
				DI          => data,    -- Input data, width defined by DATA_WIDTH parameter
				RDCLK       => rdclk,   -- 1-bit input read clock
				RDEN        => rdreq,   -- 1-bit input read enable
				RST         => aclr,    -- 1-bit input reset
				WRCLK       => wrclk,   -- 1-bit input write clock
				WREN        => wrreq    -- 1-bit input write enable
			);
			-- End of FIFO_DUALCLOCK_MACRO_inst instantiation
	end generate;

	gen18KbFifo : if ((rwcntw = 9 and (g_dat_w <= 36) and (g_dat_w >= 19)) or (rwcntw = 10 and (g_dat_w <= 18) and (g_dat_w >= 10))
		or (rwcntw = 11 and (g_dat_w <= 9) and (g_dat_w >= 5)) or (rwcntw = 12 and (g_dat_w <= 4) and (g_dat_w >= 1))
	) generate
	begin
		FIFO_DUALCLOCK_MACRO_inst : FIFO_DUALCLOCK_MACRO
			generic map(
				DEVICE                  => g_device, -- Target Device: "VIRTEX5", "VIRTEX6", "7SERIES"
				DATA_WIDTH              => g_dat_w, -- Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
				FIFO_SIZE               => "18Kb",
				-- Target BRAM, "18Kb" or "36Kb"
				FIRST_WORD_FALL_THROUGH => FALSE) -- Sets the FIFO FWFT to TRUE or FALSE
			port map(
				ALMOSTEMPTY => open,    -- 1-bit output almost empty
				ALMOSTFULL  => open,    -- 1-bit output almost full
				DO          => q,       -- Output data, width defined by DATA_WIDTH parameter
				EMPTY       => rdempty, -- 1-bit output empty
				FULL        => wrfull,  -- 1-bit output full
				RDCOUNT     => rdusedw, -- Output read count, width determined by FIFO depth
				RDERR       => open,   -- 1-bit output read error
				WRCOUNT     => wrusedw, -- Output write count, width determined by FIFO depth
				WRERR       => open,   -- 1-bit output write error
				DI          => data,    -- Input data, width defined by DATA_WIDTH parameter
				RDCLK       => rdclk,   -- 1-bit input read clock
				RDEN        => rdreq,   -- 1-bit input read enable
				RST         => aclr,    -- 1-bit input reset
				WRCLK       => wrclk,   -- 1-bit input write clock
				WREN        => wrreq    -- 1-bit input write enable
			);
			-- End of FIFO_DUALCLOCK_MACRO_inst instantiation
	end generate;
end architecture RTL;

