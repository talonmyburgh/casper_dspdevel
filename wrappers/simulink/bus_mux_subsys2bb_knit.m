function bus_mux_subsys2bb_knit()
    subsysblk = gcb;
    bus_mux_bb = [subsysblk '/bus_mux'];

    global inprts;
    global i_data;
    function updatedataprts()
        subsysblk=gcb;
        inprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Inport');

        %Get index of all in dat ports
        i_data = find(contains(inprts,'i_data_'));
    end
    % Unlink block, otherwise we're not allowed to modify it
    set_param(subsysblk,'LinkStatus','inactive');

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Here, we act on the user's decision to have a single data stream
    %input/output and remove signals as necessary.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    updatedataprts();

    %Get bb port handles to add signals
    bbports=get_param(bus_mux_bb,'PortHandles');
    config_port_count = length(bbports.Inport)-1; %ignore static i_sel

    if config_port_count < length(i_data)
        % delete excess i_data_* ports
        for i=length(i_data):-1:config_port_count+1
            inport_dat = inprts(i_data(i));
            inport_dat_lh = get_param(inport_dat{1},'LineHandles');
            delete_line(inport_dat_lh.Outport(1));
            delete_block(inport_dat{1});
        end
    else
        % add new ports
        for i=length(i_data)+1:config_port_count
            out_dat_str_n = sprintf([subsysblk '/i_data_%d'],i);
            add_block('simulink/Commonly Used Blocks/In1',out_dat_str_n);
            out_dat_ph = get_param(out_dat_str_n,'PortHandles');
            add_line(subsysblk, out_dat_ph.Outport(1), bbports.Inport(i+1));
        end
    end
end