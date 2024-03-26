function delay_tree_subsys2bb_knit()
    subsysblk = gcb;
    pipeline_bb = [subsysblk '/pipeline'];

    global outprts;
    global o_data;
    function updatedataprts()
        subsysblk=gcb;
        outprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Outport');

        %Get index of all out dat ports
        o_data = find(contains(outprts,'o_data_'));
    end
    % Unlink block, otherwise we're not allowed to modify it
    set_param(subsysblk,'LinkStatus','inactive');

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Here, we act on the user's decision to have a single data stream
    %input/output and remove signals as necessary.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    updatedataprts();

    %Get bb port handles to add signals
    bbports=get_param(pipeline_bb,'PortHandles');
    config_port_count = length(bbports.Outport);

    if config_port_count < length(o_data)
        % delete excess o_data_* ports
        for i=length(o_data):-1:config_port_count+1
            outport_dat = outprts(o_data(i));
            outport_dat_lh = get_param(outport_dat{1},'LineHandles');
            delete_line(outport_dat_lh.Inport(1));
            delete_block(outport_dat{1});
        end
    else
        % add new ports
        for i=length(o_data)+1:config_port_count
            out_dat_str_n = sprintf([subsysblk '/o_data_%d'],i);
            add_block('simulink/Commonly Used Blocks/Out1',out_dat_str_n);
            out_dat_ph = get_param(out_dat_str_n,'PortHandles');
            add_line(subsysblk, bbports.Outport(i), out_dat_ph.Inport(1));
        end
    end
end