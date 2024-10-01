
function armed_trigger_config(this_block)

  this_block.setTopLevelLanguage('VHDL');

  this_block.setEntityName('armed_trigger');
  filepath = fileparts(which('armed_trigger_config'));

  armed_trigger_blk = this_block.blockName;
  armed_trigger_blk_parent = get_param(armed_trigger_blk,'Parent');

  this_block.addSimulinkInport('arm');
  arm_port = this_block.port('arm');
  
  this_block.addSimulinkInport('trig_in');
  trig_in_port = this_block.port('trig_in');
  
  this_block.addSimulinkOutport('trig_out');
  trig_out_port = this_block.port('trig_out');

  trig_out_port = this_block.port('trig_out');
  trig_out_port.setType('UFix_1_0');
  trig_out_port.useHDLVector(false);

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.

    if (arm_port.width ~= 1);
      this_block.setError('Input data type for port "arm" must have width=1.');
    end
    arm_port.useHDLVector(false);

    if (trig_in_port.width ~= 1);
      this_block.setError('Input data type for port "trig_in" must have width=1.');
    end
    trig_in_port.useHDLVector(false);

    if (trig_out_port.width ~= 1);
      this_block.setError('Input data type for port "trig_out" must have width=1.');
    end
    trig_out_port.useHDLVector(false);

  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../misc/edge_detect.vhd'],'misc_lib');
  this_block.addFileToLibrary([filepath '/../../misc/armed_trigger.vhd'],'misc_lib');
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

