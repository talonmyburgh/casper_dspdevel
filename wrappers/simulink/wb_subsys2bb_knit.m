function wb_subsys2bb_knit()
    %fetch wideband factor to know how many ports to draw
    subsysblk = gcb;
    wb_fft_bb = [subsysblk '/wb_fft'];
    wb_factor = str2double(get_param(subsysblk,'wb_factor'));
    
    function boolval =  checkbox2bool(bxval)
       if strcmp(bxval, 'on')
        boolval= true;
       elseif strcmp(bxval, 'off')
        boolval= false;
       end 
    end
    
    %Are we using dual real/imag or single data stream? 
    dat_or_reim = checkbox2bool(get_param(subsysblk,'dat_or_reim'));
    
    % Unlink block, otherwise we're not allowed to modify it
    set_param(subsysblk, 'LinkStatus', 'inactive');
    
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
    
    %Check if we have more in/out streams than wb_factor
    %Do so and check dual/reim param so we can adjust ports accordingly
    if(dat_or_reim && (isempty(i_in_re) ~= 1))
        %this means that we need to use single data stream, but system
        %still has separate re/im prts which we must delete.
        a=isempty(i_in_re);
        
        numPrtIndexToDelete = length(i_in_re);
        fprintf('Reached case: delete re/im ports:\n dat_or_reim = %d, isempty(i_in_re) = %d, numprts2del = %d\n',dat_or_reim,a,numPrtIndexToDelete);
        for i=0:numPrtIndexToDelete-1
           %in ports
           inport_im = inprts(i_in_im(end-i));
           inport_im_lh = get_param(inport_im{1},'LineHandles');
           delete_line(inport_im_lh.Outport(1));
           delete_block(inport_im{1});
           
           inport_re = inprts(i_in_re(end-i));
           inport_re_lh = get_param(inport_re{1},'LineHandles');
           delete_line(inport_re_lh.Outport(1));
           delete_block(inport_re{1});
           
           %out ports
           outport_im = outprts(i_out_im(end-i));
           outprt_im_lh = get_param(outport_im{1},'LineHandles');
           delete_line(outprt_im_lh.Inport(1));
           delete_block(outport_im{1});
           
           outport_re = outprts(i_out_re(end-i));
           outprt_re_lh = get_param(outport_re{1},'LineHandles');
           delete_line(outprt_re_lh.Inport(1));
           delete_block(outport_re{1});
        end
        
    elseif(~dat_or_reim && (isempty(i_in_dat) ~= 1))
        %this means that we need to use dual re/im  datastream, but system
        %still has single dat prts which we must delete.
        a=isempty(i_in_re);
        numPrtIndexToDelete = length(i_in_dat);
        fprintf('Reached case: delete data ports\ndat_or_reim = %d, isempty(i_in_re) = %d, numprts2del = %d\n',dat_or_reim,a,numPrtIndexToDelete);
        
        for i=0:numPrtIndexToDelete-1
           %in ports
           inport_dat = inprts(i_in_dat(end-i));
           inport_dat_lh = get_param(inport_dat{1},'LineHandles');
           delete_line(inport_dat_lh.Outport(1));
           delete_block(inport_dat{1});
           
           %out ports
           outport_dat = outprts(i_out_dat(end-i));
           outprt_dat_lh = get_param(outport_dat{1},'LineHandles');
           delete_line(outprt_dat_lh.Inport(1));
           delete_block(outport_dat{1});
        end
        
    else
        fprintf('All good\n');
    end
    
    if dat_or_reim
        curr_prts = length(i_in_dat);
    elseif ~dat_or_reim
        curr_prts = length(i_in_re);
    end
    
    if(curr_prts > wb_factor)
       %Delete in_ports/out_port and lines
       %We can be sure that our index is array type here:
       numPrtIndexToDelete = curr_prts-wb_factor;
       for i=0:numPrtIndexToDelete-1
           %in_ports
           if(dat_or_reim)
               %delete required data ports
               inport_dat = inprts(i_in_dat(end-i));
               inport_dat_lh = get_param(inport_dat{1},'LineHandles');
               delete_line(inport_dat_lh.Outport(1));
               delete_block(inport_dat{1});
               
               outport_dat = outprts(i_out_dat(end-i));
               outprt_dat_lh = get_param(outport_dat{1},'LineHandles');
               delete_line(outprt_dat_lh.Inport(1));
               delete_block(outport_dat{1});
           else
               %delete required re/im ports
               inport_im = inprts(i_in_im(end-i));
               inport_im_lh = get_param(inport_im{1},'LineHandles');
               delete_line(inport_im_lh.Outport(1));
               delete_block(inport_im{1});

               inport_re = inprts(i_in_re(end-i));
               inport_re_lh = get_param(inport_re{1},'LineHandles');
               delete_line(inport_re_lh.Outport(1));
               delete_block(inport_re{1});
               
               outport_im = outprts(i_out_im(end-i));
               outprt_im_lh = get_param(outport_im{1},'LineHandles');
               delete_line(outprt_im_lh.Inport(1));
               delete_block(outport_im{1});

               outport_re = outprts(i_out_re(end-i));
               outprt_re_lh = get_param(outport_re{1},'LineHandles');
               delete_line(outprt_re_lh.Inport(1));
               delete_block(outport_re{1});
           end
       end
       
    elseif(curr_prts == wb_factor)
        %do nothing and leave
        
    else
        %Get bb port handles 
        bbports=get_param(wb_fft_bb,'PortHandles');
        
        %start index for ports on bb
        if (dat_or_reim)
            i_p_h_i = 10 + curr_prts;
            o_p_h_i = 9 + curr_prts;
        elseif(~dat_or_reim)
            i_p_h_i = 10 + 2*curr_prts;
            o_p_h_i = 9 + 2*curr_prts;
        end
 
        %create necessary in/out prts and add lines:
        for i=curr_prts:wb_factor-1
           %add inports/outports and set names to match bb
           if (dat_or_reim)
               in_dat_str_n = sprintf([subsysblk '/in_data_%d'],i);
               add_block('simulink/Commonly Used Blocks/In1',in_dat_str_n);
               in_dat_ph = get_param(in_dat_str_n,'PortHandles');
               add_line(subsysblk,in_dat_ph.Outport(1),bbports.Inport(i_p_h_i));
               i_p_h_i = i_p_h_i+1;
               
               out_dat_str_n = sprintf([subsysblk '/out_data_%d'],i);
               add_block('simulink/Commonly Used Blocks/Out1',out_dat_str_n);
               out_dat_ph = get_param(out_dat_str_n,'PortHandles');
               add_line(subsysblk,bbports.Outport(o_p_h_i),out_dat_ph.Inport(1));
               o_p_h_i = o_p_h_i+1;
           elseif(~dat_or_reim)
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
           end
        end
    end
end