global repo_root_dir
global proj_folder
global common_folder

proc common_systemverilog {} {
    global srclist_sv
    global common_dir

    if {![info exists srclist_sv]} {
        set srclist_sv {}
    }

    set sv_dir ${common_dir}/systemverilog
    foreach src {
        axis_bus_to_axis_bus_ce.sv
        axis_skid_buffer.sv
        axis_skid_buffer_fp_opt.sv
        mbus_skid_buffer.sv

        rst_sync.sv

        muxes.sv
        uart.sv
        util.sv

        user.sv
    } {
        lappend srclist_sv $sv_dir/$src
    }
}

proc common_verilog {} {
    global srclist_v
    global common_dir

    if {![info exists srclist_v]} {
        set srclist_v {}
    }

    set v_dir ${common_dir}/verilog
    foreach src {
    } {
        lappend srclist_v $v_dir/$src
    }
}

proc common_vhdl {} {
    global srclist_vhdl
    global common_dir

    if {![info exists srclist_vhdl]} {
        set srclist_vhdl {}
    }

    set vhdl_dir ${common_dir}/vhdl
    foreach src {
        axis_fifo_sync.vhd
        utils.vhd
    } {
        lappend srclist_vhdl $vhdl_dir/$src
    }
}


set common_dir ${repo_root_dir}/${proj_folder}/${common_folder}

common_systemverilog
common_verilog
common_vhdl