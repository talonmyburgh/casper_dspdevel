function wb_subsys2bb_knit()
    %fetch wideband factor to know how many ports to draw
    subsysblk = gcb;
    wb_fft_bb = 'wb_fft_blk/Wideband_FFT/wb_fft';
    wb_factor = str2double(get_param(subsysblk,'wb_factor'));
    
    %Collect all inports and outports of subsystem
    inprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Inport');
    outprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Outport');
    
    %Get index of all re, im and data in/outs:
    i_in_re = find(contains(inprts,'in_re_'));
    i_in_im = find(contains(inprts,'in_im_'));
    i_in_dat= find(contains(inprts,'in_data_'));
    i_out_re = find(contains(outprts,'out_re_'));
    i_out_im = find(contains(outprts,'out_im_'));
    i_out_dat= find(contains(outprts,'out_data_'));
    
    %Check if we have more in/out streams than wb_factor:
    curr_prts = length(i_in_re);
    if(curr_prts > wb_factor)
       %Delete in_ports/out_port and lines
       %We can be sure that our index is array type here:
       numPrtIndexToDelete = curr_prts-wb_factor;
       for i=0:numPrtIndexToDelete-1
           %in_ports
           inport_im = inprts(i_in_im(end-i));
           inport_im_lh = get_param(inport_im{1},'LineHandles');
           delete_line(inport_im_lh.Outport(1));
           delete_block(inport_im{1});
           
           inport_re = inprts(i_in_re(end-i));
           inport_re_lh = get_param(inport_re{1},'LineHandles');
           delete_line(inport_re_lh.Outport(1));
           delete_block(inport_re{1});
           
           inport_dat = inprts(i_in_dat(end-i));
           inport_dat_lh = get_param(inport_dat{1},'LineHandles');
           delete_line(inport_dat_lh.Outport(1));
           delete_block(inport_dat{1});
           
           %out_ports
           outport_im = outprts(i_out_im(end-i));
           outprt_im_lh = get_param(outport_im{1},'LineHandles');
           delete_line(outprt_im_lh.Inport(1));
           delete_block(outport_im{1});
           
           outport_re = outprts(i_out_re(end-i));
           outprt_re_lh = get_param(outport_re{1},'LineHandles');
           delete_line(outprt_re_lh.Inport(1));
           delete_block(outport_re{1});
           
           outport_dat = outprts(i_out_dat(end-i));
           outprt_dat_lh = get_param(outport_dat{1},'LineHandles');
           delete_line(outprt_dat_lh.Inport(1));
           delete_block(outport_dat{1});
       end
    elseif(curr_prts == wb_factor)
        %do nothing and leave
        
    else
        %Get bb port handles 
        bbports=get_param(wb_fft_bb,'PortHandles');
        
        %we know then that in_port_handles=9+(3*curr_prts) and
        %out_port_handles=8+(3*curr_ports) are drawn. Therefore we
        %draw for remainder = in/out_port_handles+(wb_factor-curr_prts)*3.

        %we know the first 9 inports are for a single input stream and the
        %other ports required (rst etc). Therefore, only match from 10
        %onwards as necessary. First 8 for outports so from 9 onwards.
        %Order of creation in bb is im, re, data so we must assign in this order.
        
        %start index for ports on bb
        i_p_h_i = 10+(3*curr_prts);
        o_p_h_i = 9+(3*curr_prts);
        
        %create necessary in/out prts and add lines:
        for i=curr_prts:wb_factor-1
           %add inports/outports and set names to match bb 
           in_im_str_n = sprintf([subsysblk '/in_im_%d'],i);
           add_block('simulink/Commonly Used Blocks/In1',in_im_str_n);
           in_im_ph = get_param(in_im_str_n,'PortHandles');
           add_line(subsysblk,in_im_ph.Outport(1),bbports.Inport(i_p_h_i));
           i_p_h_i = i_p_h_i+1;
           
           in_re_str_n = sprintf([subsysblk '/in_re_%d'],i);
           add_block('simulink/Commonly Used Blocks/In1',in_re_str_n);
           in_re_ph = get_param(in_re_str_n,'PortHandles');
           add_line(subsysblk,in_re_ph.Outport(1),bbports.Inport(i_p_h_i));
           i_p_h_i = i_p_h_i+1;
           
           in_dat_str_n = sprintf([subsysblk '/in_data_%d'],i);
           add_block('simulink/Commonly Used Blocks/In1',in_dat_str_n);
           in_dat_ph = get_param(in_dat_str_n,'PortHandles');
           add_line(subsysblk,in_dat_ph.Outport(1),bbports.Inport(i_p_h_i));
           i_p_h_i = i_p_h_i+1;
           
           out_im_str_n = sprintf([subsysblk '/out_im_%d'],i);
           add_block('simulink/Commonly Used Blocks/Out1',out_im_str_n);
           out_im_ph = get_param(out_im_str_n,'PortHandles');
           add_line(subsysblk,bbports.Outport(o_p_h_i),out_im_ph.Inport(1));
           o_p_h_i = o_p_h_i+1;
           
           out_re_str_n = sprintf([subsysblk '/out_re_%d'],i);
           add_block('simulink/Commonly Used Blocks/Out1',out_re_str_n);
           out_re_ph = get_param(out_re_str_n,'PortHandles');
           add_line(subsysblk,bbports.Outport(o_p_h_i),out_re_ph.Inport(1));
           o_p_h_i = o_p_h_i+1;
           
           out_dat_str_n = sprintf([subsysblk '/out_data_%d'],i);
           add_block('simulink/Commonly Used Blocks/Out1',out_dat_str_n);
           out_dat_ph = get_param(out_dat_str_n,'PortHandles');
           add_line(subsysblk,bbports.Outport(o_p_h_i),out_dat_ph.Inport(1));
           o_p_h_i = o_p_h_i+1;
        end
    end
end