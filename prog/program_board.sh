#!/bin/bash

# Script to program target board with BRS-100-GW1NR9 FPGA bitstream.
# See 'print_program_board_help'.

source program_board_globals.sh
source program_board_utils.sh

target_board=BRS-100-GW1NR9
program_flash=false
use_open_fpga_loader=false

while [ $# -gt 0 ]; do
    case $1 in
        -h|--help)
            print_program_board_help
            exit
            ;;
        -c|--clean_target_prior)
            clean_target_prior=true
            ;;
        -d|--list_default_target)
            echo "$target_board"
            exit
            ;;
        -l|--list_supported_targets)
            list_supported_targets
            exit
            ;;
        -s|--check_if_target_supported)
            check_if_target_supported=true
            ;;
        -b|--check_if_target_built)
            check_if_target_built=true
            ;;
        -m|--custom_bitfile)
            if [ $# -lt 2 ]; then
                echo "Option '$1' requires argument: BIT_FILE_FULLPATH"
                echo -e "Try './program_board.sh --help' for more information."

                exit
            fi

            custom_bitfile=true
            custom_bitfile_fullpath=$2
            shift 1
            ;;
        -f|--program_flash)
            program_flash=true
            ;;
        -t|--custom_target)
            if [ $# -lt 2 ]; then
                echo "Option '$1' requires argument: TARGET"
                echo -e "Try './program_board.sh --help' for more information."

                exit
            fi

            target_board=$2
            shift 1
            ;;
        -o|--open_fpga_loader)
            use_open_fpga_loader=true
            ;;

        -*)
            echo -e "Invalid option: '$1'."
            echo -e "Try './program_board.sh --help' for more information."

            exit
            ;;
        *)
            if [ ! -v target_board ]; then
                target_board=$1
            else
                echo -e "Invalid option -- '$1'."
                echo -e "Try './program_board.sh --help' for more information."

                exit
            fi
            ;;
    esac

    shift 1
done


# TODO: reject all impossible combinations
# of command line arguments...


if [ ! -v target_board ]; then
    print_program_board_usage

    exit
fi

target_board_targets=$(build_targets_for_target_board "$target_board")
td_retcode=$?
if [ $td_retcode -eq 1 ]; then
    echo "Target board '$target_board' is not supported"
    echo -e "Try './program_board.sh --help' for more information."

    exit
fi

if [ ! -v target ]; then
    if [ $td_retcode -eq 2 ]; then
        echo "Target board '$target_board' supports multiple targets: "$target_board_targets
        echo -e "Try './program_board.sh --help' for more information."

        exit
    fi

    target=$target_board_targets
else
    IFS=', ' read -r -a targets_array <<< "$target_board_targets"
    for (( i=0; i<${#targets_array[@]}; i++ )); do
        if [ "${targets_array[$i]}" == "$target" ]; then
            break
        fi
    done
    if [ $i -eq ${#targets_array[@]} ]; then
        echo "Target '$target' is not supported by board '$target_board'"
        echo -e "Try './program_board.sh --help' for more information."

        exit
    fi
fi



platform=$(target_platform_for_target_board $target_board)
if [ $? -ne 0 ]; then
    echo "Target board '$target_board' is not supported"
    echo -e "Try './program_board.sh --help' for more information."

    exit
fi
exec_from_build_directory "START"
    device=$(device_for_platform_and_target "$platform" "$target_board")
    speed_grade=$(speed_grade_for_platform_and_target "$platform" "$target_board")

    exec_end

if [ -v clean_target_prior ]; then
    exec_from_build_directory "START"
        clean_platform_device "$platform" "$device" "$speed_grade"

        exec_end
fi

target_built=$(target_firmware_built $target_board $target $device $speed_grade)
if [ $? -ne 0 ]; then
    echo ${target_built}

    exit
fi

if [ -v check_if_target_built ]; then
    echo "Target '${target_board}' firmware built status: ${target_built}"

    exit
fi

if [ -v custom_bitfile ]; then
    if [ ! -v gen_dual_sw_fw_flash_file ]; then
        program_target_with_custom_firmware "$target_board" "$target" "$device" "$speed_grade" "$program_flash" "$custom_bitfile_fullpath" "$use_open_fpga_loader"

        err=$?
        if [ $err -ne 0 ]; then
            if [ $err -eq 50 ]; then
                echo "Check 'ftdi_sio' is unloaded."
            else
                echo "Failed to program target board with custom bitfile, error code="$err
            fi
        fi

        exit
    fi

    if [ -v gen_dual_sw_fw_flash_file ]; then
        firmware_artefacts_directory=$(target_firmware_artefacts_directory $target_board $target $device $speed_grade)

        generate_dual_sw_fw_flash_file "$eelf_file_fullpath" "$custom_bitfile_fullpath" "$firmware_artefacts_directory"

        exit
    fi
else
    if [ -v update_bootrom ]; then
        if [ $target_built = false ]; then
            echo "Option '$u_opt' requires target '$target' (TARGET_BOARD = '$target_board') to be built"
            echo -e "Try './program_board.sh --help' for more information."

            exit
        fi

        exec_from_build_directory "START"
            echo -e "Updating bootROM, command line: ./${build_script} -u ${stack_size_kb} ${target} -f ${platform}"
            ./$build_script -u "$stack_size_kb" "$target" -f "$platform"

            exec_end

        program_target_with_firmware "$target_board" "$target" "$device" "$speed_grade" true
        err=$?
        if [ $err -ne 0 ]; then
            if [ $err -eq 50 ]; then
                echo "Check 'ftdi_sio' is unloaded."
            else
                echo "Failed to program target board after bootrom update, error code="$err
            fi

            exit
        fi

        exit
    fi
fi


if [ $target_built = true ]; then
    echo "Detected target board firmware already built...reusing."
else
    if [ ! -v clean_target_prior ]; then
        echo "Detected target board firmware not build, triggering a build..."
    fi

    exec_from_build_directory "START"
        if [ ! -v custom_target ]; then
            echo -e "Attempting build, command line: ./${build_script}"
            ./$build_script
        else
            echo -e "Attempting build, command line: ./${build_script} -t ${custom_target}"
            ./$build_script -t $custom_target
        fi

        exec_end
fi

if [ -v gen_dual_sw_fw_flash_file ]; then
    firmware_bitstream_fullpath=$(target_firmware_bitstream_fullpath $target_board $target $device $speed_grade)
    firmware_artefacts_directory=$(target_firmware_artefacts_directory $target_board $target $device $speed_grade)

    generate_dual_sw_fw_flash_file "$eelf_file_fullpath" "$firmware_bitstream_fullpath" "$firmware_artefacts_directory"

    exit
fi

program_target_with_firmware "$target_board" "$target" "$device" "$speed_grade" "$program_flash" "$use_open_fpga_loader"
err=$?
if [ $err -ne 0 ]; then
    if [ $err -eq 50 ]; then
        echo "Check 'ftdi_sio' is unloaded."
    else
        echo "Failed to program target board, error code="$err
    fi

    exit
fi
