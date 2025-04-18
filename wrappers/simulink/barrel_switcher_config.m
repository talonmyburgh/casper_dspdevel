function barrel_switcher_config(this_block)
  filepath = fileparts(which('barrel_switcher_config'));

  % this_block.tagAsCombinational;
  barrel_switcher_blk = this_block.blockName;
  barrel_switcher_blk_parent = get_param(barrel_switcher_blk,'Parent');
  barrel_switcher_blk_parent_name = get_param(barrel_switcher_blk_parent,'Name');

  inout_port_count = 2^str2double(get_param(barrel_switcher_blk_parent, 'number_of_ports_2exp'));
  inout_port_bit_width = str2double(get_param(barrel_switcher_blk_parent, 'port_bit_width'));
  is_async = checkbox2bool(get_param(barrel_switcher_blk_parent,'async'));

  [vhdlfile, entityname] = barrel_switcher_code_gen(barrel_switcher_blk_parent_name, inout_port_count, inout_port_bit_width);
  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName(entityname);

  %Control signals
  this_block.addSimulinkInport('i_sel');
  i_sel_port = this_block.port('i_sel');
  i_sel_port_type = sprintf('Ufix_%d_0', ceil(log2(inout_port_count)));
  i_sel_port.setType(i_sel_port_type);
  
  this_block.addSimulinkInport('i_sync');
  i_sync_port = this_block.port('i_sync');
  i_sync_port.setType('Ufix_1_0');
  i_sync_port.useHDLVector(false);

  this_block.addSimulinkOutport('o_sync');
  o_sync_port = this_block.port('o_sync');
  o_sync_port.setType('Ufix_1_0');
  o_sync_port.useHDLVector(false);

  %Data ports
  for data_i = 1:inout_port_count
    port_name = sprintf('i_data_%d',data_i);
    this_block.addSimulinkInport(port_name);

    port_name = sprintf('o_data_%d',data_i);
    this_block.addSimulinkOutport(port_name);
  end

  if is_async
    this_block.addSimulinkInport('en');
    en_port = this_block.port('en');
    en_port.setType('Ufix_1_0');
    en_port.useHDLVector(false);

    this_block.addSimulinkOutport('dvalid');
    dvalid_port = this_block.port('dvalid');
    dvalid_port.setType('Ufix_1_0');
    dvalid_port.useHDLVector(false);
  end


  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.

    for data_i = 1:inout_port_count
      port_name = sprintf('i_data_%d',data_i);
      i_data_port = this_block.port(port_name);
      if (i_data_port.width ~= inout_port_bit_width)
        this_block.setError(sprintf('Input data type for port "%s" must have width=%d.', port_name, inout_port_bit_width));
      end

      port_name = sprintf('o_data_%d',data_i);
      o_data_port = this_block.port(port_name);
      o_data_port.setWidth(inout_port_bit_width);
    end
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
  if (this_block.inputRatesKnown)
    setup_as_single_rate(this_block,'clk','ce');
  end  % if(inputRatesKnown)
  % -----------------------------

  %Generics
  this_block.addGeneric('g_async','BOOLEAN',bool2str(is_async));

  %Add Files:
  this_block.addFileToLibrary(vhdlfile, 'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'], 'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'], 'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'], 'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_slv_arr_pkg/common_slv_arr_pkg.vhd'], 'common_slv_arr_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../casper_delay/delay_simple.vhd'], 'casper_delay_lib');
  this_block.addFileToLibrary([filepath '/../../casper_reorder/mux.vhd'], 'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../casper_reorder/barrel_switcher.vhd'], 'xil_defaultlib');
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

