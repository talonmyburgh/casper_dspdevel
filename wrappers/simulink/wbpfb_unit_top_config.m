function wbpfb_unit_top_config(this_block)


  this_block.setTopLevelLanguage('VHDL');
  filepath = fileparts(which('wbpfb_unit_top_config'));

  this_block.setEntityName('wbpfb_unit_top');

  wb_pfb_blk = this_block.blockName;
  wb_pfb_blk_parent = get_param(wb_pfb_blk, 'Parent');

  %constant widths for 
  dp_stream_bsn = 64;
  bsn_data_type = sprintf('Fix_%d_0',dp_stream_bsn);
  dp_stream_empty = 16;
  empty_data_type = sprintf('Fix_%d_0',dp_stream_empty);
  dp_stream_channel = 32;
  channel_data_type = sprintf('Fix_%d_0',dp_stream_channel);
  dp_stream_error = 32;
  error_data_type = sprintf('Fix_%d_0',dp_stream_error);

function boolval =  checkbox2bool(bxval)
    if strcmp(bxval, 'on')
     boolval= true;
    elseif strcmp(bxval, 'off')
     boolval= false;
    end 
 end

 function strval = checkbox2str(bxval)
  if strcmp(bxval,'on')
    strval = 'TRUE';
  elseif strcmp(bxval, 'off')
    strval = 'FALSE'; 
  end
end

 %Fetch subsystem mask parameters for dynamic ports:
 use_reorder = get_param(wb_pfb_blk_parent,'use_reorder');
 use_fft_shift = get_param(wb_pfb_blk_parent,'use_fft_shift');
 use_separate = get_param(wb_pfb_blk_parent,'use_separate');
 alt_output  = get_param(wb_pfb_blk_parent,'alt_output');
 wb_factor =get_param(wb_pfb_blk_parent,'wb_factor');
 dbl_wb_factor = str2double(wb_factor);
 if dbl_wb_factor<1
      error("Cannot have wideband factor <1"); 
 end
 nof_points = get_param(wb_pfb_blk_parent,'nof_points');
 dbl_nof_points = 2^str2double(nof_points);
 nof_points = num2str(dbl_nof_points);
 fil_i_d_w = get_param(wb_pfb_blk_parent,'fil_in_dat_w');
 in_fil_data_type = sprintf('Fix_%s_0', fil_i_d_w);
 fft_o_d_w = get_param(wb_pfb_blk_parent,'fft_out_dat_w');
 out_fft_data_type = sprintf('Fix_%s_0', fft_o_d_w);
 fil_o_d_w = get_param(wb_pfb_blk_parent,'fil_out_dat_w');
 out_fil_data_type = sprintf('Fix_%s_0', fil_o_d_w);
 o_g_w = get_param(wb_pfb_blk_parent,'out_gain_w');
 fft_s_d_w = get_param(wb_pfb_blk_parent,'fft_stage_dat_w');
 fil_c_d_w = get_param(wb_pfb_blk_parent,'fil_coef_dat_w');
 t_d_w = get_param(wb_pfb_blk_parent,'twid_dat_w');
 double_t_d_w = str2double(t_d_w);
 max_addr_w = get_param(wb_pfb_blk_parent,'max_addr_w');
 fft_guard_w = get_param(wb_pfb_blk_parent,'fft_guard_w');
 fft_guard_en = get_param(wb_pfb_blk_parent,'fft_guard_enable');
 variant = get_param(wb_pfb_blk_parent,'use_variant');
 technology = get_param(wb_pfb_blk_parent,'vendor_technology');
 pipe_reo_in_place = get_param(wb_pfb_blk_parent,'pipe_reo_in_place');
 use_dsp = get_param(wb_pfb_blk_parent,'use_dsp');
 fft_ovflw_behav = get_param(wb_pfb_blk_parent,'fft_ovflw_behav');
 fft_use_round = get_param(wb_pfb_blk_parent,'fft_use_round');
 fft_ram_primitive = get_param(wb_pfb_blk_parent,'fft_ram_primitive');
 fil_ram_primitive = get_param(wb_pfb_blk_parent,'fil_ram_primitive');
 xtra_dat_sigs = checkbox2bool(get_param(wb_pfb_blk_parent,'xtra_dat_sigs'));
 win = get_param(wb_pfb_blk_parent, 'win');
 fwidth = get_param(wb_pfb_blk_parent, 'fwidth');
 nof_taps = get_param(wb_pfb_blk_parent,'nof_taps');
 dbl_nof_taps = str2double(nof_taps);
 nof_chan = get_param(wb_pfb_blk_parent,'nof_chan');
 nof_wb_streams = get_param(wb_pfb_blk_parent,'nof_wb_streams');
 dbl_nof_wb_streams = str2double(nof_wb_streams);
 backoff_w = get_param(wb_pfb_blk_parent,'backoff_w');
 big_endian_wb_in = get_param(wb_pfb_blk_parent,'big_endian_wb_in');
 use_prefilter = get_param(wb_pfb_blk_parent,'use_prefilter');
 dont_flip_channels = get_param(wb_pfb_blk_parent,'dont_flip_channels');

