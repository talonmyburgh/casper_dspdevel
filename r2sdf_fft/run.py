from vunit import VUnit, VUnitCLI
from os.path import join, abspath, split
from vunit.sim_if.factory import SIMULATOR_FACTORY
from casper_r2sdf_fft import twiddle_gen,pfft,roundsat
from pathlib import Path
import numpy as np
# Create VUnit instance by parsing command line arguments

def make_twiddle_post_check(fftsize, g_twiddle_width,g_do_ifft,use_vhdl_magic_file):
    """
    Return a check function to verify test case output
    """

    def post_check(output_path):
        # generate the expected twiddles for this case
        # Note if you put a magic file into revision control for a twiddle size, it will then trust
        # that size is correct, if you change the twiddle generation you'll need to delete the old magic files!
        print(f"g_do_ifft = {g_do_ifft}")
        twiddles=(2**(g_twiddle_width-1))*twiddle_gen(fftsize,g_twiddle_width,1,1,g_do_ifft,use_vhdl_magic_file,Path(output_path))
        if g_do_ifft:
            output_file = Path(output_path) / f"twiddlepkg_twidth{g_twiddle_width}_ifftsize{fftsize}.txt"
        else:
            output_file = Path(output_path) / f"twiddlepkg_twidth{g_twiddle_width}_fftsize{fftsize}.txt"
        data = np.loadtxt(output_file,dtype="int")
        print("Post check: %s" % str(output_file))
        cdata = data[0:data.size:2]+1j*data[1:data.size:2]

        if np.array_equal(cdata,twiddles):
            print('Twiddles are exactly the same!')
            return True
        else:
            diffreal=np.abs(np.real(twiddles)-np.real(cdata))
            diffimag=np.abs(np.imag(twiddles)-np.imag(cdata))
            if np.max(diffreal)>1:
                print("Twiddle Real Values are more than 1 different!");
                return False
            if np.max(diffimag)>1:
                print("Twiddle Imag Values are more than 1 different!");
                return False               
            print("Twiddle Values were +/- 1 from expected!")
            # these line can help create the magic files if left uncommented but shouldn't be uncommented normally
            #import shutil
            #shutil.copy2(output_file,os.path.realpath(os.path.dirname(__file__)))
            return True

    return post_check
def tb_twiddle_package_setup(ui):
   
    testbench=ui.test_bench("tb_vu_twiddlepkg")
    for fftsizelog2 in range(1,16): # this was originally 1,21 and passed on March 24, 2023, but reduced to make execution faster
        for bidx in range(16,19): #this was originally 12,26, but to save time was converted to16:19
            fftsize=2**fftsizelog2
            testbench.add_config(
                name=f"TwiddlePythonFFT_w{bidx}b_{fftsize}",
                generics=dict(g_twiddle_width=bidx,g_fftsize_log2=fftsizelog2,g_do_ifft=False),
                post_check=make_twiddle_post_check(fftsize,bidx,False,0))
            testbench.add_config(
                name=f"TwiddlePythonIFFT_w{bidx}b_{fftsize}",
                generics=dict(g_twiddle_width=bidx,g_fftsize_log2=fftsizelog2,g_do_ifft=True),
                post_check=make_twiddle_post_check(fftsize,bidx,True,0))
            #testbench.add_config(
            #    name=f"TwiddleMagic_w{bidx}b_{fftsize}",
            #    generics=dict(g_twiddle_width=bidx,g_fftsize_log2=fftsizelog2),
            #    post_check=make_twiddle_post_check(fftsize,bidx,1))     


def make_fft_preconfig(g_fftsize_log2, g_in_dat_w,scale_sched,data):
    """
    Return a precheck function that will generate input data.
    """

    def pre_config(output_path):
        output_file = Path(output_path) / f"input_data.txt"
        f = open(output_file,'w')
        header = np.zeros(8,dtype=np.uint32)
        header[0] = 2**g_fftsize_log2
        header[1] = g_in_dat_w
        header[2] = data.size
        header[3] = scale_sched
        header[7] = 2122219905
        np.savetxt(f,header,fmt='%u')
        data_to_write = np.zeros(2*data.size,dtype=np.int32)
        data_to_write[0::2] = np.real(data)
        data_to_write[1::2] = np.imag(data)
        
        np.savetxt(f,data_to_write,fmt='%d')
        f.close()
        return True
    return pre_config

