%% A Simulink wrapper the HDL CASPER complex_convert.
%% @author: Talon Myburgh
%% @company: Mydon Solutions

function complex_convert_config(this_block)

  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName('complex_convert');
  filepath = fileparts(which('complex_convert_config'));

  this_block.setEntityName('complex_convert');
  complex_convert = this_block.blockName;
  complex_convert_parent = get_param(complex_convert, 'Parent');

  function clip_bool = str2clipbool(clip_str)
    if strcmp(clip_str, 'Wrap')
      clip_bool = 'TRUE';
    else
      clip_bool = 'FALSE';
    end
  end

  function quantstr = str2quant(quant_str)
    if strcmp(quant_str, 'Round  (unbiased: +/- Inf)')
      quantstr = '"ROUND"';
    elseif strcmp(quant_str, 'Truncate')
      quantstr = '"TRUNCATE"';
    else
      quantstr = '"ROUNDINF"';
    end
  end

  bitwidth_in = get_param(complex_convert_parent, 'n_bits_in');
  bitwidth_in_dbl = str2double(bitwidth_in);
  bitwidth_out = get_param(complex_convert_parent, 'n_bits_out');
  bitwidth_out_dbl = str2double(bitwidth_out);
  quant_style = get_param(complex_convert_parent, 'quantization');
  quant = str2quant(quant_style);
  overflow_style = get_param(complex_convert_parent, 'overflow');
  clip = str2clipbool(overflow_style);
  latency = get_param(complex_convert_parent, 'csp_latency');
  latency_dbl = str2double(latency);

  % Create output type:
  type_input = sprintf('Ufix_%d_%d', 2*bitwidth_in_dbl, 0);
  type_output = sprintf('Ufix_%d_%d', 2*bitwidth_out_dbl, 0);

  if latency_dbl == 0
    this_block.tagAsCombinational;
  end

  this_block.addSimulinkInport('din');
  din = this_block.port('din');
  din.setType(type_input);

  this_block.addSimulinkOutport('dout');
  dout = this_block.port('dout');
  dout.setType(type_output);

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  this_block.addGeneric('g_bit_width_in','NATURAL',bitwidth_in);
  this_block.addGeneric('g_bit_width_out','NATURAL',bitwidth_out);
  this_block.addGeneric('g_quantization','STRING',quant);
  this_block.addGeneric('g_clip','BOOLEAN',clip);
  this_block.addGeneric('g_latency','NATURAL',latency);

  this_block.addFileToLibrary([filepath '/../../misc/complex_convert.vhd'],'xil_default_lib');
  this_block.addFileToLibrary([filepath '/../../misc/c_to_ri.vhd'],'xil_default_lib');
  this_block.addFileToLibrary([filepath '/../../misc/ri_to_c.vhd'],'xil_default_lib');
  this_block.addFileToLibrary([filepath '/../../misc/concat.vhd'],'xil_default_lib');
  this_block.addFileToLibrary([filepath '/../../casper_delay/delay_simple.vhd'],'casper_delay_lib');
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

