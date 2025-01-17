%% A Simulink wrapper the HDL CASPER window delay.
%% @author: Talon Myburgh
%% @company: Mydon Solutions
function window_delay_config(this_block)

  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName('window_delay');
  filepath = fileparts(which('window_delay_config'));
  window_delay = this_block.blockName;
  window_delay_parent = get_param(window_delay, 'Parent');

  delay_len = get_param(window_delay_parent, 'delay');

  this_block.addSimulinkInport('din');
  din_port = this_block.port('din');

  this_block.addSimulinkOutport('dout');
  dout_port = this_block.port('dout');
  dout_port.setType('UFix_1_0');
  dout_port.useHDLVector(false);

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.

    if (this_block.port('din').width ~= 1);
      this_block.setError('Input data type for port "din" must have width=1.');
    end

    din_port.setType('UFix_1_0');
    din_port.useHDLVector(false);

  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  uniqueInputRates = unique(this_block.getInputRates);

  this_block.addGeneric('g_delay','natural',delay_len);

  this_block.addFileToLibrary([filepath '/../../casper_delay/window_delay.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../casper_delay/sync_delay.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../misc/edge_detect.vhd'],'casper_misc_lib');
  this_block.addFileToLibrary([filepath '/../../casper_counter/common_counter.vhd'],'casper_counter_lib');
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

