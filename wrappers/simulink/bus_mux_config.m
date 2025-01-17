function bus_mux_config(this_block)
  filepath = fileparts(which('bus_mux_config'));

  % this_block.tagAsCombinational;
  bus_mux_blk = this_block.blockName;
  bus_mux_blk_parent = get_param(bus_mux_blk,'Parent');
  bus_mux_blk_parent_name = get_param(bus_mux_blk_parent,'Name');

  nof_inputs = str2double(get_param(bus_mux_blk_parent, 'number_of_inputs'));
  bit_width = str2double(get_param(bus_mux_blk_parent, 'bit_width'));
  delay = str2double(get_param(bus_mux_blk_parent, 'delay'));
  if delay == 0
    % Inform System Generator that the entity has a combinational feed through; 
    this_block.tagAsCombinational;
  end

  [vhdlfile, entityname] = bus_mux_code_gen(bus_mux_blk_parent_name, nof_inputs, bit_width, delay);
  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName(entityname);

  %Output signals
  this_block.addSimulinkOutport('o_data');
  o_data_port = this_block.port('o_data');
  data_port_type = sprintf('Ufix_%d_0', bit_width);
  o_data_port.setType(data_port_type);

  this_block.addSimulinkInport('i_sel');
  i_sel_port = this_block.port('i_sel');
  i_sel_port_type = sprintf('Ufix_%d_0', ceil(log2(nof_inputs)));
  i_sel_port.setType(i_sel_port_type);

  %Data ports
  for data_i = 1:nof_inputs
    port_name = sprintf('i_data_%d',data_i);
    this_block.addSimulinkInport(port_name);
    i_data_port = this_block.port(port_name);
    i_data_port.setType(data_port_type);
  end

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.

    for data_i = 1:nof_inputs
      port_name = sprintf('i_data_%d',data_i);
      i_data_port = this_block.port(port_name);
      if (i_data_port.width ~= bit_width)
        this_block.setError(sprintf('Input data type for port "%s" must have width=%d.', port_name, bit_width));
      end
    end

    o_data_port.setWidth(bit_width);
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
  if (this_block.inputRatesKnown)
    setup_as_single_rate(this_block,'clk','ce');
  end  % if(inputRatesKnown)
  % -----------------------------

  %Generics
  this_block.addGeneric('g_delay','NATURAL',sprintf('%d', delay));

  %Add Files:
  this_block.addFileToLibrary(vhdlfile, 'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'], 'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'], 'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'], 'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_slv_arr_pkg/common_slv_arr_pkg.vhd'], 'common_slv_arr_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../casper_delay/delay_simple.vhd'], 'casper_delay_lib');
  this_block.addFileToLibrary([filepath '/../../casper_bus/bus_mux.vhd'], 'casper_bus');
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

