LIBRARY IEEE, common_pkg_lib;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.numeric_std.ALL;
USE common_pkg_lib.common_pkg.ALL;

PACKAGE fft_gnrcs_intrfcs_pkg Is
--UPDATED BY MATLAB CODE GENERATION FOR SLV ARRAYS/INTERFACES:
CONSTANT wb_factor      : natural :=1;       -- = default 1, wideband factor
CONSTANT in_dat_w       : natural :=8;       -- = 8,  number of input bits
CONSTANT out_dat_w      : natural :=13;       -- = 13, number of output bits
CONSTANT stage_dat_w    : natural :=16;       -- = 18, data width used between the stages(= DSP multiplier-width)
CONSTANT nof_points     : natural := 1024;       -- = 1024, N point FFT

--UPDATED THROUGH THE MATLAB CONFIG FOR FFT OPERATION:
CONSTANT c_dp_stream_bsn_w      : NATURAL :=  64;  -- 64 is sufficient to count blocks of data for years
CONSTANT c_dp_stream_empty_w    : NATURAL :=  16;  --  8 is sufficient for max 256 symbols per data word, still use 16 bit to be able to count c_dp_stream_data_w in bits
CONSTANT c_dp_stream_channel_w  : NATURAL :=  32;  -- 32 is sufficient for several levels of hierarchy in mapping types of streams on to channels 
CONSTANT c_dp_stream_error_w    : NATURAL :=  32;  -- 32 is sufficient for several levels of hierarchy in mapping error numbers, e.g. 32 different one-hot encoded errors, bit [0] = 0 = OK 
CONSTANT use_reorder    : boolean := false;       -- = false for bit-reversed output, true for normal output
CONSTANT use_fft_shift  : boolean := false;       -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
CONSTANT use_separate   : boolean := true;       -- = false for complex input, true for two real inputs
CONSTANT nof_chan       : natural := 0;       -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan 
CONSTANT twiddle_offset : natural := 0;       -- = default 0, twiddle offset for PFT sections in a wideband FFT
CONSTANT out_gain_w     : natural :=0;       -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
CONSTANT guard_w        : natural :=2;       -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. 
--   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section
--   12.3.2], therefore use input guard_w = 2.
CONSTANT guard_enable   : boolean :=true;       -- = true when input needs guarding, false when input requires no guarding but scaling must be
--   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section
--   doing the input guard and par fft section doing the output compensation)

type t_fft is record
use_reorder    : boolean;       -- = false for bit-reversed output, true for normal output
use_fft_shift  : boolean;       -- = false for [0, pos, neg] bin frequencies order, true for [neg, 0, pos] bin frequencies order in case of complex input
use_separate   : boolean;       -- = false for complex input, true for two real inputs
nof_chan       : natural;       -- = default 0, defines the number of channels (=time-multiplexed input signals): nof channels = 2**nof_chan 
wb_factor      : natural;       -- = default 1, wideband factor
twiddle_offset : natural;       -- = default 0, twiddle offset for PFT sections in a wideband FFT
nof_points     : natural;       -- = 1024, N point FFT
in_dat_w       : natural;       -- = 8,  number of input bits
out_dat_w      : natural;       -- = 13, number of output bits
out_gain_w     : natural;       -- = 0, output gain factor applied after the last stage output, before requantization to out_dat_w
stage_dat_w    : natural;       -- = 18, data width used between the stages(= DSP multiplier-width)
guard_w        : natural;       -- = 2, guard used to avoid overflow in first FFT stage, compensated in last guard_w nof FFT stages. 
--   on average the gain per stage is 2 so guard_w = 1, but the gain can be 1+sqrt(2) [Lyons section
--   12.3.2], therefore use input guard_w = 2.
guard_enable   : boolean;       -- = true when input needs guarding, false when input requires no guarding but scaling must be
--   skipped at the last stage(s) compensate for input guard (used in wb fft with pipe fft section
--   doing the input guard and par fft section doing the output compensation)
stat_data_w    : positive;      -- = 56
stat_data_sz   : positive;      -- = 2
end record;

