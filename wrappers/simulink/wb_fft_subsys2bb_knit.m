%--------------------------------------------------------------------------------
%- Created for use in the CASPER ecosystem by Talon Myburgh under Mydon Solutions
%- myburgh.talon@gmail.com
%- https://github.com/talonmyburgh | https://github.com/MydonSolutions
%--------------------------------------------------------------------------------%
function wb_fft_subsys2bb_knit()
    %fetch wideband parameters to figure out which ports to draw
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

    global inprts;
    global outprts;
    global in_re in_im out_re out_im;
    global in_bsn in_sop in_eop in_empty in_err in_channel;
    global out_bsn out_sop out_eop out_empty out_err out_channel;

    function updatedataprts()
        subsysblk = gcb;
        inprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Inport');
        outprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Outport');
        
        %Get index of all re, im in/outs:
        in_re = find(contains(inprts,'in_re_'));
        in_im = find(contains(inprts,'in_im_'));
        out_re = find(contains(outprts,'out_re_'));
        out_im = find(contains(outprts,'out_im_'));
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
            %in_ports
            %delete required re/im ports
            inport_im = inprts(in_im(end-k));
            inport_im_lh = get_param(inport_im{1},'LineHandles');
            delete_line(inport_im_lh.Outport(1));
            delete_block(inport_im{1});
            
            inport_re = inprts(in_re(end-k));
            inport_re_lh = get_param(inport_re{1},'LineHandles');
            delete_line(inport_re_lh.Outport(1));
            delete_block(inport_re{1});
            
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

    
    %Check if we have more in/out streams than wb_factor    
    if(curr_prts > wb_factor)
       %Delete in_ports/out_port and lines
       %We can be sure that our index is array type here:
       numPrtIndexToDelete = curr_prts-wb_factor;
       for i=0:numPrtIndexToDelete-1
           %in_ports
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
       
    elseif(curr_prts == wb_factor)
        %do nothing and leave
        
    %Here we need to create ports since the wideband factor is larger than
    %the number of ports.
    else
        %Get bb port handles to add signals
        bbports=get_param(wb_fft_bb,'PortHandles');

        i_basic_prts = 4;
        o_basic_prts = 4;

        %start index for ports on bb
        i_p_h_i = i_basic_prts + 2*curr_prts;
        o_p_h_i = o_basic_prts + 2*curr_prts;

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
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end