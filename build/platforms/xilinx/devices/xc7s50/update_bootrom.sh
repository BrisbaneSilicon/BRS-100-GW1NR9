#!/bin/bash


print_build_usage () {
    echo "Usage: ./update_bootrom PROJECT_NAME REPO_ROOT_DIR BUILD_DIR BOOTMEM_STACK_SIZE_KB"
}

if [ $# -lt 4 ]; then
    print_update_bootrom_usage

    exit
fi

project_name=$1
repo_root_dir=$2
build_dir=$3
stack_size_kb=$4

target_part="xc7s50"
bootmem_mmi_name="bootmem_rom.mmi"
bootmem_rom_name="bootmem_stack${stack_size_kb}kb"
little_endian_suffix="_le"
proj_folder="proj"
mem_folder="mem"
mem_files_dir="${repo_root_dir}/${project_folder}/${proj_folder}/${foreign_folder}/${platform}/${target_part}/${mem_folder}"
mem_info_file="${mem_files_dir}/${bootmem_mmi_name}"
mem_def_file_little_endian="${mem_files_dir}/${bootmem_rom_name}${little_endian_suffix}.mem"
bitstream_file="${build_dir}/${artifacts_folder}/${project_name}_stack${stack_size_kb}kb.bit"
bitstream_custom_bootrom_file="${build_dir}/${artifacts_folder}/${project_name}_stack${stack_size_kb}kb_custom_bootrom.bit"

updatemem -debug -force --meminfo $mem_info_file --data $mem_def_file_little_endian --bit $bitstream_file --proc dummy --out $bitstream_custom_bootrom_file