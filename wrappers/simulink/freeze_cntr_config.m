%% A Simulink wrapper the HDL CASPER freeze_cntr.
%% @author: Talon Myburgh
%% @company: Mydon Solutions
function freeze_cntr_config(this_block)

  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName('freeze_cntr');
  filepath = fileparts(which('freeze_cntr_config'));
  this_block.setEntityName('freeze_cntr');
  freeze_cntr = this_block.blockName;
  freeze_cntr_parent = get_param(freeze_cntr, 'Parent');

  cnt_bit_w = get_param(freeze_cntr_parent, 'CounterBits');

  this_block.addSimulinkInport('en');
  this_block.addSimulinkInport('rst');

  this_block.addSimulinkOutport('addr');
  this_block.addSimulinkOutport('we');
  this_block.addSimulinkOutport('done');

  we_port = this_block.port('we');
  we_port.setType('Ufix_1_0');
  we_port.useHDLVector(false);
  done_port = this_block.port('done');
  done_port.setType('Bool');
  done_port.useHDLVector(false);

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.
    if (this_block.port('en').width ~= 1);
      this_block.setError('Input data type for port "en" must have width=1.');
    end
    this_block.port('en').useHDLVector(false);

    if (this_block.port('rst').width ~= 1);
      this_block.setError('Input data type for port "rst" must have width=1.');
    end
    this_block.port('rst').useHDLVector(false);

    addr_port = this_block.port('addr');
    addr_port.setType(sprintf('Ufix_%s_0',cnt_bit_w));
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  uniqueInputRates = unique(this_block.getInputRates);

  this_block.addGeneric('g_num_cntr_bits','NATURAL',cnt_bit_w);

  this_block.addFileToLibrary([filepath '/../../misc/freeze_cntr.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../casper_counter/common_counter.vhd'],'casper_counter_lib');
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