def make_fft_postcheck(g_use_reorder,g_in_dat_w,g_out_dat_w,g_stage_dat_w,g_guard_w,g_twiddle_width,g_fftsize_log2,g_do_rounding,g_do_saturation,scale_sched):
    """
    Return a precheck function that will generate input data.
    """
    
    def post_check(output_path):
        # Read the data created by the pre_config script
        input_file = Path(output_path) / f"input_data.txt"
        input_data = np.loadtxt(input_file,dtype="int")
        header = input_data    
        input_cdata = input_data[8:input_data.size:2]+1j*input_data[9:input_data.size:2]
        if header[0] != (2**g_fftsize_log2):
            print("Bad Header in input data")
            return False
        if header[1] != (g_in_dat_w):
            print("Input Data width mismatch")
            return False
        if header[2] != input_cdata.size:
            print("Input Data size mismatch")
            return False  
        if header[3] != scale_sched:
            print("Input Data Scale Mismatch")
            return False
        if header[7] != 2122219905:
            print("Input Data Magic Word Mismatch")
            return False
        
        # Read the stage data files (if they exist)
        #stage_data = np.zeros((input_cdata.size,g_fftsize_log2+1),dtype=np.complex128)
        #for stageidx in range(0,g_fftsize_log2+1):
            #stage_file = Path(output_path) / f"stage_data{stageidx}.txt"
            #data = np.loadtxt(stage_file,dtype="int32")
            #stage_cdata = data[0:data.size:2]+1j*data[1:data.size:2]
            #stage_data[:,stageidx] = stage_cdata
        

        output_file = Path(output_path) / f"output_data.txt"
        data = np.loadtxt(output_file,dtype="int32")
        print("Post check: %s" % str(output_file))
        vhdl_cdata = data[0:data.size:2]+1j*data[1:data.size:2]
        if input_cdata.shape != vhdl_cdata.shape:
            print("Fft Post check: Unexpected Data length")
            return False
        import shutil
        # Copy the download twiddle lookup tables into the script directory so they get used.
        #for twididx in range(0,g_fftsize_log2):
        #    twid_size = 2**twididx
        #    twid_file = Path(output_path) / f"twiddlepkg_twidth{g_twiddle_width}_fftsize{twid_size}.txt"
        #    shutil.copy2(twid_file,os.path.realpath(os.path.dirname(__file__)))

        # VHDL only support DIF, and is configured to do bitrev
        if g_use_reorder==True:
            do_output_bit_rev = 1
        else:
            do_output_bit_rev = 0
        g_bits_to_round_off = np.zeros(g_fftsize_log2)
        g_output_width = g_out_dat_w * np.ones(g_fftsize_log2)
        for bit_idx in range(0,g_fftsize_log2):
            bit = (scale_sched >> bit_idx) & 1
            if bit==1:
                g_bits_to_round_off[bit_idx]=1
            else:
                g_bits_to_round_off[bit_idx]=0
        
        expected_cdata,stagedebug=pfft(input_cdata,g_fftsize_log2,g_twiddle_width,g_do_rounding,g_do_saturation,g_output_width,g_bits_to_round_off,1,0,do_output_bit_rev,False,Path(output_path))

        file_path = Path(output_path) / f"matdata_debug.mat"
        matdict = {}
        matdict['expected_cdata'] = expected_cdata
        matdict['stagedebug'] = stagedebug
        matdict['vhdl_cdata'] = vhdl_cdata
        #matdict['stage_data'] = stage_data
        matdict['input_cdata'] = input_cdata
        #io.savemat(file_path, matdict)


        if np.array_equal(expected_cdata[:,0],vhdl_cdata):
            print("VHDL Matched Python!")
            print("Test Passed!")
            return True
        else:
            print("Data Did not match!")
            return False
        

    return post_check

