function boolval =  checkbox2bool(bxval)
  if strcmp(bxval, 'on')
   boolval= true;
  elseif strcmp(bxval, 'off')
   boolval= false;
  end 
end