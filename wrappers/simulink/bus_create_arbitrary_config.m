
function bus_create_arbitrary_config(this_block)
  filepath = fileparts(which('bus_create_arbitrary_config'));
  this_block.setTopLevelLanguage('VHDL');

  % this_block.tagAsCombinational;
  this_block.setEntityName('bus_create_arbitrary');
  bus_create_blk = this_block.blockName;
  bus_create_blk_parent = get_param(bus_create_blk,'Parent');
  
  input_bit_widths = get_param(bus_create_blk_parent,'bit_widths');
  input_bit_widths = strrep(input_bit_widths, '"', '');
  input_bit_widths = str2double(regexp(input_bit_widths,'\d+','match'));

  vhdlfile = bus_create_arbitrary_code_gen(input_bit_widths);

  %Output signals
  this_block.addSimulinkOutport('o_data');
  o_data_port = this_block.port('o_data');

  %Input signals
  for i_data_i = 1:length(input_bit_widths)
    port_name = sprintf('i_data_%d',i_data_i);
    this_block.addSimulinkInport(port_name);
  end

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.
    o_data_port.setWidth(sum(input_bit_widths));
    
    for i_data_i = 1:length(input_bit_widths)
      port_name = sprintf('i_data_%d',i_data_i)
      i_data_port = this_block.port(port_name);
      if (i_data_port.width ~= input_bit_widths(i_data_i))
        this_block.setError(sprintf('Input data type for port "%s" must have width=%d.', port_name, input_bit_widths(i_data_i)));
      end
    end
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce');
   end  % if(inputRatesKnown)
  % -----------------------------

  this_block.addFileToLibrary(vhdlfile,'xil_defaultlib');
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

