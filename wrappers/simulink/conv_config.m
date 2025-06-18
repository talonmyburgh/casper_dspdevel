%% A Simulink wrapper the HDL CASPER conv.
%% @author: Talon Myburgh
%% @company: Mydon Solutions
function conv_config(this_block)

  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName('conv');
  filepath = fileparts(which('conv_config'));
  this_block.setEntityName('conv');
  conv = this_block.blockName;
  conv_parent = get_param(conv, 'Parent');

  this_block.tagAsCombinational;

  this_block.addSimulinkInport('din');
  din = this_block.port('din');

  this_block.addSimulinkOutport('dout');
  dout = this_block.port('dout');

  str_width = '8';
  % -----------------------------
  if (this_block.inputTypesKnown)
    width = din.width;
    str_width = num2str(width);
    binpt = din.binpt;
    if (width < 1)
      this_block.setError('Input data type for port "din" must have width >= 1.');
    end
    din_datatype = sprintf('Ufix_%d_%d', width, binpt);
    dout_datatype = sprintf('Fix_%d_%d', width, binpt);
    din.setType(din_datatype);
    dout.setType(dout_datatype);
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------
  this_block.addGeneric('g_din_width', 'NATURAL', str_width);
  uniqueInputRates = unique(this_block.getInputRates);

  this_block.addFileToLibrary([filepath '/../../misc/conv.vhd'],'xil_default_lib');
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

