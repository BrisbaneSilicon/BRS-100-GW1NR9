global repo_root_dir
global proj_folder
global foreign_folder
global platform
global lib_folder

proc lib_systemverilog {} {
    global srclist_sv
    global lib_dir

    if {![info exists srclist_sv]} {
        set srclist_sv {}
    }

    set sv_dir ${lib_dir}/systemverilog
    foreach src {
    } {
        lappend srclist_sv $sv_dir/$src
    }
}

proc lib_vhdl {} {
    global srclist_vhdl
    global lib_dir

    if {![info exists srclist_vhdl]} {
        set srclist_vhdl {}
    }

    set vhdl_dir ${lib_dir}/vhdl
    foreach src {
    } {
        lappend srclist_vhdl $vhdl_dir/$src
    }
}

set lib_dir ${repo_root_dir}/${proj_folder}/${foreign_folder}/${platform}/${lib_folder}/

lib_systemverilog
lib_vhdl