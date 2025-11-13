global repo_root_dir
global proj_folder
global foreign_folder
global platform
global target_part
global speed_grade

proc gowin_systemverilog {} {
    global srclist_sv
    global speed_grade_dir

    if {![info exists srclist_sv]} {
        set srclist_sv {}
    }

    set sv_dir ${speed_grade_dir}/systemverilog
    foreach src {
        clkdiv5.sv
        clkdiv2.sv
        clk51mhz.sv
        clk66mhz.sv
        clk75mhz.sv
        clk81mhz.sv
        clk87mhz.sv

        top.sv

        flash_memory.sv
        ram_memory.sv
        psram_controller.sv

        board_demonstration.sv
    } {
        lappend srclist_sv $sv_dir/$src
    }
}

proc gowin_verilog {} {
    global srclist_v
    global speed_grade_dir

    if {![info exists srclist_v]} {
        set srclist_v {}
    }

    set v_dir ${speed_grade_dir}/verilog
    foreach src {
    } {
        lappend srclist_v $v_dir/$src
    }
}

proc gowin_vhdl {} {
    global srclist_vhdl
    global speed_grade_dir

    if {![info exists srclist_vhdl]} {
        set srclist_vhdl {}
    }

    set vhdl_dir ${speed_grade_dir}/vhdl
    foreach src {
    } {
        lappend srclist_vhdl $vhdl_dir/$src
    }
}

set speed_grade_dir ${repo_root_dir}/${proj_folder}/${foreign_folder}/${platform}/${target_part}/${speed_grade}

gowin_systemverilog
gowin_verilog
gowin_vhdl
