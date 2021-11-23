#! /usr/bin/env python
###############################################################################
#
# Copyright (C) 2016
# ASTRON (Netherlands Institute for Radio Astronomy) <http://www.astron.nl/>
# P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################

"""Create mif files for the coeffcient RAM memories per tap and for the wide
   band factor range. The coeffients in the input dat file must be in normal
   impulse response order and the nof taps and nof points must match. The
   output mif files contain the FIR coefficients in flipped order per tap.
   The FIR coefficients order is first flipped per tap and after that they 
   are output into the mif files. The output mif files are numbered in
   range(wb_factor*nof_taps), first all tap files for wb index 0, then all
   tap files for wb index 1 etc.
   
   The FIR coefficients for wb factor > 1 are created in big endian order, so
   pfir.wb_big_endian = True, because internally fil_ppf_wide.vhd uses fixed
   big endian time [0,1,2,3] to wideband P [3,2,1,0] index mapping for the
   input data. This makes that the same set of mif files can be used for
   fil_ppf_wide.vhd, independent of g_big_endian_wb_in in fil_ppf_wide.vhd.
                    
   The output MIF files use the input dat filename as prefix and append to
   that the wb_factor information and the MIF file index. 
   
   The coefficient values are stored in the MIF. The width of the data is  
   specified by pfir.coef_w. The pfir.coef_w is obtained via the command 
   line argument and is only used to identify the input dat file.
   
   A pfir_coeff_*.dat file can be created using Matlab:
   > $RADIOHDL_WORK/applications/apertif/matlab/run_pfir_coef.m
   
   The result is then (dependend on the actual settings in run_pfir_coef.m):
   > $RADIOHDL_WORK/applications/apertif/matlab/data/pfir_coeff_incrementing_8taps_64points_16b.dat
   
   This coefficients dat file needs to be copied to the local ../hex directory,
   because both the dat and the MIF files sare used in the VHDL testbenches.
   
   Usage:
   > python fil_ppf_create_mifs.py -h
   > python fil_ppf_create_mifs.py -f ../hex/pfir_coeff_incrementing_8taps_64points_16b.dat -t 8 -p 64 -w 1 -c 16
   
   The output MIF files will then be:
   ../hex/pfir_coeff_incrementing_8taps_64points_16b_1wb_0.mif
   ../hex/pfir_coeff_incrementing_8taps_64points_16b_1wb_1.mif
   ../hex/pfir_coeff_incrementing_8taps_64points_16b_1wb_2.mif
   ../hex/pfir_coeff_incrementing_8taps_64points_16b_1wb_3.mif
   ../hex/pfir_coeff_incrementing_8taps_64points_16b_1wb_4.mif
   ../hex/pfir_coeff_incrementing_8taps_64points_16b_1wb_5.mif
   ../hex/pfir_coeff_incrementing_8taps_64points_16b_1wb_6.mif
   ../hex/pfir_coeff_incrementing_8taps_64points_16b_1wb_7.mif 

   The script is defined as a single run() function that can be ran standalone
   as main (typical usage) or be imported and called by another script.
"""

import sys
import getopt
import os
import numpy as np

