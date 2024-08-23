
function partial_delay_prog_config(this_block)

  this_block.setTopLevelLanguage('VHDL');
  filepath = fileparts(which('partial_delay_prog_config'));
  this_block.setEntityName('partial_delay_prog_top');
  partial_delay_prog_blk = this_block.blockName;
  partial_delay_prog_blk_parent = get_param(partial_delay_prog_blk, 'Parent');

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

    if (this_block.port('en').width ~= 1);
      this_block.setError('Input data type for port "en" must have width=1.');
    end

    this_block.port('en').useHDLVector(false);

    % (!) Port 'delay' appeared to have dynamic type in the HDL -- please add type checking as appropriate;

    % (!) Port 'din_1' appeared to have dynamic type in the HDL -- please add type checking as appropriate;

    % (!) Port 'din_2' appeared to have dynamic type in the HDL -- please add type checking as appropriate;

    % (!) Port 'din_3' appeared to have dynamic type in the HDL -- please add type checking as appropriate;

  % (!) Port 'dout_1' appeared to have dynamic type in the HDL
  % --- you must add an appropriate type setting for this port
  % (!) Port 'dout_2' appeared to have dynamic type in the HDL
  % --- you must add an appropriate type setting for this port
  % (!) Port 'dout_3' appeared to have dynamic type in the HDL
  % --- you must add an appropriate type setting for this port
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

    uniqueInputRates = unique(this_block.getInputRates);

  this_block.addGeneric('g_async','boolean',is_async_str);
  this_block.addGeneric('g_num_ports','integer',num_ports);
  this_block.addGeneric('g_mux_latency','natural',latency);

  % Add addtional source files as needed.
  %  |-------------
  %  | Add files in the order in which they should be compiled.
  %  | If two files "a.vhd" and "b.vhd" contain the entities
  %  | entity_a and entity_b, and entity_a contains a
  %  | component of type entity_b, the correct sequence of
  %  | addFile() calls would be:
  %  |    this_block.addFile('b.vhd');
  %  |    this_block.addFile('a.vhd');
  %  |-------------

  %    this_block.addFile('');
  %    this_block.addFile('');
  this_block.addFile('C:/Users/mybur/Repos/CASPER/dspdevel_designs/casper_dspdevel/casper_delay/partial_delay_prog_blk_partial_delay_prog_top.vhd');

return;


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

% ------------------------------------------------------------

