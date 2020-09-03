function topwb_code_gen(wb_factor)
    %gather all the string arrays required to write full file:
    filepath = fileparts(which('topwb_code_gen'));                         %get filepath of this script
    vhdlfile = filepath+"/wideband_fft_top.vhd";
    hdlstr = splitlines(fileread(vhdlfile));                               %make it into a character array (each line is new row)
    prtstr = ['--data streaming in/out ports ', ...
        '(DO NOT REMOVE THIS COMMENT)'];
    i=find(contains(hdlstr,prtstr));                                       %Locate line index of specific comment to add ports after
    lnsuptoportdec = join(hdlstr(1:i),'\n');                               %create an array of lines up and to specified comment
    portdec = join(mknprts(wb_factor),'\n');                               %fetch port declarations
    j=find(contains(hdlstr,'architecture RTL of wideband_fft_top is'));    %locate start of architecture
    archstr = ['--signal assignments made here',...
        ' (DO NOT REMOVE THIS COMMENT)'];
    k=find(contains(hdlstr,archstr));
    lnsafterarchopen = join(hdlstr(j:k),'\n');                             %create an array of lines from architecture opening till where 
                                                                           %we wish to insert signal mappings in architecture
    archdec = join(mkarch(wb_factor),'\n');
    
    %Done with breaking strings up, now write them to hdl file:
    Vfile = fopen(vhdlfile,'w');
    fprintf(Vfile,lnsuptoportdec{:});
    fprintf(Vfile,'\n');
    fprintf(Vfile,portdec{:});
    fprintf(Vfile,'\n');
    fprintf(Vfile,");\nend entity wideband_fft_top;");
    fprintf(Vfile,'\n');
    fprintf(Vfile,lnsafterarchopen{:});
    fprintf(Vfile,'\n');
    fprintf(Vfile,archdec{:});
    fprintf(Vfile,"\nend architecture RTL;");
    fclose(Vfile);
end

function chararr = mknprts(wbfctr)
chararr = strings(6*wbfctr,0);
inimchar = "in_im_%c : in STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);"; 
inrechar = "in_re_%c : in STD_LOGIC_VECTOR(in_dat_w-1 DOWNTO 0);"; 
indatchar = "in_data_%c : in STD_LOGIC_VECTOR(2*in_dat_w-1 DOWNTO 0);";
outimchar = "out_im_%c : out STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0);"; 
outrechar = "out_re_%c : out STD_LOGIC_VECTOR(out_dat_w-1 DOWNTO 0);"; 
outdatchar = "out_data_%c : out STD_LOGIC_VECTOR(2*out_dat_w-1 DOWNTO 0);";
i=1;
    for j=0:1:wbfctr-1
        jj = int2str(j);
        chararr(i,1)=sprintf(inimchar,jj);
        i=i+1;
        chararr(i,1)=sprintf(inrechar,jj);
        i=i+1;
        chararr(i,1)=sprintf(indatchar,jj);
        i=i+1;
        chararr(i,1)=sprintf(outimchar,jj);
        i=i+1;
        chararr(i,1)=sprintf(outrechar,jj);
        i=i+1;
        if (j ~= wbfctr-1)
            chararr(i,1)=sprintf(outdatchar,jj);
        else
            chararr(i,1)=sprintf(strip(outdatchar,';'),jj);
        end
        i=i+1;
    end
end

function achararr = mkarch(wbfctr)
    achararr = strings(6*wbfctr,0);
    imap_re_c = "in_sosi_arr(%c).re <= RESIZE_SVEC(in_re_%c, in_sosi_arr(%c).re'length);";
    imap_im_c = "in_sosi_arr(%c).im <= RESIZE_SVEC(in_im_%c, in_sosi_arr(%c).im'length);";
    imap_data_c = "in_sosi_arr(%c).data <= RESIZE_SVEC(in_data_%c, in_sosi_arr(%c).data'length);";
    omap_re_c = "out_re_%c <= RESIZE_SVEC(out_sosi_arr(%c).re,out_dat_w);";
    omap_im_c = "out_im_%c <= RESIZE_SVEC(out_sosi_arr(%c).im,out_dat_w);";
    omap_data_c = "out_data_%c <= RESIZE_SVEC(out_sosi_arr(%c).data,2*out_dat_w);";
    
    l = 1;
        for m=0:1:wbfctr-1
            mm = int2str(m);
            achararr(l,1)=sprintf(imap_re_c,mm,mm,mm);
            l=l+1;
            achararr(l,1)=sprintf(imap_im_c,mm,mm,mm);
            l=l+1;
            achararr(l,1)=sprintf(imap_data_c,mm,mm,mm);
            l=l+1;
            achararr(l,1)=sprintf(omap_re_c,mm,mm);
            l=l+1;
            achararr(l,1)=sprintf(omap_im_c,mm,mm);
            l=l+1;
            achararr(l,1)=sprintf(omap_data_c,mm,mm);
            l=l+1;
        end
end