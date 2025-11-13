#!/bin/bash

# Constants

project_root_dir=$(git rev-parse --show-toplevel)
project_name="BRS-100-GW1NR9"
build_folder="build"
platforms_folder="platforms"
foreign_folder="foreign"
devices_folder="devices"
output_folder="output"
artifacts_folder=".artifacts"

build_dir="${project_root_dir}/${build_folder}"

# Build related constants

build_script="build.sh"
build_project_name="BRS-100-GW1NR9"
    # REVISIT: should be platform dependent

# Platform related constants

platform_utils_script_suffix="_utils.sh"
platform_check_build_requirements_script_suffix=_build_requirements.sh
platform_supported_devices_csv_file_suffix="_supported_devices_information.csv"
platform_supported_system_clock_frequencies_csv_file_suffix="_supported_system_clock_frequencies.csv"

# Device related constants

device_build_tcl_script="build.tcl"
device_update_bootrom_script="update_bootrom.sh"
device_generate_top_wrapper_script=generate_top_wrapper.sh
device_top_wrapper_filename="autogen_top_wrapper.sv"

# Echo delmiters
boldf=$(tput bold)
underlinef=$(tput smul)
normf=$(tput sgr0)

# Standard copyright
copyright="\tThe source code contained herein is provided on an \"as is\" basis. Brisbane Silicon, Pty Ltd. disclaims\n
\tany and all warranties, whether express, implied, or statutory, including any implied warranties of\n
\tmerchantability or of fitness for a particular purpose. In no event shall brisbane silicon, pty ltd.\n
\tbe liable for any incidental, punitive, or consequential damages of any kind whatsoever arising from\n
\tthe use of this source code.\n\n
\tThis disclaimer of warranty extends to the user of this source code and user's customers, employees,\n
\tagents, transferees, successors and assigns.\n\n
\tThis is not a grant of patent rights.\n"