#------------------------------------- 
#-- Fixed point model of the FFT + testbench generation
#-- Able to be imported as a module in other designs.
#-------------------------------------
#--Author	: M. Schiller (NRAO)
#--Date    : 23-March-2023
#
#--------------------------------------------------------------------------------
#-- Copyright NRAO March 23, 2023
#--------------------------------------------------------------------------------
#-- License
#-- Licensed under the Apache License, Version 2.0 (the "License");
#-- you may not use this file except in compliance with the License.
#-- You may obtain a copy of the License at
#-- 
#--     http://www.apache.org/licenses/LICENSE-2.0
#-- 
#-- Unless required by applicable law or agreed to in writing, software
#-- distributed under the License is distributed on an "AS IS" BASIS,
#-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#-- See the License for the specific language governing permissions and
#-- limitations under the License.
#--
import numpy as np
#import matplotlib.pyplot as plt
from vunit import VUnit
from pathlib import Path
import os
#from scipy import io

def roundsat(data,signednum,integer_bits,fractional_bits,g_do_rounding,g_do_saturation,print_saturation):
    if (integer_bits+fractional_bits)==0:
        # don't bother rounding.
        return data
    if np.iscomplexobj(data):
        # it's complex call ourselves with the real and imag part
        realround = roundsat(np.real(data),signednum,integer_bits,fractional_bits,g_do_rounding,g_do_saturation,print_saturation)
        imaground = roundsat(np.imag(data),signednum,integer_bits,fractional_bits,g_do_rounding,g_do_saturation,print_saturation)
        return (realround + 1j*imaground)
    if signednum==1:
        maxpos = ((pow(2,integer_bits+fractional_bits))-1)/(2**fractional_bits)
        maxneg = (0-(pow(2,integer_bits+fractional_bits)))/(2**fractional_bits)
    else:
        maxpos = ((pow(2,integer_bits+fractional_bits))-1)//(2**fractional_bits)
        maxneg = 0
    # by default around is convergent round2even, not "bankers" round away from 0.
    if g_do_rounding==1:
        dataout = np.divide(np.around(np.multiply(data,pow(2,fractional_bits))),pow(2,fractional_bits))
    else:
        dataout = np.divide(np.floor(np.multiply(data,pow(2,fractional_bits))),pow(2,fractional_bits))
    
    sathighcount = np.count_nonzero(np.greater(dataout,maxpos))
    if print_saturation==1:
        if sathighcount>0:
            print("Saturating values to Max positive")
        satlowcount = np.count_nonzero(np.less(dataout,maxneg))
        if satlowcount>0:
            print("Saturating Values to Max negative")
    if g_do_saturation==1:
        dataout = np.where(dataout<maxneg,maxneg,dataout)
        dataout = np.where(dataout>maxpos,maxpos,dataout)
    return dataout

def twiddle_gen(fftsize,g_twiddle_width,g_do_rounding,g_do_saturation,g_use_vhdl,coef_base):
    coefpath = Path(f"{coef_base}/twiddlepkg_twidth{g_twiddle_width}_fftsize{fftsize}.txt")
    if (g_use_vhdl and Path(coefpath).is_file()) :
        # the VHDL twiddle generator uses VHDL SIN/COS which aren't exactly the same
        # as the python SIN/COS
        # This causes +/- 1 errors in the twiddles
        # to get a perfect FFT simulation we have the option to use a lookup table generated
        # by VHDL, but it might not exist yet
        # if your size does not exist execute these steps:
        # 1) Add a test below in tb_twiddle_package_setup
        # 2) Execute the test using your simulator of choice
        # 3) find the output file Vunit creates eg:
        # /export/home/creon/mschiller_ngvla_project/casper_dspdevel/r2sdf_fft/vunit_out/test_output/r2sdf_fft_lib.tb_vu_twiddlepkg.Twiddle_w18b_8192_a070bdfd1c276c4964716de8a2ae80049f2966b7/fortwidddlepkg_twidth18_fftsize8192.txt
        # Add the file to Source control inside the directory that contains this script
        print("Using Prestored VHDL coefficients for this size")
        data = np.loadtxt(coefpath,dtype="int")
        print("Loading Twiddles from: %s" % str(coefpath))
        coeffs = data[0:data.size:2]+1j*data[1:data.size:2]
        coeffs = coeffs / (2**(g_twiddle_width-1))
        return coeffs
    else:
        print("Using Python Coefficient Generation")
        coeff_indices = np.arange(0,fftsize)
        coeffs = np.exp(np.multiply(coeff_indices,1.0j * -2*np.pi / (2*fftsize)))
        coeffs = roundsat(coeffs,1,0,g_twiddle_width-1,g_do_rounding,g_do_saturation,0)  # coeffs will still be floating point, but will have the precision indicated by g_twiddle_width
        return coeffs

