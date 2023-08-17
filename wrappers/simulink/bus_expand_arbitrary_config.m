
function bus_expand_arbitrary_config(this_block)
  filepath = fileparts(which('bus_expand_arbitrary_config'));
  this_block.setTopLevelLanguage('VHDL');

  % this_block.tagAsCombinational;
  this_block.setEntityName('bus_expand_arbitrary');
  bus_expand_blk = this_block.blockName;
  bus_expand_blk_parent = get_param(bus_expand_blk,'Parent');
  
  division_bit_widths = get_param(bus_expand_blk_parent,'bit_selections');
  division_bit_widths = strrep(division_bit_widths, '"', '');
  division_bit_widths = str2double(regexp(division_bit_widths,'\d+','match'));
  radix_points = get_param(bus_expand_blk_parent,'radix_points');
  radix_points = strrep(radix_points, '"', '');
  radix_points = str2double(regexp(radix_points,'\d+','match'));
  types = get_param(bus_expand_blk_parent,'types');
  types = strrep(types, '"', '');
  types = str2double(regexp(types,'\d+','match'));

  if length(division_bit_widths) ~= length(radix_points) || length(division_bit_widths) ~= length(types)
    this_block.setError(sprintf('Inconsistent number of values given.'));
  end

  vhdlfile = bus_expand_arbitrary_code_gen(division_bit_widths);

  %Input signals
  this_block.addSimulinkInport('i_data');
  i_data_port = this_block.port('i_data');

  %Output signals
  for o_data_i = 1:length(division_bit_widths)
    port_name = sprintf('o_data_%d',o_data_i);
    this_block.addSimulinkOutport(port_name);
  end

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.
    if (i_data_port.width ~= sum(division_bit_widths))
      this_block.setError(sprintf('Input data type for port "i_data" must have width=%d.', sum(division_bit_widths)));
    end
    
    for o_data_i = 1:length(division_bit_widths)
      port_name = sprintf('o_data_%d',o_data_i);
      o_data_port = this_block.port(port_name);
      o_data_port.setWidth(division_bit_widths(o_data_i));
      if types(o_data_i) == 0 % UFix
        str_o_dat_type = sprintf('UFix_%d_%d', division_bit_widths(o_data_i), radix_points(o_data_i));
        o_data_port.setType(str_o_dat_type);
      elseif types(o_data_i) == 1 % Fix
        str_o_dat_type = sprintf('Fix_%d_%d', division_bit_widths(o_data_i), radix_points(o_data_i))
        o_data_port.setType(str_o_dat_type)
      elseif types(o_data_i) == 2 % bool
        if (o_data_port.width ~= 1)
          this_block.setError(sprintf('Output port "%s" must have width 1 to be bool.', port_name));
        end
        o_data_port.setType('Bool');
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

