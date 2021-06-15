%% Twiddle Generator :
% generates the complex Twiddles in B_ bit Binary format
% and writes VHDL package for R2SDF architecture implementation.
%-------------------------------------------------------------------------%
%   Author: Raj Thilak Rajan : rajan at astron.nl: Nov 2009
%   Copyright (C) 2009-2010
%   ASTRON (Netherlands Institute for Radio Astronomy)
%   P.O.Box 2, 7990 AA Dwingeloo, The Netherlands
% 
%   This file is part of the UniBoard software suite.
%   The file is free software: you can redistribute it and/or modify
%   it under the terms of the GNU General Public License as published by
%   the Free Software Foundation, either version 3 of the License, or
%   (at your option) any later version.
% 
%   This program is distributed in the hope that it will be useful,
%   but WITHOUT ANY WARRANTY; without even the implied warranty of
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%   GNU General Public License for more details.
% 
%   You should have received a copy of the GNU General Public License
%   along with this program.  If not, see <http://www.gnu.org/licenses/>.
%-------------------------------------------------------------------------%
%%
%function [w,w_re,w_im]= twiddles(Np, Nb)
 
clear all;  close all;  clc;
j=  1i; 
K=  14;   % N= pow2(K) point FFT
B=  18;   % B= twiddle bit width
N=  2.^K;

'twiddle defintion'
w=  exp(-j*(2*pi/N));
W=  w.^([0:N-1]'*[0:N-1]);  % W matrix for DFT
Wr= real(W);                % Wr
Wi= imag(W);                % Wi

'binary weights'
S_    = 2^(B-1)-1;          % Binary scaling
sdfWr = Wr(1:(N/2),2)*S_;   % Wr scaled W_0 to W_(N/2)
sdfWi = Wi(1:(N/2),2)*S_;   % Wi scaled W_0 to W_(N/2)

'dec to binary: 2s  complement'
for ii=1:size(sdfWr,1)
  wRe(ii,:)= dec2bit(sdfWr(ii),B);
  wIm(ii,:)= dec2bit(sdfWi(ii),B);
end

'dec to binary: 2s  complement'
for ii=1:size(wRe,1)
  sdfWr_true(ii,1)= bin2dec(wRe(ii,:));
end

% cross checking realTwiddle vs (realTw->bin->obtained realTw)
  sdfWr_true((N/4)+2:N/2,1)=sdfWr_true((N/4)+2:N/2) - 2*S_;

'obtain twiddle map'
wMap=getTwiddleMap(N)+1;   % for R2SDF

if(1)
  'writing vhdl file'  
  writeVhdl(wRe, wIm, wMap);  % write weights and index into VHDL
end

if(0)
  'test signal (shifted impulse reponse)'
  x=zeros(1,N);
  %x=ones(1,N)*50;
  %x(1:(N/2))=-1;  x((N/2)+1:N)=1;
  x(10)=16;
  plot((x),'K-'); hold on;
  plot(real(((Wr)*x')),'B*-')
  plot(imag(((Wi)*x')),'r*-')
end
