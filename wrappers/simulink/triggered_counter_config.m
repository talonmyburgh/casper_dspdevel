%% A Simulink wrapper the HDL CASPER triggered counter.
%% @author: Talon Myburgh
%% @company: Mydon Solutions
function triggered_cntr_config(this_block)

  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName('triggered_cntr');
  filepath = fileparts(which('triggered_counter_config'));
  this_block.setEntityName('triggered_cntr');
  triggered_cntr = this_block.blockName;
  triggered_cntr_parent = get_param(triggered_cntr, 'Parent');

  run_len = get_param(triggered_cntr_parent, 'len');
  run_len_dbl = str2double(run_len);
  count_bit_w = nextpow2(run_len_dbl);

  this_block.addSimulinkInport('trig');

  this_block.addSimulinkOutport('count');
  this_block.addSimulinkOutport('valid');

  valid_port = this_block.port('valid');
  valid_port.setType('Ufix_1_0');
  valid_port.useHDLVector(false);

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.

    if (this_block.port('trig').width ~= 1);
      this_block.setError('Input data type for port "trig" must have width=1.');
    end
    this_block.port('trig').useHDLVector(false);

    count_port = this_block.port('count');
    count_port.setType(sprintf('Ufix_%d_0',count_bit_w));
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  uniqueInputRates = unique(this_block.getInputRates);

  this_block.addGeneric('g_run_length','NATURAL',run_len);

  this_block.addFileToLibrary([filepath '/../../misc/triggered_counter.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../misc/edge_detect.vhd'],'xil_defaultlib');
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

