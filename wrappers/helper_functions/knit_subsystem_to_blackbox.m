function knit_subsystem_to_blackbox(black_box_name)
    sys_path = gcb;
    bb_path = [sys_path '/' black_box_name];

    % Unlink block, otherwise we're not allowed to modify it
    set_param(sys_path, 'LinkStatus', 'inactive');

    % Should not wipe all subsystem-ports because some
    % may be static and wired particularly:
    %  e.g. barrel-switcher inverts the port order of i_sel and i_sync

    % Get bb port name to handle map, in order to add signals
    [bb_port_table, bb_port_handles] = get_blackbox_port_table(bb_path);
    sys_port_table = get_subsystem_port_table(sys_path);
    
    % drop any subsystem ports that don't match the black-box
    sys_port_table = delete_excess_subsystem_ports(sys_port_table, bb_port_table);
    
    % add any missing subsystem ports to match the black-box
    sys_port_table = add_missing_subsystem_ports(sys_port_table, sys_path, bb_port_table, bb_port_handles, get_param(bb_path, 'Position'));
    
    neaten_subsystem_ports(sys_path, sys_port_table, bb_port_table, get_param(bb_path, 'Position'), bb_port_handles);
end

function [port_table, port_handles_struct] = get_blackbox_port_table(black_box_path)
    port_handles_struct = get_param(black_box_path, 'PortHandles');
    display_lines = get_param(black_box_path, 'MaskDisplay');
    tokens = regexp(display_lines, "port_label\('(\w+)',(\d+),'(\w+)'\);", 'tokens');

    names = strings(0);
    types = strings(0);
    handle_indices = [];
    for i = 1:length(tokens)
        token = tokens{i};
        names{i} = token{3};

        if strcmp(token{1}, 'input')
            types{i} = 'Inport';
        elseif strcmp(token{1}, 'output')
            types{i} = 'Outport';
        end
        handle_indices(i) = str2double(token{2});
    end

    port_table = table(types', handle_indices', 'VariableNames', {'type', 'handle_index'}, 'RowNames', names');
end

function port_table = get_subsystem_port_table(subsystem_path)
    names = strings(0);
    paths = strings(0);
    types = strings(0);
    index = 1;

    for port_type = {'Inport', 'Outport'}
        port_paths = find_system(subsystem_path,'LookUnderMasks','on','BlockType',port_type{1});
        for i = 1:length(port_paths)
            tokens = regexp(port_paths{i}, '.*/(\w+)', 'tokens');
            names{index} = tokens{1}{1};
            paths{index} = port_paths{i};
            types{index} = port_type{1};
            index = index + 1;
        end
    end
    port_table = table(types', paths', 'VariableNames', {'type', 'path'}, 'RowNames', names');
end

function sys_port_table = delete_excess_subsystem_ports(sys_port_table, bb_port_table)
    for sys_port_name = sys_port_table.Row(:)'
        if ~any(contains(bb_port_table.Row(:), sys_port_name{1}))
            port_path = sys_port_table.path(sys_port_name{1});

            port_lh = get_param(port_path, 'LineHandles');
            if port_lh.Inport
              delete_line(port_lh.Inport);
            end
            if port_lh.Outport
              delete_line(port_lh.Outport);
            end
            delete_block(port_path);
            sys_port_table(sys_port_name{1}, :) = [];
        end
    end
end

function sys_port_table = add_missing_subsystem_ports(sys_port_table, sys_path, bb_port_table, bb_port_handles, bb_position_box)
    port_block_path = 'simulink/Commonly Used Blocks/';
    names = strings(0);
    paths = strings(0);
    types = strings(0);
    index = 1;

    % bb_inport_count = sum(strcmp(bb_port_table.type, 'Inport'));
    % bb_outport_count = sum(strcmp(bb_port_table.type, 'Outport'));

    for bb_port_name = bb_port_table.Row(:)'
        if ~any(contains(sys_port_table.Row(:), bb_port_name{1}))
            port_path = [sys_path '/' bb_port_name{1}];

            port_type_str = bb_port_table.type(bb_port_name{1});
            port_handle_index = bb_port_table.handle_index(bb_port_name{1});

            if strcmp(port_type_str, 'Inport')
                add_block([port_block_path 'In1'], port_path);
                % set_param(port_path, 'Position', calculate_subsystem_port_position(port_type_str, port_handle_index, bb_inport_count, bb_position_box));

                port_ph = get_param(port_path, 'PortHandles');
                add_line(sys_path, port_ph.Outport(1), bb_port_handles.Inport(port_handle_index));
            elseif strcmp(port_type_str, 'Outport')
                add_block([port_block_path 'Out1'], port_path);
                % set_param(port_path, 'Position', calculate_subsystem_port_position(port_type_str, port_handle_index, bb_outport_count, bb_position_box));

                port_ph = get_param(port_path, 'PortHandles');
                add_line(sys_path, bb_port_handles.Outport(port_handle_index), port_ph.Inport(1));
            end

            names{index} = bb_port_name{1};
            paths{index} = port_path;
            types{index} = convertStringsToChars(port_type_str);
            index = index + 1;
        end

    end
    added_port_table = table(types', paths', 'VariableNames', {'type', 'path'}, 'RowNames', names');
    sys_port_table = [sys_port_table;added_port_table];
end

function neaten_subsystem_ports(sys_path, sys_port_table, bb_port_table, bb_position_box, bb_port_handles)
    % todo calculate the position as the port is added...
    bb_left_edge = bb_position_box(1);
    bb_right_edge = bb_position_box(3);
    bb_top_edge = bb_position_box(2);
    bb_height = abs(bb_position_box(4) - bb_top_edge);
    port_height = 15;
    port_width = 25;
    line_length = 100;
    alternative_line_offset = port_width + 10;

    inport_start_step = bb_height / sum(strcmp(bb_port_table.type, 'Inport'));
    outport_start_step = bb_height / sum(strcmp(bb_port_table.type, 'Outport'));

    for port_name = bb_port_table.Row(:)'
        port_index = bb_port_table.handle_index(port_name{1});
        port_path = sys_port_table.path(port_name{1});

        port_line_length = line_length;

        % reposition
        if strcmp(bb_port_table.type(port_name{1}), 'Inport')
            if mod(port_index,2) == 1
                port_line_length = port_line_length + alternative_line_offset;
            end

            postition = [
                bb_left_edge-port_line_length-port_width,
                bb_top_edge + (port_index-0.5)*inport_start_step - 0.5*port_height,
                bb_left_edge-port_line_length,
                bb_top_edge + (port_index-0.5)*inport_start_step + 0.5*port_height
            ];
        elseif strcmp(bb_port_table.type(port_name{1}), 'Outport')
            if mod(port_index,2) == 0
                port_line_length = port_line_length + alternative_line_offset;
            end

            postition = [
                bb_right_edge+port_line_length,
                bb_top_edge + (port_index-0.5)*outport_start_step - 0.5*port_height,
                bb_right_edge+port_line_length+port_width,
                bb_top_edge + (port_index-0.5)*outport_start_step + 0.5*port_height
            ];
        end
        set_param(port_path, 'Position', postition);
        
        % draw line
        port_ph = get_param(port_path, 'PortHandles');
        port_lh = get_param(port_path, 'LineHandles');
        if port_lh.Inport
            delete_line(port_lh.Inport);
            add_line(sys_path, bb_port_handles.Outport(port_index), port_ph.Inport(1));
        elseif port_lh.Outport
            delete_line(port_lh.Outport);
            add_line(sys_path, port_ph.Outport(1), bb_port_handles.Inport(port_index));
        end
    end
end

function position = calculate_subsystem_port_position(port_type_str, port_position_index, bb_port_type_count, bb_position_box)
    % todo calculate the position as the port is added...
    bb_left_edge = bb_position_box(1);
    bb_right_edge = bb_position_box(3);
    bb_top_edge = bb_position_box(2);
    bb_height = abs(bb_position_box(4) - bb_top_edge);
    port_height = 15;
    port_width = 25;
    line_length = 100;
    alternative_line_offset = port_width + 10;

    port_vertical_step = bb_height / bb_port_type_count;

    port_line_length = line_length;

    port_position_left = 0;

    % reposition
    if strcmp(port_type_str, 'Inport')
        if mod(port_position_index,2) == 1
            port_line_length = port_line_length + alternative_line_offset;
        end

        port_position_left = bb_left_edge+port_line_length-port_width;
    elseif strcmp(port_type_str, 'Outport')
        if mod(port_position_index,2) == 0
            port_line_length = port_line_length + alternative_line_offset;
        end

        port_position_left = bb_right_edge+port_line_length;
    end
    position = [
        port_position_left,
        bb_top_edge + (port_position_index-0.5)*port_vertical_step - 0.5*port_height,
        port_position_left+port_width,
        bb_top_edge + (port_position_index-0.5)*port_vertical_step + 0.5*port_height
    ];
end
