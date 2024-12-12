%% A Simulink wrapper the HDL CASPER power.
%% @author: Talon Myburgh
%% @company: Mydon Solutions
function power_config(this_block)

  function boolval =  checkbox2bool(bxval)
    if strcmp(bxval, 'on')
     boolval= true;
    elseif strcmp(bxval, 'off')
     boolval= false;
    end 
  end

  function strboolval = bool2str(bval)
    if bval
        strboolval = '"YES"';
    elseif ~bval
        strboolval = '"NO"';
    end
  end

  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName('power');
  filepath = fileparts(which('power_config'));
  this_block.setEntityName('power');
  power = this_block.blockName;
  power_parent = get_param(power, 'Parent');

  bit_w = get_param(power_parent, 'BitWidth');
  dbl_bit_w = str2double(bit_w);
  add_latency = get_param(power_parent, 'add_latency');
  dbl_add_latency = str2double(add_latency);
  mult_latency = get_param(power_parent, 'mult_latency');
  dbl_mult_latency = str2double(mult_latency);
  use_dsp = checkbox2bool(get_param(power_parent, 'use_dsp'));
  use_dsp_str = bool2str(use_dsp);

  if dbl_add_latency + dbl_mult_latency == 0
    this_block.tagAsCombinational;
  end

  this_block.addSimulinkInport('din');
  din_port = this_block.port('din');
  this_block.addSimulinkOutport('dout');
  dout_port = this_block.port('dout');

  % -----------------------------
  if (this_block.inputTypesKnown)
    din_width = din_port.width;
    din_port.setType(sprintf('Ufix_%d_%d',din_width,0));
    dout_port.setType(sprintf('Ufix_%d_%d',din_width+1,0));
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

    uniqueInputRates = unique(this_block.getInputRates);

  this_block.addGeneric('g_bit_width_in','NATURAL',bit_w);
  this_block.addGeneric('g_add_latency','NATURAL',add_latency);
  this_block.addGeneric('g_mult_latency','NATURAL',mult_latency);
  this_block.addGeneric('g_use_dsp','STRING',use_dsp_str);

  this_block.addFileToLibrary([filepath '/../../misc/power.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../misc/c_to_ri.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../misc/concat.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/common_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_mult_component.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/mult/ip_mult_infer.vhd'],'ip_xpm_mult_lib');
  this_block.addFileToLibrary([filepath '/../../casper_adder/common_add_sub.vhd'],'casper_adder_lib');
  this_block.addFileToLibrary([filepath '/../../technology/technology_select_pkg.vhd'],'technology_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline_sl.vhd'], 'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline.vhd'], 'common_components_lib');
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

