
function sync_delay_config(this_block)

  function boolval =  checkbox2bool(bxval)
    if strcmp(bxval, 'on')
     boolval= true;
    elseif strcmp(bxval, 'off')
     boolval= false;
    end 
  end

  function strval =  checkbox2str(bxval)
    if strcmp(bxval, 'on')
    strval= 'TRUE';
    elseif strcmp(bxval, 'off')
    strval= 'FALSE';
    end 
  end

  this_block.setTopLevelLanguage('VHDL');

  this_block.setEntityName('sync_delay');
  filepath = fileparts(which('sync_delay_config'));

  sync_delay = this_block.blockName;
  sync_delay_parent = get_param(sync_delay,'Parent');
  delay = get_param(sync_delay_parent,'DelayLen');
  async = checkbox2bool(get_param(sync_delay_parent,'async'));
  async_str = checkbox2str(get_param(sync_delay_parent,'async'));
  use_delay_port = checkbox2bool(get_param(sync_delay_parent,'use_delay_port'));
  use_delay_port_str = checkbox2str(get_param(sync_delay_parent,'use_delay_port'));

  this_block.addSimulinkInport('din');
  din_port = this_block.port('din');

  if async
    this_block.addSimulinkInport('en');
    en_port = this_block.port('en');
    en_port.setType('Bool');
    en_port.useHDLVector(false);
  end

  if use_delay_port
    this_block.addSimulinkInport('delay');
    delay_port = this_block.port('delay');
    delay_port.useHDLVector(true);
  end

  this_block.addSimulinkOutport('dout');
  dout_port = this_block.port('dout');

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.

    if (this_block.port('din').width ~= 1);
      this_block.setError('Input data type for port "din" must have width=1.');
    end
    din_port.useHDLVector(false);

    dout_port.setType('Bool');
    dout_port.useHDLVector(false);

  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

    uniqueInputRates = unique(this_block.getInputRates);

  this_block.addGeneric('g_delay','NATURAL',delay);
  this_block.addGeneric('g_async','BOOLEAN',async_str);
  this_block.addGeneric('g_use_delay_port','BOOLEAN',use_delay_port_str);

  this_block.addFileToLibrary([filepath '/../../casper_delay/sync_delay.vhd'], 'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_float_types_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/fixed_pkg_c.vhd'],'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../common_pkg/common_pkg.vhd'], 'common_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../casper_counter/common_counter.vhd'], 'casper_counter_lib');
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

