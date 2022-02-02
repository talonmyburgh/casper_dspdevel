"""
This script is designed to generate one memory file per stage of the pipelined fft. The file stem is returned and the HDL will use the parameters g_stage,
g_stage_offset and g_twiddle_offset to uniquely initialise each stages coefficients. The file stem returned should be placed in the rTwoSDFPkg for constant
c_twid_file_stem. 
"""
import sys
import getopt
import os
import numpy as np

def run(argv):
    # Arguments
    class sdf:
        outdestfolder = ''
        outfileprefix = ''
        filename = ''
        nof_points = 0
        nof_stages = 0
        wb_factor = 0
        coef_w = 0
        ext = ''
        # fixed use False to create mif files for fil_ppf_wide.vhd and for apertif_unb1_bn_filterbank
        verbose = False
        gen_files = True
    
    usage_str = 'USAGE: sdf_fft_twid_create.py -o <output path> -g <gen files> -p <nof points> -w <wb factor> -c <coef width> -v <vendor - 0 Xil, 1 Alt> -V <verbos>\n'

    try:
        opts, _ = getopt.getopt(sys.argv[1:], 'ho:g:p:w:c:v:V:')
    except getopt.GetoptError:
        print(usage_str)
        sys.exit(2)
    
    for opt, arg in opts:
        if opt == '-h':
            print(usage_str)
            sys.exit()
        elif opt == '-o':
            if arg =='':
                sdf.outdestfolder = os.path.abspath(os.path.dirname(os.path.realpath(__file__)))
            else:
                sdf.outdestfolder = os.path.abspath(os.path.join(os.getcwd(),arg))
        elif opt == '-g':
            sdf.gen_files = bool(int(arg))
        elif opt == '-p':
            sdf.nof_points = int(arg)
            sdf.nof_stages = np.log2(int(arg)).astype(np.int32)
        elif opt == '-w':
            sdf.wb_factor = int(arg)
        elif opt == '-c':
            sdf.coef_w = int(arg)
        elif opt == '-v':
            if arg == '0':
                sdf.ext = 'mem'
            elif arg == '1':
                sdf.ext = 'mif'
            else:
                print('Invalid vendor provided, defaulting to Xilinx.')
        elif opt == '-V':
            sdf.verbose = bool(int(arg))

    # Generate name of output twids files if output files are required:
    if sdf.gen_files:
        directoryname = './twids'
        pathforstore = os.path.abspath(os.path.join(sdf.outdestfolder, directoryname))
        if not os.path.exists(pathforstore):
            os.mkdir(pathforstore)
            if sdf.verbose:
                print("Directory ", pathforstore, " created!")
        else:
            if sdf.verbose:
                print("Directory ", pathforstore, " already exists!")

    # Create base file name for the memory files.
        if sdf.verbose:
            sdf.outfileprefix = os.path.join(pathforstore, "sdf_twiddle_coeffs_%dp_%db" % (
                sdf.nof_points, sdf.coef_w))

    """ Takes in details regarding the sdf FFT. Furthermore it takes which stage and which wb
        instance it is. This will dictate the unique coefficients required for that rom.
        Assumes stage in range 0 -> log2(fft size) -1
        Assumes wb_instance in range 0 -> wideband factor - 1
        Returns complex values
    """
    def gen_twiddles(sdf, stage, wb_instance):
        coeff_indices = np.arange(wb_instance%2**stage, 2**stage, sdf.wb_factor)
        coeffs = np.exp(-1.0j * np.pi * coeff_indices / 2**stage)
        print("\nCoefs: ",coeffs,"\nCoeff indices: ",coeff_indices, "\nStage: ",stage, "\nWB instance: ", wb_instance, "\nWB Factor: ", sdf.wb_factor)
        return coeffs

    """ Here we write to mem files the required coefficients per wb_instance per stage
    """
    def writemem(sdf):
        if not sdf.gen_files:
            ret_twids = []
        for p in range(sdf.nof_stages):
            twids_tmp = []
            for w in range(sdf.wb_factor):
                #Logic to scale up the coefficients to integer values for later hex conversion
                s = gen_twiddles(sdf,p,w)
                #What is returned is complex, so split it into real and image.
                s_re = (np.real(s)*(2**(sdf.coef_w-1))).astype(int)
                s_im = (np.imag(s)*(2**(sdf.coef_w-1))).astype(int)
                twids_re = s_re & (2**sdf.coef_w-1)
                twids_im = s_im & (2**sdf.coef_w-1)
                if sdf.gen_files:
                    t_outfilename = sdf.outfileprefix + ("_%dwb_" % (w)) +("%dstg" % (p)) + ".mem" 
                    with open(t_outfilename,'w+') as fp:
                        for i in range(twids_re.size):
                            #Write the real coefficient line
                            s = ('%%0%dx\n' % np.ceil(sdf.coef_w/4)) % (twids_re[i])
                            fp.write(s)
                            #Write the imaginary coefficient line
                            s = ('%%0%dx\n' % np.ceil(sdf.coef_w/4)) % (twids_im[i])
                            fp.write(s)
                else:
                    for i in range(twids_re.size):
                        s = ('%%0%dx\n' % np.ceil(sdf.coef_w/4)) % (twids_re[i])
                        twids_tmp.append(s)
                        s = ('%%0%dx\n' % np.ceil(sdf.coef_w/4)) % (twids_im[i])
                        twids_tmp.append(s)
                    ret_twids.append(",".join(twids_tmp))
                
        if not sdf.gen_files:
            return ret_twids
    
    """ Here we write to mif files the required coefficients for wb_instance and stage
    """
    def writemif(sdf):
        if not sdf.gen_files:
            twids = []
        for p in range(sdf.nof_stages):
            twids_tmp = []
            for w in range(sdf.wb_factor):
                 #Logic to scale up the coefficients to integer values for later hex conversion
                s = gen_twiddles(sdf,p,w)
                s_re = (np.real(s)*(2**(sdf.coef_w-1))).astype(int)
                s_im = (np.imag(s)*(2**(sdf.coef_w-1))).astype(int)
                s_re = s_re & (2**sdf.coef_w-1)
                s_im = s_im & (2**sdf.coef_w-1)
                twids_re = s_re
                twids_im = s_im
                if sdf.gen_files:
                    t_outfilename = sdf.outfileprefix + ("_%dwb_" % (w)) + ("_stg_%d" % (p)) + ".mif"
                    with open(t_outfilename,'w+') as fp:
                        s = 'WIDTH=%d;\n' % sdf.coef_w
                        fp.write(s)
                        s = 'DEPTH=%d;\n' % sdf.twids.size
                        fp.write(s)
                        s = 'ADDRESS_RADIX=HEX;\n'
                        fp.write(s)
                        s = 'DATA_RADIX=HEX;\n'
                        fp.write(s)
                        s = 'CONTENT BEGIN\n'
                        fp.write(s)

                        for i in range(twids_re.size):
                            #Write the real coefficient line
                            s = '%x   :  %x ; \n' % (i, twids_re[i])
                            fp.write(s)
                            #Write the imaginary coefficient line
                            s = '%x   :  %x ; \n' % (i, twids_im[i])
                            fp.write(s)
                        s= 'END;\n'
                        fp.write(s)
                else:
                    for i in range(twids.size):
                        s =  ' %x   :  %x ; \n' % (i, twids_re[i])
                        twids_tmp.append(s)
                        s =  ' %x   :  %x ; \n' % (i, twids_im[i])
                        twids_tmp.append(s)
                    twids.append(",".join(twids_tmp))
        if not sdf.gen_files:
            return twids
        
###############################################################################################################
# Prepare coefficients for writing to bram file
###############################################################################################################
    if sdf.ext == 'mem' and sdf.gen_files:
        writemem(sdf)
        return sdf.outfileprefix.replace('\\', '/')
    elif sdf.ext == 'mem' and not sdf.gen_files:
        coefs = writemem(sdf)
        return coefs
    elif sdf.ext == 'mif':
        writemif(sdf)
        return sdf.outfileprefix.replace('\\', '/')
    else:
        None

if __name__ == "__main__":
    print(run(sys.argv[1:]))
