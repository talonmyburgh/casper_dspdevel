
function common_pipeline_config(this_block)

  this_block.setTopLevelLanguage('VHDL');

  this_block.setEntityName('pipeline');
  filepath = fileparts(which('pipeline_config'));
  pipeline_child = this_block.blockName;
  pipeline_parent = get_param(pipeline_child,'Parent');
  pipeline_depth = get_param(pipeline_parent,'pipeline_len');

  this_block.addSimulinkInport('in_dat');
  in_dat_port = this_block.port('in_dat');
  in_dat_port.useHDLVector(true);
  
  this_block.addSimulinkOutport('out_dat');
  out_dat_port = this_block.port('out_dat');
  
  % -----------------------------
  if (this_block.inputTypesKnown)
    out_dat_port.setWidth(in_dat_port.width);
    out_dat_port.useHDLVector(true);
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  uniqueInputRates = unique(this_block.getInputRates);

  this_block.addGeneric('g_pipeline','NATURAL', pipeline_depth);

  this_block.addFileToLibrary([filepath '/../../casper_delay/pipeline.vhd'], 'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'], 'common_pkg_lib');

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

