if {$argc < 5} {
    error "Expecting -tclargs project_name repo_root_dir build_dir target_part_number target_board"
}

set platform                        "xilinx"
set target_part                     "xc7s25"
set top_module_name                 "autogen_top_wrapper"
set device_security_wrapper_name    "device_security_wrapper"

set root_folder                     "BRS-100-GW1NR9"
set proj_folder                     "proj"
set common_folder                   "common"
set foreign_folder                  "foreign"
set scripts_folder                  "scripts"
set constraints_folder              "constraints"
set block_diagrams_folder           "block_diagrams"
set mem_folder                      "mem"
set lib_folder                      "lib"
set artifacts_folder                ".artifacts"
    # TODO: move some of these to common build script ?

set project_name                [lindex $argv 0]
set repo_root_dir               [lindex $argv 1]
set build_dir                   [lindex $argv 2]
set target_part_number          [lindex $argv 3]
set target_board                [lindex $argv 4]
set stack_size_bytes            [lindex $argv 5]
set proj_only                   [lindex $argv 6]
set synth_only                  [lindex $argv 7]

set stack_size_kb               [expr $stack_size_bytes/1024]

set mem_contents_fileset_name   mem_1
set constraints_fileset_name    constrs_1
set synth_name                  synth_1
set impl_name                   impl_1

set impl_dir                    "$build_dir/${project_name}.runs/${impl_name}"
set block_diagram_dir           "${repo_root_dir}/${root_folder}/${proj_folder}/${foreign_folder}/${platform}/${target_part}/${block_diagrams_folder}"
set mem_files_dir               "${repo_root_dir}/${root_folder}/${proj_folder}/${foreign_folder}/${platform}/${target_part}/${mem_folder}"
set constraints_dir             "${build_dir}/../${constraints_folder}"

puts "Creating Xilinx FGA project '${project_name}' specs -"
puts "\tTarget part number: ${target_part_number}"
if {$target_board != ""} {
    puts "\tTarget board: ${target_board}"
}

create_project $project_name $build_dir -part $target_part_number

set proj_dir [get_property directory [current_project]]
set proj [current_project]
set_property -name "board_part_repo_paths" -value "[file normalize "$::env(HOME)/.Xilinx/Vivado/2023.2/xhub/board_store/xilinx_board_store"] [file normalize "$::env(HOME)/.Xilinx/Vivado/2023.2/xhub/board_store/xilinx_board_store/XilinxBoardStore"]" -objects $proj
set_property -name "board_part" -value "${target_board}" -objects $proj
set_property -name "default_lib" -value "xil_defaultlib" -objects $proj
set_property -name "enable_vhdl_2008" -value "1" -objects $proj
set_property -name "ip_cache_permissions" -value "read write" -objects $proj
set_property -name "ip_output_repo" -value "$proj_dir/${project_name}.cache/ip" -objects $proj
set_property -name "mem.enable_memory_map_generation" -value "1" -objects $proj
set_property -name "platform.board_id" -value "arty-s7-25" -objects $proj
set_property -name "revised_directory_structure" -value "1" -objects $proj
set_property -name "sim.central_dir" -value "$proj_dir/${project_name}.ip_user_files" -objects $proj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $proj
set_property -name "simulator_language" -value "Mixed" -objects $proj
set_property -name "target_language" -value "Verilog" -objects $proj

puts "Source HDL"
source ${repo_root_dir}/${root_folder}/${proj_folder}/${common_folder}/${scripts_folder}/synth.tcl
source ${repo_root_dir}/${root_folder}/${proj_folder}/${foreign_folder}/${platform}/${target_part}/${scripts_folder}/synth.tcl
source ${repo_root_dir}/${root_folder}/${proj_folder}/${foreign_folder}/${platform}/${lib_folder}/${scripts_folder}/synth.tcl
read_verilog -sv $srclist_sv
read_verilog $srclist_v
read_vhdl -vhdl2008 $srclist_vhdl

puts "Source Sim HDL"
source ${repo_root_dir}/${root_folder}/${proj_folder}/${common_folder}/${scripts_folder}/sim.tcl
source ${repo_root_dir}/${root_folder}/${proj_folder}/${foreign_folder}/${platform}/${target_part}/${scripts_folder}/sim.tcl
read_verilog -sv $simlist_sv
read_vhdl -vhdl2008 $simlist_vhdl

puts "Source mem files"
set mem_files [list \
    "${mem_files_dir}/bootmem_stack${stack_size_kb}kb.mem" \
]
add_files -norecurse ${mem_files}

puts "Source constraints"
set constraint_files [list \
    "${constraints_dir}/location.xdc" \
    "${constraints_dir}/timing.xdc" \
    "${constraints_dir}/post_synth.xdc" \
]
add_files -fileset $constraints_fileset_name -norecurse ${constraint_files}

puts "Source block diagrams"
set block_diagrams [list \
    "clock_200mhz" \
    "clock_180mhz" \
    "clock_170mhz" \
    "ahb_to_axilite" \
]
foreach bd $block_diagrams {
    source "${block_diagram_dir}/$bd.tcl"
}

puts "Generate block diagram wrappers"
set block_designs [get_files -filter {!IS_GENERATED} *.bd]
foreach bd $block_designs {
    open_bd_design $bd
    reset_target all [get_files  $bd]
    make_wrapper -files [get_files $bd] -top -import
}

puts "Source and set top-module wrapper"
read_verilog -sv "${build_dir}/${artifacts_folder}/${top_module_name}.sv"
set_property top "${top_module_name}" [current_fileset]
update_compile_order -fileset [current_fileset]

puts "Source device security wrapper"
read_verilog -sv "${build_dir}/${artifacts_folder}/${device_security_wrapper_name}.sv"
update_compile_order -fileset [current_fileset]

puts "Project generation complete"
if {$proj_only == "true"} {
    exit
}


puts "Configure synthesis"
set_property steps.synth_design.args.assert 1 [get_runs $synth_name]

puts "Launching synthesis"
launch_runs $synth_name -jobs 4
wait_on_run -timeout 600 $synth_name

if {$synth_only == "true"} {
    exit
}

puts "Configure PAR"
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs $impl_name]

puts "Launching PAR"
launch_runs $impl_name -jobs 4
wait_on_run -timeout 600 $impl_name

open_run $impl_name
set timing_pass [expr {[get_property SLACK [get_timing_paths]] >= 0}]
if {$timing_pass == 0} {
    # NOTE: occassionally there is an edge-case in
    # which a timing closure violation is acceptable,
    # if that is the case, it can be handled here
    # explicitly.

    puts "Implementation failed to achieve timing closure - please review project and rebuild."
    exit
}
close_design

puts "Launching write bitstream"
launch_runs $impl_name -to_step write_bitstream
wait_on_run -timeout 10 $impl_name

puts "Generating XSA"
write_hw_platform -fixed -include_bit -force -file "${impl_dir}/${project_name}.xsa"

puts "Deploying XSA"
file copy -force "${impl_dir}/${project_name}.xsa" "${build_dir}/${artifacts_folder}"

puts "Deploying Bitstream"
file copy -force "${impl_dir}/${top_module_name}.bit" "${build_dir}/${artifacts_folder}/${project_name}_stack${stack_size_kb}kb.bit"