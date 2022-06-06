
function munge_config(this_block)
  filepath = fileparts(which('munge_config'));
  this_block.setTopLevelLanguage('VHDL');

  this_block.setEntityName('munge_static');
  munge_blk = this_block.blockName;
  munge_blk_parent = get_param(munge_blk,'Parent');

  nof_divisions = get_param(munge_blk_parent,'number_of_divisions');
  nof_divisions = str2double(nof_divisions);
  division_w = get_param(munge_blk_parent,'division_size_bits');
  division_w = str2double(division_w);
  order = get_param(munge_blk_parent,'packing_order');
  order = strrep(order, '"', '');
  order = strrep(order, '+', '');
  order = strrep(order, '-', '');

  vhdl_file = munge_code_gen(nof_divisions,division_w,order);

  %Input signals
  this_block.addSimulinkInport('din');
  din_port = this_block.port('din');
  din_port.setWidth(nof_divisions*division_w);

  %Output signals
  this_block.addSimulinkOutport('dout');
  dout_port = this_block.port('dout');
  dout_port.setWidth(nof_divisions*division_w);

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  this_block.addFileToLibrary(vhdl_file,'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../casper_flow_control/munge.vhd'],'casper_flow_control_lib');
  this_block.addFileToLibrary([filepath '/../../casper_flow_control/tb_munge.vhd'],'casper_flow_control_lib');
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