function stages = stagecalc(dbl_nof_points)
  stages = ceil(log2(dbl_nof_points));
end
num_stages = stagecalc(dbl_nof_points);
ovflwshiftreg_type = sprintf('Ufix_%d_0',num_stages);

technology_int = 0;
if strcmp(technology, 'Xilinx')
  technology_int = 0;
end % if technology Xilinx
if strcmp(technology, 'UniBoard')
  technology_int = 1;
end % if technology UniBoard

%Update the vhdl top file with the required ports per wb_factor:
vhdlfile = top_wbpfb_code_gen(dbl_wb_factor, dbl_nof_wb_streams, double_t_d_w, dbl_nof_points, dbl_nof_taps, win, str2double(fwidth)...
          ,xtra_dat_sigs, str2double(fil_o_d_w), str2double(fft_o_d_w), str2double(fft_s_d_w), str2double(fil_c_d_w)...
          ,str2double(fil_i_d_w), str2double(fil_o_d_w), technology_int);

%inport declarations
this_block.addSimulinkInport('rst');
in_rst_port = this_block.port('rst');
in_rst_port.setType('Ufix_1_0');
in_rst_port.useHDLVector(false);
this_block.addSimulinkInport('in_sync');
in_sync_port = this_block.port('in_sync');
in_sync_port.setType('Ufix_1_0');
in_sync_port.useHDLVector(false);
this_block.addSimulinkInport('in_valid');
in_valid_port = this_block.port('in_valid');
in_valid_port.setType('Ufix_1_0');
in_valid_port.useHDLVector(false);
this_block.addSimulinkInport('shiftreg');
in_shiftreg_port = this_block.port('shiftreg');
in_shiftreg_port.setType(ovflwshiftreg_type);

%If extra data signals are specified, we add them below
if xtra_dat_sigs
  %extra signals inport declarations 
  this_block.addSimulinkInport('in_bsn');
  in_bsn_port = this_block.port('in_bsn');
  in_bsn_port.setType(bsn_data_type);

  this_block.addSimulinkInport('in_sop');
  in_sop_port = this_block.port('in_sop');
  in_sop_port.setType('Ufix_1_0');
  in_sop_port.useHDLVector(false);
  
  this_block.addSimulinkInport('in_eop');
  in_eop_port = this_block.port('in_eop');
  in_eop_port.setType('Ufix_1_0');
  in_eop_port.useHDLVector(false);
  
  this_block.addSimulinkInport('in_empty');
  in_empty_port = this_block.port('in_empty');
  in_empty_port.setType(empty_data_type);
  
  this_block.addSimulinkInport('in_err');
  in_err_port = this_block.port('in_err');
  in_err_port.setType(error_data_type);
  
  this_block.addSimulinkInport('in_channel');
  in_channel_port = this_block.port('in_channel');
  in_channel_port.setType(channel_data_type);
end

%Generate im, re per wb_factor*nof_wb_streams:
for i=0:dbl_nof_wb_streams-1
  for j=0:dbl_wb_factor-1
    in_im_port = sprintf('in_im_str%d_wb%d',i,j);
    this_block.addSimulinkInport(in_im_port);
    in_im = this_block.port(in_im_port);
    in_im.setType(in_fil_data_type);
    
    in_re_port = sprintf('in_re_str%d_wb%d',i,j);
    this_block.addSimulinkInport(in_re_port);
    in_re = this_block.port(in_re_port);
  in_re.setType(in_fil_data_type);
  end
end

