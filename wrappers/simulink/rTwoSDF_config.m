
function rTwoSDF_config(this_block)

  % Revision History:
  %
  %   07-Aug-2020  (12:17 hours):
  %     Original code was machine generated by Xilinx's System Generator after parsing
  %     /home/talon/Documents/CASPERWORK/casper_dspdevel/r2sdf_fft/rTwoSDF.vhd
  %
  %
  % Get the path of this script
  filepath = fileparts(which('rTwoSDF_config'));

  this_block.setTopLevelLanguage('VHDL');

  this_block.setEntityName('rTwoSDF');
  
  r2sdf_blk = this_block.blockName;
  r2sdf_blk_parent = get_param(r2sdf_blk, 'Parent');

  % System Generator has to assume that your entity  has a combinational feed through; 
  %   if it  doesn't, then comment out the following line:
  this_block.tagAsCombinational;

  this_block.addSimulinkInport('rst');
  this_block.addSimulinkInport('in_re');
  this_block.addSimulinkInport('in_im');
  this_block.addSimulinkInport('in_val');

  this_block.addSimulinkOutport('out_re');
  this_block.addSimulinkOutport('out_im');
  this_block.addSimulinkOutport('out_val');

  out_val_port = this_block.port('out_val');
  out_val_port.setType('UFix_1_0');
  out_val_port.useHDLVector(false);
  
  %Obtain port objects:
  in_rst_port = this_block.port('rst');
  in_re_port = this_block.port('in_re');
  in_im_port = this_block.port('in_im');
  in_val_port = this_block.port('in_val');
  
  out_re_port = this_block.port('out_re');
  out_im_port = this_block.port('out_im');
  
  %fetch generic values from mask parameters:
  nof_chan = get_param(r2sdf_blk_parent,'g_nof_chan');
  use_reorder = get_param(r2sdf_blk_parent,'g_use_reorder');
  i_d_w = get_param(r2sdf_blk_parent,'g_in_dat_w');
  o_d_w = get_param(r2sdf_blk_parent,'g_out_dat_w');
  s_d_w = get_param(r2sdf_blk_parent,'g_stage_dat_w');
  g_d_w = get_param(r2sdf_blk_parent,'g_guard_w');
  nof_pts = get_param(r2sdf_blk_parent,'g_nof_points');
  variant = get_param(r2sdf_blk_parent,'g_variant');
  u_dsp = get_param(r2sdf_blk_parent,'g_use_dsp');
  tech = get_param(r2sdf_blk_parent,'g_technology');
  ram_p = get_param(r2sdf_blk_parent,'g_ram_primitive');

  if strcmp(use_reorder, 'on')
    use_reorder_bool = 'TRUE';
  else
    use_reorder_bool = 'FALSE';
  end

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.
    %rst
    if (in_rst_port.width ~= 1)
      this_block.setError('Input data type for port "rst" must have width=1.');
    end
    in_rst_port.useHDLVector(false);

    %in_re
    in_re_port.useHDLVector(true);
    in_re_port.setWidth(str2double(i_d_w));

    %in_im
    in_im_port.useHDLVector(true);
    in_im_port.setWidth(str2double(i_d_w));

    %in_val
    if (in_val_port.width ~= 1)
      this_block.setError('Input data type for port "in_val" must have width=1.');
    end
    in_val_port.useHDLVector(false);
    
    %out_re
    out_re_port.useHDLVector(true);
    out_re_port.setWidth(str2double(o_d_w));
    
    %out_im
    out_im_port.useHDLVector(true);
    out_im_port.setWidth(str2double(o_d_w));
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
  if (this_block.inputRatesKnown)
    setup_as_single_rate(this_block,'clk','ce')
  end  % if(inputRatesKnown)
  % -----------------------------

  uniqueInputRates = unique(this_block.getInputRates);

  %set up generics:
  this_block.addGeneric('g_nof_chan','integer',nof_chan);
  this_block.addGeneric('g_use_reorder','boolean', use_reorder_bool);
  this_block.addGeneric('g_in_dat_w','integer',i_d_w);
  this_block.addGeneric('g_out_dat_w','integer',o_d_w);
  this_block.addGeneric('g_stage_dat_w','integer',s_d_w);
  this_block.addGeneric('g_guard_w','integer',g_d_w);
  this_block.addGeneric('g_nof_points','integer',nof_pts);
  this_block.addGeneric('g_variant','string',variant);
  this_block.addGeneric('g_use_dsp','string',u_dsp);
  this_block.addGeneric('g_stage_lat','integer','1');
  this_block.addGeneric('g_weight_lat','integer','1');
  this_block.addGeneric('g_mult_lat','integer','4');
  this_block.addGeneric('g_bf_lat','integer','1');
  this_block.addGeneric('g_bf_use_zdly','integer','1');
  this_block.addGeneric('g_bf_in_a_zdly','integer','0');
  this_block.addGeneric('g_bf_out_d_zdly','integer','0');
  this_block.addGeneric('g_technology','integer',tech);
  this_block.addGeneric('g_ram_primitive','string',ram_p);

  % Add addtional source files as needed.
  %  |-------------
  %  | Add files in the order in which they should be compiled.
  %  | If two files "a.vhd" and "b.vhd" contain the entities
  %  | entity_a and entity_b, and entity_a contains a
  %  | component of type entity_b, the correct sequence of
  %  | addFile() calls would be:
  %  |    this_block.addFile('b.vhd');
  %  |    this_block.addFile('a.vhd');
  %  |-------------

  this_block.addFileToLibrary([filepath '/../../common_components/common_bit_delay.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline_sl.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_mult_component.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_complex_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/common_complex_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_counter/common_counter.vhd'],'casper_counter_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_delay.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_pkg.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_component_pkg.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_ram_crw_crw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_ram_cr_cw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_crw_crw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_paged_ram_crw_crw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_paged_ram_rw_rw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_paged_ram_r_w.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_requantize/common_round.vhd'],'casper_requantize_lib');
  this_block.addFileToLibrary([filepath '/../../casper_requantize/common_resize.vhd'],'casper_requantize_lib');
  this_block.addFileToLibrary([filepath '/../../casper_requantize/common_requantize.vhd'],'casper_requantize_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_str_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/ip_cmult_rtl_3dsp.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/ip_cmult_rtl_4dsp.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/ip_xpm_ram_cr_cw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoBF.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoBFStage.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoOrder.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/twiddlesPkg.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoSDFPkg.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoWeights.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoWMul.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoSDFStage.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoSDF.vhd'],'r2sdf_fft_lib');
return;


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

% ------------------------------------------------------------

