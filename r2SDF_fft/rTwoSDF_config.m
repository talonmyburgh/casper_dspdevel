
function rTwoSDF_config(this_block)

  % Revision History:
  %
  %   03-Jun-2020  (15:52 hours):
  %     Original code was machine generated by Xilinx's System Generator after parsing
  %     /home/talon/Documents/CASPERWORK/casper_dspdevel/r2SDF_fft/rTwoSDF.vhd
  %`
  %

  this_block.setTopLevelLanguage('VHDL');

  this_block.setEntityName('rTwoSDF');

  % System Generator has to assume that your entity  has a combinational feed through; 
  %   if it  doesn't, then comment out the following line:
  this_block.tagAsCombinational;

  this_block.addSimulinkInport('clk');
  this_block.addSimulinkInport('rst');
  this_block.addSimulinkInport('in_re');
  this_block.addSimulinkInport('in_im');
  this_block.addSimulinkInport('in_val');

  this_block.addSimulinkOutport('out_re');
  this_block.addSimulinkOutport('out_im');
  this_block.addSimulinkOutport('out_val');

  out_val_port = this_block.port('out_val');
  out_val_port.setType('UFix_1_0');
  out_val_port.useHDLVector(false);

  % -----------------------------
  if (this_block.inputTypesKnown)
    % do input type checking, dynamic output type and generic setup in this code block.

    if (this_block.port('clk').width ~= 1)
      this_block.setError('Input data type for port "clk" must have width=1.');
    end

    this_block.port('clk').useHDLVector(false);

    if (this_block.port('rst').width ~= 1)
      this_block.setError('Input data type for port "rst" must have width=1.');
    end

    this_block.port('rst').useHDLVector(false);

    % (!) Port 'in_re' appeared to have dynamic type in the HDL -- please add type checking as appropriate;

    % (!) Port 'in_im' appeared to have dynamic type in the HDL -- please add type checking as appropriate;

    if (this_block.port('in_val').width ~= 1)
      this_block.setError('Input data type for port "in_val" must have width=1.');
    end

    this_block.port('in_val').useHDLVector(false);

  % (!) Port 'out_re' appeared to have dynamic type in the HDL
  % --- you must add an appropriate type setting for this port
  % (!) Port 'out_im' appeared to have dynamic type in the HDL
  % --- you must add an appropriate type setting for this port
  end  % if(inputTypesKnown)
  % -----------------------------

  % System Generator found no apparent clock signals in the HDL, assuming combinational logic.
  % -----------------------------
   if (this_block.inputRatesKnown)
     inputRates = this_block.inputRates; 
     uniqueInputRates = unique(inputRates); 
     outputRate = uniqueInputRates(1);
     for i = 2:length(uniqueInputRates)
       if (uniqueInputRates(i) ~= Inf)
         outputRate = gcd(outputRate,uniqueInputRates(i));
       end
     end  % for(i)
     for i = 1:this_block.numSimulinkOutports 
       this_block.outport(i).setRate(outputRate); 
     end  % for(i)
   end  % if(inputRatesKnown)
  % -----------------------------

    uniqueInputRates = unique(this_block.getInputRates);

  % (!) Custimize the following generic settings as appropriate. If any settings depend
  %      on input types, make the settings in the "inputTypesKnown" code block.
  %      The addGeneric function takes  3 parameters, generic name, type and constant value.
  %      Supported types are boolean, real, integer and string.
  this_block.addGeneric('g_nof_chan','natural','0');
  this_block.addGeneric('g_use_reorder','boolean','true');
  this_block.addGeneric('g_in_dat_w','natural','8');
  this_block.addGeneric('g_out_dat_w','natural','14');
  this_block.addGeneric('g_stage_dat_w','natural','18');
  this_block.addGeneric('g_guard_w','natural','2');
  this_block.addGeneric('g_nof_points','natural','1024');
  this_block.addGeneric('g_pipeline','t_fft_pipeline','c_fft_pipeline');

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
  this_block.addFile('rTwoSDF.vhd');

return;