def tb_vu_trwosdf_vfmodel_setup(ui):
   
    testbench=ui.test_bench("tb_vu_trwosdf_vfmodel")
    use_reorder = True
    in_dat_w = 18
    out_dat_w = 18
    stage_dat_w = 18
    guard_w = 0
    twiddle_width = 18
    fftsize_log2 = 13
    
    do_rounding = 1
    do_saturation = 1
    enable_pattern = 2 #every other clock
    # Decode some of those for VHDL
    if do_rounding==1:
        use_round = "ROUND"
        use_mult_round = "ROUND"
    if do_saturation==1:
        ovflw_behav = "SATURATE"

    scale_sched = 0
    for stage in range(0,fftsize_log2):
        if (stage % 2)==1:
            scale_sched = scale_sched + 2**stage
        # scale at Stage 0
        if stage==0:
            scale_sched = scale_sched + 2**stage
        if stage==2:
            scale_sched = scale_sched + 2**stage
    

    d_indices = np.arange(0,2*(2**fftsize_log2))
    # Generate a full scale cw with 12-bits
    data = 2047*np.exp(1.0j * 2*np.pi * d_indices*(-2e9/7e9))
    noise = np.random.normal(0, 5.5, size=(data.shape[0]))
    data = data + noise
    data = roundsat(data,1,in_dat_w,0,1,1,1)

    enable_pattern = 0
    testbench.add_config(
        pre_config=make_fft_preconfig(fftsize_log2,in_dat_w,scale_sched,data),
        post_check=make_fft_postcheck(use_reorder,in_dat_w,out_dat_w,stage_dat_w,guard_w,twiddle_width,fftsize_log2,do_rounding,do_saturation,scale_sched),
        name=f"FFTR2SDF_E0_s{fftsize_log2}_reorder{use_reorder}_din{in_dat_w}_dout{out_dat_w}_stagew{stage_dat_w}_guardw{guard_w}_doround{do_rounding}_dosaturation{do_saturation}_scale{scale_sched}",
        generics=dict(g_use_reorder=use_reorder,g_in_dat_w=in_dat_w,g_out_dat_w=out_dat_w,g_stage_dat_w=stage_dat_w,g_guard_w=guard_w,g_twiddle_width=twiddle_width,g_fftsize_log2=fftsize_log2,g_ovflw_behav=ovflw_behav,g_use_round=use_round,g_use_mult_round=use_mult_round,g_enable_pattern=enable_pattern))
    enable_pattern = 1
    testbench.add_config(
        pre_config=make_fft_preconfig(fftsize_log2,in_dat_w,scale_sched,data),
        post_check=make_fft_postcheck(use_reorder,in_dat_w,out_dat_w,stage_dat_w,guard_w,twiddle_width,fftsize_log2,do_rounding,do_saturation,scale_sched),
        name=f"FFTR2SDF_Erandom_s{fftsize_log2}_reorder{use_reorder}_din{in_dat_w}_dout{out_dat_w}_stagew{stage_dat_w}_guardw{guard_w}_doround{do_rounding}_dosaturation{do_saturation}_scale{scale_sched}",
        generics=dict(g_use_reorder=use_reorder,g_in_dat_w=in_dat_w,g_out_dat_w=out_dat_w,g_stage_dat_w=stage_dat_w,g_guard_w=guard_w,g_twiddle_width=twiddle_width,g_fftsize_log2=fftsize_log2,g_ovflw_behav=ovflw_behav,g_use_round=use_round,g_use_mult_round=use_mult_round,g_enable_pattern=enable_pattern))
    enable_pattern = 2
    testbench.add_config(
        pre_config=make_fft_preconfig(fftsize_log2,in_dat_w,scale_sched,data),
        post_check=make_fft_postcheck(use_reorder,in_dat_w,out_dat_w,stage_dat_w,guard_w,twiddle_width,fftsize_log2,do_rounding,do_saturation,scale_sched),
        name=f"FFTR2SDF_E10Clocks_s{fftsize_log2}_reorder{use_reorder}_din{in_dat_w}_dout{out_dat_w}_stagew{stage_dat_w}_guardw{guard_w}_doround{do_rounding}_dosaturation{do_saturation}_scale{scale_sched}",
        generics=dict(g_use_reorder=use_reorder,g_in_dat_w=in_dat_w,g_out_dat_w=out_dat_w,g_stage_dat_w=stage_dat_w,g_guard_w=guard_w,g_twiddle_width=twiddle_width,g_fftsize_log2=fftsize_log2,g_ovflw_behav=ovflw_behav,g_use_round=use_round,g_use_mult_round=use_mult_round,g_enable_pattern=enable_pattern))
    enable_pattern = 3
    testbench.add_config(
        pre_config=make_fft_preconfig(fftsize_log2,in_dat_w,scale_sched,data),
        post_check=make_fft_postcheck(use_reorder,in_dat_w,out_dat_w,stage_dat_w,guard_w,twiddle_width,fftsize_log2,do_rounding,do_saturation,scale_sched),
        name=f"FFTR2SDF_E100Clocks_s{fftsize_log2}_reorder{use_reorder}_din{in_dat_w}_dout{out_dat_w}_stagew{stage_dat_w}_guardw{guard_w}_doround{do_rounding}_dosaturation{do_saturation}_scale{scale_sched}",
        generics=dict(g_use_reorder=use_reorder,g_in_dat_w=in_dat_w,g_out_dat_w=out_dat_w,g_stage_dat_w=stage_dat_w,g_guard_w=guard_w,g_twiddle_width=twiddle_width,g_fftsize_log2=fftsize_log2,g_ovflw_behav=ovflw_behav,g_use_round=use_round,g_use_mult_round=use_mult_round,g_enable_pattern=enable_pattern))
        


            #    name=f"TwiddleMagic_w{bidx}b_{fftsize}",
            #    generics=dict(g_twiddle_width=bidx,g_fftsize_log2=fftsizelog2),
            #    post_check=make_twiddle_post_check(fftsize,bidx,1))     


