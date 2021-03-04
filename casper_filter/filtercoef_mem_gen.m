function coefs = coefgen(N, taps, win, fwidth)
%coefgen - Generate filterbank coeficients CASPER styles.
%
% Syntax: coefs = coefgen(N, taps, )
%
% Long description
    w_str = {"hanning", "hamming", "bartlett", "blackman"};
    f_handles = {@hanning, @hanning, @bartlett, @blackman}
    WinDic = containers.Map(w_str, f_handles);
    alltaps = N*taps;
    windowval = WinDic[win](alltaps);
    coefs = (windowval .* sinc(fwidth .* (arange(0:alltaps-1)./N .- taps/2)));
end