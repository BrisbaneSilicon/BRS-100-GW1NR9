if {$argc < 6} {
    error "Expecting -tclargs project_name repo_root_dir build_dir target_part_number target_part_version speed_grade"
}

set platform                        "gowin"
set target_part                     "GW1NR-9"

set root_folder                     "BRS-100-GW1NR9"
set proj_folder                     "proj"
set common_folder                   "common"
set foreign_folder                  "foreign"
set scripts_folder                  "scripts"
set constraints_folder              "constraints"
set artifacts_folder                ".artifacts"
    # TODO: move some of these to common build script ?

set lib_folder                      "lib"
set device_security_wrapper_name    "device_security_wrapper"
set ela_variant                     "fcapz"

set project_name                    [lindex $argv 0]
set repo_root_dir                   [lindex $argv 1]
set build_dir                       [lindex $argv 2]
set target_part_number              [lindex $argv 3]
set target_part_version             [lindex $argv 4]
set speed_grade                     [lindex $argv 5]
set system_clock_frequency_mhz      [lindex $argv 6]
set embedded_logic_analyzer         [lindex $argv 7]
set proj_only                       [lindex $argv 8]
set synth_only                      [lindex $argv 9]

puts "Creating Gowin FPGA project '${project_name}' specs -"
puts "\tTarget part number: ${target_part_number}"
puts "\tTarget part version: ${target_part_version}"
create_project -name $project_name -dir $build_dir -pn $target_part_number -device_version $target_part_version -force

set_option -verilog_std sysv2017
set_option -vhdl_std vhd2008
set_option -use_sspi_as_gpio 1
set_option -use_mspi_as_gpio 1
set_option -place_option 2
set_option -replicate_resources 1
set_option -clock_route_order 1
set_option -route_option 1
set_option -use_done_as_gpio 1

source ${repo_root_dir}/${proj_folder}/${common_folder}/${scripts_folder}/synth.tcl
source ${repo_root_dir}/${proj_folder}/${foreign_folder}/${platform}/${target_part}/${speed_grade}/${scripts_folder}/synth.tcl
foreach src $srclist_sv {
    add_file -type verilog $src
}
foreach src $srclist_v {
    add_file -type verilog $src
}
foreach src $srclist_vhdl {
    add_file -type vhdl $src
}

if {$embedded_logic_analyzer == "true"} {
    # NOTE: pull in required ELA files...

    set fcapzero_folder     "fpgacapZero"
    set rtl_folder          "rtl"

    set fcapzero_rtl_path   "$repo_root_dir/$proj_folder/$foreign_folder/$fcapzero_folder/$rtl_folder"

    if {![file isdirectory $fcapzero_rtl_path]} {
        puts "Error: dependency 'fpgacapZero' not found! Run 'git submodule update --init' to fetch it."
        exit 1
    }

    set fpgacapzero_verilog_files [list \
        $fcapzero_rtl_path/fcapz_version.vh \
        $fcapzero_rtl_path/reset_sync.v \
        $fcapzero_rtl_path/dpram.v \
        $fcapzero_rtl_path/trig_compare.v \
        $fcapzero_rtl_path/fcapz_regbus_mux.v \
        $fcapzero_rtl_path/fcapz_ela.v \
        $fcapzero_rtl_path/fcapz_ela_gowin.v \
        $fcapzero_rtl_path/jtag_reg_iface_gowin.v \
        $fcapzero_rtl_path/jtag_pipe_iface.v \
        $fcapzero_rtl_path/jtag_burst_read.v \
        $fcapzero_rtl_path/jtag_tap/jtag_tap_gowin.v \
        $fcapzero_rtl_path/fcapz_async_fifo.v \
        $fcapzero_rtl_path/fcapz_ejtagaxi.v \
        $fcapzero_rtl_path/fcapz_eio.v \
        $fcapzero_rtl_path/fcapz_eio_gowin.v \
        $fcapzero_rtl_path/dff_sync.v \
        $fcapzero_rtl_path/dff_reg_sync.v \
        $fcapzero_rtl_path/gowin/gw_jtag.v
    ]

    foreach src $fpgacapzero_verilog_files {
        add_file -type verilog $src
    }
}

add_file "../../${constraints_folder}/location.cst"
add_file "../../${constraints_folder}/timing_${system_clock_frequency_mhz}mhz.sdc"

add_file -type verilog ../${artifacts_folder}/autogen_top_wrapper.sv
set_option -top_module autogen_top_wrapper

puts "Project generation complete"
if {$proj_only == "true"} {
    exit
}

puts "Launching Synthesis"
run syn

puts "Synthesis complete"
if {$synth_only == "true"} {
    exit
}

puts "Launching Place-and-Route"
run pnr

puts "Deploying bitstream"
file copy -force impl/pnr/${project_name}.fs ../${artifacts_folder}/${project_name}.fs
