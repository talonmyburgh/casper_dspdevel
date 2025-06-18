function reorder_config(this_block)
  filepath = fileparts(which('reorder_config'));

  % this_block.tagAsCombinational;
  reorder_blk = this_block.blockName;
  reorder_blk_parent = get_param(reorder_blk,'Parent');
  reorder_blk_parent_name = get_param(reorder_blk_parent,'Name');

  inout_port_count = str2double(get_param(reorder_blk_parent, 'number_of_ports'));
  inout_port_bit_width = str2double(get_param(reorder_blk_parent, 'port_bit_width'));
  map_latency = get_param(reorder_blk_parent, 'map_latency');
  bram_latency = get_param(reorder_blk_parent, 'bram_latency');
  fanout_latency = get_param(reorder_blk_parent, 'fanout_latency');
  use_block_ram = checkbox2bool(get_param(reorder_blk_parent,'block_ram'));
  use_double_buffer = checkbox2bool(get_param(reorder_blk_parent,'double_buffer'));
  use_software_control = checkbox2bool(get_param(reorder_blk_parent,'software_control'));
  reorder_str = get_param(reorder_blk_parent,'reorder'); % vector of zero-indexed indices that effect the reordering
  reorder_str = regexprep(reorder_str, '[^\[\]\d,]', '');
  reorder = eval(reorder_str);

  % test reorder index vector
  indices_mapped = repelem([false], length(reorder));
  for i = 1:length(reorder)
    index = reorder(i);
    indices_mapped(index+1) = true;
  end
  % if (~all(indices_mapped))
  %   % this_block.setError(sprintf('%d :%s: %s.', length(reorder), strjoin(string(reorder), ', '), strjoin(string(indices_mapped), ', ')));
  %   this_block.setError(sprintf('Reorder map must map all indices. Indices were missed: %s.', strjoin(string(indices_mapped), ', ')));
  % end

  [vhdlfile, memfile, entityname] = reorder_code_gen(reorder_blk_parent_name, inout_port_count, inout_port_bit_width, reorder);
  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName(entityname);

  %Input signals
  this_block.addSimulinkInport('i_sync');
  i_sync_port = this_block.port('i_sync');
  i_sync_port.setType('Ufix_1_0');
  i_sync_port.useHDLVector(false);
  
  this_block.addSimulinkInport('i_en');
  i_en_port = this_block.port('i_en');
  i_en_port.setType('Ufix_1_0');
  i_en_port.useHDLVector(false);
  
  %Output signals
  this_block.addSimulinkOutport('o_sync');
  o_sync_port = this_block.port('o_sync');
  o_sync_port.setType('Ufix_1_0');
  o_sync_port.useHDLVector(false);

  this_block.addSimulinkOutport('o_valid');
  o_valid_port = this_block.port('o_valid');
  o_valid_port.setType('Ufix_1_0');
  o_valid_port.useHDLVector(false);

  %Data ports
  for data_i = 1:inout_port_count
    port_name = sprintf('i_data_%d',data_i-1);
    this_block.addSimulinkInport(port_name);

    port_name = sprintf('o_data_%d',data_i-1);
    this_block.addSimulinkOutport(port_name);
  end

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.

    for data_i = 1:inout_port_count
      port_name = sprintf('i_data_%d',data_i-1);
      i_data_port = this_block.port(port_name);
      if (i_data_port.width ~= inout_port_bit_width)
        this_block.setError(sprintf('Input data type for port "%s" must have width=%d.', port_name, inout_port_bit_width));
      end

      port_name = sprintf('o_data_%d',data_i-1);
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
  this_block.addGeneric('g_map_latency','NATURAL',map_latency);
  this_block.addGeneric('g_bram_latency','NATURAL',bram_latency);
  this_block.addGeneric('g_fanout_latency','NATURAL',fanout_latency);
  this_block.addGeneric('g_double_buffer','BOOLEAN',bool2str(use_block_ram));
  this_block.addGeneric('g_block_ram','BOOLEAN',bool2str(use_double_buffer));
  this_block.addGeneric('g_software_controlled','BOOLEAN',bool2str(use_software_control));

  %Add Files:
  if memfile ~= "UNUSED" 
    this_block.addFileToLibrary(memfile, 'xil_defaultlib');
  end
  this_block.addFileToLibrary(vhdlfile, 'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'], 'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'], 'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/float_pkg_c.vhd'], 'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'], 'common_pkg_lib');

  this_block.addFileToLibrary([filepath '/../../common_slv_arr_pkg/common_slv_arr_pkg.vhd'], 'common_slv_arr_pkg_lib');

  this_block.addFileToLibrary([filepath '/../../casper_delay/delay_simple.vhd'], 'casper_delay_lib');
  this_block.addFileToLibrary([filepath '/../../casper_delay/delay_bram_en_plus.vhd'], 'casper_delay_lib');
  
  this_block.addFileToLibrary([filepath '/../../common_components/common_components_pkg.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_delay.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline_sl.vhd'],'common_components_lib');

  this_block.addFileToLibrary([filepath '/../../technology/technology_select_pkg.vhd'],'technology_lib');
  
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_pkg.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_component_pkg.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_ram_crw_crw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_ram_cr_cw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_rom_r_r.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_rom_r.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_crw_crw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_rw_rw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_r_w.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_rom_r_r.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_rom_r.vhd'],'casper_ram_lib');

  this_block.addFileToLibrary([filepath '/../../casper_counter/free_run_counter.vhd'], 'casper_counter_lib');
  this_block.addFileToLibrary([filepath '/../../casper_counter/common_counter.vhd'], 'casper_counter_lib');

  this_block.addFileToLibrary([filepath '/../../casper_bus/bus_fill_slv_arr.vhd'], 'casper_bus_lib');
  
  this_block.addFileToLibrary([filepath '/../../misc/sync_delay_en.vhd'], 'casper_misc_lib');
  this_block.addFileToLibrary([filepath '/../../misc/edge_detect.vhd'], 'casper_misc_lib');
  this_block.addFileToLibrary([filepath '/../../misc/reg.vhd'], 'casper_misc_lib');
  
  this_block.addFileToLibrary([filepath '/../../casper_reorder/mux.vhd'], 'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../casper_reorder/dbl_buffer.vhd'], 'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../casper_reorder/reorder.vhd'], 'xil_defaultlib');
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

