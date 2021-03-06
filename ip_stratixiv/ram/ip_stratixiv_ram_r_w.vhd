-- megafunction wizard: %RAM: 2-PORT%
-- GENERATION: STANDARD
-- VERSION: WM1.0
-- MODULE: altsyncram 

-- ============================================================
-- File Name: ip_stratixiv_ram_r_w.vhd
-- Megafunction Name(s):
--      altsyncram
--
-- Simulation Library Files(s):
--      altera_mf
-- ============================================================
-- ************************************************************
-- THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
--
-- 9.0 Build 235 06/17/2009 SP 2 SJ Full Version
-- ************************************************************


--Copyright (C) 1991-2009 Altera Corporation
--Your use of Altera Corporation's design tools, logic functions 
--and other software and tools, and its AMPP partner logic 
--functions, and any output files from any of the foregoing 
--(including device programming or simulation files), and any 
--associated documentation or information are expressly subject 
--to the terms and conditions of the Altera Program License 
--Subscription Agreement, Altera MegaCore Function License 
--Agreement, or other applicable license agreement, including, 
--without limitation, that your use is for the sole purpose of 
--programming logic devices manufactured by Altera and sold by 
--Altera or its authorized distributors.  Please refer to the 
--applicable agreement for further details.


LIBRARY ieee;
USE ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.all;

ENTITY ip_stratixiv_ram_r_w IS
  GENERIC (
    g_adr_w     : NATURAL := 5;
    g_dat_w     : NATURAL := 8;
    g_nof_words : NATURAL := 2**5;
    g_init_file : STRING  := "UNUSED"
  );
  PORT (
    clock       : IN STD_LOGIC  := '1';
    enable      : IN STD_LOGIC  := '1';
    data        : IN STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0);
    rdaddress   : IN STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0);
    wraddress   : IN STD_LOGIC_VECTOR(g_adr_w-1 DOWNTO 0);
    wren        : IN STD_LOGIC  := '0';
    q           : OUT STD_LOGIC_VECTOR(g_dat_w-1 DOWNTO 0)
  );
END ip_stratixiv_ram_r_w;


ARCHITECTURE SYN OF ip_stratixiv_ram_r_w IS

  SIGNAL sub_wire0  : STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);

  COMPONENT altsyncram
  GENERIC (
    address_aclr_b    : STRING;
    address_reg_b   : STRING;
    clock_enable_input_a    : STRING;
    clock_enable_input_b    : STRING;
    clock_enable_output_b   : STRING;
    init_file   : STRING;
    intended_device_family    : STRING;
    lpm_type    : STRING;
    numwords_a    : NATURAL;
    numwords_b    : NATURAL;
    operation_mode    : STRING;
    outdata_aclr_b    : STRING;
    outdata_reg_b   : STRING;
    power_up_uninitialized    : STRING;
    read_during_write_mode_mixed_ports    : STRING;
    widthad_a   : NATURAL;
    widthad_b   : NATURAL;
    width_a   : NATURAL;
    width_b   : NATURAL;
    width_byteena_a   : NATURAL
  );
  PORT (
      clocken0  : IN STD_LOGIC ;
      wren_a  : IN STD_LOGIC ;
      clock0  : IN STD_LOGIC ;
      address_a : IN STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
      address_b : IN STD_LOGIC_VECTOR (g_adr_w-1 DOWNTO 0);
      q_b : OUT STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0);
      data_a  : IN STD_LOGIC_VECTOR (g_dat_w-1 DOWNTO 0)
  );
  END COMPONENT;

BEGIN
  q    <= sub_wire0(g_dat_w-1 DOWNTO 0);

  altsyncram_component : altsyncram
  GENERIC MAP (
    address_aclr_b => "NONE",
    address_reg_b => "CLOCK0",
    clock_enable_input_a => "NORMAL",
    clock_enable_input_b => "NORMAL",
    clock_enable_output_b => "NORMAL",
    init_file => g_init_file,
    intended_device_family => "Stratix IV",
    lpm_type => "altsyncram",
    numwords_a => g_nof_words,
    numwords_b => g_nof_words,
    operation_mode => "DUAL_PORT",
    outdata_aclr_b => "NONE",
    outdata_reg_b => "CLOCK0",
    power_up_uninitialized => "FALSE",
    read_during_write_mode_mixed_ports => "DONT_CARE",
    widthad_a => g_adr_w,
    widthad_b => g_adr_w,
    width_a => g_dat_w,
    width_b => g_dat_w,
    width_byteena_a => 1
  )
  PORT MAP (
    clocken0 => enable,
    wren_a => wren,
    clock0 => clock,
    address_a => wraddress,
    address_b => rdaddress,
    data_a => data,
    q_b => sub_wire0
  );

END SYN;