def run(argv):
    # Arguments
    class pfir:
        infilename = ''
        outdestfolder = ''
        outfileprefix = ''
        filename = ''
        nof_taps = 0
        nof_points = 0
        wb_factor = 0
        coef_w = 0
        ext = 'mem'
        # fixed use False to create mif files for fil_ppf_wide.vhd and for apertif_unb1_bn_filterbank
        wb_big_endian = False
        window_func = ''
        fwidth = 1.0
        verbose = False
        gen_files = True
        file_nof_points = 0
    
    usage_str = 'USAGE: fil_ppf_create.py -f <input path and file name> -o <output path> -g <gen files> -t <nof taps> -p <nof points> -w <wb factor> -c <coef width> -v <vendor - 0 Xil, 1 Alt> -W <window function> -F <fwidth> -V <verbose>\n'

    try:
        opts, _ = getopt.getopt(sys.argv[1:], 'hf:o:g:t:p:w:c:v:W:F:V:')
    except getopt.GetoptError:
        print(usage_str)
        sys.exit(2)

    # print sys.argv
    for opt, arg in opts:
        if opt == '-h':
            print(usage_str)
            sys.exit()
        elif opt == '-f':
            pfir.infilename = arg
            pfir.filename = os.path.basename(arg)
            pfir.name = os.path.splitext(pfir.filename)[0]
        elif opt == '-o':
            if arg == '':
                pfir.outdestfolder = os.path.abspath(os.path.dirname(os.path.realpath(__file__)))
            else:
                pfir.outdestfolder = os.path.abspath(os.path.join(os.getcwd(), arg))
        elif opt == '-g':
            pfir.gen_files = bool(int(arg))
        elif opt == '-t':
            pfir.nof_taps = int(arg)
        elif opt == '-p':
            pfir.nof_points = int(arg)
        elif opt == '-w':
            pfir.wb_factor = int(arg)
        elif opt == '-c':
            pfir.coef_w = int(arg)
        elif opt == '-v':
            if arg == '0':
                pfir.ext = 'mem'
            elif arg == '1':
                pfir.ext = 'mif'
            else:
                print('Invalid vendor provided, defaulting to Xilinx.')
        elif opt == '-W':
            pfir.window_func = arg
        elif opt == '-F':
            pfir.fwidth = float(arg)
        elif opt == '-V':
            pfir.verbose = bool(int(arg))

    # Generate name of output hex files if output files are required:
    if pfir.gen_files:
        directoryname = './hex'
        pathforstore = os.path.abspath(os.path.join(pfir.outdestfolder, directoryname))
        if not os.path.exists(pathforstore):
            os.mkdir(pathforstore)
            if pfir.verbose:
                print("Directory ", pathforstore, " created!")
        else:
            if pfir.verbose:
                print("Directory ", pathforstore, " already exists!")

    # Create base file name for the memory files. If an input file was provided it serves as a basename, else, one must be generated.
        if pfir.infilename != '':
            if pfir.verbose:
                print("Filename will be composed from input filename")
            pfir.outfileprefix = os.path.join(pathforstore,pfir.filename.split(
                '.')[0])
        else:
            if pfir.verbose:
                print("No input filename specified - will create one from the provided paramenters.")
            pfir.outfileprefix = os.path.join(pathforstore, "pfir_coeffs_%s_%dt_%dp_%db" % (
                pfir.window_func, pfir.nof_taps, pfir.nof_points, pfir.coef_w)
            )

    def fetchdatcoeffs(pfir):
        c_nof_files = pfir.wb_factor * pfir.nof_taps
        pfir.file_nof_points = pfir.nof_points//pfir.wb_factor
        print('Creating wb_factor * nof_taps (= %d*%d) = %d %s-files for PFIR.' %
              (pfir.wb_factor, pfir.nof_taps, c_nof_files, pfir.ext))
        print('. With %d points per tap' % pfir.nof_points)
        print('. With %d points per %s-file' % (pfir.file_nof_points, pfir.ext))
        print('. With %d bit coefficient in RAM' % (pfir.coef_w))
        print('\n')

        # Read coefficients from PFIR file
        pfir_coefs = []
        with open(pfir.infilename, 'r') as fp:
            for line in fp:
                if line.strip() != '':                # skip empty line
                    s = int(line)                     # one coef per line
                    s = s & (2**pfir.coef_w-1)        # mask the
                    pfir_coefs.append(s)
        return pfir_coefs

    def gen_coefs(pfir):
        WinDic = {  # dictionary of various filter types
            'hanning': np.hanning,
            'hamming': np.hamming,
            'bartlett': np.bartlett,
            'blackman': np.blackman,
        }
        alltaps = pfir.nof_points*pfir.nof_taps
        windowval = WinDic[pfir.window_func](alltaps)
        totalcoeffs = (windowval*np.sinc(pfir.fwidth *
                       (np.arange(alltaps)/(pfir.nof_points) - pfir.nof_taps/2)))
        return totalcoeffs

    def writemem(pfir, pfir_coefs_flip):
        if not pfir.gen_files:
            coefs = []
        for k in range(pfir.wb_factor):
            if pfir.wb_big_endian == True:
                # reverse, to fit big endian time to wideband input data mapping t[0,1,2,3] = P[3,2,1,0]
                kk = pfir.wb_factor-1-k
            else:
                # keep, to fit little endian time to wideband input data mapping t[3,2,1,0] = P[3,2,1,0]
                kk = k

            for j in range(pfir.nof_taps):
                coefs_tmp = []
                # append MEM index in range(c_nof_files)
                if pfir.gen_files:
                    t_outfilename = pfir.outfileprefix + '_%dwb' % pfir.wb_factor + \
                        '_%d.%s' % (k*pfir.nof_taps+j, pfir.ext)
                    with open(t_outfilename, 'w+') as fp:
                        for i in range(pfir.file_nof_points):
                            s = ('%%0%dx\n' % np.ceil(pfir.coef_w/4)) % (
                                pfir_coefs_flip[j*pfir.nof_points+i*pfir.wb_factor+kk])  # use kk
                            fp.write(s)
                else:
                    for i in range(pfir.file_nof_points):
                        s = ('%%0%dx' % np.ceil(pfir.coef_w/4)) % (
                                pfir_coefs_flip[j*pfir.nof_points+i*pfir.wb_factor+kk])  # use kk
                        coefs_tmp.append(s)
                    coefs.append(",".join(coefs_tmp))
        if not pfir.gen_files:
            return coefs

    def writemif(pfir, pfir_coefs_flip):
        for k in range(pfir.wb_factor):
            if pfir.wb_big_endian == True:
                # reverse, to fit big endian time to wideband input data mapping t[0,1,2,3] = P[3,2,1,0]
                kk = pfir.wb_factor-1-k
            else:
                # keep, to fit little endian time to wideband input data mapping t[3,2,1,0] = P[3,2,1,0]
                kk = k

            for j in range(pfir.nof_taps):
                # append MIF index in range(c_nof_files)
                t_outfilename = pfir.outfileprefix + '_%dwb' % pfir.wb_factor +\
                    '_%d.%s' % (k*pfir.nof_taps+j, pfir.ext)
                with open(t_outfilename, 'w+') as fp:
                    s = 'WIDTH=%d;\n' % pfir.coef_w
                    fp.write(s)
                    s = 'DEPTH=%d;\n' % pfir.file_nof_points
                    fp.write(s)
                    s = 'ADDRESS_RADIX=HEX;\n'
                    fp.write(s)
                    s = 'DATA_RADIX=HEX;\n'
                    fp.write(s)
                    s = 'CONTENT BEGIN\n'
                    fp.write(s)

                    for i in range(pfir.file_nof_points):
                        s = ' %x   :  %x ; \n' % (
                            i, pfir_coefs_flip[j*pfir.nof_points+i*pfir.wb_factor+kk])  # use kk
                        fp.write(s)

                    s = 'END;\n'
                    fp.write(s)

