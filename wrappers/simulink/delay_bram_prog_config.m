
function delay_bram_prog_config(this_block)

  this_block.setTopLevelLanguage('VHDL');
  delay_bram_prog = this_block.blockName;
  delay_bram_prog_parent = get_param(delay_bram_prog,'Parent');

  this_block.setEntityName('delay_bram_prog');
  max_delay = get_param(delay_bram_blk_en_plus_parent,'max_delay');
  bram_primitive = get_param(delay_bram_blk_en_plus_parent,'bram_primitive');
  ram_latency = get_param(delay_bram_blk_en_plus_parent,'ram_latency');
  
  % System Generator has to assume that your entity  has a combinational feed through; 
  %   if it  doesn't, then comment out the following line:
  this_block.tagAsCombinational;

  this_block.addSimulinkInport('din');
  this_block.addSimulinkInport('delay');

  this_block.addSimulinkOutport('dout');

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.

    % (!) Port 'din' appeared to have dynamic type in the HDL -- please add type checking as appropriate;

    % (!) Port 'delay' appeared to have dynamic type in the HDL -- please add type checking as appropriate;

  % (!) Port 'dout' appeared to have dynamic type in the HDL
  % --- you must add an appropriate type setting for this port
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

    uniqueInputRates = unique(this_block.getInputRates);

  % (!) Custimize the following generic settings as appropriate. If any settings depend
  %      on input types, make the settings in the "inputTypesKnown" code block.
  %      The addGeneric function takes  3 parameters, generic name, type and constant value.
  %      Supported types are boolean, real, integer and string.
  this_block.addGeneric('g_max_delay','NATURAL','7');
  this_block.addGeneric('g_ram_primitive','STRING','"block"');
  this_block.addGeneric('g_ram_latency','NATURAL','2');

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
  this_block.addFile('C:/Users/mybur/Work/CASPER/dspdevel_designs/casper_dspdevel/casper_delay/delay_bram_prog.vhd');

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

