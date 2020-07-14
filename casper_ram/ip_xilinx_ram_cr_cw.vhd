LIBRARY ieee, common_pkg_lib;
USE ieee.std_logic_1164.all;
USE common_pkg_lib.common_pkg.ALL;

ENTITY ip_xilinx_ram_cr_cw IS
  GENERIC (
    g_adr_w      : NATURAL := 5;
    g_dat_w      : NATURAL := 8;
    g_bram_size  : STRING := "18kb"; -- choose 9kb, 18kb, 36kb
    g_rd_latency : NATURAL := 2;  -- choose 1 or 2
    g_init_file  : STRING  := "UNUSED"
  );
  PORT
  (
    data      : IN  STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
    rdaddress : IN  STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
    rdclock   : IN  STD_LOGIC ;
    rdclocken : IN  STD_LOGIC  := '1';
    wraddress : IN  STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
    wrclock   : IN  STD_LOGIC  := '1';
    wrclocken : IN  STD_LOGIC  := '1';
    wren      : IN  STD_LOGIC  := '0';
    q         : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0)
  );
END ip_xilinx_ram_cr_cw;

architecture syn of ip_xilinx_ram_cr_cw is
	
	SIGNAL c_outdata_reg_b : STD_LOGIC := sel_a_b(g_rd_latency-1=0, '0', '1');
	
	CONSTANT initfile : STRING := sel_a_b(g_init_file="UNUSED", "None", g_init_file);
  
  	SIGNAL sub_wire0  : STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
  	
  	component BRAM_SDP_MACRO
  		generic(
  			BRAM_SIZE           : string;
  			DEVICE              : string;
  			DO_REG              : integer;
  			INIT_FILE           : string;
  			READ_WIDTH          : integer;
  			WRITE_MODE          : string;
  			WRITE_WIDTH         : integer
  		);
  		port(
  			DO     : out std_logic_vector(READ_WIDTH - 1 downto 0);
  			DI     : in  std_logic_vector(WRITE_WIDTH - 1 downto 0);
  			RDADDR : in  std_logic_vector;
  			RDCLK  : in  std_ulogic;
  			RDEN   : in  std_ulogic;
  			REGCE  : in  std_ulogic;
  			RST    : in  std_ulogic;
  			WE     : in  std_logic_vector;
  			WRADDR : in  std_logic_vector;
  			WRCLK  : in  std_ulogic;
  			WREN   : in  std_ulogic
  		);
  	end component BRAM_SDP_MACRO;
	
begin
	
	q    <= sub_wire0(g_dat_w-1 DOWNTO 0);
	
	sdp_ram_comp : BRAM_SDP_MACRO
		generic map(
			BRAM_SIZE => g_bram_size,
			DEVICE => "7SERIES",
			DO_REG => g_rd_latency-1,
			INIT_FILE => initfile,
			READ_WIDTH => g_dat_w,
			WRITE_MODE => "WRITE_FIRST",
			WRITE_WIDTH => g_dat_w
		)
		port map(
			DO     => sub_wire0,
			DI     => data,
			RDADDR => rdaddress,
			RDCLK  => rdclock,
			RDEN   => rdclocken,
			REGCE  => c_outdata_reg_b,
			RST    => '0',
			WE     => (others=>'1'),
			WRADDR => wraddress,
			WRCLK  => wrclock,
			WREN   => wren
		);
	
end architecture syn;
