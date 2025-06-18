
function delay_bram_prog_dp_config(this_block)

  function boolval =  checkbox2bool(bxval)
    if strcmp(bxval, 'on')
     boolval= true;
    elseif strcmp(bxval, 'off')
     boolval= false;
    end 
  end

  filepath = fileparts(which('delay_bram_prog_dp_config'));
  this_block.setTopLevelLanguage('VHDL');
  delay_bram_prog_dp_blk = this_block.blockName;
  delay_bram_prog_dp_blk_parent = get_param(delay_bram_prog_dp_blk,'Parent');
  this_block.setEntityName('delay_bram_prog_dp');

  this_block.tagAsCombinational;

  is_async = checkbox2bool(get_param(delay_bram_prog_dp_blk_parent,'is_async'));
  max_delay = get_param(delay_bram_prog_dp_blk_parent,'max_delay');
  bram_latency = get_param(delay_bram_prog_dp_blk_parent,'bram_latency');
  bram_primitive = get_param(delay_bram_prog_dp_blk_parent,'bram_primitive');

  this_block.addSimulinkInport('din');
  din_port = this_block.port('din');
  this_block.addSimulinkInport('delay');
  delay_port = this_block.port('delay');
  
  if(is_async)
    this_block.addSimulinkInport('en');
    en_port = this_block.port('en');
    en_port.useHDLVector(false);
  end

  this_block.addSimulinkOutport('dout');
  dout_port = this_block.port('dout');

  % -----------------------------
  if (this_block.inputTypesKnown)
    dout_port.setWidth(din_port.width);
  end  % if(inputTypesKnown)

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  this_block.addGeneric('g_max_delay','NATURAL',max_delay);
  this_block.addGeneric('g_ram_primitive','STRING',bram_primitive);
  this_block.addGeneric('g_ram_latency','NATURAL',bram_latency);
  
  this_block.addFileToLibrary([filepath '/../../casper_delay/delay_bram_prog_dp.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_adder/common_add_sub.vhd'],'casper_adder_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_components_pkg.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_counter/free_run_counter.vhd'],'casper_counter_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_delay.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_pkg.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_component_pkg.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../technology/technology_select_pkg.vhd'],'technology_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_ram_crw_crw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_ram_cr_cw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_crw_crw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_rw_rw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/ram/ip_xpm_ram_cr_cw.vhd'],'ip_xpm_ram_lib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/ram/ip_xpm_ram_crw_crw.vhd'],'ip_xpm_ram_lib');
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

