open_project [lindex $argv 0]
set f [open tmp.txt w]
set hierarchy [get_files -compile_order sources -used_in synthesis]
foreach arch $hierarchy {
    puts $f $arch
}
close $f

