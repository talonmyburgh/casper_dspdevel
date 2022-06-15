
function addr_bram_vacc_config(this_block)

  filepath = fileparts(which('addr_bram_vacc_config'));
  this_block.setTopLevelLanguage('VHDL');
  addr_bram_vacc = this_block.blockName;
  addr_bram_vacc_parent = get_param(addr_bram_vacc,'Parent');

  this_block.setEntityName('addr_bram_vacc');

  function boolval =  checkbox2bool(bxval)
    if strcmp(bxval, 'on')
     boolval= true;
    elseif strcmp(bxval, 'off')
     boolval= false;
    end 
  end
  function strboolval = bool2sign(bval)
    if bval
        strboolval = "SIGNED";
    elseif ~bval
        strboolval = "UNSIGNED";
    end
end

  vector_length = get_param(delay_bram_prog_parent,'vector_length');
  vector_length_dbl = str2num(output_bit_w)
  output_sign = checkbox2bool(get_param(delay_bram_prog_parent,'output_sign'));
  output_sign_sign = bool2sign(output_sign)
  output_bit_w = get_param(delay_bram_prog_parent,'output_bit_w');
  output_bit_w_dbl = str2num(output_bit_w)
  output_bin_pt = get_param(delay_bram_prog_parent,'output_bin_pt');
  output_bin_pt_dbl = str2num(output_bin_pt)

  this_block.addSimulinkInport('new_acc');
  new_acc_port = this_block.port('new_acc');
  this_block.addSimulinkInport('din');
  din_port = this_block.port('din');

  this_block.addSimulinkOutport('addr');
  addr_port = this_block.port('addr');
  this_block.addSimulinkOutport('we');
  we_port = this_block.port('we');
  this_block.addSimulinkOutport('dout');
  dout_port = this_block.port('dout');

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.

    if (this_block.port('new_acc').width ~= 1);
      this_block.setError('Input data type for port "new_acc" must have width=1.');
    end

    new_acc_port.useHDLVector(false);
    we_port.useHDLVector(false);

    if(output_sign)
      dout_port.setType(sprintf("Fix_%d_%d",output_bit_w_dbl,output_bin_pt_dbl));
    else
      dout_port.setType(sprintf("Ufix_%d_%d",output_bit_w_dbl,output_bin_pt_dbl));
    end;

    addr_port.setWidth(ceil(log2(vector_length_dbl)))
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
  this_block.addGeneric('g_vector_length','NATURAL','16');
  this_block.addGeneric('g_output_type','STRING','"SIGNED"');
  this_block.addGeneric('g_bit_w','NATURAL','32');

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
  this_block.addFile('C:/Users/mybur/OneDrive/Work/CASPER/dspdevel_designs/casper_dspdevel/casper_accumulators/addr_bram_vacc.vhd');

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

