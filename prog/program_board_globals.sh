#!/bin/bash

source program_board_shared.sh

exec_from_build_directory "START"
    source build_utils.sh

    exec_end

# constants

clean_target_build_option="--clean"
default_target_build_option="--default_target"

project_root_dir=$(git rev-parse --show-toplevel)
project_name="BRS-100-GW1NR9"
program_folder="prog"
foreign_folder="foreign"
scripts_folder="scripts"
generic_folder="generic"
bin_folder="bin"
board_folder="board"

program_dir=${project_root_dir}/${program_folder}
build_dir=${project_root_dir}/${build_folder}
board_dir=${project_root_dir}/${program_folder}/${board_folder}

program_board_script="program_board.sh"
program_flash_script="program_flash.sh"
gen_standalone_flash_script="gen_standalone_flash.sh"

supported_boards_csv_filename="supported_boards.csv"

open_fpga_loader_bin="openFPGALoader"
gowin_programmer_cli_bin="programmer_cli"

bitstream_ext="fs"

elf_ext="elf"
pmu_elf="pmufw.$elf_ext"
fsbl_elf="fsbl.$elf_ext"
supervisor_elf="supervisor.$elf_ext"

# echo delmiters
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