cli = VUnitCLI()
cli.parser.add_argument('--twid',action = 'store_true',help = 'Run the Twiddle Tests')
cli.parser.add_argument('--bitaccurate',action = 'store_true',help = 'Run the bitaccurate Tests')
args = cli.parse_args()
vu = VUnit.from_args(args = args)
#vu = VUnit.from_argv(argv = args,)
vu.add_vhdl_builtins()
vu.add_random()

script_dir,_ = split(abspath(__file__))
# XPM Library compile
lib_xpm = vu.add_library("xpm")
lib_xpm.add_source_files(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_VCOMP.vhd"))
xpm_source_file_base = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_base.vhd"))
xpm_source_file_sdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_tdpram.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_dprom.vhd"))
xpm_source_file_tdpram = lib_xpm.add_source_file(join(script_dir, "../xilinx/xpm_vhdl/src/xpm/xpm_memory/hdl/xpm_memory_sprom.vhd"))
xpm_source_file_sdpram.add_dependency_on(xpm_source_file_base)
xpm_source_file_tdpram.add_dependency_on(xpm_source_file_base)

# Altera_mf library
lib_altera_mf = vu.add_library("altera_mf")
lib_altera_mf.add_source_file(join(script_dir, "../intel/altera_mf/altera_mf_components.vhd"))
altera_mf_source_file = lib_altera_mf.add_source_file(join(script_dir, "../intel/altera_mf/altera_mf.vhd"))

# XPM Multiplier library
ip_xpm_mult_lib = vu.add_library("ip_xpm_mult_lib", allow_duplicate=True)
ip_cmult_3dsp = ip_xpm_mult_lib.add_source_file(join(script_dir, "../ip_xpm/mult/ip_cmult_rtl_3dsp.vhd"))
ip_cmult_4dsp = ip_xpm_mult_lib.add_source_file(join(script_dir, "../ip_xpm/mult/ip_cmult_rtl_4dsp.vhd"))

# STRATIXIV Multiplier library
ip_stratixiv_mult_lib = vu.add_library("ip_stratixiv_mult_lib", allow_duplicate=True)
ip_stratixiv_complex_mult_rtl = ip_stratixiv_mult_lib.add_source_file(join(script_dir, "../ip_stratixiv/mult/ip_stratixiv_complex_mult_rtl.vhd"))
ip_stratixiv_complex_mult = ip_stratixiv_mult_lib.add_source_file(join(script_dir, "../ip_stratixiv/mult/ip_stratixiv_complex_mult.vhd"))
ip_stratixiv_complex_mult.add_dependency_on(altera_mf_source_file)

# XPM RAM library
ip_xpm_ram_lib = vu.add_library("ip_xpm_ram_lib")
ip_xpm_file_cr_cw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_ram_cr_cw.vhd"))
ip_xpm_file_cr_cw.add_dependency_on(xpm_source_file_sdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_ram_crw_crw.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_rom_r_r.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)
ip_xpm_file_crw_crw = ip_xpm_ram_lib.add_source_files(join(script_dir, "../ip_xpm/ram/ip_xpm_rom_r.vhd"))
ip_xpm_file_crw_crw.add_dependency_on(xpm_source_file_tdpram)

# STRATIXIV RAM Library
ip_stratixiv_ram_lib = vu.add_library("ip_stratixiv_ram_lib")
ip_stratix_file_cr_cw = ip_stratixiv_ram_lib.add_source_file(join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_cr_cw.vhd"))
ip_stratix_file_crw_crw = ip_stratixiv_ram_lib.add_source_file(join(script_dir, "../ip_stratixiv/ram/ip_stratixiv_ram_crw_crw.vhd"))
ip_stratix_file_cr_cw.add_dependency_on(altera_mf_source_file)
ip_stratix_file_crw_crw.add_dependency_on(altera_mf_source_file)

# COMMON COMPONENTS Library 
common_components_lib = vu.add_library("common_components_lib")
common_components_lib.add_source_files(join(script_dir, "../common_components/common_pipeline.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_bit_delay.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_pipeline_sl.vhd"))
common_components_lib.add_source_files(join(script_dir, "../common_components/common_delay.vhd"))

# COMMON PACKAGE Library
common_pkg_lib = vu.add_library("common_pkg_lib")
# the latest version (4.0.0) of GHDL doesn't like the hacked up vhdl 93 fixed library so we'll use the real one but compile if for common_pkg
# Questa simulator will still use the hacked up one so we have some verification it works as expected since the hacked one is uses in Vivado sim and synth
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_float_types_c.vhd"))
if SIMULATOR_FACTORY.select_simulator().name == "ghdl":
   #common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_float_types_c_2008redirect.vhdl"))
    #common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_generic_pkg-body_2008redirect.vhdl"))
    common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_generic_pkg_2008redirect.vhdl"))
    #common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/float_generic_pkg-body_2008redirect.vhdl"))
    common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/float_generic_pkg_2008redirect.vhdl"))
    common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/float_pkg_c_2008redirect.vhdl"))
    common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_pkg_c_2008redirect.vhdl"))
else:
    # use the "hacked" up VHDL93 version in other simulators 
    common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/fixed_pkg_c.vhd"))
    common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/float_pkg_c.vhd"))    
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_str_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/tb_common_pkg.vhd"))
common_pkg_lib.add_source_files(join(script_dir, "../common_pkg/common_lfsr_sequences_pkg.vhd"))

# TECHNOLOGY Library
technology_lib = vu.add_library("technology_lib")
technology_lib.add_source_files(join(script_dir, "../technology/technology_select_pkg.vhd"))

# COMMON COUNTER Library
casper_counter_lib = vu.add_library("casper_counter_lib")
casper_counter_lib.add_source_file(join(script_dir, "../casper_counter/common_counter.vhd"))

# CASPER MUlTIPLIER Library
casper_multiplier_lib = vu.add_library("casper_multiplier_lib")
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_mult_component.vhd"))
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_agilex_versal_cmult.vhd"))
tech_complex_mult = casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/tech_complex_mult.vhd"))
casper_multiplier_lib.add_source_file(join(script_dir, "../casper_multiplier/common_complex_mult.vhd"))
tech_complex_mult.add_dependency_on(ip_cmult_3dsp)
tech_complex_mult.add_dependency_on(ip_cmult_4dsp)
tech_complex_mult.add_dependency_on(ip_stratixiv_complex_mult)
tech_complex_mult.add_dependency_on(ip_stratixiv_complex_mult_rtl)

# CASPER REQUANTIZE Library
casper_requantize_lib = vu.add_library("casper_requantize_lib")
casper_requantize_lib.add_source_file(join(script_dir, "../casper_requantize/common_round.vhd"))
casper_requantize_lib.add_source_file(join(script_dir, "../casper_requantize/common_resize.vhd"))
casper_requantize_lib.add_source_file(join(script_dir, "../casper_requantize/common_requantize.vhd"))
casper_requantize_lib.add_source_file(join(script_dir, "../casper_requantize/r_shift_requantize.vhd"))

# CASPER RAM Library
casper_ram_lib = vu.add_library("casper_ram_lib")
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_pkg.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_component_pkg.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_ram_cr_cw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_rom_r_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/tech_memory_rom_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_crw_crw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_rom_r_r.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_r_w.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_rw_rw.vhd"))
casper_ram_lib.add_source_file(join(script_dir, "../casper_ram/common_paged_ram_crw_crw.vhd"))

# RTWOSDF Library
# Pathline for twid coefficients
twid_path_stem = script_dir + '/data/twids/sdf_twiddle_coeffs'
print(twid_path_stem)

r2sdf_fft_lib = vu.add_library("r2sdf_fft_lib")
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoBF.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoBFStage.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoOrder.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"twiddlesPkg.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoSDFPkg.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoWeights.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoWMul.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoSDFStage.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"rTwoSDF.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"tb_rTwoSDF.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"tb_rTwoOrder.vhd"))
r2sdf_fft_lib.add_source_file(join(script_dir,"tb_tb_vu_rTwoSDF.vhd"))


# Setup the Twiddle Testbench by calling it's python function
if args.twid:
    r2sdf_fft_lib.add_source_file(join(script_dir,"tb_vu_twiddlepkg.vhd"))
    #from r2sdf_fft_py import tb_twiddle_package_setup
    tb_twiddle_package_setup(r2sdf_fft_lib)
if args.bitaccurate:
    r2sdf_fft_lib.add_source_file(join(script_dir,"tb_vu_rtwosdf_vfmodel.vhd"))
    #from r2sdf_fft_py import tb_vu_trwosdf_vfmodel_setup
    tb_vu_trwosdf_vfmodel_setup(r2sdf_fft_lib)

TB_GENERATED = r2sdf_fft_lib.test_bench("tb_tb_vu_rTwoSDF")
TB_GENERATED.add_config(
    name = "u_act_impulse_16p_16i_16o",
    generics=dict(g_use_uniNoise_file = False,g_in_en = 1,g_use_reorder = True,g_nof_points = 16,g_in_dat_w = 16,g_out_dat_w = 16,g_guard_w = 2,g_diff_margin = 1, g_twid_file_stem = twid_path_stem, g_file_loc_prefix = script_dir + "/"))
TB_GENERATED.add_config(
    name = "u_act_noise_1024p_8i_14o",
    generics=dict(g_use_uniNoise_file = True,g_in_en = 1,g_use_reorder = True,g_nof_points = 1024,g_in_dat_w = 8,g_out_dat_w = 14,g_guard_w = 2,g_diff_margin = 1, g_twid_file_stem = twid_path_stem, g_file_loc_prefix = script_dir + "/"))
TB_GENERATED.add_config(
    name = "u_rnd_noise_1024p_8i_14o",
    generics=dict(g_use_uniNoise_file = True,g_in_en = 0,g_use_reorder = True,g_nof_points = 1024,g_in_dat_w = 8,g_out_dat_w = 14,g_guard_w = 2,g_diff_margin = 1, g_twid_file_stem = twid_path_stem, g_file_loc_prefix = script_dir + "/"))
TB_GENERATED.add_config(
    name = "u_rnd_noise_1024p_8i_14o_flipped",
    generics=dict(g_use_uniNoise_file = True,g_in_en = 0,g_use_reorder = False,g_nof_points = 1024,g_in_dat_w = 8,g_out_dat_w = 14,g_guard_w = 2,g_diff_margin = 1, g_twid_file_stem = twid_path_stem, g_file_loc_prefix = script_dir + "/"))

# Run vunit function
vu.set_compile_option("ghdl.a_flags", ["-frelaxed","-fsynopsys","-fexplicit","-Wno-hide"])
#vu.set_sim_option("ghdl.elab_e", True)
vu.set_sim_option("ghdl.elab_flags", ["-frelaxed","-fsynopsys","-fexplicit","--syn-binding"])
vu.set_sim_option("ghdl.sim_flags",["--max-stack-alloc=4096"])
# Don't optimize in Modelsim/Questa GUI mode
vu.set_sim_option("modelsim.vsim_flags.gui",["-voptargs=+acc"])
vu.main()
