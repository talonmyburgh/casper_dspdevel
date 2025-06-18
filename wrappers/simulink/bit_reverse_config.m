
function bit_reverse_config(this_block)

  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName('bit_reverse');
  filepath = fileparts(which('bit_reverse_config'));
  
  bit_reverse_blk = this_block.blockName;
  bit_reverse_blk_parent = get_param(bit_reverse_blk,'Parent');

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

  is_async = checkbox2bool(get_param(bit_reverse_blk_parent,'is_async'));

  % System Generator has to assume that your entity  has a combinational feed through; 
  %   if it  doesn't, then comment out the following line:
  if is_async
    this_block.tagAsCombinational;
  end

  %In ports
  this_block.addSimulinkInport('in_val');
  in_val_port = this_block.port('in_val');
  
  %Out ports
  this_block.addSimulinkOutport('out_val');
  out_val_port = this_block.port('out_val');
  
  % -----------------------------
  if (this_block.inputTypesKnown)
    out_val_port.setWidth(in_val_port.width);
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------
  
  %Generics
  this_block.addGeneric('g_async','BOOLEAN',bool2str(is_async));

  %Add Files:
  this_block.addFileToLibrary([filepath '/../../misc/bit_reverse.vhd'],'misc_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
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
end
% ------------------------------------------------------------

