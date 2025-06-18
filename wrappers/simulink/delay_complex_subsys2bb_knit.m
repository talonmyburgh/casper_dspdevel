function delay_complex_subsys2bb_knit()

    function boolval =  checkbox2bool(bxval)
        if strcmp(bxval, 'on')
            boolval= true;
        elseif strcmp(bxval, 'off')
            boolval= false;
        end 
    end

    subsysblk = gcb;
    delay_complex_bb = [subsysblk '/delay_complex'];
    is_async = checkbox2bool(get_param(subsysblk,'is_async'));

    inprts = find_system(subsysblk,'LookUnderMasks','on','BlockType','Inport');
    in_en = find(contains(inprts,'en'));

    bbports = get_param(delay_complex_bb,'PortHandles');
    if(is_async)
        if(isempty(in_en))
            in_en_str = [subsysblk '/en'];
            add_block('simulink/Commonly Used Blocks/In1',in_en_str);
            en_ph = get_param(in_en_str,'PortHandles');
            add_line(subsysblk, en_ph.Outport(1),bbports.Inport(2));
        end
    else
        if(isempty(in_en))
            %do nothing
        else
            in_en_str = [subsysblk '/en'];
            in_en_lh = get_param(in_en_str,'LineHandles');
            delete_line(in_en_lh.Outport(1));
            delete_block(in_en_str);
        end
    end
end