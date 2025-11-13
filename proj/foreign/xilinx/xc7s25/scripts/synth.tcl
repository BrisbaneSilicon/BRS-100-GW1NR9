global repo_root_dir
global proj_folder
global foreign_folder
global platform
global target_part

proc xilinx_systemverilog {} {
    global srclist_sv
    global platform_dir

    if {![info exists srclist_sv]} {
        set srclist_sv {}
    }

    set sv_dir ${platform_dir}/systemverilog
    foreach src {
        top.sv
    } {
        lappend srclist_sv $sv_dir/$src
    }
}

set platform_dir ${repo_root_dir}/${proj_folder}/${foreign_folder}/${platform}/${target_part}

xilinx_systemverilog