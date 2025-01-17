
function bus_accumulator_stringgenerics_config(this_block)

  filepath = fileparts(which('barrel_switcher_config'));

  % this_block.setTopLevelLanguage('VHDL');
  % this_block.setEntityName('bus_accumulator_stringgenerics');
  bus_acc_blk = this_block.blockName;
  bus_acc_blk_parent = get_param(bus_acc_blk,'Parent');

  input_bit_widths = get_param(bus_acc_blk_parent,'input_bit_widths');
  input_bit_widths = str2double(regexp(input_bit_widths,'\d+','match'));

  input_binary_points = get_param(bus_acc_blk_parent,'input_binary_points');
  input_binary_points = str2double(regexp(input_binary_points,'\d+','match'));

  output_bit_widths = get_param(bus_acc_blk_parent,'output_bit_widths');
  output_bit_widths = str2double(regexp(output_bit_widths,'\d+','match'));

  is_signed = checkbox2bool(get_param(bus_acc_blk_parent, 'en_enabled'));

  % if length(input_bit_widths) ~= length(input_binary_points)
  %   this_block.setError(sprintf('Number of input bit widths (%d) must match input binary points (%d) ', length(input_bit_widths), length(input_binary_points)));
  % end
  if length(input_bit_widths) ~= length(output_bit_widths)
    this_block.setError(sprintf('Number of output bit widths (%d) must match input bit widths (%d) ', length(output_bit_widths), length(input_bit_widths)));
  end

  this_block.addSimulinkInport('din');
  this_block.addSimulinkInport('rst');
  this_block.addSimulinkInport('en');

  this_block.addSimulinkOutport('dout');


  rst_port = this_block.port('rst');
  rst_port.setType('Bool');
  rst_port.useHDLVector(false);

  en_port = this_block.port('en');
  en_port.setType('Bool');
  en_port.useHDLVector(false);

  din_port = this_block.port('din');
  din_port.setWidth(sum(input_bit_widths));
  
  dout_port = this_block.port('dout');
  dout_port.setWidth(sum(output_bit_widths));

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.
    
  % --- you must add an appropriate type setting for this port
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

    uniqueInputRates = unique(this_block.getInputRates);

  % (!) Custimize the following generic settings as appropriate. If any settings depend
  %      on input types, make the settings in the "inputTypesKnown" code block.
  %      The addGeneric function takes  3 parameters, generic name, type and constant value.
  %      Supported types are boolean, real, integer and string.
  if is_signed
    this_block.addGeneric('g_data_type','string','"SIGNED"');
  else
    this_block.addGeneric('g_data_type','string','"UNSIGNED"');
  end


  input_bit_widths_str = strjoin(string(input_bit_widths), ',');
  input_bit_widths_str = sprintf('"%s"', input_bit_widths_str);
  output_bit_widths_str = strjoin(string(output_bit_widths), ',');
  output_bit_widths_str = sprintf('"%s"', output_bit_widths_str);
  this_block.addGeneric('g_bus_constituent_widths','string',input_bit_widths_str);
  this_block.addGeneric('g_bus_constituent_expansion_widths','string',output_bit_widths_str);

  % add files
  this_block.addFileToLibrary([filepath '/../../casper_bus/bus_accumulator_stringgenerics.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../casper_bus/bus_accumulator.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../casper_accumulators/simple_accumulator.vhd'],'casper_accumulators_lib');

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

