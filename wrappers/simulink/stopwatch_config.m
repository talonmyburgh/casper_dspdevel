%% A Simulink wrapper the HDL CASPER stopwatch.
%% @author: Talon Myburgh
%% @company: Mydon Solutions
function stopwatch_config(this_block)

  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName('stopwatch');
  filepath = fileparts(which('stopwatch_config'));
  this_block.setEntityName('stopwatch');
  stopwatch = this_block.blockName;
  stopwatch_parent = get_param(stopwatch, 'Parent');

  this_block.addSimulinkInport('start');
  this_block.addSimulinkInport('stop');
  this_block.addSimulinkInport('reset');
  this_block.addSimulinkOutport('count');

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.
    
    if (this_block.port('start').width ~= 1);
      this_block.setError('Input data type for port "start" must have width=1.');
    end
    this_block.port('start').useHDLVector(false);

    if (this_block.port('stop').width ~= 1);
      this_block.setError('Input data type for port "stop" must have width=1.');
    end
    this_block.port('stop').useHDLVector(false);

    if (this_block.port('reset').width ~= 1);
      this_block.setError('Input data type for port "reset" must have width=1.');
    end
    this_block.port('reset').useHDLVector(false);

    count_port = this_block.port('count');
    count_port.setType('Ufix_32_0');
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  uniqueInputRates = unique(this_block.getInputRates);

  this_block.addFileToLibrary([filepath '/../../misc/stopwatch.vhd'],'xil_defaultlib');
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

