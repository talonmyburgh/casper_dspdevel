function out=dec2bit(in,len)	 

if(in>=0)
  in= floor(in);
  out=strcat('0',dec2bin(in,len-1));
else
  in= round(in);
  const=(2^(len-1)-1);
  out=strcat('1',dec2bin(const-abs(in),len-1));
end;
return;