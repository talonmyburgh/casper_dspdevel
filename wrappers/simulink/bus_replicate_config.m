
function bus_replicate_config(this_block)

  % Revision History:
  %
  %   31-Aug-2024  (16:09 hours):
  %     Original code was machine generated by Xilinx's System Generator after parsing
  %     C:\Users\radonn\Work\source\dspdevel_designs\casper_dspdevel\casper_bus\bus_replicate.vhd
  %
  %

  this_block.setTopLevelLanguage('VHDL');
  this_block.setEntityName('bus_replicate');
  
  filepath = fileparts(which('bus_replicate_config'));

  bus_replicate_blk = this_block.blockName;
  bus_create_blk_parent = get_param(bus_replicate_blk,'Parent');

  % System Generator has to assume that your entity  has a combinational feed through; 
  %   if it  doesn't, then comment out the following line:
  replication_factor = str2double(get_param(bus_create_blk_parent,'replication_factor'));
  latency = str2double(get_param(bus_create_blk_parent,'delay'));
  if (latency == 0) 
    this_block.tagAsCombinational;
  end

  this_block.addSimulinkInport('i_data');
  this_block.addSimulinkOutport('o_data');


  % -----------------------------
  if (this_block.inputTypesKnown)
    i_data_port = this_block.port('i_data');
    
    o_data_port = this_block.port('o_data');
    o_data_port.setWidth(replication_factor*i_data_port.width);
  end  % if(inputTypesKnown)
  % -----------------------------

  % -----------------------------
   if (this_block.inputRatesKnown)
     setup_as_single_rate(this_block,'clk','ce')
   end  % if(inputRatesKnown)
  % -----------------------------

  this_block.addGeneric('g_replication_factor','NATURAL', int2str(replication_factor));
  this_block.addGeneric('g_latency','NATURAL', int2str(latency));

  %Add Files:
  this_block.addFileToLibrary([filepath '/../../casper_bus/bus_replicate.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../casper_bus/bus_fill_slv_arr.vhd'],'xil_defaultlib');
  this_block.addFileToLibrary([filepath '/../../casper_delay/delay_simple.vhd'],'casper_delay_lib');
  this_block.addFileToLibrary([filepath '/../../common_slv_arr_pkg/common_slv_arr_pkg.vhd'],'common_slv_arr_pkg_lib');
  this_block.addFileToLibrary([filepath '/../../casper_flow_control/bus_create.vhd'],'casper_flow_control_lib');

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

