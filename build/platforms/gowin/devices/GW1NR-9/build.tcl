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