constant c_fft : t_fft := (true, false, false, 0, 4, 0, 1024, 8, 14, 0, c_dsp_mult_w, 2, true, 56, 2);

type t_fft_slv_arr_in IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);
type t_fft_slv_arr_stg IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(stage_dat_w-1 DOWNTO 0);
type t_fft_slv_arr_out IS ARRAY (INTEGER RANGE <>) OF STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0);

-- barebones t_dp_sosi record
TYPE t_bb_sosi_in IS RECORD  -- Source Out or Sink In
sync     : STD_LOGIC; 
bsn      : STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);                                          -- ctrl
re       : STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);               -- data
im       : STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);               -- data
valid    : STD_LOGIC;                                           -- ctrl
sop      : STD_LOGIC;                                           -- ctrl
eop      : STD_LOGIC;                                           -- ctrl
empty    : STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);    -- info at eop
channel  : STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);  -- info at sop
err      : STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);    -- info at eop (name field 'err' to avoid the 'error' keyword)
END RECORD;

CONSTANT c_bb_sosi_rst_in : t_bb_sosi_in := ('0', (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'), '0', '0', '0', (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'));

-- barebones t_dp_sosi record
TYPE t_bb_sosi_out IS RECORD  -- Source Out or Sink In
sync     : STD_LOGIC;   
bsn      : STD_LOGIC_VECTOR(c_dp_stream_bsn_w-1 DOWNTO 0);                                        -- ctrl
re       : STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0);              -- data
im       : STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0);              -- data
valid    : STD_LOGIC;                                           -- ctrl
sop      : STD_LOGIC;                                           -- ctrl
eop      : STD_LOGIC;                                           -- ctrl
empty    : STD_LOGIC_VECTOR(c_dp_stream_empty_w-1 DOWNTO 0);    -- info at eop
channel  : STD_LOGIC_VECTOR(c_dp_stream_channel_w-1 DOWNTO 0);  -- info at sop
err      : STD_LOGIC_VECTOR(c_dp_stream_error_w-1 DOWNTO 0);    -- info at eop (name field 'err' to avoid the 'error' keyword)
END RECORD;

CONSTANT c_bb_sosi_rst_out : t_bb_sosi_out := ('0', (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'), '0', '0', '0', (OTHERS=>'0'), (OTHERS=>'0'), (OTHERS=>'0'));

TYPE t_bb_sosi_arr_in IS ARRAY (INTEGER RANGE <>) OF t_bb_sosi_in;
TYPE t_bb_sosi_arr_out IS ARRAY (INTEGER RANGE <>) OF t_bb_sosi_out;

-- FFT shift swaps right and left half of bin axis to shift zero-frequency component to center of spectrum
function fft_shift(bin : std_logic_vector) return std_logic_vector;
function fft_shift(bin, w : natural) return natural;
function fft_shiftreglen_pipe(wb_factor, pts : natural) return natural;
function fft_shiftreglen_par(wb_factor,pts : natural) return natural;

-- Calculate the shiftregister and ovflw register sizes for both FFT's.
CONSTANT c_stages      : NATURAL := ceil_log2(nof_points);
CONSTANT c_stages_pipe : NATURAL := fft_shiftreglen_pipe(wb_factor,nof_points);
CONSTANT c_stages_par  : NATURAL := fft_shiftreglen_par(wb_factor,nof_points);
END fft_gnrcs_intrfcs_pkg;

PACKAGE BODY fft_gnrcs_intrfcs_pkg is

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

function fft_shiftreglen_pipe(wb_factor,pts : natural) return natural is
    begin
    return ceil_log2(nof_points/wb_factor);
end;

-- Calculate the length of the shiftregister and ovflw register for par fft
function fft_shiftreglen_par(wb_factor,pts :natural) return natural is
    variable sr_len : integer;
    begin
        if(wb_factor = pts) then
            sr_len := ceil_log2(nof_points);
        elsif(wb_factor>1 and wb_factor < pts) then
            sr_len := ceil_log2(wb_factor);
        end if;
    return sr_len;
end;


END fft_gnrcs_intrfcs_pkg;
