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
function par_twiddle_pkg_gen(Np, Nb, destfolder)
  % clear all;  close all;  clc;
  j=  1i; 
  B=  Nb;   % B= twiddle bit width
  N=  Np;

  %'twiddle defintion'
  w=  exp(-j*(2*pi/N));
  W=  w.^((0:N-1)'*(0:N-1));  % W matrix for DFT
  Wr= real(W);                % Wr
  Wi= imag(W);                % Wi

  %'binary weights'
  S_    = 2^(B-1)-1;          % Binary scaling
  sdfWr = Wr(1:(N/2),2)*S_;   % Wr scaled W_0 to W_(N/2)
  sdfWi = Wi(1:(N/2),2)*S_;   % Wi scaled W_0 to W_(N/2)

  %'dec to binary: 2s  complement'
  for ii=1:size(sdfWr,1)
    wRe(ii,:)= dec2bit(sdfWr(ii),B);
    wIm(ii,:)= dec2bit(sdfWi(ii),B);
  end

  %'obtain twiddle map'
  wMap=getTwiddleMap(N)+1;   % for R2SDF

  %'writing vhdl file'  
  writeTwiddlePkg(wRe, wIm, wMap, destfolder);  % write weights and index into VHDL
end

function wMap= getTwiddleMap(N)
  m=log2(N);      %number of stages
  wMap=zeros(N/2,m);%init Map
  
  wMap(1:N/2,1)=0:1:(N/2)-1;
  for ii=2:m
    wMap(1:N/2,ii)=2*(rem(wMap(1:N/2,ii-1),N/4));
  end
  %wMap((N/2)+1:N,:)= wMap(1:N/2,:);
end

function out=dec2bit(in,len)	 
  if(in>=0)
    in= floor(in);
    out=strcat('0',dec2bin(in,len-1));
  else
    in= round(in);
    const=(2^(len-1)-1);
    out=strcat('1',dec2bin(const-abs(in),len-1));
  end
end