% outport declarations
this_block.addSimulinkOutport('fil_sync');
fil_sync_port = this_block.port('fil_sync');
fil_sync_port.setType('Ufix_1_0');
fil_sync_port.useHDLVector(false);
this_block.addSimulinkOutport('out_sync');
out_sync_port = this_block.port('out_sync');
out_sync_port.setType('Ufix_1_0');
out_sync_port.useHDLVector(false);
this_block.addSimulinkOutport('fil_valid');
fil_valid_port = this_block.port('fil_valid');
fil_valid_port.setType('Ufix_1_0');
fil_valid_port.useHDLVector(false);
this_block.addSimulinkOutport('out_valid');
out_valid_port = this_block.port('out_valid');
out_valid_port.setType('Ufix_1_0');
out_valid_port.useHDLVector(false);
this_block.addSimulinkOutport('ovflw');
out_ovflw_port = this_block.port('ovflw');
out_ovflw_port.setType(ovflwshiftreg_type);

if xtra_dat_sigs
  this_block.addSimulinkOutport('fil_bsn');
  fil_bsn_port = this_block.port('fil_bsn');
  fil_bsn_port.setType(bsn_data_type);
  this_block.addSimulinkOutport('out_bsn');
  out_bsn_port = this_block.port('out_bsn');
  out_bsn_port.setType(bsn_data_type);
  
  this_block.addSimulinkOutport('fil_sop');
  fil_sop_port = this_block.port('fil_sop');
  fil_sop_port.setType('Ufix_1_0');
  fil_sop_port.useHDLVector(false);
  this_block.addSimulinkOutport('out_sop');
  out_sop_port = this_block.port('out_sop');
  out_sop_port.setType('Ufix_1_0');
  out_sop_port.useHDLVector(false);
  
  this_block.addSimulinkOutport('fil_eop');
  fil_eop_port = this_block.port('fil_eop');
  fil_eop_port.setType('Ufix_1_0');
  fil_eop_port.useHDLVector(false);
  this_block.addSimulinkOutport('out_eop');
  out_eop_port = this_block.port('out_eop');
  out_eop_port.setType('Ufix_1_0');
  out_eop_port.useHDLVector(false);
  
  this_block.addSimulinkOutport('fil_empty');
  fil_empty_port = this_block.port('fil_empty');
  fil_empty_port.setType(empty_data_type);
  this_block.addSimulinkOutport('out_empty');
  out_empty_port = this_block.port('out_empty');
  out_empty_port.setType(empty_data_type);
  
  this_block.addSimulinkOutport('fil_err');
  fil_err_port = this_block.port('fil_err');
  fil_err_port.setType(error_data_type);
  this_block.addSimulinkOutport('out_err');
  out_err_port = this_block.port('out_err');
  out_err_port.setType(error_data_type);
  
  this_block.addSimulinkOutport('fil_channel');
  fil_channel_port = this_block.port('fil_channel');
  fil_channel_port.setType(channel_data_type);
  this_block.addSimulinkOutport('out_channel');
  out_channel_port = this_block.port('out_channel');
  out_channel_port.setType(channel_data_type);
end

for i=0:dbl_nof_wb_streams-1
  for j=0:dbl_wb_factor -1
    fil_im_port = sprintf('fil_im_str%d_wb%d',i,j);
    this_block.addSimulinkOutport(fil_im_port);
    fil_im = this_block.port(fil_im_port);
    fil_im.setType(out_fil_data_type);

    fil_re_port = sprintf('fil_re_str%d_wb%d',i,j);
    this_block.addSimulinkOutport(fil_re_port);
    fil_re = this_block.port(fil_re_port);
    fil_re.setType(out_fil_data_type);
  end
end

for i=0:dbl_nof_wb_streams-1
  for j=0:dbl_wb_factor-1
    out_im_port = sprintf('out_im_str%d_wb%d',i,j);
    this_block.addSimulinkOutport(out_im_port);
    out_im = this_block.port(out_im_port);
    out_im.setType(out_fft_data_type);
    
    out_re_port = sprintf('out_re_str%d_wb%d',i,j);
    this_block.addSimulinkOutport(out_re_port);
    out_re = this_block.port(out_re_port);
    out_re.setType(out_fft_data_type);
  end
