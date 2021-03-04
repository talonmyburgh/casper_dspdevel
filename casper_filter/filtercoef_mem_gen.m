function coefs = filtercoef_mem_gen(N, taps, win, fwidth)
%coefgen - Generate filterbank coeficients CASPER styles.
%
% Syntax: coefs = coefgen(N, taps, )
    alltaps = N*taps;
    if win == 'hanning'
        windowval = transpose(hanning(alltaps));
    elseif win == 'hamming'
        windowval = transpose(hamming(alltaps));
    elseif win == 'bartlett'
        windowval = transpose(bartlett(alltaps));
    elseif win == 'blackman'
        windowval = transpose(blackman(alltaps));
    end
    coefs = windowval .* sinc(fwidth * ([0:alltaps-1]/N - taps/2));
end