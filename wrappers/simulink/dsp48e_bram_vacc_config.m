
function dsp48e_bram_vacc_config(this_block)

  this_block.setTopLevelLanguage('VHDL');

  this_block.setEntityName('dsp48e_bram_vacc');
  filepath = fileparts(which('dsp48e_bram_vacc_config'));

  function boolval =  checkbox2bool(bxval)
    if strcmp(bxval, 'on')
     boolval= true;
    elseif strcmp(bxval, 'off')
     boolval= false;
    end 
  end
  function strboolval = bool2sign(bval)
    if bval
        strboolval = '"SIGNED"';
    elseif ~bval
        strboolval = '"UNSIGNED"';
    end
  end

  dsp48e_bram_vacc_blk = this_block.blockName;
  dsp48e_bram_vacc_blk_parent = get_param(dsp48e_bram_vacc_blk,'Parent');

  %Extract block parameters
  vector_length = get_param(dsp48e_bram_vacc_blk_parent,'vector_length');
  is_signed = checkbox2bool(get_param(dsp48e_bram_vacc_blk_parent,'arith_type'));
  output_bit_w = get_param(dsp48e_bram_vacc_blk_parent,'n_bits_out');
  output_bin_pt = get_param(dsp48e_bram_vacc_blk_parent,'bin_pt_out');
  dspversion = get_param(dsp48e_bram_vacc_blk_parent,'dsp_version');

  this_block.addSimulinkInport('new_acc');
  new_acc_port = this_block.port('new_acc');

  this_block.addSimulinkInport('din');

  this_block.addSimulinkOutport('valid');
  valid_port = this_block.port('valid');
  valid_port.setType('Ufix_1_0');
  valid_port.useHDLVector(false);

  this_block.addSimulinkOutport('dout');
  dout_port = this_block.port('dout');
  if is_signed
    dout_port.setType(sprintf('Fix_%s_%s',output_bit_w,output_bin_pt))
  else
    dout_port.setType(sprintf('Ufix_%s_%s',output_bit_w,output_bin_pt))
  end

  valid_port = this_block.port('valid');
  valid_port.setType('UFix_1_0');
  valid_port.useHDLVector(false);

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.
    if (new_acc_port.width ~= 1)
      this_block.setError('Input data type for port "new_acc" must have width=1.');
    end
    new_acc_port.setType('Ufix_1_0');
    new_acc_port.useHDLVector(false);
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------
  is_signed_str = bool2sign(is_signed);
  this_block.addGeneric('g_vector_length','NATURAL',vector_length);
  this_block.addGeneric('g_output_type','STRING',is_signed_str);
  this_block.addGeneric('g_bit_w','NATURAL',output_bit_w);
  this_block.addGeneric('g_dsp48_version','NATURAL',dspversion);

  this_block.addFileToLibrary([filepath '/../../casper_accumulators/dsp48e_bram_vacc.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../misc/edge_detect.vhd'],'casper_misc_lib');
  this_block.addFileToLibrary([filepath '/../../casper_counter/free_run_up_counter.vhd'],'casper_counter_lib');
  this_block.addFileToLibrary([filepath '/../../misc/pulse_ext.vhd'],'casper_misc_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_pkg.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_counter/common_counter.vhd'],'casper_counter_lib');
  this_block.addFileToLibrary([filepath '/../../technology/technology_select_pkg.vhd'],'technology_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_component_pkg.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_ram_crw_crw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_ram_cr_cw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_crw_crw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_rw_rw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_r_w.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_delay/delay_bram.vhd'],'casper_delay_lib');
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

