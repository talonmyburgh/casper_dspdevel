import os
import sys
import glob

# launch vivado in tcl mode and execute tcl script to write out hierarchy to txt file
vivcommand = os.path.abspath('C:/Xilinx/Vivado/2020.1/bin/vivado.bat') +' -mode batch -source getprojhierarchy.tcl -tclargs '+os.path.abspath(sys.argv[1])
os.system(vivcommand)

# open hierarchy txt file
with open('./tmp.txt', mode="r") as hierarchyfile:
    # readlines
    hier_lines = hierarchyfile.readlines()
    for i, hline in enumerate(hier_lines):
        # split the full path for each file to get folder_name (used to define library name) and file_name
        splt_hier = hier_lines[i].strip().split('/')[-3:]
        if (splt_hier[0] == "ip_xpm"):
            libname = "\'" + splt_hier[0] + "_" + splt_hier[1] + "_lib\'"
            localpath = "filepath \'/../../" + splt_hier[0] + "/" + splt_hier[1] + "/" + splt_hier[2] + "\'" 
            hier_lines[i] = "this_block.addFileToLibrary([" + localpath + "]," + libname + ");\n"
        else:
            libname = "\'" + splt_hier[1] + "_lib\'"
            localpath = "filepath \'/../../" + splt_hier[1] + "/" + splt_hier[2] + "\'" 
            hier_lines[i] = "this_block.addFileToLibrary([" + localpath + "]," + libname + ");\n"
hierarchyfile.close()

# open matlab config file in read mode
print(sys.argv)
with open(sys.argv[2], mode='r') as mlibfile:
    mlib_lines = mlibfile.readlines()
    # locate where comment tag to include file names is
    lines = []
    for j, mline in enumerate(mlib_lines):
        # lsub_mlines = slice up to commment tag
        # rsub_mlines = slice from next return statement to end after comment tag
        if(mline.strip() == "%ADD FILES HERE:"):
            lsub_mlines = mlib_lines[:j]
            #get sublist of lines from next return statement
            rsub_ind = [x.strip() for x in mlib_lines[j:]].index("return;")
            rsub_mlines = mlib_lines[rsub_ind+j:]
            # concatenate lsub_mlines with the include lines created from hierarchy file followed by the remainder of the lines from the return - reversed for correct compile order
            lines = lsub_mlines + hier_lines + rsub_mlines
            continue
        else:
            continue
    if not lines:
        raise Exception("Tag: \"%ADD FILES HERE:\" in specified config.m file not located. Aborting.")
mlibfile.close()

# open config file in write mode
with open(os.path.abspath(sys.argv[2]), mode='w') as mlibfile:
    if lines:
        # writeout
        mlibfile.writelines(lines)

filesToRemove = ['./tmp.txt'] + glob.glob('./vivado*.jou') + glob.glob('./vivado*.log')
for rmFiles in filesToRemove:
    try:
        os.remove(rmFiles)
    except:
        print("Error while deleting file : ", rmFiles)
