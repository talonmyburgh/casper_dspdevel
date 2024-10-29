%% A Simulink wrapper the HDL CASPER convert.
%% @author: Talon Myburgh
%% @company: Mydon Solutions
function convert_config(this_block)

  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName('convert');
  filepath = fileparts(which('convert_config'));
  this_block.setEntityName('convert');
  convert = this_block.blockName;
  convert_parent = get_param(convert, 'Parent');

  function quantstr = str2quant(quant_str)
    if strcmp(quant_str, 'Round  (unbiased: +/- Inf)')
      quantstr = '"ROUND"';
    elseif strcmp(quant_str, 'Truncate')
      quantstr = '"TRUNCATE"';
    else
      quantstr = '"ROUNDINF"';
    end
  end

  i_bin_pt = get_param(convert_parent, 'bin_pt_in');
  i_bin_pt_dbl = str2double(i_bin_pt);
  o_bit_w = get_param(convert_parent, 'n_bits_out');
  o_bit_w_dbl = str2double(o_bit_w);
  o_bin_pt = get_param(convert_parent, 'bin_pt_out');
  o_bin_pt_dbl = str2double(o_bin_pt);
  quant = get_param(convert_parent, 'quantization');
  quant_str = str2quant(quant);
  lat = get_param(convert_parent, 'csp_latency');
  dbl_lat = str2double(lat);

  if dbl_lat == 0
    this_block.tagAsCombinational;
  end

  this_block.addSimulinkInport('din');
  din_port = this_block.port('din');
  this_block.addSimulinkOutport('dout');
  dout_port = this_block.port('dout');

  % -----------------------------
  if (this_block.inputTypesKnown)
    if o_bit_w_dbl < o_bin_pt_dbl
      this_block.setError('Output bit width must be greater than or equal to the output binary point.');
    end
    if i_bin_pt_dbl < o_bin_pt_dbl
      this_block.setError('Does not support upscaling number of fractional bits.');
    end
    i_bit_w = din_port.width;
    din_port.setType(sprintf('Ufix_%d_%d',i_bit_w,i_bin_pt_dbl));
    dout_port.setType(sprintf('Fix_%d_%d',o_bit_w_dbl,o_bin_pt_dbl));
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

    uniqueInputRates = unique(this_block.getInputRates);

  this_block.addGeneric('g_bin_point_in','NATURAL',i_bin_pt);
  this_block.addGeneric('g_out_bitwidth','NATURAL',o_bit_w);
  this_block.addGeneric('g_bin_point_out','NATURAL',o_bin_pt);
  this_block.addGeneric('g_quantization','STRING',quant_str);
  this_block.addGeneric('g_latency','NATURAL',lat);

  this_block.addFileToLibrary([filepath '/../../misc/convert.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_str_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../casper_adder/common_add_sub.vhd'],'casper_adder_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline.vhd'], 'common_components_lib');

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

