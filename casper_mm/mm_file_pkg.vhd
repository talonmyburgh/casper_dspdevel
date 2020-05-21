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

-- Author :
--   D. van der Schuur  May 2012  Original for Python - file IO - VHDL 
--   E. Kooistra        feb 2017  Added purpose and description
--                                Added procedures for external control in a
--                                pure VHDL test bench.
--
-- Purpose: Provide DUT access via MM bus through file IO per MM slave
-- Description:
--   This package provides file IO access to MM slaves and to the status of
--   the simulation:
--
-- 1) MM slave access
--   Access to MM slaves is provided by component mm_file.vhd that first calls
--   mmf_file_create() and loop forever calling mmf_mm_from_file(). Each MM
--   slave has a dedicated pair of request (.ctrl) and response (.stat) IO
--   files.
--   The mmf_file_create() creates the .ctrl file and mmf_mm_from_file() reads
--   it to check whether there is a WR or RD access request. For a WR request
--   the wr_data and wr_addr are read from the .ctrl and output on the MM bus
--   via mm_mosi. For a RD access request the rd_addr is read from the .ctrl
--   and output on the MM bus via mm_mosi. The after the read latency the
--   rd_data is written to the .stat file that is then created and closed.
--
--                    wr             rd  _________               __________
--   mmf_mm_bus_wr() ---> ctrl file --->|         |---mm_mosi-->|          |
--                                      | mm_file |             | MM slave |
--   mmf_mm_bus_rd() <--- stat file <---|___\_____|<--mm_miso---|__________|
--                    rd             wr      \
--                                            \--> loop: mmf_mm_from_file()
--
--   The ctrl file is created by mm_file at initialization and recreated by
--   every call of mmf_mm_from_file().
--   The stat file is recreated by every call of mmf_mm_bus_rd().
--
-- 2) Simulator access
--   External access to the simulation is provided via a .ctrl file that
--   supports GET_SIM_TIME and then report the NOW time via the .stat file.
--   The simulation access is provided via a procedure mmf_poll_sim_ctrl_file()
--   that works similar component mm_file.vhd.
--
--                      wr             rd
--                    |---> ctrl file --->|
--   mmf_sim_get_now()|                   |mmf_poll_sim_ctrl_file()
--                    |<--- stat file <---|  \
--                      rd             wr     \
--                                             \--> loop: mmf_sim_ctrl_from_file()
--
--   The ctrl file is created by mmf_poll_sim_ctrl_file at initialization and
--   recreated by every call of mmf_sim_ctrl_from_file().
--   The stat file is recreated by every call of mmf_sim_get_now().
--
-- A) External control by a Python script
--   A Python script can issue requests via the .ctrl files to control the
--   simulation and read the .stat files. This models the MM access via a
--   Monitoring and Control protocol via 1GbE.
--
--   Internal procedures:
--   . mmf_file_create(filename: IN STRING);
--   . mmf_mm_from_file(SIGNAL mm_clk  : IN STD_LOGIC; 
--   . mmf_sim_ctrl_from_file(rd_filename: IN STRING;
--   
--   External procedures (used in a VHDL design to provide access to the MM
--   slaves and simulation via file IO):
--   . mm_file.vhd --> instead of a procedure MM slave file IO uses a component
--   . mmf_poll_sim_ctrl_file()
--   
-- B) External control by a VHDL process --> see tb_mm_file.vhd
--   Instead of a Python script the file IO access to the MM slaves can also
--   be used in a pure VHDL testbench. This is useful when the MM slave bus
--   signals (mm_mosi, mm_miso) are not available on the entity of the DUT
--   (device under test), which is typically the case when a complete FPGA
--   design needs to be simulated.
--
--   Internal procedures:
--   . mmf_wait_for_file_status()
--   . mmf_wait_for_file_empty()
--   . mmf_wait_for_file_not_empty()
--                                      
--   External procedures (used in a VHDL test bench to provide access to the 
--   MM slaves in a DUT VHDL design and simulation via file IO):
--   . mmf_mm_bus_wr()
--   . mmf_mm_bus_rd()
--   . mmf_sim_get_now()
--
--   External function to create unique sim.ctrl/sim.stat filename per test bench in a multi tb
--   . mmf_slave_prefix()
--
-- Remarks:
-- . The timing of the MM access in mmf_mm_bus_wr() and mmf_mm_bus_rd() and the
--   simulation access in mmf_sim_get_now() is not critical. The timing of the first
--   access depends on the tb. Due to falling_edge(mm_clk) in mmf_wait_for_file_*()
--   all subsequent accesses will start at falling_edge(mm_clk)
  
LIBRARY IEEE, common_pkg_lib, casper_ram_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE common_pkg_lib.common_pkg.ALL;
USE common_pkg_lib.tb_common_pkg.ALL;
USE casper_ram_lib.common_ram_pkg.ALL;
USE work.tb_common_mem_pkg.ALL;
USE std.textio.ALL;
USE IEEE.std_logic_textio.ALL;
USE common_pkg_lib.common_str_pkg.ALL;

PACKAGE mm_file_pkg IS

  -- Constants used by mm_file.vhd
  CONSTANT c_mmf_mm_clk_period : TIME :=  100 ps;  -- Default mm_clk period in simulation. Set much faster than DP clock to speed up
                                                   -- simulation of MM access. Without file IO throttling 100 ps is a good balance
                                                   -- between simulation speed and file IO rate.
  CONSTANT c_mmf_mm_timeout    : TIME := 1000 ns;  -- Default MM file IO timeout period. Set large enough to account for MM-DP clock
                                                   -- domain crossing delays. Use 0 ns to disable file IO throttling, to have file IO
                                                   -- at the mm_clk rate.
  CONSTANT c_mmf_mm_pause      : TIME :=  100 ns;  -- Default MM file IO pause period after timeout. Balance between file IO rate
                                                   -- reduction and responsiveness to new MM access.
  
  -- Procedure to (re)create empty file
  PROCEDURE mmf_file_create(filename: IN STRING);

  -- Procedure to perform an MM access from file
  PROCEDURE mmf_mm_from_file(SIGNAL mm_clk  : IN STD_LOGIC; 
                             SIGNAL mm_rst  : IN STD_LOGIC; 
                             SIGNAL mm_mosi : OUT t_mem_mosi;
                             SIGNAL mm_miso : IN  t_mem_miso;
                             rd_filename: IN STRING;
                             wr_filename: IN STRING;
                             rd_latency: IN NATURAL);

  -- Procedure to process a simulation status request from the .ctrl file and provide response via the .stat file
  PROCEDURE mmf_sim_ctrl_from_file(rd_filename: IN STRING;
                                   wr_filename: IN STRING);

  -- Procedure to poll the simulation status
  PROCEDURE mmf_poll_sim_ctrl_file(rd_file_name: IN STRING; 
                                   wr_file_name: IN STRING);

  -- Procedure to poll the simulation status
  PROCEDURE mmf_poll_sim_ctrl_file(SIGNAL mm_clk  : IN STD_LOGIC;
                                   rd_file_name: IN STRING; 
                                   wr_file_name: IN STRING);

  -- Procedures that keep reading the file until it has been made empty or not empty by some other program,
  -- to ensure the file is ready for a new write access
  PROCEDURE mmf_wait_for_file_status(rd_filename   : IN STRING;  -- file name with extension
                                     exit_on_empty : IN BOOLEAN;
                                     SIGNAL mm_clk : IN STD_LOGIC);
                                    
  PROCEDURE mmf_wait_for_file_empty(rd_filename   : IN STRING;  -- file name with extension
                                    SIGNAL mm_clk : IN STD_LOGIC);
  PROCEDURE mmf_wait_for_file_not_empty(rd_filename   : IN STRING;  -- file name with extension
                                        SIGNAL mm_clk : IN STD_LOGIC);
                                        
  -- Procedure to issue a write access via the MM request .ctrl file  
  PROCEDURE mmf_mm_bus_wr(filename      : IN STRING;   -- file name without extension
                          wr_addr       : IN INTEGER;  -- use integer to support full 32 bit range
                          wr_data       : IN INTEGER;
                          SIGNAL mm_clk : IN STD_LOGIC);
                             
  -- Procedure to issue a read access via the MM request .ctrl file and get the read data from the MM response file
  PROCEDURE mmf_mm_bus_rd(filename       : IN STRING;   -- file name without extension
                          rd_latency     : IN NATURAL;
                          rd_addr        : IN INTEGER;  -- use integer to support full 32 bit range
                          SIGNAL rd_data : OUT STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0);
                          SIGNAL mm_clk  : IN STD_LOGIC);
  -- . rd_latency = 1
  PROCEDURE mmf_mm_bus_rd(filename       : IN STRING;
                          rd_addr        : IN INTEGER;
                          SIGNAL rd_data : OUT STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0);
                          SIGNAL mm_clk  : IN STD_LOGIC);

  -- Procedure that reads the rd_data every rd_interval until has the specified rd_value, the proc arguments can be understood as a sentence
  PROCEDURE mmf_mm_wait_until_value(filename         : IN STRING;   -- file name without extension
                                    rd_addr          : IN INTEGER;
                                    c_representation : IN STRING;  -- treat rd_data as "SIGNED" or "UNSIGNED" 32 bit word
                                    SIGNAL rd_data   : INOUT STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0);
                                    c_condition      : IN STRING;  -- ">", ">=", "=", "<=", "<", "/="
                                    c_rd_value       : IN INTEGER;
                                    c_rd_interval    : IN TIME;
                                    SIGNAL mm_clk    : IN STD_LOGIC);
                                       
  -- Procedure to get NOW via simulator status
  PROCEDURE mmf_sim_get_now(filename       : IN STRING;   -- file name without extension
                            SIGNAL rd_now  : OUT STRING;
                            SIGNAL mm_clk  : IN STD_LOGIC);

  -- Functions to create prefixes for the mmf file filename
  FUNCTION mmf_prefix(name : STRING; index : NATURAL) RETURN STRING;  -- generic prefix name with index to be used for a file IO filename
  FUNCTION mmf_tb_prefix(tb : INTEGER) RETURN STRING;                 -- fixed test bench prefix with index tb to allow file IO with multi tb
  FUNCTION mmf_subrack_prefix(subrack : INTEGER) RETURN STRING;       -- fixed subrack prefix with index subrack to allow file IO with multi subracks that use same unb numbers

  -- Functions to create mmf file prefix that is unique per slave, for increasing number of hierarchy levels:
  -- . return "filepath/s0_i0_"
  -- . return "filepath/s0_i0_s1_i1_"
  -- . return "filepath/s0_i0_s1_i1_s2_i2_"
  -- . return "filepath/s0_i0_s1_i1_s2_i2_s3_i3_"
  -- . return "filepath/s0_i0_s1_i1_s2_i2_s3_i3_s4_i4_"
  FUNCTION mmf_slave_prefix(dir_path, s0 : STRING; i0 : NATURAL) RETURN STRING;
  FUNCTION mmf_slave_prefix(dir_path, s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL) RETURN STRING;
  FUNCTION mmf_slave_prefix(dir_path, s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL; s2 : STRING; i2 : NATURAL) RETURN STRING;
  FUNCTION mmf_slave_prefix(dir_path, s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL; s2 : STRING; i2 : NATURAL; s3 : STRING; i3 : NATURAL) RETURN STRING;
  FUNCTION mmf_slave_prefix(dir_path, s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL; s2 : STRING; i2 : NATURAL; s3 : STRING; i3 : NATURAL; s4 : STRING; i4 : NATURAL) RETURN STRING;
  
  CONSTANT c_mmf_local_dir_path : STRING := "mmfiles/";   -- local directory in project file build directory
  FUNCTION mmf_slave_prefix(s0 : STRING; i0 : NATURAL) RETURN STRING;
  FUNCTION mmf_slave_prefix(s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL) RETURN STRING;
  FUNCTION mmf_slave_prefix(s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL; s2 : STRING; i2 : NATURAL) RETURN STRING;
  FUNCTION mmf_slave_prefix(s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL; s2 : STRING; i2 : NATURAL; s3 : STRING; i3 : NATURAL) RETURN STRING;
  FUNCTION mmf_slave_prefix(s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL; s2 : STRING; i2 : NATURAL; s3 : STRING; i3 : NATURAL; s4 : STRING; i4 : NATURAL) RETURN STRING;
  
  ----------------------------------------------------------------------------
  -- Declare mm_file component to support positional generic and port mapping of many instances in a TB
  ----------------------------------------------------------------------------
  COMPONENT mm_file
  GENERIC(
    g_file_prefix       : STRING;
    g_file_enable       : STD_LOGIC := '1';
    g_mm_rd_latency     : NATURAL := 2;
    g_mm_timeout        : TIME := c_mmf_mm_timeout;
    g_mm_pause          : TIME := c_mmf_mm_pause
  );
  PORT (
    mm_rst        : IN  STD_LOGIC;
    mm_clk        : IN  STD_LOGIC;
    mm_master_out : OUT t_mem_mosi;
    mm_master_in  : IN  t_mem_miso 
  );
  END COMPONENT;

