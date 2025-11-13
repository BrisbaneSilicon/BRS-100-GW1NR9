#!/bin/bash

source program_board_shared.sh
source program_board_globals.sh

exec_from_build_directory "START"
    source build_utils.sh

    exec_end


# supported boards lists
supported_boards_header=""

supported_boards_board_id=()
supported_boards_build_target=()
supported_boards_platform=()
supported_boards_bitstream_ext=()
supported_boards_default_target=()


print_program_board_usage () {
    echo "Usage: ./program_board [OPTIONS...] TARGET_BOARD"
    echo "Try './program_board.sh --help' for more information."
}

print_program_board_help () {
    echo -e "${underlinef}PROGRAM_BOARD${normf}\n"
    echo -e "${boldf}NAME${normf}"
    echo -e "\tprogram_board - program a BRS-100-GW1NR9 board its FPGA firmware\n"
    echo -e "${boldf}SYNOPSIS${normf}"
    echo -e "\t${boldf}program_board${normf} ${underlinef}[OPTIONS...]${normf} <TARGET_BOARD>\n"
    echo -e "${boldf}DESCRIPTION${normf}"
    echo -e "\tProgram TARGET_BOARD with its variant of the BRS-100-GW1NR9 FPGA firmware."
    echo -e "\tAlternatively, query supported target boards and options.\n"
    echo -e "${boldf}OPTIONS${normf}"
    echo -e "\t${boldf}-h, --help${normf}\n\t\tDisplay this help and exit.\n"
    echo -e "\t${boldf}-d, --list_default_target${normf}\n\t\tList the default build target.\n"
    echo -e "\t${boldf}-c, --clean_target_prior${normf}\n\t\tClean TARGET_BOARD build prior to building and programming the BRS-100-GW1NR9 board.\n"
    echo -e "\t${boldf}-f, --update_flash_only${normf} MCS_FILE_FULLPATH\n\t\tUpdate TARGET_BOARD flash with provided MCS_FILE_FULL_PATH.\n"
    echo -e "\t${boldf}-m, --custom_bitfile${normf} CUSTOM_BITFILE_FULLPATH\n\t\tProgram TARGET_BOARD with custom bitfile CUSTOM_BITFILE_FULLPATH.\n"
    echo -e "\t${boldf}-l, --list_supported_targets${normf}\n\t\tList supported build targets and exit.\n"
    echo -e "\t${boldf}-s, --check_if_target_supported${normf}\n\t\tPrint supported status of provided target board and exit.\n"
    echo -e "\t${boldf}-b, --check_if_target_built${normf}\n\t\tPrint firmware built status of provided target board and exit.\n"
    echo -e "\t${boldf}-t, --custom_target_device${normf} CUSTOM_TARGET\n\t\tInstead of the default target, target 'CUSTOM_TARGET'.\n"
    echo -e "${boldf}AUTHOR${normf}"
    echo -e "\tWritten by Craig Haywood\n"
    echo -e "${boldf}COPYRIGHT${normf}"
    echo -e $copyright
}

