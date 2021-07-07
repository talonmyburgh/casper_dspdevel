function fil_subsys2bb_knit()
    subsysblk = gcb;
    fil_bb = [subsysblk '/filterbank_top'];
    wb_factor = str2double(get_param(subsysblk,'wb_factor'));
    global inprts;
    global outprts;
    global in_dat out_dat;
    function updatedataprts()
        subsysblk=gcb;
        inprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Inport');
        outprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Outport');

        %Get index of all in/out dat ports
        in_dat = find(contains(inprts,'in_dat_'));
        out_dat = find(contains(outprts,'out_dat_'));
    end
    % Unlink block, otherwise we're not allowed to modify it
    set_param(subsysblk,'LinkStatus','inactive');

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Here, we act on the user's decision to have a single data stream
    %input/output and remove signals as necessary.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    updatedataprts();

    curr_prts = length(in_dat);
    if(curr_prts > wb_factor)
        numPrtIndexToDelete = curr_prts-wb_factor;
        for i=0:numPrtIndexToDelete-1
            inport_dat = inprts(in_dat(end-i));
            inport_dat_lh = get_param(inport_dat{1},'LineHandles');
            delete_line(inport_dat_lh.Outport(1));
            delete_block(inport_dat{1});
            
            fprintf('prts2delete: %d, curr_prts: %d',numPrtIndexToDelete,curr_prts);
            outport_dat = outprts(out_dat(end-i));
            outport_dat_lh = get_param(outport_dat{1},'LineHandles');
            delete_line(outport_dat_lh.Inport(1));
            delete_block(outport_dat{1});
        end
    elseif(curr_prts==wb_factor)
    %do nothing

    %Here we need to create ports since the wideband factor is larger than the number of ports.
    else
        %Get bb port handles to add signals
        bbports=get_param(fil_bb,'PortHandles');
        i_p_h_i = 3 + curr_prts;
        o_p_h_i = 2 + curr_prts;

        for i=curr_prts:wb_factor-1
            in_dat_str_n = sprintf([subsysblk '/in_dat_%d'],i);
            add_block('simulink/Commonly Used Blocks/In1',in_dat_str_n);
            in_dat_ph = get_param(in_dat_str_n,'PortHandles');
            add_line(subsysblk,in_dat_ph.Outport(1),bbports.Inport(i_p_h_i));
            i_p_h_i = i_p_h_i+1;

            out_dat_str_n = sprintf([subsysblk '/out_dat_%d'],i);
            add_block('simulink/Commonly Used Blocks/Out1',out_dat_str_n);
            out_dat_ph = get_param(out_dat_str_n,'PortHandles');
            add_line(subsysblk,bbports.Outport(o_p_h_i),out_dat_ph.Inport(1));
            o_p_h_i = o_p_h_i +1;
        end
    end
end