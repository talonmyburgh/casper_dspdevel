function cross_multiplier_subsys2bb_knit()
    subsysblk = gcb;
    cross_multiplier_bb = [subsysblk '/cross_multiplier'];
    nof_streams = str2double(get_param(subsysblk,'nof_streams'));

    global inprts;
    global outprts;
    global din;
    global dout;
    global bbports;

    % Unlink block, otherwise we're not allowed to modify it
    set_param(subsysblk, 'LinkStatus', 'inactive');

    function updatedataprts(subsysblk, cross_multiplier_bb)
        bbports=get_param(cross_multiplier_bb,'PortHandles');
        inprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Inport');
        outprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Outport');
        
        %Get index of all re, im in/outs:
        din = find(contains(inprts,'din'));
        dout = find(contains(outprts,'x'));
    end

    function map = gen_map(nof_streams)
        nof_outputs = ((nof_streams + 1) * nof_streams)/2;
        map = zeros(nof_outputs,2);
        i = 1;
        for s=0:1:nof_streams-1
            for ss=s:1:nof_streams-1
                map(i,:) = [s,ss];
                i = i+1;
            end
        end
    end

    function delete_all_data_ports()
        %delete input ports
        for k=0:length(din)-1
            din_prt = inprts(din(end-k));
            din_lh = get_param(din_prt{1},'LineHandles');
            delete_line(din_lh.Outport(1));
            delete_block(din_prt{1});
        end
        %delete output ports
        for j=0:length(dout)-1
            dout_prt = outprts(dout(end-j));
            dout_lh = get_param(dout_prt{1},'LineHandles');
            delete_line(dout_lh.Inport(1));
            delete_block(dout_prt{1});
        end
    end

    function add_data_ports(subsysblk, nof_streams)
        map = gen_map(nof_streams);
        nof_outputs = ((nof_streams + 1) * nof_streams)/2;

        for i=0:1:nof_streams-1
            din_str_n = sprintf([subsysblk '/din_%d'],i);
            add_block('simulink/Commonly Used Blocks/In1',din_str_n);
            din_ph = get_param(din_str_n,'PortHandles');
            add_line(subsysblk,din_ph.Outport(1),bbports.Inport(i+2));
        end

        for o=0:1:nof_outputs-1
            a = map(o+1,1);
            b = map(o+1,2);
            dout_str_n = sprintf([subsysblk '/din%d_x_din%d'],a,b);
            add_block('simulink/Commonly Used Blocks/Out1',dout_str_n);
            dout_ph = get_param(dout_str_n,'PortHandles');
            add_line(subsysblk,bbports.Outport(o+2),dout_ph.Inport(1));
        end
    end

    updatedataprts(subsysblk, cross_multiplier_bb);
    delete_all_data_ports();
    updatedataprts(subsysblk, cross_multiplier_bb);
    add_data_ports(subsysblk, nof_streams);
end