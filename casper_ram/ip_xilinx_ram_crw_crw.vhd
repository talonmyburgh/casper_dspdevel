LIBRARY ieee, common_pkg_lib;
USE ieee.std_logic_1164.all;
USE common_pkg_lib.common_pkg.ALL;

ENTITY ip_xilinx_ram_crw_crw IS
	GENERIC(
		g_adr_w      : NATURAL := 5;
		g_dat_w      : NATURAL := 8;
		g_bram_size  : STRING  := "18kb";
		g_rd_latency : NATURAL := 2;    -- choose 1 or 2
		g_init_file  : STRING  := "UNUSED"
	);
	PORT(
		address_a : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
		address_b : IN  STD_LOGIC_VECTOR(g_adr_w - 1 DOWNTO 0);
		clock_a   : IN  STD_LOGIC := '1';
		clock_b   : IN  STD_LOGIC;
		data_a    : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		data_b    : IN  STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		enable_a  : IN  STD_LOGIC := '1';
		enable_b  : IN  STD_LOGIC := '1';
		rden_a    : IN  STD_LOGIC := '1';
		rden_b    : IN  STD_LOGIC := '1';
		wren_a    : IN  STD_LOGIC := '0';
		wren_b    : IN  STD_LOGIC := '0';
		q_a       : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
		q_b       : OUT STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0)
	);
END ip_xilinx_ram_crw_crw;

ARCHITECTURE SYN OF ip_xilinx_ram_crw_crw IS

	component BRAM_TDP_MACRO
		generic(
			BRAM_SIZE     : string;
			DEVICE        : string;
			DOA_REG       : integer;
			DOB_REG       : integer;
			INIT_FILE     : string;
			READ_WIDTH_A  : integer;
			READ_WIDTH_B  : integer;
			WRITE_WIDTH_A : integer;
			WRITE_WIDTH_B : integer
		);
		port(
			DOA    : out std_logic_vector(READ_WIDTH_A - 1 downto 0);
			DOB    : out std_logic_vector(READ_WIDTH_B - 1 downto 0);
			ADDRA  : in  std_logic_vector;
			ADDRB  : in  std_logic_vector;
			CLKA   : in  std_ulogic;
			CLKB   : in  std_ulogic;
			DIA    : in  std_logic_vector(WRITE_WIDTH_A - 1 downto 0);
			DIB    : in  std_logic_vector(WRITE_WIDTH_B - 1 downto 0);
			ENA    : in  std_ulogic;
			ENB    : in  std_ulogic;
			REGCEA : in  std_ulogic;
			REGCEB : in  std_ulogic;
			RSTA   : in  std_ulogic;
			RSTB   : in  std_ulogic;
			WEA    : in  std_logic_vector;
			WEB    : in  std_logic_vector
		);
	end component BRAM_TDP_MACRO;

	SIGNAL c_outdata_reg : STD_LOGIC := sel_a_b(g_rd_latency - 1 = 0, '0', '1');

	SIGNAL sub_wire0 : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);
	SIGNAL sub_wire1 : STD_LOGIC_VECTOR(g_dat_w - 1 DOWNTO 0);

	CONSTANT initfile : STRING := sel_a_b(g_init_file = "UNUSED", "None", g_init_file);

begin
	q_a <= sub_wire0(g_dat_w-1 DOWNTO 0) when rden_a = '1';
	q_b <= sub_wire1(g_dat_w-1 DOWNTO 0) when rden_b = '1';

	tdp_ram_component : BRAM_TDP_MACRO
		generic map(
			BRAM_SIZE     => g_bram_size,
			DEVICE        => "7SERIES",
			DOA_REG       => g_rd_latency - 1,
			DOB_REG       => g_rd_latency - 1,
			INIT_FILE     => initfile,
			READ_WIDTH_A  => g_dat_w,
			READ_WIDTH_B  => g_dat_w,
			WRITE_WIDTH_A => g_dat_w,
			WRITE_WIDTH_B => g_dat_w
		)
		port map(
			DOA    => sub_wire0,
			DOB    => sub_wire1,
			ADDRA  => address_a,
			ADDRB  => address_b,
			CLKA   => clock_a,
			CLKB   => clock_b,
			DIA    => data_a,
			DIB    => data_b,
			ENA    => enable_a,
			ENB    => enable_b,
			REGCEA => c_outdata_reg,
			REGCEB => c_outdata_reg,
			RSTA   => '0',
			RSTB   => '0',
			WEA    => (others => wren_a),
			WEB    => (others => wren_b)
		);

END SYN;
