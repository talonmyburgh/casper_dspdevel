# Binary Output
using FixedPointNumbers
using DSP

fixedToString(num::Fixed; base=10, bitstringProcessor=x->x, pad=1) = string(parse(Int, bitstringProcessor(bitstring(num)), base=2), base=base, pad=pad)

function writeMemFile(data, outFilePath, bitWidth=36)
	outFile = open(outFilePath, "w")
	for val in data
		write(outFile, fixedToString(val, base=16, bitstringProcessor=x->lpad((bitWidth < length(x) ? x[end-(bitWidth-1):end] : x), bitWidth, x[1]), pad=ceil(Int, bitWidth/4))*"\n")
	end
	close(outFile)
end

function coeff_gen(N :: Integer, taps :: Integer; win :: String = "hanning", fwidth :: Float64 = 1.0)
    WinDic = Dict{String,Function}(                                                                 #dictionary of various filter types
    "hanning" => DSP.hanning,
    "hamming" => DSP.hamming,
    "bartlett" => DSP.bartlett,
    "blackman" => DSP.blackman,
    );
    alltaps = N*taps;
    windowval=WinDic[win](alltaps);                                               
    totalcoeffs = (windowval.*sinc.(fwidth.*(collect(0:alltaps-1)./(N) .- taps/2)));
    return totalcoeffs;
end