
function pulse_ext_config(this_block)
  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName('pulse_ext');
  filepath = fileparts(which('pulse_ext_config'));

  pulse_ext_blk = this_block.blockName;
  pulse_ext_blk_parent = get_param(pulse_ext_blk,'Parent');

  extension = get_param(pulse_ext_blk_parent, 'extension');

  this_block.addSimulinkInport('i_pulse');

  this_block.addSimulinkOutport('o_pulse');

  o_pulse_port = this_block.port('o_pulse');
  o_pulse_port.setType('UFix_1_0');
  o_pulse_port.useHDLVector(false);

  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.

    if (this_block.port('i_pulse').width ~= 1);
      this_block.setError('Input data type for port "i_pulse" must have width=1.');
    end

    this_block.port('i_pulse').useHDLVector(false);

  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  this_block.addGeneric('g_extension','NATURAL',extension);

  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../misc/edge_detect.vhd'],'misc_lib');
  this_block.addFileToLibrary([filepath '/../../casper_counter/free_run_counter.vhd'],'casper_counter_lib');
  this_block.addFileToLibrary([filepath '/../../misc/pulse_ext.vhd'],'misc_lib');
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

