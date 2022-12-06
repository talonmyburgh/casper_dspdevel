function c_to_ri_config(this_block)

    this_block.setTopLevelLanguage('VHDL');
    this_block.setEntityName('c_to_ri');
    filepath = fileparts(which('c_to_ri_config'));
  
    c_to_ri_blk = this_block.blockName;
    c_to_ri_blk_parent = get_param(c_to_ri_blk,'Parent');
  
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
  
    is_async = checkbox2bool(get_param(c_to_ri_blk_parent,'is_async'));
    bit_width = get_param(c_to_ri_blk_parent,'bit_width');
    bin_pt = get_param(c_to_ri_blk_parent,'bin_pt');
  
    % System Generator has to assume that your entity  has a combinational feed through; 
    %   if it  doesn't, then comment out the following line:
    if is_async
      this_block.tagAsCombinational;
    end
  
    %Inputs
    this_block.addSimulinkInport('c_in');
    c_in_port = this_block.port('c_in');
    
    %Outputs
    this_block.addSimulinkOutport('re_out');
    re_out_port = this_block.port('re_out');
    
    this_block.addSimulinkOutport('im_out');
    im_out_port = this_block.port('im_out');
    
    if (this_block.inputTypesKnown)
      re_out_port.setType(sprintf('Fix_%s_%s',bit_width,bin_pt));
      im_out_port.setType(sprintf('Fix_%s_%s',bit_width,bin_pt));
    end
    % -----------------------------
  
     if (this_block.inputRatesKnown)
       setup_as_single_rate(this_block,'clk','ce')
     end  % if(inputRatesKnown)
    % -----------------------------
    
    %Generics:
    this_block.addGeneric('g_async','BOOLEAN',bool2str(is_async));
    this_block.addGeneric('g_bit_width','NATURAL',bit_width);
  
    %Add Files:
    this_block.addFileToLibrary([filepath '/../../misc/c_to_ri.vhd'],'misc_lib');
  
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
  
  % ------------------------------------------------------------
  end
  
  