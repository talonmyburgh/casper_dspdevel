function wb_pfb_subsys2bb_knit()
    %fetch wideband parameters to figure out which ports to draw
    subsysblk = gcb;
    wb_pfb_bb = [subsysblk '/wb_pfb'];
    wb_factor = str2double(get_param(subsysblk,'wb_factor'));
    nof_wb_streams = str2double(get_param(subsysblk,'nof_wb_streams'));
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
    global in_re in_im out_re out_im fil_re fil_im;
    global in_bsn in_sop in_eop in_empty in_err in_channel;
    global out_bsn out_sop out_eop out_empty out_err out_channel;
    global fil_bsn fil_sop fil_eop fil_empty fil_err fil_channel;

    function updatedataprts()
        subsysblk = gcb;
        inprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Inport');
        outprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Outport');

        %Get index of all re, im in/outs:
        in_re = find(contains(inprts,'in_re_'));
        in_im = find(contains(inprts,'in_im_'));
        
        fil_re = find(contains(outprts,'fil_re_'));
        fil_im = find(contains(outprts,'fil_im_'));

        out_re = find(contains(outprts,'out_re_'));
        out_im = find(contains(outprts,'out_im_'));
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
        
        fil_bsn = find(contains(outprts,'fil_bsn'));
        fil_sop = find(contains(outprts,'fil_sop'));
        fil_eop = find(contains(outprts,'fil_eop'));
        fil_empty = find(contains(outprts,'fil_empty'));
        fil_err = find(contains(outprts,'fil_err'));
        fil_channel = find(contains(outprts,'fil_channel'));

        out_bsn = find(contains(outprts,'out_bsn'));
        out_sop = find(contains(outprts,'out_sop'));
        out_eop = find(contains(outprts,'out_eop'));
        out_empty = find(contains(outprts,'out_empty'));
        out_err = find(contains(outprts,'out_err'));
        out_channel = find(contains(outprts,'out_channel'));
    end
    
    % Unlink block, otherwise we're not allowed to modify it
    set_param(subsysblk, 'LinkStatus', 'inactive');
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Here we make checks on whether the extra interface signals were asked
    %for by the user or not. Then we add/remove the reports as requested.
    %Unfortunately, Simulink complains if there are data/reim ports present
    %and so we must delete them all each time we make changes here.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    updatedataprts();
    
    function numPrt2delete = prts2delete
            numPrt2delete = length(in_re);
    end
    
    function deleteDatPrts()
        numPrt2delete=prts2delete();
        for k=0:numPrt2delete-1
            %delete required re/im ports
            inport_im = inprts(in_im(end-k));
            inport_im_lh = get_param(inport_im{1},'LineHandles');
            delete_line(inport_im_lh.Outport(1));
            delete_block(inport_im{1});
            
            inport_re = inprts(in_re(end-k));
            inport_re_lh = get_param(inport_re{1},'LineHandles');
            delete_line(inport_re_lh.Outport(1));
            delete_block(inport_re{1});
            
            filport_im = outprts(fil_im(end-k));
            filprt_im_lh = get_param(filport_im{1},'LineHandles');
            delete_line(filprt_im_lh.Inport(1));
            delete_block(filport_im{1});
            
            filport_re = outprts(fil_re(end-k));
            filprt_re_lh = get_param(filport_re{1},'LineHandles');
            delete_line(filprt_re_lh.Inport(1));
            delete_block(filport_re{1});

            outport_im = outprts(out_im(end-k));
            outprt_im_lh = get_param(outport_im{1},'LineHandles');
            delete_line(outprt_im_lh.Inport(1));
            delete_block(outport_im{1});
            
            outport_re = outprts(out_re(end-k));
            outprt_re_lh = get_param(outport_re{1},'LineHandles');
            delete_line(outprt_re_lh.Inport(1));
            delete_block(outport_re{1});
        end
    end
    
    updateotherprts();
    
    if(xtra_dat_sigs && (isempty(in_bsn) == 0))
        %do nothing
        
    %In this case, we don't want extra data signals but they are present 
    %in the design   
    elseif(~xtra_dat_sigs && (isempty(in_bsn) ==0))
        %delete data sigs
        deleteDatPrts();
        
        %delete control signals 
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
        
        f_bsn = outprts(fil_bsn);
        fil_bsn_lh = get_param(f_bsn{1},'LineHandles');
        delete_line(fil_bsn_lh.Inport);
        delete_block(f_bsn{1});
        
        f_sop = outprts(fil_sop);
        fil_sop_lh = get_param(f_sop{1},'LineHandles');
        delete_line(fil_sop_lh.Inport);
        delete_block(f_sop{1});
        
        f_eop = outprts(fil_eop);
        fil_eop_lh = get_param(f_eop{1},'LineHandles');
        delete_line(fil_eop_lh.Inport);
        delete_block(f_eop{1});
        
        f_empty = outprts(fil_empty);
        fil_empty_lh = get_param(f_empty{1},'LineHandles');
        delete_line(fil_empty_lh.Inport);
        delete_block(f_empty{1});
        
        f_err = outprts(fil_err);
        fil_err_lh = get_param(f_err{1},'LineHandles');
        delete_line(fil_err_lh.Inport);
        delete_block(f_err{1});
        
        f_chan = outprts(fil_channel);
        fil_chan_lh = get_param(f_chan{1},'LineHandles');
        delete_line(fil_chan_lh.Inport);
        delete_block(f_chan{1});

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
        bbports=get_param(wb_pfb_bb,'PortHandles');
        %Delete ports so Simulink cannot complain.
        deleteDatPrts();
        
        %create signals
        %in ports
        in_bsn_str = sprintf([subsysblk '/in_bsn']);
        add_block('simulink/Commonly Used Blocks/In1',in_bsn_str);
        in_bsn_ph = get_param(in_bsn_str,'PortHandles');
        add_line(subsysblk,in_bsn_ph.Outport(1),bbports.Inport(5));
               
        in_sop_str = sprintf([subsysblk '/in_sop']);
        add_block('simulink/Commonly Used Blocks/In1',in_sop_str);
        in_sop_ph = get_param(in_sop_str,'PortHandles');
        add_line(subsysblk,in_sop_ph.Outport(1),bbports.Inport(6));
        
        in_eop_str = sprintf([subsysblk '/in_eop']);
        add_block('simulink/Commonly Used Blocks/In1',in_eop_str);
        in_eop_ph = get_param(in_eop_str,'PortHandles');
        add_line(subsysblk,in_eop_ph.Outport(1),bbports.Inport(7));
        
        in_empty_str = sprintf([subsysblk '/in_empty']);
        add_block('simulink/Commonly Used Blocks/In1',in_empty_str);
        in_empty_ph = get_param(in_empty_str,'PortHandles');
        add_line(subsysblk,in_empty_ph.Outport(1),bbports.Inport(8));
        
        in_err_str = sprintf([subsysblk '/in_err']);
        add_block('simulink/Commonly Used Blocks/In1',in_err_str);
        in_err_ph = get_param(in_err_str,'PortHandles');
        add_line(subsysblk,in_err_ph.Outport(1),bbports.Inport(9));        
        
        in_chan_str = sprintf([subsysblk '/in_channel']);
        add_block('simulink/Commonly Used Blocks/In1',in_chan_str);
        in_chan_ph = get_param(in_chan_str,'PortHandles');
        add_line(subsysblk,in_chan_ph.Outport(1),bbports.Inport(10));
        
        %out ports
        fil_bsn_str = sprintf([subsysblk '/fil_bsn']);
        add_block('simulink/Commonly Used Blocks/Out1',fil_bsn_str);
        fil_bsn_ph = get_param(fil_bsn_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(6),fil_bsn_ph.Inport(1));
        out_bsn_str = sprintf([subsysblk '/out_bsn']);
        add_block('simulink/Commonly Used Blocks/Out1',out_bsn_str);
        out_bsn_ph = get_param(out_bsn_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(7),out_bsn_ph.Inport(1));
        
        fil_sop_str = sprintf([subsysblk '/fil_sop']);
        add_block('simulink/Commonly Used Blocks/Out1',fil_sop_str);
        fil_sop_ph = get_param(fil_sop_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(8),fil_sop_ph.Inport(1));
        out_sop_str = sprintf([subsysblk '/out_sop']);
        add_block('simulink/Commonly Used Blocks/Out1',out_sop_str);
        out_sop_ph = get_param(out_sop_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(9),out_sop_ph.Inport(1));

        fil_eop_str = sprintf([subsysblk '/fil_eop']);
        add_block('simulink/Commonly Used Blocks/Out1',fil_eop_str);
        fil_eop_ph = get_param(fil_eop_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(10),fil_eop_ph.Inport(1));
        out_eop_str = sprintf([subsysblk '/out_eop']);
        add_block('simulink/Commonly Used Blocks/Out1',out_eop_str);
        out_eop_ph = get_param(out_eop_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(11),out_eop_ph.Inport(1));
        
        fil_empty_str = sprintf([subsysblk '/fil_empty']);
        add_block('simulink/Commonly Used Blocks/Out1',fil_empty_str);
        fil_empty_ph = get_param(fil_empty_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(12),fil_empty_ph.Inport(1));
        out_empty_str = sprintf([subsysblk '/out_empty']);
        add_block('simulink/Commonly Used Blocks/Out1',out_empty_str);
        out_empty_ph = get_param(out_empty_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(13),out_empty_ph.Inport(1));
        
        fil_err_str = sprintf([subsysblk '/fil_err']);
        add_block('simulink/Commonly Used Blocks/Out1',fil_err_str);
        fil_err_ph = get_param(fil_err_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(14),fil_err_ph.Inport(1)); 
        out_err_str = sprintf([subsysblk '/out_err']);
        add_block('simulink/Commonly Used Blocks/Out1',out_err_str);
        out_err_ph = get_param(out_err_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(15),out_err_ph.Inport(1)); 
        
        fil_chan_str = sprintf([subsysblk '/fil_channel']);
        add_block('simulink/Commonly Used Blocks/Out1',fil_chan_str);
        fil_chan_ph = get_param(fil_chan_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(16),fil_chan_ph.Inport(1));  
        out_chan_str = sprintf([subsysblk '/out_channel']);
        add_block('simulink/Commonly Used Blocks/Out1',out_chan_str);
        out_chan_ph = get_param(out_chan_str,'PortHandles');
        add_line(subsysblk,bbports.Outport(17),out_chan_ph.Inport(1)); 
    
    %In this case, we don't want extra signals and they are are not present    
    else
        %do nothing
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Here, we act on the user's decision to have a single data stream
    %input/output and remove signals as necessary.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    %Collect all inports and outports of subsystem again (will have
    %changed)
    updatedataprts();
    
    %Adjust number of in/out ports depending on the wideband factor
    %specified.
    curr_prts = length(in_re);
       
    if(curr_prts == wb_factor*nof_wb_streams)
        %do nothing and leave
        
    %Here we need to create ports since the wideband factor is larger than
    %the number of ports.
    else
        deleteDatPrts();
        %Get bb port handles to add signals
        bbports=get_param(wb_pfb_bb,'PortHandles');
        if xtra_dat_sigs
            i_basic_prts = 11;
            o_basic_prts = 18;
        else
            i_basic_prts = 5;
            o_basic_prts = 6;
        end
        %start index for ports on bb
        i_p_h_i = i_basic_prts;
        f_p_h_i = o_basic_prts;
        o_p_h_i = o_basic_prts + 2*(wb_factor*nof_wb_streams);
 
        %create necessary in/out prts and add lines:
        for j=0:nof_wb_streams-1
            for i=0:wb_factor-1
            %add inports/outports and set names to match bb
                in_im_str_n = sprintf([subsysblk '/in_im_str%d_wb%d'],j,i);
                add_block('simulink/Commonly Used Blocks/In1',in_im_str_n);
                in_im_ph = get_param(in_im_str_n,'PortHandles');
                add_line(subsysblk,in_im_ph.Outport(1),bbports.Inport(i_p_h_i));
                i_p_h_i = i_p_h_i+1;

                in_re_str_n = sprintf([subsysblk '/in_re_str%d_wb%d'],j,i);
                add_block('simulink/Commonly Used Blocks/In1',in_re_str_n);
                in_re_ph = get_param(in_re_str_n,'PortHandles');
                add_line(subsysblk,in_re_ph.Outport(1),bbports.Inport(i_p_h_i));
                i_p_h_i = i_p_h_i+1;
                
                fil_im_str_n = sprintf([subsysblk '/fil_im_str%d_wb%d'],j,i);
                add_block('simulink/Commonly Used Blocks/Out1',fil_im_str_n);
                fil_im_ph = get_param(fil_im_str_n,'PortHandles');
                add_line(subsysblk,bbports.Outport(f_p_h_i),fil_im_ph.Inport(1));
                f_p_h_i = f_p_h_i+1;

                fil_re_str_n = sprintf([subsysblk '/fil_re_str%d_wb%d'],j,i);
                add_block('simulink/Commonly Used Blocks/Out1',fil_re_str_n);
                fil_re_ph = get_param(fil_re_str_n,'PortHandles');
                add_line(subsysblk,bbports.Outport(f_p_h_i),fil_re_ph.Inport(1));
                f_p_h_i = f_p_h_i+1;

                out_im_str_n = sprintf([subsysblk '/out_im_str%d_wb%d'],j,i);
                add_block('simulink/Commonly Used Blocks/Out1',out_im_str_n);
                out_im_ph = get_param(out_im_str_n,'PortHandles');
                add_line(subsysblk,bbports.Outport(o_p_h_i),out_im_ph.Inport(1));
                o_p_h_i = o_p_h_i+1;

                out_re_str_n = sprintf([subsysblk '/out_re_str%d_wb%d'],j,i);
                add_block('simulink/Commonly Used Blocks/Out1',out_re_str_n);
                out_re_ph = get_param(out_re_str_n,'PortHandles');
                add_line(subsysblk,bbports.Outport(o_p_h_i),out_re_ph.Inport(1));
                o_p_h_i = o_p_h_i+1;
            end
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end