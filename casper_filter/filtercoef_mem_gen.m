function filtercoef_mem_gen(N,taps,win,fwidth,sign,b_width,f_width)
    fixarray = fi(coefcalc(N,taps,win,fwidth),sign,b_width,f_width);
    memfile = sprintf("filter_coefs_%d_%d_%s_%.2f.mem",N,taps,win,fwidth);
    Mfile = fopen(memfile,'w');
    if(Mfile == -1)
        error("Cannot open mem file");
    end
    for i = 1:length(fixarray)
       fprintf(Mfile,'%s\n',hex(fixarray(i))); 
    end
    fclose(Mfile);
end
function coefs = coefcalc(N, taps, win, fwidth)
%coefgen - Generate filterbank coeficients CASPER styles.
%
% Syntax: coefs = coefgen(N, taps, )
    alltaps = N*taps;
    if strcmp(win,'hanning')
        windowval = transpose(hanning(alltaps));
    elseif strcmp(win,'hamming')
        windowval = transpose(hamming(alltaps));
    elseif strcmp(win,'bartlett')
        windowval = transpose(bartlett(alltaps));
    elseif strcmp(win,'blackman')
        windowval = transpose(blackman(alltaps));
    else
        error("No suppported window function supplied to win variable");
    end
    coefs = windowval .* sinc(fwidth * ([0:alltaps-1]/N - taps/2));
end