target_firmware_bitstream_fullpath() {
    if [ $# -lt 4 ]; then
        echo "Error, function 'target_firmware_bitstream_fullpath' requires minimum four arguments: target_board build_target \
device speed_grade [custom bootrom]"

        return 1
    fi

    if [ $# -gt 4 ]; then
        custom_bootrom=$5
    else
        custom_bootrom=false
    fi

    platform=$(target_platform_for_target_board $1)
    if [ $? -ne 0 ]; then
        echo "Error, failed to find platform of target_board: $1"

        return 2
    fi

    bitstream_ext=$(bitstream_ext_for_target_board_and_build_target $1 $2)
    if [ $? -ne 0 ]; then
        echo "Error, failed to find bitstream extension for target_board, build_target: $1, $2"

        return 3
    fi

    bitstream_dir="${build_dir}/${platforms_folder}/${platform}/${devices_folder}/${3}/${4}/${output_folder}/${artifacts_folder}"

    if [ $3 == "GW1NR-9" ] || [ $3 == "GW2AR-18" ]; then
        echo "${bitstream_dir}/${project_name}.${bitstream_ext}"
    else
        if [ $custom_bootrom = true ]; then
            echo "${bitstream_dir}/${project_name}_${bitstream_stack_prefix}*${bitstream_stack_suffix}_custom_bootrom.${bitstream_ext}"
        else
            echo "${bitstream_dir}/${project_name}_${bitstream_stack_prefix}*${bitstream_stack_suffix}.${bitstream_ext}"
        fi
    fi

    return 0
}

target_firmware_artefacts_directory() {
    if [ $# -lt 4 ]; then
        echo "Error, function 'target_firmware_bitstream_fullpath' requires minimum four arguments: target_board build_target \
device speed_grade [custom bootrom]"

        return 1
    fi

    if [ $# -gt 4 ]; then
        custom_bootrom=$5
    else
        custom_bootrom=false
    fi

    platform=$(target_platform_for_target_board $1)
    if [ $? -ne 0 ]; then
        echo "Error, failed to find platform of target_board: $1"

        return 2
    fi

    bitstream_ext=$(bitstream_ext_for_target_board_and_build_target $1 $2)
    if [ $? -ne 0 ]; then
        echo "Error, failed to find bitstream extension for target_board, build_target: $1, $2"

        return 3
    fi

    echo "${build_dir}/${platforms_folder}/${platform}/${devices_folder}/${3}/${4}/${output_folder}/${artifacts_folder}"

    return 0
}

target_firmware_built() {
    if [ $# -lt 4 ]; then
        echo "Error, function 'target_firmware_built' requires four arguments: target_board build_target device speed_grade"

        return 1
    fi

    firmware_bitstream_fullpath=$(target_firmware_bitstream_fullpath "$1" "$2" "$3" "$4")
    if [ $? -ne 0  ]; then
        return 2
    fi

    if [ -e $firmware_bitstream_fullpath ]; then
        echo true
        return 0
    fi

    echo false
    return 0
}

load_supported_boards_information() {
    f=true
    while read line
    do
        if [ $f = true ]; then
            supported_boards_header=$line
        else
            IFS=',' read -r -a arr <<< "$line"

            supported_boards_board_id+=(${arr[0]})
            supported_boards_build_target+=(${arr[1]})
            supported_boards_platform+=(${arr[2]})
            supported_boards_bitstream_ext+=(${arr[3]})
            supported_boards_default_target+=(${arr[4]})
        fi
        f=false
    done < $supported_boards_csv_filename

    l=${#supported_boards_platform[@]}
    if [ $l -gt 0 ]; then
        return 0
    fi

    # NOTE: failed to load a single
    # supported board...
    return 1
}

list_supported_targets() {
    supported_target_boards=()
    for (( i=0; i<${#supported_boards_board_id[@]}; i++ )); do
        already_included=0
        for (( j=0; j<${#supported_target_boards[@]}; j++ )); do
            if [ "${supported_boards_board_id[$i]}" == "${supported_target_boards[$j]}" ]; then
                already_included=1
                break
            fi
        done
        if [ $already_included -eq 0 ]; then
            supported_target_boards+=(${supported_boards_board_id[$i]})
        fi
    done

    for (( i=0; i<${#supported_target_boards[@]}; i++ )); do
        if [ $i -gt 0 ]; then
            echo -n ", "
        fi
        echo -n "${supported_target_boards[$i]}"
    done
    echo ""

    return 0
}

build_targets_for_target_board() {
    if [ $# -lt 1 ]; then
        echo "Error, function 'target_device_for_target_board' requires one argument: target_board"

        return 1
    fi

    supported_target_devices=()
    for (( i=0; i<${#supported_boards_board_id[@]}; i++ )); do
        if [ "${supported_boards_board_id[$i]}" == "$1" ]; then
            supported_target_devices+=(${supported_boards_build_target[$i]})
        fi
    done

    if [ ${#supported_target_devices[@]} -eq 1 ]; then
        echo -n "${supported_target_devices[0]}"

        return 0
    fi
    if [ ${#supported_target_devices[@]} -gt 1 ]; then
        for (( i=0; i<${#supported_target_devices[@]}; i++ )); do
            if [ $i -gt 0 ]; then
                echo -n ", "
            fi
            echo -n "${supported_target_devices[$i]}"
        done
        echo ""

        return 2
    fi

    return 1
}

target_platform_for_target_board() {
    if [ $# -lt 1 ]; then
        echo "Error, function 'target_platform_for_target_board' requires one argument: target_board"

        return 1
    fi

    for (( i=0; i<${#supported_boards_board_id[@]}; i++ )); do
        if [ "${supported_boards_board_id[$i]}" == "$1" ]; then
            echo "${supported_boards_platform[$i]}"

            return 0
        fi
    done

    return 2
}

bitstream_ext_for_target_board_and_build_target() {
    if [ $# -lt 2 ]; then
        echo "Error, function 'bitstream_ext_for_target_board_and_device' requires two arguments: target_board build_target"

        return 1
    fi

    for (( i=0; i<${#supported_boards_board_id[@]}; i++ )); do
        if [ "${supported_boards_board_id[$i]}" == "$1" ]; then
            if [ "${supported_boards_build_target[$i]}" == "$2" ]; then
                echo "${supported_boards_bitstream_ext[$i]}"

                return 0
            fi
        fi
    done

    return 2
}

program_target_with_firmware() {
    if [ $# -lt 4 ]; then
        echo "Error, function 'program_target_with_firmware' requires minimum of four arguments: target_board build_target \
device speed_grade [custom_bootrom]"

        return 1
    fi

    if [ $# -gt 4 ]; then
        custom_bootrom=$5
    else
        custom_bootrom=false
    fi

    bitstream_fullpath=$(target_firmware_bitstream_fullpath "$1" "$2" "$3" "$4" $custom_bootrom)
    if [ $? -ne 0  ]; then
        return 2
    fi
    if [ -e $bitstream_fullpath ]; then
        platform=$(target_platform_for_target_board $1)
        if [ $? -ne 0  ]; then
            return 3
        fi

        if [ "$platform" == "gowin" ]; then
            speed_grade_category=${speed_grade:0:1}

            echo "Program command line: '$gowin_programmer_cli_bin --device $3$speed_grade_category --operation_index 5 -f $bitstream_fullpath'"
            $gowin_programmer_cli_bin --device $3$speed_grade_category --operation_index 5 -f $bitstream_fullpath

            return $?
        fi

        if [ "$platform" == "xilinx" ]; then
            if [ "$target_board" == "ARTYS7-25" ] || [ "$target_board" == "ARTYS7-50" ]; then
                do_generic_xilinx_prog=true
            fi

            if [ -v do_generic_xilinx_prog ]; then
                if [ $do_generic_xilinx_prog ]; then
                    cd $program_dir/$foreign_folder/$platform/$scripts_folder/$generic_folder/
                    source $program_board_script $3 $bitstream_fullpath

                    return $?
                fi
            fi
        fi
    fi

    return 44
}

# REVISIT: merge with above function...
program_target_with_custom_firmware() {
    if [ $# -lt 5 ]; then
        echo "Error, function 'program_target_with_custom_firmware' requires minimum of five arguments: target_board build_target \
device speed_grade custom_bitfile_fullpath"

        return 1
    fi

    platform=$(target_platform_for_target_board $1)
    if [ $? -ne 0  ]; then
        return 2
    fi
        if [ "$platform" == "gowin" ]; then
            speed_grade_category=${speed_grade:0:1}

            echo "Program command line: '$gowin_programmer_cli_bin --device $3$speed_grade_category --operation_index 5 -f $custom_bitfile_fullpath'"
            $gowin_programmer_cli_bin --device $3$speed_grade_category --operation_index 5 -f $custom_bitfile_fullpath

            return $?
        fi

    if [ "$platform" == "xilinx" ]; then
        if [ "$target_board" == "ARTYS7-25" ] || [ "$target_board" == "ARTYS7-50" ]; then
            do_generic_xilinx_prog=true
        fi

        if [ -v do_generic_xilinx_prog ]; then
            if [ $do_generic_xilinx_prog ]; then
                cd $program_dir/$foreign_folder/$platform/$scripts_folder/$generic_folder/
                source $program_board_script $3 $custom_bitfile_fullpath

                return $?
            fi
        fi
    fi

    return 4
}

update_flash_for_target_board() {
    if [ $# -lt 3 ]; then
        echo "Error, function 'update_flash_for_target_board' requires two arguments: target_board device mcs_file_fullpath"

        return 1
    fi

    target_board=$1
    device=$2
    mcs_file_fullpath=$3

    if [ "$target_board" != "ARTYS7-25" ] && [ "$target_board" != "ARTYS7-50" ]; then
        echo "Error, function 'update_flash_for_target_board' does not support target_board=${target_board}"

        return 2;
    fi

    flash_device="s25fl128sxxxxxx0-spi-x1_x2_x4"
        # TODO: put in CSV file 'supported_boards.csv' ?

    cd $program_dir/$foreign_folder/$platform/$scripts_folder/$generic_folder
    source $program_flash_script $device $mcs_file_fullpath $flash_device

    return 0
}

generate_dual_sw_fw_flash_file() {
    if [ $# -lt 3 ]; then
        echo "Error, function 'generate_dual_sw_fw_flash_file' requires three arguments: eelf_file_fullpath bitfile_fullpath artefacts_directory"

        return 1
    fi

    flash_device="s25fl128sxxxxxx0-spi-x1_x2_x4"
        # TODO: put in CSV file 'supported_boards.csv' ?

    cd $program_dir/$foreign_folder/$platform/$scripts_folder/$generic_folder
    source $gen_standalone_flash_script $1 $2 $flash_device $3

    return 0
}


############################################### Sourcing script functionality ###############################################

load_supported_boards_information
if [ $? -ne 0 ]; then
    return 2
fi

return 0