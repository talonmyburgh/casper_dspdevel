
function complex_addsub_config(this_block)

  this_block.setTopLevelLanguage('VHDL');

  this_block.setEntityName('complex_addsub');
  filepath = fileparts(which('complex_addsub_config'));

  complex_addsub = this_block.blockName;
  complex_addsub_parent = get_param(complex_addsub, 'Parent');

  % System Generator has to assume that your entity  has a combinational feed through; 
  %   if it  doesn't, then comment out the following line:
  bitwidth = get_param(complex_addsub_parent, 'bitwidth');
  dbl_bitwidth = str2double(bitwidth);
  add_latency = get_param(complex_addsub_parent, 'add_latency');
  

  this_block.addSimulinkInport('a');
  this_block.addSimulinkInport('b');

  this_block.addSimulinkOutport('a_plus_b');
  a_plus_b = this_block.port('a_plus_b');
  this_block.addSimulinkOutport('a_minus_b');
  a_minus_b = this_block.port('a_minus_b');

  dout_type = sprintf('Ufix_%d_0',2*dbl_bitwidth);
  % -----------------------------
  if (this_block.inputTypesKnown)
    a_plus_b.setType(dout_type);
    a_minus_b.setType(dout_type);
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  uniqueInputRates = unique(this_block.getInputRates);

  this_block.addGeneric('g_bit_width','NATURAL',bitwidth);
  this_block.addGeneric('g_add_latency','NATURAL',add_latency);

  this_block.addFileToLibrary([filepath '/../../misc/complex_addsub.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../misc/c_to_ri.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../misc/ri_to_c.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../misc/concat.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_str_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../casper_adder/common_add_sub.vhd'],'casper_adder_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline.vhd'], 'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_delay/delay_simple.vhd'],'casper_delay_lib');

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

