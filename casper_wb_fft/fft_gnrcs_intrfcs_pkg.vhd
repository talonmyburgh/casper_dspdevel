LIBRARY IEEE, common_pkg_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;

PACKAGE fft_gnrcs_intrfcs_pkg IS
--UPDATED BY MATLAB CODE GENERATION FOR SLV ARRAYS/INTERFACES:
CONSTANT c_fft_in_dat_w       : natural := 8;       -- = 8,  number of input bits
CONSTANT c_fft_out_dat_w      : natural := 16;      -- = 13, number of output bits
CONSTANT c_fft_stage_dat_w    : natural := 18;      -- = 18, data width used between the stages(= DSP multiplier-width)

--UPDATED THROUGH THE MATLAB CONFIG FOR FFT OPERATION:
CONSTANT c_fft_use_reorder          : boolean := false;     -- = false for bit-reversed output, true for normal output
CONSTANT c_fft_use_fft_shift        : boolean := false;     -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
CONSTANT c_fft_use_separate         : boolean := true;      -- = false for complex input, true for two real inputs
CONSTANT c_fft_wb_factor      		: natural := 1;   		-- = default 1, wideband factor",wb_factor);
CONSTANT c_fft_nof_points     		: natural := 1024;    	-- = 1024, N point FFT",nof_points);
CONSTANT c_fft_nof_chan             : natural := 0;       	-- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan 
CONSTANT c_fft_twiddle_dat_w  		: natural := 18;	    -- = 18, coefficient data width
CONSTANT c_max_addr_w				   : natural := 8;			-- = 10, address width above which to store coeffients in bram/ultra 
CONSTANT c_fft_out_gain_w           : natural := 0;       	-- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
CONSTANT c_fft_guard_w              : natural := 2;       	-- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. 
--   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section
--   12.3.2], therefore use input guard_w = 2.
CONSTANT c_fft_guard_enable   : boolean :=false;       -- = true when input needs guarding, false when input requires no guarding but scaling must be
--   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section
--   doing the input guard and par fft section doing the output compensation)
CONSTANT c_pipe_reo_in_place : boolean := false;

CONSTANT c_dp_stream_bsn_w      : NATURAL := 64;  		-- 64 is sufficient to count blocks of data for years
CONSTANT c_dp_stream_empty_w    : NATURAL := 16;  		--  8 is sufficient for max 256 symbols per data word, still use 16 bit to be able to count c_dp_stream_data_w in bits
CONSTANT c_dp_stream_channel_w  : NATURAL := 32;  		-- 32 is sufficient for several levels of hierarchy in mapping types of streams on to channels 
CONSTANT c_dp_stream_error_w    : NATURAL := 32;  		-- 32 is sufficient for several levels of hierarchy in mapping error numbers, e.g. 32 different one-hot encoded errors, bit [0] = 0 = OK 

type t_fft is record
use_reorder    : boolean;       -- = false for bit-reversed output, true for normal output
use_fft_shift  : boolean;       -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
use_separate   : boolean;       -- = false for complex input, true for two real inputs
nof_chan       : natural;       -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan 
wb_factor      : natural;       -- = default 1, wideband factor
nof_points     : natural;       -- = 1024, N point FFT
in_dat_w       : natural;       -- = 8,  number of input bits
out_dat_w      : natural;       -- = 13, number of output bits
out_gain_w     : natural;       -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
stage_dat_w    : natural;       -- = 18, data width used between the stages(= DSP multiplier-width)
twiddle_dat_w  : natural;		-- = 18, data width of the twiddle coefficients in the FFT
max_addr_w	   : natural;		-- = 10, address width above which to store coeffients in bram/ultra 
guard_w        : natural;       -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. 
--   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section
--   12.3.2], therefore use input guard_w = 2.
guard_enable        : boolean;       -- = true when input needs guarding, false when input requires no guarding but scaling must be
--   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section
--   doing the input guard and par fft section doing the output compensation)
stat_data_w         : positive;      -- = 56
stat_data_sz        : positive;      -- = 2
pipe_reo_in_place   : boolean;       -- = false for pipelined FFT reorder double buffer, true for single
end record;

constant c_fft : t_fft := (true, false, false, 0, c_fft_wb_factor, c_fft_nof_points, c_fft_in_dat_w, c_fft_out_dat_w, 0, c_dsp_mult_w, c_fft_twiddle_dat_w, 9, 2, true, 56, 2, false);

-- Check consistancy of the FFT parameters
function fft_r2_parameter_asserts(g_fft : t_fft) return boolean; -- the return value is void, because always true or abort due to failure

type t_fft_slv_arr_in IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_fft_in_dat_w-1 DOWNTO 0);
type t_fft_slv_arr_stg IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_fft_stage_dat_w-1 DOWNTO 0);
type t_fft_slv_arr_out IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(c_fft_out_dat_w-1 DOWNTO 0);

--t_dp_sosi record
TYPE t_fft_sosi_in IS RECORD  -- Source Out or Sink In
sync     : STD_LOGIC; 
bsn      : STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);      -- ctrl
re       : STD_LOGIC_VECTOR(c_fft_in_dat_w-1 DOWNTO 0);             -- data
im       : STD_LOGIC_VECTOR(c_fft_in_dat_w-1 DOWNTO 0);             -- data
valid    : STD_LOGIC;                                           -- ctrl
sop      : STD_LOGIC;                                           -- ctrl
eop      : STD_LOGIC;                                           -- ctrl
empty    : STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);    -- info at eop
channel  : STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);  -- info at sop
err      : STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);    -- info at eop (name field 'err' to avoid the 'error' keyword)
END RECORD;

