
function cross_multiplier_config(this_block)

  this_block.setTopLevelLanguage('VHDL');

  this_block.setEntityName('cross_multiplier_top');

  filepath = fileparts(which('cross_multiplier_config'));

  cross_mult = this_block.blockName;
  cross_mult_parent = get_param(cross_mult, 'Parent');

  function boolval =  checkbox2bool(bxval)
    if strcmp(bxval, 'on')
     boolval= true;
    elseif strcmp(bxval, 'off')
     boolval= false;
    end 
  end

  function strboolval = bool2str(bval)
    if bval
        strboolval = 'TRUE';
    elseif ~bval
        strboolval = 'FALSE';
    end
  end

  nof_streams = get_param(cross_mult_parent, 'nof_streams');
  dbl_nof_streams = str2double(nof_streams);
  nof_aggregations =get_param(cross_mult_parent, 'aggregation');
  dbl_nof_aggregations = str2double(nof_aggregations);
  in_bit_width =str2double(get_param(cross_mult_parent, 'in_bit_w'));
  out_bit_width =str2double(get_param(cross_mult_parent, 'out_bit_w'));
  use_dsp = bool2str(checkbox2bool(get_param(cross_mult_parent,'use_dsp')));
  use_gauss = bool2str(checkbox2bool(get_param(cross_mult_parent,'use_gauss')));
  input_latency = get_param(cross_mult_parent, 'pipeline_input');
  product_latency = get_param(cross_mult_parent, 'pipeline_product');
  adder_latency = get_param(cross_mult_parent, 'pipeline_adder');
  round_latency = get_param(cross_mult_parent, 'pipeline_round');
  output_latency = get_param(cross_mult_parent, 'pipeline_output');
  ovflw_behav = bool2str(checkbox2bool(get_param(cross_mult_parent,'ovflw_behav')));
  quant_behav = get_param(cross_mult_parent, 'quant_behav');

  nof_outputs = ((dbl_nof_streams+1) * (dbl_nof_streams))/2;
  din_type = sprintf('Ufix_%d_0',dbl_nof_aggregations*2*in_bit_width);
  dout_type = sprintf('Ufix_%d_0',dbl_nof_aggregations*2*out_bit_width);

  %Generate the vhdl top file
  vhdlfile = cross_multiplier_code_gen(dbl_nof_streams,dbl_nof_aggregations,in_bit_width, out_bit_width);

  this_block.addSimulinkInport('sync_in');
  sync_in_port = this_block.port('sync_in');
  sync_in_port.setType('Bool');
  sync_in_port.useHDLVector(false);

  this_block.addSimulinkOutport('sync_out');
  sync_out_port = this_block.port('sync_out');
  sync_out_port.setType('Bool');
  sync_out_port.useHDLVector(false);
  
  for s = 0:1:dbl_nof_streams-1
    name = sprintf('din_%d',s);
    this_block.addSimulinkInport(name);
    this_block.port(name).setType(din_type);
  end
  for o = 0:1:nof_outputs-1
    name = sprintf('dout_%d',o);
    this_block.addSimulinkOutport(name);
    this_block.port(name).setType(dout_type);
  end

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  uniqueInputRates = unique(this_block.getInputRates);

  this_block.addGeneric('g_use_gauss','BOOLEAN',use_gauss);
  this_block.addGeneric('g_use_dsp','BOOLEAN',use_dsp);
  this_block.addGeneric('g_pipeline_input','NATURAL',input_latency);
  this_block.addGeneric('g_pipeline_product','NATURAL',product_latency);
  this_block.addGeneric('g_pipeline_adder','NATURAL',adder_latency);
  this_block.addGeneric('g_pipeline_round','NATURAL',round_latency);
  this_block.addGeneric('g_pipeline_output','NATURAL',output_latency);
  this_block.addGeneric('ovflw_behav','BOOLEAN',ovflw_behav);
  this_block.addGeneric('quant_behav','NATURAL',quant_behav);

  srcloc = fileparts(vhdlfile);

  this_block.addFileToLibrary(vhdlfile,'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../technology/technology_select_pkg.vhd'],'technology_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline_sl.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_mult_component.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_agilex_versal_cmult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_complex_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/common_complex_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/cmult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_str_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([srcloc '/correlator_pkg.vhd'],'casper_correlator_lib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/mult/ip_cmult_rtl_3dsp.vhd'],'ip_xpm_mult_lib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/mult/ip_cmult_rtl_4dsp.vhd'],'ip_xpm_mult_lib');
  this_block.addFileToLibrary([filepath '/../../casper_correlator/cross_multiplier.vhd'],'casper_correlator_lib');
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

