function cmult_subsys2bb_knit()

    function boolval =  checkbox2bool(bxval)
        if strcmp(bxval, 'on')
            boolval= true;
        elseif strcmp(bxval, 'off')
            boolval= false;
        end 
    end

    subsysblk = gcb;
    cmult_bb = [subsysblk '/cmult'];
    is_async = checkbox2bool(get_param(subsysblk,'is_async'));

    inprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Inport');
    outprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Outport');
    rst = find(contains(inprts,'rst'));
    in_val = find(contains(inprts,'in_val'));
    out_val = find(contains(outprts,'out_val'));

    bbports = get_param(cmult_bb,'PortHandles');
    if(~is_async)
        if(isempty(rst) && isempty(in_val) && isempty(out_val))
            rst_str = [subsysblk '/rst'];
            in_val_str = [subsysblk '/in_val'];
            out_val_str = [subsysblk '/out_val'];

            add_block('simulink/Commonly Used Blocks/In1',rst_str);
            rst_ph = get_param(rst_str,'PortHandles');
            add_line(subsysblk, rst_ph.Outport(1),bbports.Inport(3));

            add_block('simulink/Commonly Used Blocks/In1',in_val_str);
            in_val_ph = get_param(in_val_str,'PortHandles');
            add_line(subsysblk, in_val_ph.Outport(1),bbports.Inport(4));

            add_block('simulink/Commonly Used Blocks/Out1',out_val_str);
            out_val_ph = get_param(out_val_str,'PortHandles');
            add_line(subsysblk, bbports.Outport(2), out_val_ph.Inport(1));
        end
    else
        if(isempty(rst) && isempty(in_val))
            %do nothing
        else
            rst_str = [subsysblk '/rst'];
            in_val_str = [subsysblk '/in_val'];
            out_val_str = [subsysblk '/out_val'];

            rst_lh = get_param(rst_str,'LineHandles');
            delete_line(rst_lh.Outport(1));
            delete_block(rst_str);

            in_val_lh = get_param(in_val_str,'LineHandles');
            delete_line(in_val_lh.Outport(1));
            delete_block(in_val_str);

            out_val_lh = get_param(out_val_str,'LineHandles');
            delete_line(out_val_lh.Inport(1));
            delete_block(out_val_str);
        end
    end
end