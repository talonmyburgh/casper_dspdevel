
function partial_delay_prog_config(this_block)
  this_block.setTopLevelLanguage('VHDL');
  filepath = fileparts(which('partial_delay_prog_config'));
  this_block.setEntityName('partial_delay_prog_top');
  partial_delay_prog_blk = this_block.blockName;
  partial_delay_prog_blk_parent = get_param(partial_delay_prog_blk, 'Parent');

  %set some width defaults to avoid errors
  din_width = 10;

  function boolval =  checkbox2bool(bxval)
    if strcmp(bxval, 'on')
     boolval= true;
    elseif strcmp(bxval, 'off')
     boolval= false;
    end 
  end

  function strboolval = bool2str(bval)
      if bval
          strboolval = 'TRUE';
      elseif ~bval
          strboolval = 'FALSE';
      end
  end

  is_async = checkbox2bool(get_param(partial_delay_prog_blk_parent, 'async'));
  is_async_str = bool2str(is_async);
  num_ports = get_param(partial_delay_prog_blk_parent, 'n_ports');
  num_ports_dbl = str2double(num_ports);
  latency = get_param(partial_delay_prog_blk_parent, 'mux_latency');


  this_block.addSimulinkInport('delay');
  delay_port = this_block.port('delay');
  if is_async
    this_block.addSimulinkInport('en');
  end
  for i = 1:num_ports_dbl
    this_block.addSimulinkInport(sprintf('din_%d', i));
    this_block.addSimulinkOutport(sprintf('dout_%d', i));
  end

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.
    
    if (this_block.port('en').width ~= 1) && is_async
      this_block.setError('Input data type for port "en" must have width=1.');
      this_block.port('en').setType('Bool');
    end
    delay_port.useHDLVector(true);

    for i=1:num_ports_dbl
      din_port = this_block.port(sprintf('din_%d', i));
      if i == 1
        din_width = din_port.getWidth;
      else
        if din_port.width ~= din_width
          this_block.setError('All input data ports must have the same width.');
        end
      end
      dout_port = this_block.port(sprintf('dout_%d', i));
      dout_port.setWidth(din_width);
      din_port.useHDLVector(true);
      dout_port.useHDLVector(true);
    end
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  this_block.addGeneric('g_async','boolean',is_async_str);
  this_block.addGeneric('g_num_ports','integer',num_ports);
  this_block.addGeneric('g_mux_latency','natural',latency);

  [partial_delay_prog_top_file, var_mux_update_file] = partial_delay_prog_code_gen(num_ports_dbl, din_width);

  this_block.addFileToLibrary(partial_delay_prog_top_file, 'xil_defaultlib');
  this_block.addFileToLibrary([filepath '../../casper_delay/partial_delay_prog.vhd'], 'xil_defaultlib');
  this_block.addFileToLibrary(var_mux_update_file, 'casper_reoder_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'],'common_pkg_lib');
return;
end

% ------------------------------------------------------------

function setup_as_single_rate(block,clkname,cename) 
  inputRates = block.inputRates; 
  uniqueInputRates = unique(inputRates); 
  if (length(uniqueInputRates)==1 & uniqueInputRates(1)==Inf) 
    block.addError('The inputs to this block cannot all be constant.'); 
    return; 
  end 
  if (uniqueInputRates(end) == Inf) 
     hasConstantInput = true; 
     uniqueInputRates = uniqueInputRates(1:end-1); 
  end 
  if (length(uniqueInputRates) ~= 1) 
    block.addError('The inputs to this block must run at a single rate.'); 
    return; 
  end 
  theInputRate = uniqueInputRates(1); 
  for i = 1:block.numSimulinkOutports 
     block.outport(i).setRate(theInputRate); 
  end 
  block.addClkCEPair(clkname,cename,theInputRate); 
  return; 
end
% ------------------------------------------------------------

