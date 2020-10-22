function wb_subsys2bb_knit()
    %fetch wideband parameters to figure out which ports to draw
    subsysblk = gcb;
    wb_fft_bb = [subsysblk '/wb_fft'];
    wb_factor = str2double(get_param(subsysblk,'wb_factor'));
    xtra_dat_sigs = checkbox2bool(get_param(subsysblk,'xtra_dat_sigs'));
    
    function boolval =  checkbox2bool(bxval)
       if strcmp(bxval, 'on')
        boolval= true;
       elseif strcmp(bxval, 'off')
        boolval= false;
       end 
    end

    global inprts;
    global outprts;
    global in_re in_im in_dat out_re out_im out_dat;
    global in_bsn in_sop in_eop in_empty in_err in_channel;
    global out_bsn out_sop out_eop out_empty out_err out_channel;

    function updatedataprts()
        subsysblk = gcb;
        inprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Inport');
        outprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Outport');
        
        %Get index of all re, im and data in/outs:
        in_re = find(contains(inprts,'in_re_'));
        in_im = find(contains(inprts,'in_im_'));
        in_dat= find(contains(inprts,'in_data_'));
        out_re = find(contains(outprts,'out_re_'));
        out_im = find(contains(outprts,'out_im_'));
        out_dat= find(contains(outprts,'out_data_'));
    end

    function updateotherprts()
        subsysblk = gcb;
        inprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Inport');
        outprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Outport');
        in_bsn = find(contains(inprts,'in_bsn'));
        in_sop = find(contains(inprts,'in_sop'));
        in_eop = find(contains(inprts,'in_eop'));
        in_empty = find(contains(inprts,'in_empty'));
        in_err = find(contains(inprts,'in_err'));
        in_channel = find(contains(inprts,'in_channel'));

        out_bsn = find(contains(outprts,'out_bsn'));
        out_sop = find(contains(outprts,'out_sop'));
        out_eop = find(contains(outprts,'out_eop'));
        out_empty = find(contains(outprts,'out_empty'));
        out_err = find(contains(outprts,'out_err'));
        out_channel = find(contains(outprts,'out_channel'));
    end
    
    %Are we using dual real/imag or single data stream? 
    use_separate = checkbox2bool(get_param(subsysblk,'use_separate'));
    
    % Unlink block, otherwise we're not allowed to modify it
    set_param(subsysblk, 'LinkStatus', 'inactive');
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Here we make checks on whether the extra interface signals were asked
    %for by the user or not. Then we add/remove the reports as requested.
    %Unfortunately, Simulink complains if there are data/reim ports present
    %and so we must delete them all each time we make changes here.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    updatedataprts();
    if ~use_separate
        numPrtIndexToDelete = length(in_dat);
    else
        numPrtIndexToDelete = length(in_re);
    end
    
    for i=0:numPrtIndexToDelete-1
           %in_ports
           if(~use_separate)
               %delete required data ports
               inport_dat = inprts(in_dat(end-i));
               inport_dat_lh = get_param(inport_dat{1},'LineHandles');
               delete_line(inport_dat_lh.Outport(1));
               delete_block(inport_dat{1});
               
               outport_dat = outprts(out_dat(end-i));
               outprt_dat_lh = get_param(outport_dat{1},'LineHandles');
               delete_line(outprt_dat_lh.Inport(1));
               delete_block(outport_dat{1});
           else
               %delete required re/im ports
               inport_im = inprts(in_im(end-i));
               inport_im_lh = get_param(inport_im{1},'LineHandles');
               delete_line(inport_im_lh.Outport(1));
               delete_block(inport_im{1});

               inport_re = inprts(in_re(end-i));
               inport_re_lh = get_param(inport_re{1},'LineHandles');
               delete_line(inport_re_lh.Outport(1));
               delete_block(inport_re{1});
               
               outport_im = outprts(out_im(end-i));
               outprt_im_lh = get_param(outport_im{1},'LineHandles');
               delete_line(outprt_im_lh.Inport(1));
               delete_block(outport_im{1});

               outport_re = outprts(out_re(end-i));
               outprt_re_lh = get_param(outport_re{1},'LineHandles');
               delete_line(outprt_re_lh.Inport(1));
               delete_block(outport_re{1});
           end
    end
    
    updateotherprts();
    
    if(xtra_dat_sigs && (isempty(in_bsn) == 0))
        %do nothing
        fprintf('case 1 xtra_dat_sigs = %d, isempty = %d\n',xtra_dat_sigs,isempty(in_bsn));
    %In this case, we don't want extra data signals but they are present 
    %in the design   
    elseif(~xtra_dat_sigs && (isempty(in_bsn) ==0))
        fprintf('case 2 xtra_dat_sigs = %d, isempty = %d\n',xtra_dat_sigs,isempty(in_bsn));
        %In this case, we don't want extra signals but they are present in
        %the design.
        %delete signals 
        i_bsn = inprts(in_bsn);
        in_bsn_lh = get_param(i_bsn{1},'LineHandles');
        delete_line(in_bsn_lh.Outport);
        delete_block(i_bsn{1});
        
        i_sop = inprts(in_sop);
        in_sop_lh = get_param(i_sop{1},'LineHandles');
        delete_line(in_sop_lh.Outport);
        delete_block(i_sop{1});
        
        i_eop = inprts(in_eop);
        in_eop_lh = get_param(i_eop{1},'LineHandles');
        delete_line(in_eop_lh.Outport);
        delete_block(i_eop{1});
        
        i_empty = inprts(in_empty);
        in_empty_lh = get_param(i_empty{1},'LineHandles');
        delete_line(in_empty_lh.Outport);
        delete_block(i_empty{1});
        
        i_err = inprts(in_err);
        in_err_lh = get_param(i_err{1},'LineHandles');
        delete_line(in_err_lh.Outport);
        delete_block(i_err{1});
        
        i_chan = inprts(in_channel);
        in_chan_lh = get_param(i_chan{1},'LineHandles');
        delete_line(in_chan_lh.Outport);
        delete_block(i_chan{1});
        
        o_bsn = outprts(out_bsn);
        out_bsn_lh = get_param(o_bsn{1},'LineHandles');
        delete_line(out_bsn_lh.Inport);
        delete_block(o_bsn{1});
        
        o_sop = outprts(out_sop);
        out_sop_lh = get_param(o_sop{1},'LineHandles');
        delete_line(out_sop_lh.Inport);
        delete_block(o_sop{1});
        
        o_eop = outprts(out_eop);
        out_eop_lh = get_param(o_eop{1},'LineHandles');
        delete_line(out_eop_lh.Inport);
        delete_block(o_eop{1});
        
        o_empty = outprts(out_empty);
        out_empty_lh = get_param(o_empty{1},'LineHandles');
        delete_line(out_empty_lh.Inport);
        delete_block(o_empty{1});
        
        o_err = outprts(out_err);
        out_err_lh = get_param(o_err{1},'LineHandles');
        delete_line(out_err_lh.Inport);
        delete_block(o_err{1});
        
        o_chan = outprts(out_channel);
        out_chan_lh = get_param(o_chan{1},'LineHandles');
        delete_line(out_chan_lh.Inport);
        delete_block(o_chan{1});
        
    %In this case, we want extra signals but they are not present in the
    %design
    elseif(xtra_dat_sigs && (isempty(in_bsn) == 1))
        fprintf('case 3 xtra_dat_sigs = %d, isempty = %d\n',xtra_dat_sigs,isempty(in_bsn));
        bbports=get_param(wb_fft_bb,'PortHandles');
        %create signals
        
        %in ports
        in_bsn_str = sprintf([subsysblk '/in_bsn']);
        add_block('simulink/Commonly Used Blocks/In1',in_bsn_str);
        in_bsn_ph = get_param(in_bsn_str,'PortHandles');
        add_line(subsysblk,in_bsn_ph.Outport(1),bbports.Inport(4));
               
        in_sop_str = sprintf([subsysblk '/in_sop']);
        add_block('simulink/Commonly Used Blocks/In1',in_sop_str);
        in_sop_ph = get_param(in_sop_str,'PortHandles');
        add_line(subsysblk,in_sop_ph.Outport(1),bbports.Inport(5));
        
        in_eop_str = sprintf([subsysblk '/in_eop']);
        add_block('simulink/Commonly Used Blocks/In1',in_eop_str);
        in_eop_ph = get_param(in_eop_str,'PortHandles');
        add_line(subsysblk,in_eop_ph.Outport(1),bbports.Inport(6));
        
        in_empty_str = sprintf([subsysblk '/in_empty']);
        add_block('simulink/Commonly Used Blocks/In1',in_empty_str);
        in_empty_ph = get_param(in_empty_str,'PortHandles');
        add_line(subsysblk,in_empty_ph.Outport(1),bbports.Inport(7));
        
        in_err_str = sprintf([subsysblk '/in_err']);
        add_block('simulink/Commonly Used Blocks/In1',in_err_str);
        in_err_ph = get_param(in_err_str,'PortHandles');
        add_line(subsysblk,in_err_ph.Outport(1),bbports.Inport(8));        
        
        in_chan_str = sprintf([subsysblk '/in_channel']);
        add_block('simulink/Commonly Used Blocks/In1',in_chan_str);
        in_chan_ph = get_param(in_chan_str,'PortHandles');
        add_line(subsysblk,in_chan_ph.Outport(1),bbports.Inport(9));
        
        %out ports
        out_bsn_str = sprintf([subsysblk '/out_bsn']);
        add_block('simulink/Commonly Used Blocks/Out1',out_bsn_str);
        out_bsn_ph = get_param(out_bsn_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(3),out_bsn_ph.Inport(1));
        
        out_sop_str = sprintf([subsysblk '/out_sop']);
        add_block('simulink/Commonly Used Blocks/Out1',out_sop_str);
        out_sop_ph = get_param(out_sop_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(4),out_sop_ph.Inport(1));

        out_eop_str = sprintf([subsysblk '/out_eop']);
        add_block('simulink/Commonly Used Blocks/Out1',out_eop_str);
        out_eop_ph = get_param(out_eop_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(5),out_eop_ph.Inport(1));
        
        out_empty_str = sprintf([subsysblk '/out_empty']);
        add_block('simulink/Commonly Used Blocks/Out1',out_empty_str);
        out_empty_ph = get_param(out_empty_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(6),out_empty_ph.Inport(1));
        
        out_err_str = sprintf([subsysblk '/out_err']);
        add_block('simulink/Commonly Used Blocks/Out1',out_err_str);
        out_err_ph = get_param(out_err_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(7),out_err_ph.Inport(1)); 
        
        out_chan_str = sprintf([subsysblk '/out_channel']);
        add_block('simulink/Commonly Used Blocks/Out1',out_chan_str);
        out_chan_ph = get_param(out_chan_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(8),out_chan_ph.Inport(1));  
    
    %In this case, we don't want extra signals and they are are not present    
    else
        fprintf('case 4 xtra_dat_sigs = %d, isempty = %d\n',xtra_dat_sigs,isempty(in_bsn));
        %do nothing
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Here, we act on the user's decision to have a single data stream
    %input/output and remove signals as necessary.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %Collect all inports and outports of subsystem again (will have
    %changed)
    updatedataprts();
    
    %Check if using separate in/out ports or not. Delete other ports if
    %present.
    if(~use_separate && (isempty(in_re) == 0))
        numPrtIndexToDelete = length(in_re);
        %this means that we need to use single data stream, but system
        %still has separate re/im prts which we must delete.

        for i=0:numPrtIndexToDelete-1
           %in ports
           inport_im = inprts(in_im(end-i));
           inport_im_lh = get_param(inport_im{1},'LineHandles');
           delete_line(inport_im_lh.Outport(1));
           delete_block(inport_im{1});
           
           inport_re = inprts(in_re(end-i));
           inport_re_lh = get_param(inport_re{1},'LineHandles');
           delete_line(inport_re_lh.Outport(1));
           delete_block(inport_re{1});
           
           %out ports
           outport_im = outprts(out_im(end-i));
           outprt_im_lh = get_param(outport_im{1},'LineHandles');
           delete_line(outprt_im_lh.Inport(1));
           delete_block(outport_im{1});
           
           outport_re = outprts(out_re(end-i));
           outprt_re_lh = get_param(outport_re{1},'LineHandles');
           delete_line(outprt_re_lh.Inport(1));
           delete_block(outport_re{1});
        end
        
    elseif(use_separate && (isempty(in_dat) == 0))
        %this means that we need to use dual re/im  datastream, but system
        %still has single dat prts which we must delete.
        numPrtIndexToDelete = length(in_dat);
        for i=0:numPrtIndexToDelete-1
           %in ports
           inport_dat = inprts(in_dat(end-i));
           inport_dat_lh = get_param(inport_dat{1},'LineHandles');
           delete_line(inport_dat_lh.Outport(1));
           delete_block(inport_dat{1});
           
           %out ports
           outport_dat = outprts(out_dat(end-i));
           outprt_dat_lh = get_param(outport_dat{1},'LineHandles');
           delete_line(outprt_dat_lh.Inport(1));
           delete_block(outport_dat{1});
        end
    end
    
    updatedataprts();
    %Adjust number of in/out ports depending on the wideband factor
    %specified.
    if ~use_separate
        curr_prts = length(in_dat);
    else
        curr_prts = length(in_re);
    end
    
    %Check if we have more in/out streams than wb_factor    
    if(curr_prts > wb_factor)
       %Delete in_ports/out_port and lines
       %We can be sure that our index is array type here:
       numPrtIndexToDelete = curr_prts-wb_factor;
       for i=0:numPrtIndexToDelete-1
           %in_ports
           if(~use_separate)
               %delete required data ports
               inport_dat = inprts(in_dat(end-i));
               inport_dat_lh = get_param(inport_dat{1},'LineHandles');
               delete_line(inport_dat_lh.Outport(1));
               delete_block(inport_dat{1});
               
               outport_dat = outprts(out_dat(end-i));
               outprt_dat_lh = get_param(outport_dat{1},'LineHandles');
               delete_line(outprt_dat_lh.Inport(1));
               delete_block(outport_dat{1});
           else
               %delete required re/im ports
               inport_im = inprts(in_im(end-i));
               inport_im_lh = get_param(inport_im{1},'LineHandles');
               delete_line(inport_im_lh.Outport(1));
               delete_block(inport_im{1});

               inport_re = inprts(in_re(end-i));
               inport_re_lh = get_param(inport_re{1},'LineHandles');
               delete_line(inport_re_lh.Outport(1));
               delete_block(inport_re{1});
               
               outport_im = outprts(out_im(end-i));
               outprt_im_lh = get_param(outport_im{1},'LineHandles');
               delete_line(outprt_im_lh.Inport(1));
               delete_block(outport_im{1});

               outport_re = outprts(out_re(end-i));
               outprt_re_lh = get_param(outport_re{1},'LineHandles');
               delete_line(outprt_re_lh.Inport(1));
               delete_block(outport_re{1});
           end
       end
       
    elseif(curr_prts == wb_factor)
        %do nothing and leave
        
    %Here we need to create ports since the wideband factor is larger than
    %the number of ports.
    else
        %Get bb port handles to add signals
        bbports=get_param(wb_fft_bb,'PortHandles');
        if xtra_dat_sigs
            i_basic_prts = 10;
            o_basic_prts = 9;
        else
            i_basic_prts = 4;
            o_basic_prts = 3;
        end
        %start index for ports on bb
        if (~use_separate)
            i_p_h_i = i_basic_prts + curr_prts;
            o_p_h_i = o_basic_prts + curr_prts;
        elseif(use_separate)
            i_p_h_i = i_basic_prts + 2*curr_prts;
            o_p_h_i = o_basic_prts + 2*curr_prts;
        end
 
        %create necessary in/out prts and add lines:
        for i=curr_prts:wb_factor-1
           %add inports/outports and set names to match bb
           if (~use_separate)
               fprintf("case 1: iphi=%d, ophi=%d and currprts =%d\n",i_p_h_i,o_p_h_i,curr_prts);
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
               
           elseif(use_separate)
               fprintf("case 2: iphi=%d, ophi=%d and currprts =%d\n",i_p_h_i,o_p_h_i,curr_prts);
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
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end