CONSTANT c_fft_sosi_rst_in : t_fft_sosi_in := ('0', (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'), '0', '0', '0', (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'));

--t_dp_sosi record
TYPE t_fft_sosi_out IS RECORD  -- Source Out or Sink In
sync     : STD_LOGIC;   
bsn      : STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);      -- ctrl
re       : STD_LOGIC_VECTOR(c_fft_out_dat_w-1 DOWNTO 0);            -- data
im       : STD_LOGIC_VECTOR(c_fft_out_dat_w-1 DOWNTO 0);            -- data
valid    : STD_LOGIC;                                           -- ctrl
sop      : STD_LOGIC;                                           -- ctrl
eop      : STD_LOGIC;                                           -- ctrl
empty    : STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);    -- info at eop
channel  : STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);  -- info at sop
err      : STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);    -- info at eop (name field 'err' to avoid the 'error' keyword)
END RECORD;

CONSTANT c_fft_sosi_rst_out : t_fft_sosi_out := ('0', (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'), '0', '0', '0', (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'));

TYPE t_fft_sosi_arr_in IS ARRAY (INTEGER RANGE <>) OF t_fft_sosi_in;
TYPE t_fft_sosi_arr_out IS ARRAY (INTEGER RANGE <>) OF t_fft_sosi_out;

-- short hand to create an svec from integer of bit width in_dat_w
function to_fft_in_svec(n : integer) return std_logic_vector;
function to_fft_stg_svec(n : integer) return std_logic_vector;

-- FFT shift swaps right and left half of bin axis to shift zero-frequency component to center of spectrum
function fft_shift(bin : std_logic_vector) return std_logic_vector;
function fft_shift(bin, w : natural) return natural;

-- Calculate stage lengths for the pipelined and parallel FFT's separately.
function fft_shiftreglen_pipe(wb_factor, pts : natural) return natural;
function fft_shiftreglen_par(wb_factor,pts : natural) return natural;

END fft_gnrcs_intrfcs_pkg;

PACKAGE BODY fft_gnrcs_intrfcs_pkg is

function fft_r2_parameter_asserts(g_fft : t_fft) return boolean is
begin
-- nof_points
assert g_fft.nof_points = 2**true_log2(g_fft.nof_points) report "fft_r2: nof_points must be a power of 2" severity failure;
-- wb_factor
assert g_fft.wb_factor = 2**true_log2(g_fft.wb_factor) report "fft_r2: wb_factor must be a power of 2" severity failure;
-- use_reorder
if g_fft.use_reorder = false then
assert g_fft.use_separate = false report "fft_r2 : without use_reorder there cannot be use_separate for two real inputs" severity failure;
assert g_fft.use_fft_shift = false report "fft_r2 : without use_reorder there cannot be use_fft_shift for complex input" severity failure;
end if;
-- use_separate
if g_fft.use_separate = true then
assert g_fft.use_fft_shift = false report "fft_r2 : with use_separate there cannot be use_fft_shift for two real inputs" severity failure;
end if;
-- in_place
if g_fft.pipe_reo_in_place = true then
assert g_fft.nof_chan = 0 report "fft_r2 : can't use in place buffer with multiple channels in pipeline reorder" severity failure;
assert g_fft.use_fft_shift = false report "fft_r2 : can't use in place buffer and use_fft_shift in pipeline reorder" severity failure; 
end if;
return true;
end;

function to_fft_in_svec(n : integer) return std_logic_vector is
begin
	return RESIZE_SVEC(TO_SVEC(n, c_fft_in_dat_w), c_fft_in_dat_w);
end;

function to_fft_stg_svec(n : integer) return std_logic_vector is
begin
	return RESIZE_SVEC(TO_SVEC(n, c_fft_stage_dat_w), c_fft_stage_dat_w);
end;

function fft_shift(bin : std_logic_vector) return std_logic_vector is
constant c_w   : natural                            := bin'length;
variable v_bin : std_logic_vector(c_w - 1 downto 0) := bin;
begin
return not v_bin(c_w - 1) & v_bin(c_w - 2 downto 0); -- invert MSbit for fft_shift
end;

-- Calculate the length of the shiftregister and ovflw register for pipe fft
function fft_shift(bin, w : natural) return natural is
begin
return TO_UINT(fft_shift(TO_UVEC(bin, w)));
end;

-- Functions for stage length calculations for wideband FFT
function fft_shiftreglen_pipe(wb_factor,pts : natural) return natural is
	variable sr_len : natural;
begin
	if(wb_factor = 1) then
		sr_len := ceil_log2(pts);
	elsif(wb_factor>1 and wb_factor < pts) then
		sr_len := ceil_log2(pts/wb_factor);
	else
		sr_len := 0;
	end if;
	return sr_len;
end;

-- Calculate the length of the shiftregister and ovflw register for par fft
function fft_shiftreglen_par(wb_factor,pts :natural) return natural is
variable sr_len : natural;
begin
	if(wb_factor = pts) then
		sr_len := ceil_log2(pts);
	elsif(wb_factor>1 and wb_factor < pts) then
		sr_len := ceil_log2(wb_factor);
	else
		sr_len := 0;
	end if;
	return sr_len;
end;

END fft_gnrcs_intrfcs_pkg;
								