END mm_file_pkg;

PACKAGE BODY mm_file_pkg IS

  PROCEDURE mmf_file_create(filename: IN STRING) IS
    FILE created_file : TEXT OPEN write_mode IS filename;
  BEGIN
    -- Write the file with nothing in it
    write(created_file, "");
  END;

  PROCEDURE mmf_mm_from_file(SIGNAL mm_clk : IN STD_LOGIC; 
                             SIGNAL mm_rst : IN STD_LOGIC; 
                             SIGNAL mm_mosi : OUT t_mem_mosi;
                             SIGNAL mm_miso : IN  t_mem_miso;
                             rd_filename: IN STRING;
                             wr_filename: IN STRING;
                             rd_latency: IN NATURAL) IS
    FILE rd_file : TEXT;
    FILE wr_file : TEXT;

    VARIABLE open_status_rd: file_open_status;
    VARIABLE open_status_wr: file_open_status;

    VARIABLE rd_line : LINE;
    VARIABLE wr_line : LINE;

    -- Note: Both the address and the data are interpreted as 32-bit data!
    -- This means one has to use leading zeros in the file when either is
    -- less than 8 hex characters, e.g.:
    -- (address) 0000000A
    -- (data)    DEADBEEF
    -- ...as a hex address 'A' would fit in only 4 bits, causing an error in hread().
    VARIABLE v_addr_slv : STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0);
    VARIABLE v_data_slv : STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0);

    VARIABLE v_rd_wr_str : STRING(1 TO 2); -- Contains 'RD' or 'WR'

  BEGIN

    proc_common_wait_until_low(mm_clk, mm_rst);

    -- We have to open the file explicitely so we can check the status
    file_open(open_status_rd, rd_file, rd_filename, read_mode);

    -- open_status may throw an error if the file is being written to by some other program
    IF open_status_rd=open_ok THEN

      IF NOT endfile(rd_file) THEN
        -- The file is not empty: process its contents
 
        -- Read a line from it, first line indicates RD or WR
        readline(rd_file, rd_line);
        read(rd_line, v_rd_wr_str); 
        
        -- The second line represents the address offset:
        readline(rd_file, rd_line);
        hread(rd_line, v_addr_slv);  -- read the string as HEX and assign to SLV.

        -- Write only: The third line contains the data to write:
        IF v_rd_wr_str="WR" THEN
          readline(rd_file, rd_line);
          hread(rd_line, v_data_slv);  -- read the string as HEX and assign to SLV.
        END IF;
        
        -- We're done reading MM request from the .ctrl file.
        -- Clear the .ctrl file by closing and recreating it, because we don't want to do the same
        -- MM request again the next time this procedure is called.
        file_close(rd_file); 
        mmf_file_create(rd_filename); 
        
        -- Execute the MM request to the MM slave
        IF v_rd_wr_str="WR" THEN
          print_str("[" & time_to_str(now) & "] " & rd_filename & ": Writing 0x" & slv_to_hex(v_data_slv) & " to address 0x" & slv_to_hex(v_addr_slv));
          -- Treat 32 bit hex data from file as 32 bit VHDL INTEGER, so need to use signed TO_SINT() to avoid out of NATURAL range
          -- warning in simulation due to '1' sign bit, because unsigned VHDL NATURAL only fits 31 bits
          proc_mem_mm_bus_wr(TO_UINT(v_addr_slv), TO_SINT(v_data_slv), mm_clk, mm_miso, mm_mosi);

        ELSIF v_rd_wr_str="RD" THEN
          proc_mem_mm_bus_rd(TO_UINT(v_addr_slv), mm_clk, mm_miso, mm_mosi);
          IF rd_latency>0 THEN
            proc_mem_mm_bus_rd_latency(rd_latency, mm_clk);
          END IF;
          v_data_slv := mm_miso.rddata(31 DOWNTO 0);
          print_str("[" & time_to_str(now) & "] " & rd_filename & ": Reading from address 0x" & slv_to_hex(v_addr_slv) & ": 0x" & slv_to_hex(v_data_slv));
      
          -- Write the RD response read data to the .stat file
          file_open(open_status_wr, wr_file, wr_filename, write_mode);
          hwrite(wr_line, v_data_slv);
          writeline(wr_file, wr_line);
          file_close(wr_file); 
        END IF;
 
      ELSE
        -- Nothing to process; wait one MM clock cycle.
        proc_common_wait_some_cycles(mm_clk, 1);
      END IF;

    ELSE
      REPORT "mmf_mm_from_file() could not open " & rd_filename & " at " & time_to_str(now) SEVERITY NOTE;
      -- Try again next time; wait one MM clock cycle.
      proc_common_wait_some_cycles(mm_clk, 1);
    END IF;

    -- The END implicitely close the rd_file, if still necessary.
  END;

  
  PROCEDURE mmf_sim_ctrl_from_file(rd_filename: IN STRING;
                                   wr_filename: IN STRING) IS

    FILE rd_file : TEXT;
    FILE wr_file : TEXT;

    VARIABLE open_status_rd: file_open_status;
    VARIABLE open_status_wr: file_open_status;

    VARIABLE rd_line : LINE;
    VARIABLE wr_line : LINE;

    VARIABLE v_rd_wr_str : STRING(1 TO 12); -- "GET_SIM_TIME"

  BEGIN

    -- We have to open the file explicitely so we can check the status
    file_open(open_status_rd, rd_file, rd_filename, read_mode);

    -- open_status may throw an error if the file is being written to by some other program
    IF open_status_rd=open_ok THEN

      IF NOT endfile(rd_file) THEN
        -- The file is not empty: process its contents
 
        -- Read a line from it, interpret the simulation request
        readline(rd_file, rd_line);
        read(rd_line, v_rd_wr_str);

        -- We're done reading this simulation request .ctrl file. Clear the file by closing and recreating it.
        file_close(rd_file); 
        mmf_file_create(rd_filename); 

        -- Execute the simulation request
        IF v_rd_wr_str="GET_SIM_TIME" THEN
          -- Write the GET_SIM_TIME response time NOW to the .stat file
          file_open(open_status_wr, wr_file, wr_filename, write_mode);
          write(wr_line, time_to_str(now));
          writeline(wr_file, wr_line);
          file_close(wr_file); 
        END IF;
 
      ELSE
        -- Nothing to process; wait in procedure mmf_poll_sim_ctrl_file
        NULL;
      END IF;

    ELSE
      REPORT "mmf_mm_from_file() could not open " & rd_filename & " at " & time_to_str(now) SEVERITY NOTE;
      -- Try again next time; wait in procedure mmf_poll_sim_ctrl_file
    END IF;

    -- The END implicitely close the rd_file, if still necessary.
  END;


  PROCEDURE mmf_poll_sim_ctrl_file(rd_file_name: IN STRING; wr_file_name : IN STRING) IS
  BEGIN
    -- Create the ctrl file that we're going to read from
    print_str("[" & time_to_str(now) & "] " & rd_file_name & ": Created" );
    mmf_file_create(rd_file_name);

    WHILE TRUE LOOP
      mmf_sim_ctrl_from_file(rd_file_name, wr_file_name);
      WAIT FOR 1 ns;
    END LOOP;

  END;


  PROCEDURE mmf_poll_sim_ctrl_file(SIGNAL mm_clk  : IN STD_LOGIC;
                                   rd_file_name: IN STRING; wr_file_name : IN STRING) IS
  BEGIN
    -- Create the ctrl file that we're going to read from
    print_str("[" & time_to_str(now) & "] " & rd_file_name & ": Created" );
    mmf_file_create(rd_file_name);

    WHILE TRUE LOOP
      mmf_sim_ctrl_from_file(rd_file_name, wr_file_name);
      proc_common_wait_some_cycles(mm_clk, 1);
    END LOOP;

  END;


  PROCEDURE mmf_wait_for_file_status(rd_filename   : IN STRING;  -- file name with extension
                                     exit_on_empty : IN BOOLEAN;
                                     SIGNAL mm_clk : IN STD_LOGIC) IS
    FILE     rd_file        : TEXT;
    VARIABLE open_status_rd : file_open_status;
    VARIABLE v_endfile      : BOOLEAN;
  BEGIN
    -- Check on falling_edge(mm_clk) because mmf_mm_from_file() operates on rising_edge(mm_clk)
    -- Note: In fact the file IO also works fine when rising_edge() is used, but then
    --       tb_tb_mm_file.vhd takes about 1% more mm_clk cycles
    WAIT UNTIL falling_edge(mm_clk);
    
    -- Keep reading the file until it has become empty by some other program
    WHILE TRUE LOOP
      -- Open the file in read mode to check whether it is empty
      file_open(open_status_rd, rd_file, rd_filename, read_mode);
      -- open_status may throw an error if the file is being written to by some other program
      IF open_status_rd=open_ok THEN
        v_endfile := endfile(rd_file);
        file_close(rd_file);
        IF exit_on_empty THEN
          IF v_endfile THEN
            -- The file is empty; continue
            EXIT;
          ELSE
            -- The file is not empty; wait one MM clock cycle.
            WAIT UNTIL falling_edge(mm_clk);
          END IF;
        ELSE
          IF v_endfile THEN
            -- The file is empty; wait one MM clock cycle.
            WAIT UNTIL falling_edge(mm_clk);
          ELSE
            -- The file is not empty; continue
            EXIT;
          END IF;
        END IF;
      ELSE
        REPORT "mmf_wait_for_file_status() could not open " & rd_filename & " at " & time_to_str(now) SEVERITY NOTE;
        WAIT UNTIL falling_edge(mm_clk);
      END IF;
    END LOOP;
    -- The END implicitely close the file, if still necessary.
  END;

  PROCEDURE mmf_wait_for_file_empty(rd_filename   : IN STRING;  -- file name with extension
                                    SIGNAL mm_clk : IN STD_LOGIC) IS
  BEGIN
    mmf_wait_for_file_status(rd_filename, TRUE, mm_clk);
  END;

  PROCEDURE mmf_wait_for_file_not_empty(rd_filename   : IN STRING;  -- file name with extension
                                        SIGNAL mm_clk : IN STD_LOGIC) IS
  BEGIN
    mmf_wait_for_file_status(rd_filename, FALSE, mm_clk);
  END;
    
  PROCEDURE mmf_mm_bus_wr(filename      : IN STRING;   -- file name without extension
                          wr_addr       : IN INTEGER;  -- use integer to support full 32 bit range
                          wr_data       : IN INTEGER;
                          SIGNAL mm_clk : IN STD_LOGIC) IS
    CONSTANT ctrl_filename  : STRING := filename & ".ctrl";
    FILE     ctrl_file      : TEXT;
    VARIABLE open_status_wr : file_open_status;
    VARIABLE wr_line        : LINE;

  BEGIN
    -- Write MM WR access to the .ctrl file.
    -- The MM device is ready for a new MM request, because any previous MM request has finished at
    -- mmf_mm_bus_wr() or mmf_mm_bus_rd() procedure exit, therefore just overwrite the .ctrl file.
    file_open(open_status_wr, ctrl_file, ctrl_filename, write_mode);
    -- open_status may throw an error if the file is being written to by some other program
    IF open_status_wr=open_ok THEN
      write(wr_line, STRING'("WR"));
      writeline(ctrl_file, wr_line);
      hwrite(wr_line, TO_SVEC(wr_addr, c_word_w));
      writeline(ctrl_file, wr_line);
      hwrite(wr_line, TO_SVEC(wr_data, c_word_w));
      writeline(ctrl_file, wr_line);
      file_close(ctrl_file); 
    ELSE
      REPORT "mmf_mm_bus_wr() could not open " & ctrl_filename & " at " & time_to_str(now) SEVERITY NOTE;
    END IF;

    -- Prepare for next MM request
    -- Keep reading the .ctrl file until it is empty, to ensure that the MM device is ready for a new MM request
    mmf_wait_for_file_empty(ctrl_filename, mm_clk);

    -- The END implicitely close the ctrl_file, if still necessary.
  END;
                          
  PROCEDURE mmf_mm_bus_rd(filename       : IN STRING;   -- file name without extension
                          rd_latency     : IN NATURAL;
                          rd_addr        : IN INTEGER;  -- use integer to support full 32 bit range
                          SIGNAL rd_data : OUT STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0);
                          SIGNAL mm_clk  : IN STD_LOGIC) IS
    CONSTANT ctrl_filename  : STRING := filename & ".ctrl";
    CONSTANT stat_filename  : STRING := filename & ".stat";
    FILE     ctrl_file      : TEXT;
    FILE     stat_file      : TEXT;
    VARIABLE open_status_wr : file_open_status;
    VARIABLE open_status_rd : file_open_status;
    VARIABLE wr_line        : LINE;
    VARIABLE rd_line        : LINE;
    VARIABLE v_rd_data      : STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0);

  BEGIN
    -- Clear the .stat file by recreating it, because we don't want to do read old file data again
    mmf_file_create(stat_filename); 

    -- Write MM RD access to the .ctrl file.
    -- The MM device is ready for a new MM request, because any previous MM request has finished at
    -- mmf_mm_bus_wr() or mmf_mm_bus_rd() procedure exit, therefore just overwrite the .ctrl file.
    file_open(open_status_wr, ctrl_file, ctrl_filename, write_mode);
    -- open_status may throw an error if the file is being written to by some other program
    IF open_status_wr=open_ok THEN
      write(wr_line, STRING'("RD"));
      writeline(ctrl_file, wr_line);
      hwrite(wr_line, TO_SVEC(rd_addr, c_word_w));
      writeline(ctrl_file, wr_line);
      file_close(ctrl_file);
    ELSE
      REPORT "mmf_mm_bus_rd() could not open " & ctrl_filename & " at " & time_to_str(now) SEVERITY FAILURE;
    END IF;
    
    -- Wait until the MM RD access has written the read data to the .stat file
    mmf_wait_for_file_not_empty(stat_filename, mm_clk);

    -- Read the MM RD access read data from the .stat file
    file_open(open_status_rd, stat_file, stat_filename, read_mode);
    -- open_status may throw an error if the file is being written to by some other program
    IF open_status_rd=open_ok THEN
      readline(stat_file, rd_line);
      hread(rd_line, v_rd_data);
      file_close(stat_file);
      rd_data <= v_rd_data;
      -- wait to ensure rd_data has got v_rd_data, otherwise rd_data still holds the old data on procedure exit
      -- the wait should be < mm_clk period/2 to not affect the read rate
      WAIT FOR 1 fs;
    ELSE
      REPORT "mmf_mm_bus_rd() could not open " & stat_filename & " at " & time_to_str(now) SEVERITY FAILURE;
    END IF;
    
    -- No need to prepare for next MM request, because:
    -- . the .ctrl file must already be empty because the .stat file was there
    -- . the .stat file will be cleared on this procedure entry
    
    -- The END implicitely closes the files, if still necessary
  END;

  -- rd_latency = 1
  PROCEDURE mmf_mm_bus_rd(filename       : IN STRING;
                          rd_addr        : IN INTEGER;
                          SIGNAL rd_data : OUT STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0);
                          SIGNAL mm_clk  : IN STD_LOGIC) IS
  BEGIN
    mmf_mm_bus_rd(filename, 1, rd_addr, rd_data, mm_clk);
  END;
  
  PROCEDURE mmf_mm_wait_until_value(filename         : IN STRING;   -- file name without extension
                                    rd_addr          : IN INTEGER;
                                    c_representation : IN STRING;  -- treat rd_data as "SIGNED" or "UNSIGNED" 32 bit word
                                    SIGNAL rd_data   : INOUT STD_LOGIC_VECTOR(c_word_w-1 DOWNTO 0);
                                    c_condition      : IN STRING;  -- ">", ">=", "=", "<=", "<", "/="
                                    c_rd_value       : IN INTEGER;
                                    c_rd_interval    : IN TIME;
                                    SIGNAL mm_clk    : IN STD_LOGIC) IS
  BEGIN
    WHILE TRUE LOOP
      -- Read current 
      mmf_mm_bus_rd(filename, rd_addr, rd_data, mm_clk);  -- only read low part
      IF c_representation="SIGNED" THEN
        IF    c_condition=">"  THEN IF TO_SINT(rd_data)> c_rd_value THEN EXIT; ELSE WAIT FOR c_rd_interval; END IF;
        ELSIF c_condition=">=" THEN IF TO_SINT(rd_data)>=c_rd_value THEN EXIT; ELSE WAIT FOR c_rd_interval; END IF;
        ELSIF c_condition="/=" THEN IF TO_SINT(rd_data)/=c_rd_value THEN EXIT; ELSE WAIT FOR c_rd_interval; END IF;
        ELSIF c_condition="<=" THEN IF TO_SINT(rd_data)<=c_rd_value THEN EXIT; ELSE WAIT FOR c_rd_interval; END IF;
        ELSIF c_condition="<"  THEN IF TO_SINT(rd_data)< c_rd_value THEN EXIT; ELSE WAIT FOR c_rd_interval; END IF;
        ELSE                        IF TO_SINT(rd_data) =c_rd_value THEN EXIT; ELSE WAIT FOR c_rd_interval; END IF;  -- default: "="
        END IF;
      ELSE  -- default: UNSIGED
        IF    c_condition=">"  THEN IF TO_UINT(rd_data)> c_rd_value THEN EXIT; ELSE WAIT FOR c_rd_interval; END IF;
        ELSIF c_condition=">=" THEN IF TO_UINT(rd_data)>=c_rd_value THEN EXIT; ELSE WAIT FOR c_rd_interval; END IF;
        ELSIF c_condition="/=" THEN IF TO_UINT(rd_data)/=c_rd_value THEN EXIT; ELSE WAIT FOR c_rd_interval; END IF;
        ELSIF c_condition="<=" THEN IF TO_UINT(rd_data)<=c_rd_value THEN EXIT; ELSE WAIT FOR c_rd_interval; END IF;
        ELSIF c_condition="<"  THEN IF TO_UINT(rd_data)< c_rd_value THEN EXIT; ELSE WAIT FOR c_rd_interval; END IF;
        ELSE                        IF TO_UINT(rd_data) =c_rd_value THEN EXIT; ELSE WAIT FOR c_rd_interval; END IF;  -- default: "="
        END IF;
      END IF;
    END LOOP;
  END mmf_mm_wait_until_value;
                          
                            
  PROCEDURE mmf_sim_get_now(filename       : IN STRING;   -- file name without extension
                            SIGNAL rd_now  : OUT STRING;
                            SIGNAL mm_clk  : IN STD_LOGIC) IS
    CONSTANT ctrl_filename  : STRING := filename & ".ctrl";
    CONSTANT stat_filename  : STRING := filename & ".stat";
    FILE     ctrl_file      : TEXT;
    FILE     stat_file      : TEXT;
    VARIABLE open_status_wr : file_open_status;
    VARIABLE open_status_rd : file_open_status;
    VARIABLE wr_line        : LINE;
    VARIABLE rd_line        : LINE;
    VARIABLE v_rd_now       : STRING(rd_now'RANGE);

  BEGIN
    -- Clear the sim.stat file by recreating it, because we don't want to do read old simulator status again
    mmf_file_create(stat_filename);
        
    -- Write GET_SIM_TIME to the sim.ctrl file
    -- The simulation is ready for a new simulation status request, because any previous simulation status request has finished at
    -- mmf_sim_get_now() procedure exit, therefore just overwrite the .ctrl file.
    file_open(open_status_wr, ctrl_file, ctrl_filename, write_mode);
    -- open_status may throw an error if the file is being written to by some other program
    IF open_status_wr=open_ok THEN
      write(wr_line, STRING'("GET_SIM_TIME"));
      writeline(ctrl_file, wr_line);
      file_close(ctrl_file);
    ELSE
      REPORT "mmf_sim_get_now() could not open " & ctrl_filename & " at " & time_to_str(now) SEVERITY FAILURE;
    END IF;
    
    -- Wait until the simulation has written the simulation status to the sim.stat file
    mmf_wait_for_file_not_empty(stat_filename, mm_clk);

    -- Read the GET_SIM_TIME simulation status from the .stat file
    file_open(open_status_rd, stat_file, stat_filename, read_mode);
    -- open_status may throw an error if the file is being written to by some other program
    IF open_status_rd=open_ok THEN
      readline(stat_file, rd_line);
      read(rd_line, v_rd_now);
      file_close(stat_file);
      rd_now <= v_rd_now;
      print_str("GET_SIM_TIME = " & v_rd_now & " at " & time_to_str(now));
    ELSE
      REPORT "mmf_sim_get_now() could not open " & stat_filename & " at " & time_to_str(now) SEVERITY FAILURE;
    END IF;
    
    -- No need to prepare for next simulation status request, because:
    -- . the .ctrl file must already be empty because the .stat file was there
    -- . the .stat file will be cleared on this procedure entry
    
    -- The END implicitely closes the files, if still necessary
  END;
  
  -- Functions to create prefixes for the mmf file filename
  FUNCTION mmf_prefix(name : STRING; index : NATURAL) RETURN STRING IS
  BEGIN
    RETURN name & "_" & int_to_str(index) & "_";
  END;
  
  FUNCTION mmf_tb_prefix(tb : INTEGER) RETURN STRING IS
  BEGIN
    RETURN mmf_prefix("TB", tb);
  END;
  
  FUNCTION mmf_subrack_prefix(subrack : INTEGER) RETURN STRING IS
  BEGIN
    RETURN mmf_prefix("SUBRACK", subrack);
  END;
  
  -- Functions to create mmf file prefix that is unique per slave, for increasing number of hierarchy levels:
  FUNCTION mmf_slave_prefix(dir_path, s0 : STRING; i0 : NATURAL) RETURN STRING IS
  BEGIN
    RETURN dir_path & mmf_prefix(s0, i0);
  END;

  FUNCTION mmf_slave_prefix(dir_path, s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL) RETURN STRING IS
  BEGIN
    RETURN dir_path & mmf_prefix(s0, i0) & mmf_prefix(s1, i1);
  END;

  FUNCTION mmf_slave_prefix(dir_path, s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL; s2 : STRING; i2 : NATURAL) RETURN STRING IS
  BEGIN
    RETURN dir_path & mmf_prefix(s0, i0) & mmf_prefix(s1, i1) & mmf_prefix(s2, i2);
  END;

  FUNCTION mmf_slave_prefix(dir_path, s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL; s2 : STRING; i2 : NATURAL; s3 : STRING; i3 : NATURAL) RETURN STRING IS
  BEGIN
    RETURN dir_path & mmf_prefix(s0, i0) & mmf_prefix(s1, i1) & mmf_prefix(s2, i2) & mmf_prefix(s3, i3);
  END;
  
  FUNCTION mmf_slave_prefix(dir_path, s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL; s2 : STRING; i2 : NATURAL; s3 : STRING; i3 : NATURAL; s4 : STRING; i4 : NATURAL) RETURN STRING IS
  BEGIN
    RETURN dir_path & mmf_prefix(s0, i0) & mmf_prefix(s1, i1) & mmf_prefix(s2, i2) & mmf_prefix(s3, i3) & mmf_prefix(s4, i4);
  END;

  -- Use local dir_path  
  FUNCTION mmf_slave_prefix(s0 : STRING; i0 : NATURAL) RETURN STRING IS
  BEGIN
    RETURN c_mmf_local_dir_path & mmf_prefix(s0, i0);
  END;

  FUNCTION mmf_slave_prefix(s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL) RETURN STRING IS
  BEGIN
    RETURN c_mmf_local_dir_path & mmf_prefix(s0, i0) & mmf_prefix(s1, i1);
  END;

  FUNCTION mmf_slave_prefix(s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL; s2 : STRING; i2 : NATURAL) RETURN STRING IS
  BEGIN
    RETURN c_mmf_local_dir_path & mmf_prefix(s0, i0) & mmf_prefix(s1, i1) & mmf_prefix(s2, i2);
  END;

  FUNCTION mmf_slave_prefix(s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL; s2 : STRING; i2 : NATURAL; s3 : STRING; i3 : NATURAL) RETURN STRING IS
  BEGIN
    RETURN c_mmf_local_dir_path & mmf_prefix(s0, i0) & mmf_prefix(s1, i1) & mmf_prefix(s2, i2) & mmf_prefix(s3, i3);
  END;
  
  FUNCTION mmf_slave_prefix(s0 : STRING; i0 : NATURAL; s1 : STRING; i1 : NATURAL; s2 : STRING; i2 : NATURAL; s3 : STRING; i3 : NATURAL; s4 : STRING; i4 : NATURAL) RETURN STRING IS
  BEGIN
    RETURN c_mmf_local_dir_path & mmf_prefix(s0, i0) & mmf_prefix(s1, i1) & mmf_prefix(s2, i2) & mmf_prefix(s3, i3) & mmf_prefix(s4, i4);
  END;

END mm_file_pkg;

