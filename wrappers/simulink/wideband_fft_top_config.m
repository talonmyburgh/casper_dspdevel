
function wideband_fft_top_config(this_block)

  % Revision History:
  %
  %   31-Aug-2020  (11:48 hours):
  %     Original code was machine generated by Xilinx's System Generator after parsing
  %     /home/talon/Documents/CASPERWORK/casper_dspdevel/wrappers/simulink/wideband_fft_top.vhd
  %
  % Get the path of this script
  filepath = fileparts(which('wideband_fft_top_config'));

  this_block.setTopLevelLanguage('VHDL');

  this_block.setEntityName('wideband_fft_top');
  wb_fft_blk = this_block.blockName;
  wb_fft_blk_parent = get_param(wb_fft_blk, 'Parent');
  
  %constant widths for 
  dp_stream_bsn = 64;
  dp_stream_empty = 16;
  dp_stream_channel = 32;
  dp_stream_error = 32;
  
    function boolval =  checkbox2bool(bxval)
       if strcmp(bxval, 'on')
        boolval= 'TRUE';
       else
        boolval= 'FALSE';
       end 
    end
  
  %Fetch subsystem mask parameters for dynamic ports:
  use_reorder = get_param(wb_fft_blk_parent,'use_reorder');
  use_fft_shift = get_param(wb_fft_blk_parent,'use_fft_shift');
  use_separate = get_param(wb_fft_blk_parent,'use_separate');
  nof_chan = get_param(wb_fft_blk_parent,'nof_chan');
  wb_factor = str2double(get_param(wb_fft_blk_parent,'wb_factor'));
  twiddle_offset = get_param(wb_fft_blk_parent,'twiddle_offset');
  nof_points = get_param(wb_fft_blk_parent,'nof_points');
  i_d_w = get_param(wb_fft_blk_parent,'in_dat_w');
  o_d_w = get_param(wb_fft_blk_parent,'out_dat_w');
  o_g_w = get_param(wb_fft_blk_parent,'out_gain_w');
  s_d_w = get_param(wb_fft_blk_parent,'stage_dat_w');
  guard_w = get_param(wb_fft_blk_parent,'guard_w');
  guard_en = get_param(wb_fft_blk_parent,'guard_enable');
  
  use_reorder = checkbox2bool(use_reorder);
  use_fft_shift = checkbox2bool(use_fft_shift);
  use_separate = checkbox2bool(use_separate);
  guard_en = checkbox2bool(guard_en);
  
  %Update the vhdl top file with the required ports per wb_factor:
  topwb_code_gen(wb_factor);

  % System Generator has to assume that your entity  has a combinational feed through; 
  %   if it  doesn't, then comment out the following line:
  this_block.tagAsCombinational;

  this_block.addSimulinkInport('rst');
  this_block.addSimulinkInport('in_sync');
  this_block.addSimulinkInport('in_bsn');
  this_block.addSimulinkInport('in_valid');
  this_block.addSimulinkInport('in_sop');
  this_block.addSimulinkInport('in_eop');
  this_block.addSimulinkInport('in_empty');
  this_block.addSimulinkInport('in_err');
  this_block.addSimulinkInport('in_channel');
  
  %Dynamically add in im, re and data streams per wb_factor:
  for i=0:wb_factor-1
    this_block.addSimulinkInport(sprintf('in_im_%d',i));
    this_block.addSimulinkInport(sprintf('in_re_%d',i));
    this_block.addSimulinkInport(sprintf('in_data_%d',i));
  end
  this_block.addSimulinkOutport('out_sync');
  this_block.addSimulinkOutport('out_bsn');
  this_block.addSimulinkOutport('out_valid');
  this_block.addSimulinkOutport('out_sop');
  this_block.addSimulinkOutport('out_eop');
  this_block.addSimulinkOutport('out_empty');
  this_block.addSimulinkOutport('out_err');
  this_block.addSimulinkOutport('out_channel');

  %Dynamically add out im, re and data streams per wb_factor:
  for i=0:wb_factor-1   
    this_block.addSimulinkOutport(sprintf('out_im_%d',i));
    this_block.addSimulinkOutport(sprintf('out_re_%d',i));
    this_block.addSimulinkOutport(sprintf('out_data_%d',i));
  end
  
  %std_logic signals:
  in_sync_port = this_block.port('in_sync');
  in_sync_port.setType('UFix_1_0');
  in_sync_port.useHDLVector(false);
  in_valid_port = this_block.port('in_valid');
  in_valid_port.setType('UFix_1_0');
  in_valid_port.useHDLVector(false);
  in_sop_port = this_block.port('in_sop');
  in_sop_port.setType('UFix_1_0');
  in_sop_port.useHDLVector(false);
  in_eop_port = this_block.port('in_eop');
  in_eop_port.setType('UFix_1_0');
  in_eop_port.useHDLVector(false);

  out_sync_port = this_block.port('out_sync');
  out_sync_port.setType('UFix_1_0');
  out_sync_port.useHDLVector(false);
  out_valid_port = this_block.port('out_valid');
  out_valid_port.setType('UFix_1_0');
  out_valid_port.useHDLVector(false);
  out_sop_port = this_block.port('out_sop');
  out_sop_port.setType('UFix_1_0');
  out_sop_port.useHDLVector(false);
  out_eop_port = this_block.port('out_eop');
  out_eop_port.setType('UFix_1_0');
  out_eop_port.useHDLVector(false);
  
  %Obtain port objects:
  in_rst_port = this_block.port('rst');
  in_bsn_port = this_block.port('in_bsn');
  in_empty_port = this_block.port('in_empty');
  in_err_port = this_block.port('in_err');
  in_channel_port = this_block.port('in_channel');

  out_bsn_port = this_block.port('out_bsn');
  out_empty_port = this_block.port('out_empty');
  out_err_port = this_block.port('out_err');
  out_channel_port = this_block.port('out_channel');

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.

    %rst port
    if (in_rst_port.width ~= 1)
      this_block.setError('Input data type for port "rst" must have width=1.');
    end
    in_rst_port.useHDLVector(false);

    %input sync
    if (in_sync_port.width ~= 1)
      this_block.setError('Input data type for port "in_sync" must have width=1.');
    end
    in_sync_port.useHDLVector(false);
    
    %input bsn
    in_bsn_port.useHDLVector(true);
    in_bsn_port.setWidth(dp_stream_bsn);

    %input valid
    if (in_valid_port.width ~= 1)
      this_block.setError('Input data type for port "in_valid" must have width=1.');
    end
    in_valid_port.useHDLVector(false);

    %input sop
    if (in_sop_port.width ~= 1)
      this_block.setError('Input data type for port "in_sop" must have width=1.');
    end
    in_sop_port.useHDLVector(false);

    %input eop
    if (in_eop_port.width ~= 1)
      this_block.setError('Input data type for port "in_eop" must have width=1.');
    end
    in_eop_port.useHDLVector(false);

    %input empty
    in_empty_port.useHDLVector(true);
    in_empty_port.setWidth(dp_stream_empty);

    %input error
    in_err_port.useHDLVector(true);
    in_err_port.setWidth(dp_stream_error);
    
    %input channel
    in_channel_port.useHDLVector(true);
    in_channel_port.setWidth(dp_stream_channel);
    
    %output bsn
    out_bsn_port.useHDLVector(true);
    out_bsn_port.setWidth(dp_stream_bsn);
    
    %output empty
    out_empty_port.useHDLVector(true);
    out_empty_port.setWidth(dp_stream_empty);
    
    %output error
    out_err_port.useHDLVector(true);
    out_err_port.setWidth(dp_stream_error);
     
    %output channel
    out_channel_port.useHDLVector(true);
    out_channel_port.setWidth(dp_stream_channel);
    
    %input/output im, re and data
    for j=0:wb_factor-1
        this_block.port(sprintf('in_im_%d',j)).useHDLVector(true);
        this_block.port(sprintf('in_im_%d',j)).setWidth(str2double(i_d_w));
        this_block.port(sprintf('in_re_%d',j)).useHDLVector(true);
        this_block.port(sprintf('in_re_%d',j)).setWidth(str2double(i_d_w));
        this_block.port(sprintf('in_data_%d',j)).useHDLVector(true);
        this_block.port(sprintf('in_data_%d',j)).setWidth(str2double(2*i_d_w));
        this_block.port(sprintf('out_im_%d',j)).useHDLVector(true);
        this_block.port(sprintf('out_im_%d',j)).setWidth(str2double(i_d_w));
        this_block.port(sprintf('out_re_%d',j)).useHDLVector(true);
        this_block.port(sprintf('out_re_%d',j)).setWidth(str2double(i_d_w));
        this_block.port(sprintf('out_data_%d',j)).useHDLVector(true);
        this_block.port(sprintf('out_data_%d',j)).setWidth(str2double(2*i_d_w));
    end
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

    uniqueInputRates = unique(this_block.getInputRates);
    
  %      Add generics to blackbox (this_block)
  %      The addGeneric function takes  3 parameters, generic name, type and constant value.
  %      Supported types are boolean, real, integer and string.
  this_block.addGeneric('use_reorder','boolean',use_reorder);
  this_block.addGeneric('use_fft_shift','boolean',use_fft_shift);
  this_block.addGeneric('use_separate','boolean',use_separate);
  this_block.addGeneric('nof_chan','natural',nof_chan);
  this_block.addGeneric('wb_factor','natural',num2str(wb_factor));
  this_block.addGeneric('twiddle_offset','natural',twiddle_offset);
  this_block.addGeneric('nof_points','natural',nof_points);
  this_block.addGeneric('in_dat_w','natural',i_d_w);
  this_block.addGeneric('out_dat_w','natural',o_d_w);
  this_block.addGeneric('out_gain_w','natural',o_g_w);
  this_block.addGeneric('stage_dat_w','natural',s_d_w);
  this_block.addGeneric('guard_w','natural',guard_w);
  this_block.addGeneric('guard_enable','boolean',guard_en);
  

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
this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline.vhd'],'common_components_lib');
this_block.addFileToLibrary([filepath '/../../casper_adder/casper_common_add_sub.vhd'],'casper_adder_lib');
this_block.addFileToLibrary([filepath '/../../common_components/common_async.vhd'],'common_components_lib');
this_block.addFileToLibrary([filepath '/../../common_components/common_areset.vhd'],'common_components_lib');
this_block.addFileToLibrary([filepath '/../../common_components/common_bit_delay.vhd'],'common_components_lib');
this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline_sl.vhd'],'common_components_lib');
this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_mult_component.vhd'],'casper_multiplier_lib');
this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_complex_mult.vhd'],'casper_multiplier_lib');
this_block.addFileToLibrary([filepath '/../../casper_multiplier/common_complex_mult.vhd'],'casper_multiplier_lib');
this_block.addFileToLibrary([filepath '/../../casper_counter/common_counter.vhd'],'casper_counter_lib');
this_block.addFileToLibrary([filepath '/../../common_components/common_delay.vhd'],'common_components_lib');
this_block.addFileToLibrary([filepath '/../../casper_fifo/common_rl_decrease.vhd'],'casper_fifo_lib');
this_block.addFileToLibrary([filepath '/../../casper_fifo/common_fifo_rd.vhd'],'casper_fifo_lib');
this_block.addFileToLibrary([filepath '/../../casper_fifo/tech_fifo_component_pkg.vhd'],'casper_fifo_lib');
this_block.addFileToLibrary([filepath '/../../casper_fifo/tech_fifo_sc.vhd'],'casper_fifo_lib');
this_block.addFileToLibrary([filepath '/../../casper_fifo/common_fifo_sc.vhd'],'casper_fifo_lib');
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
this_block.addFileToLibrary([filepath '/../../casper_multiplexer/common_zip.vhd'],'casper_multiplexer_lib');
this_block.addFileToLibrary([filepath '/../../casper_dp_pkg/dp_stream_pkg.vhd'],'casper_dp_pkg_lib');
this_block.addFileToLibrary([filepath '/../../casper_wb_fft/fft_pkg.vhd'],'casper_wb_fft_lib');
this_block.addFileToLibrary([filepath '/../../r2sdf_fft/twiddlesPkg.vhd'],'r2sdf_fft_lib');
this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoSDFPkg.vhd'],'r2sdf_fft_lib');
this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoBF.vhd'],'r2sdf_fft_lib');
this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoWMul.vhd'],'r2sdf_fft_lib');
this_block.addFileToLibrary([filepath '/../../casper_wb_fft/fft_r2_bf_par.vhd'],'casper_wb_fft_lib');
this_block.addFileToLibrary([filepath '/../../casper_wb_fft/fft_r2_par.vhd'],'casper_wb_fft_lib');
this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoBFStage.vhd'],'r2sdf_fft_lib');
this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoWeights.vhd'],'r2sdf_fft_lib');
this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoSDFStage.vhd'],'r2sdf_fft_lib');
this_block.addFileToLibrary([filepath '/../../casper_wb_fft/fft_sepa.vhd'],'casper_wb_fft_lib');
this_block.addFileToLibrary([filepath '/../../casper_wb_fft/fft_reorder_sepa_pipe.vhd'],'casper_wb_fft_lib');
this_block.addFileToLibrary([filepath '/../../casper_wb_fft_no_ss/fft_r2_pipe.vhd'],'casper_wb_fft_no_ss_lib');
this_block.addFileToLibrary([filepath '/../../casper_wb_fft_no_ss/fft_sepa_wide.vhd'],'casper_wb_fft_no_ss_lib');
this_block.addFileToLibrary([filepath '/../../casper_wb_fft_no_ss/fft_r2_wide.vhd'],'casper_wb_fft_no_ss_lib');
this_block.addFileToLibrary([filepath '/../../casper_wb_fft_no_ss/fft_wide_unit_control.vhd'],'casper_wb_fft_no_ss_lib');
this_block.addFileToLibrary([filepath '/../../casper_wb_fft_no_ss/fft_wide_unit.vhd'],'casper_wb_fft_no_ss_lib');
this_block.addFileToLibrary([filepath '/../../casper_multiplier/ip_cmult_rtl_3dsp.vhd'],'casper_multiplier_lib');
this_block.addFileToLibrary([filepath '/../../casper_multiplier/ip_cmult_rtl_4dsp.vhd'],'casper_multiplier_lib');
this_block.addFileToLibrary([filepath '/../../casper_fifo/ip_xilinx_fifo_sc.vhd'],'casper_fifo_lib');
this_block.addFileToLibrary([filepath '/../../casper_ram/ip_xpm_ram_cr_cw.vhd'],'casper_ram_lib');
this_block.addFileToLibrary([filepath '/../../casper_ram/ip_xpm_ram_crw_crw.vhd'],'casper_ram_lib');
this_block.addFileToLibrary([filepath '/../../simulink/wideband_fft_top.vhd'],'simulink_lib');
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
  


% ------------------------------------------------------------
end
