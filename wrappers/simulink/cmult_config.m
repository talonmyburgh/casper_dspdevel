function cmult_config(this_block)

  this_block.setTopLevelLanguage('VHDL');

  this_block.setEntityName('cmult');
  filepath = fileparts(which('cmult_config'));
  
  function boolval =  checkbox2bool(bxval)
    if strcmp(bxval, 'on')
     boolval= true;
    elseif strcmp(bxval, 'off')
     boolval= false;
    end 
  end
  function strval = bool2str(boolval)
    if boolval
        strval = 'TRUE';
    else
        strval = 'FALSE';
    end
  end
    function nat = quant2nat(quant)
       if strcmp(quant,"Truncate")
           nat = '0';
       elseif strcmp(quant,"Round-Even")
           nat = '1';
       else
           nat = '2';
       end
    end
    function boolstr = str_clip(ovflw)
       if strcmp(ovflw,"Wrap")
           boolstr = 'FALSE';
       else
           boolstr = 'TRUE';
       end
    end

  cmult_blk = this_block.blockName;
  cmult_parent = get_param(cmult_blk,'Parent');
  %Extract block parameters
  in_a_bw = get_param(cmult_parent, 'in_a_bw');
  in_b_bw = get_param(cmult_parent, 'in_b_bw');
  out_ab_bw = get_param(cmult_parent, 'out_ab_bw');
  out_ab_bp = get_param(cmult_parent, 'out_ab_bp');
  quant_method = quant2nat(get_param(cmult_parent, 'quant_method'));
  ovflw_method = str_clip(get_param(cmult_parent, 'ovflw_method'));
  conjugate = checkbox2bool(get_param(cmult_parent, 'conjugate'));
  pipeline_input = get_param(cmult_parent, 'pipeline_input');
  pipeline_product = get_param(cmult_parent, 'pipeline_product');
  pipeline_adder = get_param(cmult_parent, 'pipeline_adder');
  pipeline_output = get_param(cmult_parent, 'pipeline_output');
  pipeline_round = get_param(cmult_parent, 'pipeline_round');
  use_gauss = checkbox2bool(get_param(cmult_parent, 'use_gauss'));
  use_ip = checkbox2bool(get_param(cmult_parent, 'use_ip'));
  use_dsp = checkbox2bool(get_param(cmult_parent, 'use_dsp'));
  
  this_block.addSimulinkInport('rst');
  rst_port = this_block.port('rst');
  
  this_block.addSimulinkInport('in_a');
  in_a_port = this_block.port('in_a');
  this_block.addSimulinkInport('in_b');
  in_b_port = this_block.port('in_b');
  
  this_block.addSimulinkInport('in_val');
  in_val_port = this_block.port('in_val');

  this_block.addSimulinkOutport('out_ab');
  out_ab_port = this_block.port('out_ab');
  out_ab_port.setType(sprintf('Ufix_%d_0',2*str2double(out_ab_bw)));
  
  this_block.addSimulinkOutport('out_val');
  out_val_port = this_block.port('out_val');
  
  out_val_port.setType('Ufix_1_0');
  out_val_port.useHDLVector(false);
  
  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.

    if (rst_port.width ~= 1)
      this_block.setError('Input data type for port "rst" must have width=1.');
    end
    rst_port.useHDLVector(false);

    if in_a_port.getWidth ~= 2*str2double(in_a_bw)
      this_block.setError(sprintf('Input data width for port "in_a" must be %d.',2*str2double(in_a_bw)));
    end
    if in_b_port.getWidth ~= 2*str2double(in_b_bw)
      this_block.setError(sprintf('Input data width for port "in_b" must be %d.',2*str2double(in_b_bw)));
    end
    if (in_val_port.width ~= 1)
      this_block.setError('Input data type for port "in_val" must have width=1.');
    end
    in_val_port.useHDLVector(false);
    
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  this_block.addGeneric('g_use_ip','BOOLEAN',bool2str(use_ip));
  this_block.addGeneric('g_a_bw','NATURAL',in_a_bw);
  this_block.addGeneric('g_b_bw','NATURAL',in_b_bw);
  this_block.addGeneric('g_ab_bw','NATURAL',out_ab_bw);
  this_block.addGeneric('g_conjugate_b','BOOLEAN',bool2str(conjugate));
  this_block.addGeneric('g_use_gauss','BOOLEAN',bool2str(use_gauss));
  this_block.addGeneric('g_use_dsp','BOOLEAN',bool2str(use_dsp));
  this_block.addGeneric('g_round_method','NATURAL',quant_method);
  this_block.addGeneric('g_ovflw_method','BOOLEAN',ovflw_method);
  this_block.addGeneric('g_pipeline_input','NATURAL',pipeline_input);
  this_block.addGeneric('g_pipeline_product','NATURAL',pipeline_product);
  this_block.addGeneric('g_pipeline_adder','NATURAL',pipeline_adder);
  this_block.addGeneric('g_pipeline_round','NATURAL',pipeline_round);
  this_block.addGeneric('g_pipeline_output','NATURAL',pipeline_output);

  this_block.addFileToLibrary([filepath '/../../casper_multiplier/cmult.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/mult/ip_cmult_rtl_4dsp.vhd'],'ip_xpm_mult_lib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/mult/ip_cmult_rtl_3dsp.vhd'],'ip_xpm_mult_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/common_complex_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_complex_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_complex_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_str_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/common_complex_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_complex_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_agilex_versal_cmult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_mult_component.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline_sl.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../technology/technology_select_pkg.vhd'],'technology_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'],'common_pkg_lib');
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