end

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  % (!) Custimize the following generic settings as appropriate. If any settings depend
  %      on input types, make the settings in the "inputTypesKnown" code block.
  %      The addGeneric function takes  3 parameters, generic name, type and constant value.
  %      Supported types are boolean, real, integer and string.
  this_block.addGeneric('g_big_endian_wb_in','boolean',checkbox2str(big_endian_wb_in));
  this_block.addGeneric('g_wb_factor','natural',wb_factor);
  this_block.addGeneric('g_nof_points','natural',nof_points);
  this_block.addGeneric('g_nof_chan','natural',nof_chan);
  this_block.addGeneric('g_nof_wb_streams','natural',nof_wb_streams);
  this_block.addGeneric('g_alt_output','boolean',checkbox2str(alt_output));
  this_block.addGeneric('g_nof_taps','natural',nof_taps);
  this_block.addGeneric('g_fil_backoff_w','natural',backoff_w);
  this_block.addGeneric('g_fil_in_dat_w','natural',fil_i_d_w);
  this_block.addGeneric('g_fil_out_dat_w','natural',fil_o_d_w);
  this_block.addGeneric('g_coef_dat_w','natural',fil_c_d_w);
  this_block.addGeneric('g_use_reorder','boolean',checkbox2str(use_reorder));
  this_block.addGeneric('g_use_fft_shift','boolean',checkbox2str(use_fft_shift));
  this_block.addGeneric('g_use_separate','boolean',checkbox2str(use_separate));
  this_block.addGeneric('g_fft_in_dat_w','natural',fil_o_d_w);
  this_block.addGeneric('g_fft_out_dat_w','natural',fft_o_d_w);
  this_block.addGeneric('g_fft_out_gain_w','natural',o_g_w);
  this_block.addGeneric('g_stage_dat_w','natural',fft_s_d_w);
  this_block.addGeneric('g_twiddle_dat_w','natural',t_d_w);
  this_block.addGeneric('g_max_addr_w','natural',max_addr_w);
  this_block.addGeneric('g_guard_w','natural',fft_guard_w);
  this_block.addGeneric('g_guard_enable','boolean',checkbox2str(fft_guard_en));
  this_block.addGeneric('g_pipe_reo_in_place','boolean',checkbox2str(pipe_reo_in_place));
  this_block.addGeneric('g_dont_flip_channels','boolean',checkbox2str(dont_flip_channels));
  this_block.addGeneric('g_use_prefilter','boolean',checkbox2str(use_prefilter));
  this_block.addGeneric('g_fil_ram_primitive','string',fil_ram_primitive);
  this_block.addGeneric('g_use_variant','string',variant);
  this_block.addGeneric('g_use_dsp','string',use_dsp);
  this_block.addGeneric('g_ovflw_behav','string',fft_ovflw_behav);
  this_block.addGeneric('g_use_round','string',fft_use_round);
  this_block.addGeneric('g_fft_ram_primitive','string',fft_ram_primitive);

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

  %get location of generated hdl source files:
  srcloc = fileparts(vhdlfile);

  % Copy across the technology_select_pkg as per mask's vendor_technology
  source_technology_select_pkg = '';
  if strcmp(technology, 'Xilinx')
    source_technology_select_pkg = [filepath '/../../technology/technology_select_pkg_casperxpm.vhd'];
  end % if technology Xilinx
  if strcmp(technology, 'UniBoard')
    source_technology_select_pkg = [filepath '/../../technology/technology_select_pkg_casperunb1.vhd'];
  end % if technology UniBoard
  copyfile(source_technology_select_pkg, [srcloc '/technology_select_pkg.vhd']);

  this_block.addFileToLibrary(vhdlfile, 'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_adder/common_add_sub.vhd'],'casper_adder_lib');
  this_block.addFileToLibrary([filepath '/../../casper_adder/common_adder_tree.vhd'],'casper_adder_lib');
  this_block.addFileToLibrary([filepath '/../../casper_adder/common_adder_tree_a_str.vhd'],'casper_adder_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_bit_delay.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_pipeline_sl.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_mult_component.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([srcloc   '/technology_select_pkg.vhd'],'technology_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_complex_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/common_complex_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_counter/common_counter.vhd'],'casper_counter_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_delay.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/tech_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplier/common_mult.vhd'],'casper_multiplier_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_pkg.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_component_pkg.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_ram_crw_crw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_ram_cr_cw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_crw_crw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_paged_ram_crw_crw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_paged_ram_rw_rw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_paged_ram_r_w.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_paged_reg.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_rw_rw.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/common_ram_r_w.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_requantize/common_round.vhd'],'casper_requantize_lib');
  this_block.addFileToLibrary([filepath '/../../casper_requantize/common_resize.vhd'],'casper_requantize_lib');
  this_block.addFileToLibrary([filepath '/../../casper_requantize/common_requantize.vhd'],'casper_requantize_lib');
  this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_rom_r_r.vhd'],'casper_ram_lib');
 this_block.addFileToLibrary([filepath '/../../casper_ram/tech_memory_rom_r.vhd'],'casper_ram_lib');
 this_block.addFileToLibrary([filepath '/../../casper_ram/common_rom_r_r.vhd'],'casper_ram_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_str_pkg.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_components/common_switch.vhd'],'common_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_multiplexer/common_zip.vhd'],'casper_multiplexer_lib');
  this_block.addFileToLibrary([srcloc   '/fft_gnrcs_intrfcs_pkg.vhd'],'wb_fft_lib');
  this_block.addFileToLibrary([srcloc   '/rTwoSDFPkg.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([srcloc   '/fil_pkg.vhd'],'casper_filter_lib');
  this_block.addFileToLibrary([filepath '/../../casper_wbpfb/wbpfb_gnrcs_intrfcs_pkg.vhd'],'wpfb_lib');
  this_block.addFileToLibrary([filepath '/../../casper_dp_pkg/dp_stream_pkg.vhd'],'dp_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../casper_dp_components/dp_hold_ctrl.vhd'],'dp_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_dp_components/dp_hold_input.vhd'],'dp_components_lib');
  this_block.addFileToLibrary([filepath '/../../casper_pipeline/dp_pipeline.vhd'],'casper_pipeline_lib');
  this_block.addFileToLibrary([filepath '/../../casper_wbpfb/dp_bsn_restore_global.vhd'],'wpfb_lib');
  this_block.addFileToLibrary([filepath '/../../casper_wbpfb/dp_block_gen_valid_arr.vhd'],'wpfb_lib');
  this_block.addFileToLibrary([srcloc   '/twiddlesPkg.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoBF.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../casper_requantize/r_shift_requantize.vhd'],'casper_requantize_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoWMul.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../casper_wb_fft/fft_r2_bf_par.vhd'],'wb_fft_lib');
  this_block.addFileToLibrary([filepath '/../../casper_wb_fft/fft_r2_par.vhd'],'wb_fft_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoBFStage.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoWeights.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../r2sdf_fft/rTwoSDFStage.vhd'],'r2sdf_fft_lib');
  this_block.addFileToLibrary([filepath '/../../casper_wb_fft/fft_sepa.vhd'],'wb_fft_lib');
  this_block.addFileToLibrary([filepath '/../../casper_wb_fft/fft_reorder_sepa_pipe.vhd'],'wb_fft_lib');
  this_block.addFileToLibrary([filepath '/../../casper_wb_fft/fft_r2_pipe.vhd'],'wb_fft_lib');
  this_block.addFileToLibrary([filepath '/../../casper_wb_fft/fft_sepa_wide.vhd'],'wb_fft_lib');
  this_block.addFileToLibrary([filepath '/../../casper_wb_fft/fft_r2_wide.vhd'],'wb_fft_lib');
  this_block.addFileToLibrary([filepath '/../../casper_filter/fil_ppf_ctrl.vhd'],'casper_filter_lib');
  this_block.addFileToLibrary([filepath '/../../casper_filter/fil_ppf_filter.vhd'],'casper_filter_lib');
  this_block.addFileToLibrary([filepath '/../../casper_filter/fil_ppf_single.vhd'],'casper_filter_lib');
  this_block.addFileToLibrary([filepath '/../../casper_filter/fil_ppf_wide.vhd'],'casper_filter_lib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/mult/ip_cmult_rtl_3dsp.vhd'],'ip_xpm_mult_lib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/mult/ip_cmult_rtl_4dsp.vhd'],'ip_xpm_mult_lib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/mult/ip_mult_infer.vhd'],'ip_xpm_mult_lib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/ram/ip_xpm_ram_cr_cw.vhd'],'ip_xpm_ram_lib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/ram/ip_xpm_ram_crw_crw.vhd'],'ip_xpm_ram_lib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/ram/ip_xpm_rom_r.vhd'],'ip_xpm_ram_lib');
  this_block.addFileToLibrary([filepath '/../../ip_xpm/ram/ip_xpm_rom_r_r.vhd'],'ip_xpm_ram_lib');
  this_block.addFileToLibrary([filepath '/../../casper_wbpfb/wbpfb_unit_dev.vhd'],'wpfb_lib');
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

