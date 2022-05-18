function ri_to_c_config(this_block)

  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName('ri_to_c');
  filepath = fileparts(which('ri_to_c_config'));

  ri_to_c_blk = this_block.blockName;
  ri_to_c_blk_parent = get_param(ri_to_c_blk,'Parent');

  function boolval =  checkbox2bool(bxval)
    if strcmp(bxval, 'on')
     boolval= true;
    elseif strcmp(bxval, 'off')
     boolval= false;
    end 
  end
  function strboolval = bool2str(bval)
    if bval
        strboolval = 'TRUE';
    elseif ~bval
        strboolval = 'FALSE';
    end
end

  is_async = checkbox2bool(get_param(ri_to_c_blk_parent,'is_async'));

  % System Generator has to assume that your entity  has a combinational feed through; 
  %   if it  doesn't, then comment out the following line:
  if is_async
    this_block.tagAsCombinational;
  end

  %Inputs
  this_block.addSimulinkInport('re_in');
  re_in_port = this_block.port('re_in');
  this_block.addSimulinkInport('im_in');
  im_in_port = this_block.port('im_in');

  %Outputs
  this_block.addSimulinkOutport('c_out');
  c_out_port = this_block.port('c_out');

  % -----------------------------
  if (this_block.inputTypesKnown)
    %Logic to act as the reinterpret block:
    c_out_port.setWidth(re_in_port.width + im_in_port.width);
  end  % if(inputTypesKnown)
  % -----------------------------

   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------
  
  %Generics:
  this_block.addGeneric('g_async','BOOLEAN',bool2str(is_async));

  %Add Files:
  this_block.addFile([filepath '/../../misc/concat.vhd'],'misc_lib');
  this_block.addFile([filepath '/../../misc/ri_to_c.vhd'],'misc_lib');

return;
end

% ------------------------------------------------------------

function setup_as_single_rate(block,clkname,cename) 
  inputRates = block.inputRates; 
  uniqueInputRates = unique(inputRates); 
  if (length(uniqueInputRates)==1 & uniqueInputRates(1)==Inf) 
    block.addError('The inputs to this block cannot all be constant.'); 
    return; 
  end 
  if (uniqueInputRates(end) == Inf) 
     hasConstantInput = true; 
     uniqueInputRates = uniqueInputRates(1:end-1); 
  end 
  if (length(uniqueInputRates) ~= 1) 
    block.addError('The inputs to this block must run at a single rate.'); 
    return; 
  end 
  theInputRate = uniqueInputRates(1); 
  for i = 1:block.numSimulinkOutports 
     block.outport(i).setRate(theInputRate); 
  end 
  block.addClkCEPair(clkname,cename,theInputRate); 
  return; 

% ------------------------------------------------------------
end

