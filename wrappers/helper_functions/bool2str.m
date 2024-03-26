function strboolval = bool2str(bval)
  if bval
      strboolval = 'TRUE';
  elseif ~bval
      strboolval = 'FALSE';
  end
end