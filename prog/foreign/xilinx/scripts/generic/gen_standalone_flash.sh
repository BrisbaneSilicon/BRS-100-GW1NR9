#!/bin/bash

verbose_print=true

this_script_dir=$(pwd)

xil_dir=".Xil"
output_dir=$this_script_dir/output
log_dir=$output_dir/log

prog_flashscript=gen_standalone_flash.tcl

platform="xilinx"

project_root_dir=$(git rev-parse --show-toplevel)
build_folder="build"

build_dir="${project_root_dir}/${build_folder}"

print_usage () {
    echo -e "Usage: ./gen_standalone_flash EELF_FILE_FULLPATH BIT_FILE_FULLPATH FLASH_DEVICE OUTPUT_DIR"
}

setup () {
    if [ ! -e $log_dir ]; then
        mkdir -p $log_dir
    fi
}

cleanup () {
    if [ -e $output_dir ]; then
        rm -rf $output_dir
    fi
    if [ -e $xil_dir ]; then
        rm -rf $xil_dir
    fi
}

############################################### Sourcing script functionality ###############################################

if [ $# -lt 4 ]; then
    print_usage

    return 1
fi

cd $build_dir
source "${build_dir}/build_globals.sh" $verbose_print
source "${build_dir}/build_utils.sh" $verbose_print
cd $this_script_dir

check_prog_requirements_script_fullpath="${build_dir}/${platforms_folder}/${platform}/${platform}${platform_check_build_requirements_script_suffix}"
source $check_prog_requirements_script_fullpath $verbose_print
if [ $? -ne 0 ]; then
    echo "Unable to find '${platform}' installation directory, exit."

    return 2
fi

setup
vivado -mode batch -log $log_dir/build.log -journal $log_dir/journal.jou -source $prog_flashscript -tclargs $1 $2 $3 $4
cleanup

return 0