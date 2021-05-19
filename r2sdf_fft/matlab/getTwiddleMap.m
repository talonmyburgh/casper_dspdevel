%% Twiddle Map generation:
% returns the sequence of Twiddles for R2SDF FFT Architecture.
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
function wMap= getTwiddleMap(N)

m=log2(N);      %number of stages
wMap=zeros(N/2,m);%init Map

wMap(1:N/2,1)=0:1:(N/2)-1;
for ii=2:m
  wMap(1:N/2,ii)=2*(rem(wMap(1:N/2,ii-1),N/4));
end;
%wMap((N/2)+1:N,:)= wMap(1:N/2,:);

return;