-- ============================================================
-- CNX file retrieval info
-- ============================================================
-- Retrieval info: PRIVATE: ADDRESSSTALL_A NUMERIC "0"
-- Retrieval info: PRIVATE: ADDRESSSTALL_B NUMERIC "0"
-- Retrieval info: PRIVATE: BYTEENA_ACLR_A NUMERIC "0"
-- Retrieval info: PRIVATE: BYTEENA_ACLR_B NUMERIC "0"
-- Retrieval info: PRIVATE: BYTE_ENABLE_A NUMERIC "0"
-- Retrieval info: PRIVATE: BYTE_ENABLE_B NUMERIC "0"
-- Retrieval info: PRIVATE: BYTE_SIZE NUMERIC "8"
-- Retrieval info: PRIVATE: BlankMemory NUMERIC "0"
-- Retrieval info: PRIVATE: CLOCK_ENABLE_INPUT_A NUMERIC "1"
-- Retrieval info: PRIVATE: CLOCK_ENABLE_INPUT_B NUMERIC "1"
-- Retrieval info: PRIVATE: CLOCK_ENABLE_OUTPUT_A NUMERIC "0"
-- Retrieval info: PRIVATE: CLOCK_ENABLE_OUTPUT_B NUMERIC "1"
-- Retrieval info: PRIVATE: CLRdata NUMERIC "0"
-- Retrieval info: PRIVATE: CLRq NUMERIC "0"
-- Retrieval info: PRIVATE: CLRrdaddress NUMERIC "0"
-- Retrieval info: PRIVATE: CLRrren NUMERIC "0"
-- Retrieval info: PRIVATE: CLRwraddress NUMERIC "0"
-- Retrieval info: PRIVATE: CLRwren NUMERIC "0"
-- Retrieval info: PRIVATE: Clock NUMERIC "0"
-- Retrieval info: PRIVATE: Clock_A NUMERIC "0"
-- Retrieval info: PRIVATE: Clock_B NUMERIC "0"
-- Retrieval info: PRIVATE: ECC NUMERIC "0"
-- Retrieval info: PRIVATE: IMPLEMENT_IN_LES NUMERIC "0"
-- Retrieval info: PRIVATE: INDATA_ACLR_B NUMERIC "0"
-- Retrieval info: PRIVATE: INDATA_REG_B NUMERIC "0"
-- Retrieval info: PRIVATE: INIT_FILE_LAYOUT STRING "PORT_B"
-- Retrieval info: PRIVATE: INIT_TO_SIM_X NUMERIC "0"
-- Retrieval info: PRIVATE: INTENDED_DEVICE_FAMILY STRING "Stratix IV"
-- Retrieval info: PRIVATE: JTAG_ENABLED NUMERIC "0"
-- Retrieval info: PRIVATE: JTAG_ID STRING "NONE"
-- Retrieval info: PRIVATE: MAXIMUM_DEPTH NUMERIC "0"
-- Retrieval info: PRIVATE: MEMSIZE NUMERIC "256"
-- Retrieval info: PRIVATE: MEM_IN_BITS NUMERIC "0"
-- Retrieval info: PRIVATE: MIFfilename STRING "fft_3n1024sin.hex"
-- Retrieval info: PRIVATE: OPERATION_MODE NUMERIC "2"
-- Retrieval info: PRIVATE: OUTDATA_ACLR_B NUMERIC "0"
-- Retrieval info: PRIVATE: OUTDATA_REG_B NUMERIC "1"
-- Retrieval info: PRIVATE: RAM_BLOCK_TYPE NUMERIC "0"
-- Retrieval info: PRIVATE: READ_DURING_WRITE_MODE_MIXED_PORTS NUMERIC "2"
-- Retrieval info: PRIVATE: READ_DURING_WRITE_MODE_PORT_A NUMERIC "3"
-- Retrieval info: PRIVATE: READ_DURING_WRITE_MODE_PORT_B NUMERIC "3"
-- Retrieval info: PRIVATE: REGdata NUMERIC "1"
-- Retrieval info: PRIVATE: REGq NUMERIC "1"
-- Retrieval info: PRIVATE: REGrdaddress NUMERIC "1"
-- Retrieval info: PRIVATE: REGrren NUMERIC "1"
-- Retrieval info: PRIVATE: REGwraddress NUMERIC "1"
-- Retrieval info: PRIVATE: REGwren NUMERIC "1"
-- Retrieval info: PRIVATE: SYNTH_WRAPPER_GEN_POSTFIX STRING "0"
-- Retrieval info: PRIVATE: USE_DIFF_CLKEN NUMERIC "0"
-- Retrieval info: PRIVATE: UseDPRAM NUMERIC "1"
-- Retrieval info: PRIVATE: VarWidth NUMERIC "0"
-- Retrieval info: PRIVATE: WIDTH_READ_A NUMERIC "8"
-- Retrieval info: PRIVATE: WIDTH_READ_B NUMERIC "8"
-- Retrieval info: PRIVATE: WIDTH_WRITE_A NUMERIC "8"
-- Retrieval info: PRIVATE: WIDTH_WRITE_B NUMERIC "8"
-- Retrieval info: PRIVATE: WRADDR_ACLR_B NUMERIC "0"
-- Retrieval info: PRIVATE: WRADDR_REG_B NUMERIC "0"
-- Retrieval info: PRIVATE: WRCTRL_ACLR_B NUMERIC "0"
-- Retrieval info: PRIVATE: enable NUMERIC "1"
-- Retrieval info: PRIVATE: rden NUMERIC "0"
-- Retrieval info: CONSTANT: ADDRESS_ACLR_B STRING "NONE"
-- Retrieval info: CONSTANT: ADDRESS_REG_B STRING "CLOCK0"
-- Retrieval info: CONSTANT: CLOCK_ENABLE_INPUT_A STRING "NORMAL"
-- Retrieval info: CONSTANT: CLOCK_ENABLE_INPUT_B STRING "NORMAL"
-- Retrieval info: CONSTANT: CLOCK_ENABLE_OUTPUT_B STRING "NORMAL"
-- Retrieval info: CONSTANT: INIT_FILE STRING "fft_3n1024sin.hex"
-- Retrieval info: CONSTANT: INTENDED_DEVICE_FAMILY STRING "Stratix IV"
-- Retrieval info: CONSTANT: LPM_TYPE STRING "altsyncram"
-- Retrieval info: CONSTANT: NUMWORDS_A NUMERIC "32"
-- Retrieval info: CONSTANT: NUMWORDS_B NUMERIC "32"
-- Retrieval info: CONSTANT: OPERATION_MODE STRING "DUAL_PORT"
-- Retrieval info: CONSTANT: OUTDATA_ACLR_B STRING "NONE"
-- Retrieval info: CONSTANT: OUTDATA_REG_B STRING "CLOCK0"
-- Retrieval info: CONSTANT: POWER_UP_UNINITIALIZED STRING "FALSE"
-- Retrieval info: CONSTANT: READ_DURING_WRITE_MODE_MIXED_PORTS STRING "DONT_CARE"
-- Retrieval info: CONSTANT: WIDTHAD_A NUMERIC "5"
-- Retrieval info: CONSTANT: WIDTHAD_B NUMERIC "5"
-- Retrieval info: CONSTANT: WIDTH_A NUMERIC "8"
-- Retrieval info: CONSTANT: WIDTH_B NUMERIC "8"
-- Retrieval info: CONSTANT: WIDTH_BYTEENA_A NUMERIC "1"
-- Retrieval info: USED_PORT: clock 0 0 0 0 INPUT VCC clock
-- Retrieval info: USED_PORT: data 0 0 8 0 INPUT NODEFVAL data[7..0]
-- Retrieval info: USED_PORT: enable 0 0 0 0 INPUT VCC enable
-- Retrieval info: USED_PORT: q 0 0 8 0 OUTPUT NODEFVAL q[7..0]
-- Retrieval info: USED_PORT: rdaddress 0 0 5 0 INPUT NODEFVAL rdaddress[4..0]
-- Retrieval info: USED_PORT: wraddress 0 0 5 0 INPUT NODEFVAL wraddress[4..0]
-- Retrieval info: USED_PORT: wren 0 0 0 0 INPUT GND wren
-- Retrieval info: CONNECT: @data_a 0 0 8 0 data 0 0 8 0
-- Retrieval info: CONNECT: @wren_a 0 0 0 0 wren 0 0 0 0
-- Retrieval info: CONNECT: q 0 0 8 0 @q_b 0 0 8 0
-- Retrieval info: CONNECT: @address_a 0 0 5 0 wraddress 0 0 5 0
-- Retrieval info: CONNECT: @address_b 0 0 5 0 rdaddress 0 0 5 0
-- Retrieval info: CONNECT: @clock0 0 0 0 0 clock 0 0 0 0
-- Retrieval info: CONNECT: @clocken0 0 0 0 0 enable 0 0 0 0
-- Retrieval info: LIBRARY: altera_mf altera_mf.altera_mf_components.all
-- Retrieval info: GEN_FILE: TYPE_NORMAL ip_stratixiv_ram_r_w.vhd TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ip_stratixiv_ram_r_w.inc FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ip_stratixiv_ram_r_w.cmp TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ip_stratixiv_ram_r_w.bsf FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ip_stratixiv_ram_r_w_inst.vhd FALSE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ip_stratixiv_ram_r_w_waveforms.html TRUE
-- Retrieval info: GEN_FILE: TYPE_NORMAL ip_stratixiv_ram_r_w_wave*.jpg FALSE
-- Retrieval info: LIB_FILE: altera_mf