def fft_butterfly(xa,xb,twiddle,g_do_rounding,g_do_saturation,g_output_width,g_bits_to_round_off,g_do_dif):
    # xa/xb are assumeed to be integers between stages, any fraction will be rounded off on outputs
    if g_do_dif==1:
        ya = xa+xb
        yb = np.multiply(twiddle,(xa-xb))
        # this isn't really best practice to round here, but it's what the VHDL does
        yb = roundsat(yb,1,g_output_width-1,0,g_do_rounding,g_do_saturation,1)
        ya = np.multiply(ya,pow(2,(-g_bits_to_round_off)))
        yb = np.multiply(yb,pow(2,(-g_bits_to_round_off)))
    else:
        temp = np.multiply(xb,twiddle)
        # this isn't really best practice to round here, but it's what the VHDL does
        temp = roundsat(temp,1,g_output_width-1,0,g_do_rounding,g_do_saturation,1)
        ya = xa + temp
        yb = xa - temp
        ya = np.multiply(ya,pow(2,(-g_bits_to_round_off)))
        yb = np.multiply(yb,pow(2,(-g_bits_to_round_off)))
    ya = roundsat(ya,1,g_output_width-1,0,g_do_rounding,g_do_saturation,1) # no fraction bit on output, integer only!
    yb = roundsat(yb,1,g_output_width-1,0,g_do_rounding,g_do_saturation,1)
    return ya,yb