###################################################################################################
# Generate/fetch coefficients
###################################################################################################
    # If neither a infilename for input dat coefficients nor a window function is provided, exit.
    if (pfir.infilename == '' and pfir.window_func == '') or pfir.nof_taps == 0 or pfir.nof_points == 0 or pfir.wb_factor == 0 or pfir.coef_w == 0:
        print('Missing arguments!')
        print(usage_str)
        sys.exit()

    # If a window function is provided, we'll generate the coefficients.
    elif pfir.infilename == '' and pfir.window_func != '':
        c_nof_files = pfir.wb_factor * pfir.nof_taps
        pfir.file_nof_points = pfir.nof_points//pfir.wb_factor
        if pfir.verbose:
            print('Creating wb_factor * nof_taps (= %d*%d) = %d MIF-files for PFIR with coefficients from input file %s.' %
                  (pfir.wb_factor, pfir.nof_taps, c_nof_files, pfir.infilename))
            print('. With %d points per tap' % pfir.nof_points)
            print('. With %d points per file' % pfir.file_nof_points)
            print('. With %d bit coefficient in RAM' % (pfir.coef_w))
            print('\n')
        s = gen_coefs(pfir)
        s = (s*(2**(pfir.coef_w-1))).astype(int)
        s = s & (2**pfir.coef_w-1)
        # should probably do all this with numpy arrays rather than lists but that is for later.
        pfir_coefs = s.tolist()

    # if the filepath is provided, we'll use the dat inputs to write out the mem/mif files.
    elif pfir.infilename != '' and pfir.window_func == '':
        pfir_coefs = fetchdatcoeffs(pfir)

###############################################################################################################
# Prepare coefficients for writing to bram file
###############################################################################################################
    # Flip the order of the coefficients per tap - needs to happen regardless of which technology we're implementing for.
    pfir_coefs_flip = []
    for j in range(pfir.nof_taps):
        for i in range(pfir.nof_points):
            pfir_coefs_flip.append(
                pfir_coefs[j*pfir.nof_points + pfir.nof_points-1-i])

    if pfir.ext == 'mem' and pfir.gen_files:
        writemem(pfir, pfir_coefs_flip)
        return pfir.outfileprefix.replace('\\', '/')
    elif pfir.ext == 'mem' and not pfir.gen_files:
        coefs = writemem(pfir, pfir_coefs_flip)
        return coefs
    elif pfir.ext == 'mif':
        writemif(pfir, pfir_coefs_flip)
        return pfir.outfileprefix.replace('\\', '/')
    else:
        None

if __name__ == "__main__":
    print(run(sys.argv[1:]))
