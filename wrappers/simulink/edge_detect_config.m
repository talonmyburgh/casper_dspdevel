
function edge_detect_config(this_block)

  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName('edge_detect');
  filepath = fileparts(which('edge_detect_config'));

  edge_detect_blk = this_block.blockName;
  edge_detect_blk_parent = get_param(edge_detect_blk,'Parent');

  edge_type = get_param(edge_detect_blk_parent, 'edge_type');
  output_pol = get_param(edge_detect_blk_parent, 'output_pol');

  this_block.addSimulinkInport('in_sig');
  in_sig_val = this_block.port('in_sig');
  
  this_block.addSimulinkOutport('out_sig');
  out_sig_val = this_block.port('out_sig');

  % -----------------------------
  if (this_block.inputTypesKnown)
    out_sig_val.setWidth(in_sig_val.width);
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  this_block.addGeneric('g_edge_type','STRING',edge_type);
  this_block.addGeneric('g_output_pol','STRING',output_pol);

  this_block.addFileToLibrary([filepath '/../../misc/edge_detect.vhd'],'misc_lib');
return;

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