def fft_stage(stage_in,fft_size_log2,g_twiddle_width,g_do_rounding,g_do_saturation,g_output_width,g_bits_to_round_off,g_do_dif,coef_base):
    # Make sure input is the length
    if fft_size_log2==0:
        stage_out=stage_in
        return stage_out
    if np.mod(stage_in.shape[0],2**fft_size_log2)>0:
        stage_in = stage_in[1:(2**fft_size_log2)*(stage_in.shape[0]//2**fft_size_log2)]
    if g_do_dif==1:
        #in DIF FFT we need to split into two halves the stage_in data based on
        #the current FFTsize
        #First reshape stage_in into fftsize X N
        data = np.transpose(np.reshape(stage_in,((np.shape(stage_in)[0]//(2**fft_size_log2)),(2**fft_size_log2))))
        xa  = data[0:2**(fft_size_log2-1),:]
        xb = data[2**(fft_size_log2-1):,:]
        # Twiddle values are always rounded and saturated.
        twiddle = twiddle_gen(2**(fft_size_log2-1),g_twiddle_width,1,1,1,coef_base)
        twiddle = np.tile(np.transpose(np.atleast_2d(twiddle)),(1,np.shape(xa)[1]))
        ya,yb = fft_butterfly(xa,xb,twiddle,g_do_rounding,g_do_saturation,g_output_width,g_bits_to_round_off,g_do_dif)
        stage_out = np.zeros(data.shape,np.complex128)
        stage_out[0:2**(fft_size_log2-1),:] = ya
        stage_out[2**(fft_size_log2-1):2**(fft_size_log2),:] = yb
    else:
        if fft_size_log2==0:
            stage_out=stage_in
            return stage_out
        data = np.reshape(stage_in,(pow(2,fft_size_log2),np.shape(stage_in)[0]/(pow(2,fft_size_log2))));
        xa  = data[0:2^(fft_size_log2-1),:]
        xb = data[2^(fft_size_log2-1):,:]
        twiddle = twiddle_gen(pow(2,(fft_size_log2-1)),g_twiddle_width,1,1,1,coef_base)
        twiddle = np.tile(twiddle,(1,np.shape(xa)[1]))
        ya,yb = fft_butterfly(xa,xb,twiddle,g_do_rounding,g_do_saturation,g_output_width,g_bits_to_round_off,g_do_dif)
        stage_out = np.zeros(data.shape,np.complex128)
        stage_out[0:2**(fft_size_log2-1),:] = ya
        stage_out[2**(fft_size_log2-1):2**(fft_size_log2),:] = yb

 
    stage_out = np.reshape(np.transpose(stage_out),(stage_out.shape[0]*stage_out.shape[1],1))
    return stage_out

def bit_reverse_traverse_no_generator(a):
    n = a.shape[0]
    assert(not n&(n-1))

    if n == 1:
        return a
    else:
        even_indicies = np.arange(n/2,dtype=np.int32)*2
        odd_indicies = np.arange(n/2,dtype=np.int32)*2 + 1

        evens = bit_reverse_traverse_no_generator(a[even_indicies])
        odds = bit_reverse_traverse_no_generator(a[odd_indicies])

        return np.concatenate([evens, odds])

def get_bit_reversed_list_no_generator(l):
    n = len(l)

    indexs = np.arange(n,dtype=np.int32)
    b = []
    for i in bit_reverse_traverse_no_generator(indexs):
        b.append(l[i])

    return b

def bitrevorder(a):
    return get_bit_reversed_list_no_generator(a)


def pfft(data,fftsize_log2,g_twiddle_width,g_do_rounding,g_do_saturation,g_output_width,g_bits_to_round_off,g_do_dif,g_do_bit_rev_input,g_do_bit_rev_output,coef_base):
    # enforce that input data is a multiple of the FFTsize
    if np.mod(data.shape[0],pow(2,fftsize_log2))>0:
        data = data[1:(pow(2,fftsize_log2)*np.floor(data.shape[1]/pow(2,fftsize_log2)))]


    if g_do_dif==1:
        idxlog2range = np.arange(fftsize_log2,0,-1)
    else:
        idxlog2range = np.arange(1,fftsize_log2+1)
    if g_do_bit_rev_input==1:
        # Bitrev won't accept long arrays properly
        data_bit_rev_in = np.reshape(data,(2**fftsize_log2,(data.shape[0]//(2**fftsize_log2))))
        for n in range(0,data_bit_rev_in.shape[1]):
            data[n*(2**fftsize_log2):(n+1)*(2**fftsize_log2)]=bitrevorder(data_bit_rev_in[:,n])
            

    stageout = data
    stage_num = 0
    if g_output_width.size != idxlog2range.size:
        raise ValueError('g_output_width not long enough')
        return 1
    if len(g_bits_to_round_off) != len(idxlog2range):
        raise ValueError('g_bits_to_round_off not long enough')
        return 1
    stagedebug =np.zeros((data.size,idxlog2range.size),dtype=np.complex128)
    for idxlog2 in idxlog2range:
        print("Processing Stage %d of %d\n"%(stage_num,len(idxlog2range)))
        stageout = fft_stage(stageout,int(idxlog2),g_twiddle_width,g_do_rounding,g_do_saturation,int(g_output_width[idxlog2-1]),int(g_bits_to_round_off[idxlog2-1]),g_do_dif,coef_base)
        stagedebug[:,stage_num] = stageout[:,0]
        stage_num = stage_num + 1

    if g_do_bit_rev_output==1:
        # Bitrev won't accept long arrays properly that exceed the FFTsize.
        # convert to an array of fftsize x n so we can operate on single length blocks at a time.
        data_bit_rev_in = np.transpose(np.reshape(stageout,((np.shape(stageout)[0]//(2**fftsize_log2)),(2**fftsize_log2))))

        for n in range(0,data_bit_rev_in.shape[1]):
            temp_rev = np.asarray(bitrevorder(data_bit_rev_in[:,n]))
            stageout[n*(2**fftsize_log2):(n+1)*(2**fftsize_log2)]=np.transpose(np.atleast_2d(temp_rev))
    return stageout,stagedebug



def main():
    print("There is no main..")


if __name__=="__main__":
    main()