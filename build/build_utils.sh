#!/bin/bash

verbose_print="${1:-true}"

source build_globals.sh


print_build_usage () {
    echo "Usage: ./build TARGET [OPTIONS...]"
    echo "Try './build.sh --help' for more information."
}

print_build_help () {
    if [ ! -v platform ]; then
        init_platform_exit_on_failure
    else
        check_target_supported_for_platform_exit_on_failure
    fi

    echo -e "${underlinef}BUILD${normf}\n"
    echo -e "${boldf}NAME${normf}"
    echo -e "\tbuild - build the BRS-100-GW1NR9 FPGA firmware\n"
    echo -e "${boldf}SYNOPSIS${normf}"
    echo -e "\t${boldf}build${normf} [OPTIONS...]\n"
    echo -e "${boldf}DESCRIPTION${normf}"
    echo -e "\tBuild or query build options for the BRS-100-GW1NR9 FPGA firmware.\n"
    echo -e "${boldf}OPTIONS${normf}"
    echo -e "${boldf}    Generic Program Information${normf}"
    echo -e "\t${boldf}-h, --help${normf}\n\t\tDisplay this help and exit.\n"
    echo -e "${boldf}    Build Target Information${normf}"
    echo -e "\t${boldf}-d, --list_default_target${normf}\n\t\tList the default build target.\n"
    echo -e "\t${boldf}-l, --list_supported_targets${normf} [PLATFORM]\n\t\tList supported build targets of PLATFORM (or all platforms, if none specified) and exit.\n"
    echo -e "\t${boldf}-i, --list_supported_platforms${normf}\n\t\tList supported target platforms and exit.\n"
    echo -e "\t${boldf}-y, --list_supported_system_clock_frequencies${normf}\n\t\tList supported system clock frequencies and exit.\n"
    echo -e "${boldf}    Build Related${normf}"
    echo -e "\t${boldf}-u, --uart_baud${normf} ${underlinef}UART_BAUD${normf}\n\t\tSet user comms baud rate (default 115200).\n"
    echo -e "\t${boldf}-r, --disable_pushbutton_reset${normf}\n\t\tDisable pushbutton 1 as hard reset.\n"
    echo -e "\t${boldf}-b, --board_demonstration${normf}\n\t\tPerform build of board demonstration bitstream.\n"
    echo -e "\t${boldf}-o, --custom_test_string${normf} ${underlinef}TEST_STRING${normf}\n\t\tSet board demonstration SRAM/HRAM/Flash test payload (1-32 printable ASCII chars, no slash in custom strings). Requires -b.\n"
    echo -e "\t${boldf}-e, --embedded_logic_analyzer${normf}\n\t\tInclude an Embedded Logic Analyzer (fpgacapZero) in the bitstream.\n"
    echo -e "\t${boldf}-t, --custom_target_device${normf} ${underlinef}CUSTOM_TARGET${normf}\n\t\tPerform build targeting CUSTOM_TARGET.\n"
    echo -e "\t${boldf}-k, --clock_frequency${normf} ${underlinef}FREQUENCY_MHZ${normf}\n\t\tUse a frequency of FREQUENCY_MHZ for the system clock (default 51 MHz)."
    echo -e "\t\tSee '-y, --list_supported_system_clock_frequencies' above, for more information.\n"
    echo -e "\t${boldf}-f, --platform${normf} PLATFORM\n\t\tSpecify PLATFORM for build or clean.\n"
    echo -e "\t${boldf}-c, --clean${normf}\n\t\tPerform cleanup of TARGET for specified PLATFORM and exit.\n"
    echo -e "\t${boldf}-m, --clean_platform${normf}\n\t\tPerform cleanup of all target devices for specified PLATFORM and exit.\n"
    echo -e "\t${boldf}-a, --clean_all_platforms${normf}\n\t\tPerform cleanup of all target devices for all platforms and exit.\n"
    echo -e "\t${boldf}-p, --proj_only${normf}\n\t\tOnly generate the project file, then exit. Takes priority over ${boldf}-s${normf}/${boldf}--synth_only${normf} if both are provided.\n"
    echo -e "\t${boldf}-s, --synth_only${normf}\n\t\tOnly proceed with build until synthesis is complete, then exit.\n"
    echo -e "${boldf}AUTHOR${normf}"
    echo -e "\tWritten by Craig Haywood\n"
    echo -e "${boldf}COPYRIGHT${normf}"
    echo -e $copyright
}

print_build_utils_error() {
    if [ $# -lt 1 ]; then
        echo "Error, function 'print_utils_error' requires an argument: error_number"

        return 1
    fi

    case $1 in
        1)
            echo "Failed to load a single supported target from file: '${supported_devices_file}'."
            ;;
        *)
            echo "Unknown error code: "$1
            ;;
    esac

    return 0
}

chk_opt() {
    if [ $# -lt 2 ]; then
        echo "Command line option '"$1"' requires an argument"
        echo -e "Try './build.sh --help' for more information."

        exit 1
    fi
}

vprint() {
    [ $verbose_print = true ] && echo $1
}

vprint_no_newline() {
    [ $verbose_print = true ] && echo -n $1
}

vprint_failed() {
    vprint "failure."
}

vprint_done() {
    vprint "done."
}

source_no_args() {
    source $1
}

cleanup_target_directory() {
    if [ $# -lt 1 ]; then
        echo "Error, function 'cleanup_target_directory' requires one argument: target_directory"

        return 1
    fi

    rm -rf "$1/$output_folder"

    return 0
}

clean_platform_device() {
    local pdir
    local tdir
    local sdir

    if [ $# -lt 3 ]; then
        echo "Error, function 'clean_platform_device' requires three arguments: platform target_device speed_grade"

        return 1
    fi

    is_target_device_supported_for_platform "$1" "$2"
    if [ $? -ne 0 ]; then
        echo "Platform '$1' does not support target device '$2'"
        echo -e "Try './build.sh --help' for more information."

        exit
    fi

    pdir="$platforms_folder/$1"
    tdir="$pdir/$devices_folder/$2"
    sdir="$tdir/$speed_grade"

    cleanup_target_directory "$sdir"

    return 0
}

clean_platform() {
    local pdir
    local ddir
    local platform

    if [ $# -lt 1 ]; then
        echo "Error, function 'clean_platform' requires one argument: platform"

        return 1
    fi

    platform="$1"
    pdir="$platforms_folder/$platform"
    ddir="$pdir/$devices_folder"
    for potential_device_dir in $(ls $ddir); do
        for potential_speed_grade_dir in $(ls "$ddir/$potential_device_dir"); do
            if [ -d "$ddir/$potential_device_dir/$potential_speed_grade_dir" ]; then
                cleanup_target_directory "$ddir/$potential_device_dir/$potential_speed_grade_dir"
            fi
        done
    done

    platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
    platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
    platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"
        # REVISIT: refactor to function...

    source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath
    ${platform}_post_build_cleanup

    return 0
}

clean_all_platforms() {
    local platform
    local pdir
    local ddir

    for platform in $(ls $platforms_folder); do
        pdir="$platforms_folder/$platform"
        ddir="$pdir/$devices_folder"
        for potential_device_dir in $(ls $ddir); do
            for potential_speed_grade_dir in $(ls "$ddir/$potential_device_dir"); do
                if [ -d "$ddir/$potential_device_dir/$potential_speed_grade_dir" ]; then
                    cleanup_target_directory "$ddir/$potential_device_dir/$potential_speed_grade_dir"
                fi
            done
        done

        platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
        platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
        platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"
        source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath
        ${platform}_post_build_cleanup
    done

    return 0
}

list_supported_platforms() {
    ls $platforms_folder
}

is_supported_platform() {
    local platform

    for platform in $(ls $platforms_folder); do
        if [ "$1" == "$platform" ]; then
            return 0
        fi
    done

    return 1
}

list_supported_targets_for_platform() {
    local platform

    if [ $# -lt 1 ]; then
        echo "Error, function 'list_supported_targets_for_platform' requires one argument: platform"

        return 1
    fi

    for platform in $(ls $platforms_folder); do
        if [ "$1" == "$platform" ]; then
            platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
            platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
            platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

            source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath
            ${platform}_list_supported_target_build_ids

            return 0
        fi
    done

    return 2
}

list_supported_targets_for_all_platforms() {
    local platform

    for platform in $(ls $platforms_folder); do
        platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
        platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
        platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

        source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath

        echo -e "-----------------------------------------"
        echo -e "Platform  : ${platform}"
        echo -e "Target(s) : "$(${platform}_list_supported_target_build_ids)
    done
    echo -e "-----------------------------------------"

    return 0
}


list_supported_target_devices_for_platform() {
    local platform

    if [ $# -lt 1 ]; then
        echo "Error, function 'list_supported_target_devices_for_platform' requires one argument: platform"

        return 1
    fi

    for platform in $(ls $platforms_folder); do
        if [ "$1" == "$platform" ]; then
            platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
            platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
            platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

            source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath
            ${platform}_list_supported_target_device_ids

            return 0
        fi
    done

    return 2
}

does_platform_target_support_bootrom_update() {
    local platform

    if [ $# -lt 2 ]; then
        echo "Error, function 'does_platform_target_support_bootrom_update' requires two arguments: platform target_device"

        return 1
    fi

    is_supported_platform $1
    if [ $? -ne 0 ]; then
        return 2
    fi

    platform=$1
    platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
    platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
    platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

    source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath

    ${platform}_does_target_build_id_support_bootrom_update_only $2
    if [ $? -ne 0 ]; then
        return 3
    fi

    return 0
}

does_platform_target_support_security_mode() {
    local platform

    if [ $# -lt 2 ]; then
        echo "Error, function 'does_platform_target_support_security_mode' requires two arguments: platform target_device"

        return 1
    fi

    is_supported_platform $1
    if [ $? -ne 0 ]; then
        return 2
    fi

    platform=$1
    platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
    platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
    platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

    source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath

    ${platform}_does_target_build_id_support_security_mode $2
    if [ $? -ne 0 ]; then
        return 3
    fi

    return 0
}

is_target_build_id_supported_for_platform() {
    local platform

    if [ $# -lt 2 ]; then
        echo "Error, function 'is_target_build_id_supported_for_platform' requires two arguments: platform target_device"

        return 1
    fi

    is_supported_platform $1
    if [ $? -ne 0 ]; then
        return 2
    fi

    platform=$1
    platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
    platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
    platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

    source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath

    ${platform}_is_target_build_id_supported $2
    if [ $? -ne 0 ]; then
        return 3
    fi

    return 0
}

is_target_device_supported_for_platform() {
    local platform

    if [ $# -lt 2 ]; then
        echo "Error, function 'is_target_device_supported_for_platform' requires two arguments: platform target_device"

        return 1
    fi

    is_supported_platform $1
    if [ $? -ne 0 ]; then
        return 2
    fi

    platform=$1
    platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
    platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
    platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

    source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath

    ${platform}_is_target_device_supported $2
    if [ $? -ne 0 ]; then
        return 3
    fi

    return 0
}

device_for_platform_and_target() {
    local platform

    if [ $# -lt 2 ]; then
        echo "Error, function 'device_for_platform_and_target' requires two arguments: platform target"

        return 1
    fi

    is_supported_platform $1
    if [ $? -ne 0 ]; then
        return 2
    fi

    platform=$1
    platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
    platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
    platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

    source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath

    ${platform}_is_target_build_id_supported $2
    if [ $? -ne 0 ]; then
        return 3
    fi

    ${platform}_device_for_target_build_id $2

    return 0
}

speed_grade_for_platform_and_target() {
    local platform

    if [ $# -lt 2 ]; then
        echo "Error, function 'device_for_platform_and_target' requires two arguments: platform target"

        return 1
    fi

    is_supported_platform $1
    if [ $? -ne 0 ]; then
        return 2
    fi

    platform=$1
    platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
    platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
    platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

    source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath

    ${platform}_is_target_build_id_supported $2
    if [ $? -ne 0 ]; then
        return 3
    fi

    ${platform}_speed_grade_for_target_build_id $2

    return 0
}

list_supported_target_devices_for_all_platforms() {
    local platform

    for platform in $(ls $platforms_folder); do
        platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
        platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
        platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

        source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath

        echo -e "-----------------------------------------"
        echo -e "Platform  : ${platform}"
        echo -e "Target(s) : "$(${platform}_list_supported_target_device_ids)
    done
    echo -e "-----------------------------------------"

    return 0
}

default_target_device_for_platform() {
    local platform

    for platform in $(ls $platforms_folder); do
        if [ "$1" == "$platform" ]; then
            platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
            platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
            platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

            source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath
            echo $(${platform}_default_target_device)

            return 0
        fi
    done

    return 1
}

default_build_target_for_platform() {
    local platform

    for platform in $(ls $platforms_folder); do
        if [ "$1" == "$platform" ]; then
            platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
            platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
            platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

            source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath
            echo $(${platform}_default_build_id)

            return 0
        fi
    done

    return 1
}

platforms_for_target_device() {
    local supported_platforms
    local platform
    local cnt

    if [ $# -lt 1 ]; then
        echo "Error, function 'platform_for_target_device' requires one argument: target_device"

        return 1
    fi

    cnt=0
    supported_platforms=""
    for platform in $(ls $platforms_folder); do
        platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
        platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
        platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

        source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath

        ${platform}_is_target_device_supported $1
        if [ $? -eq 0 ]; then
            if [ $cnt -eq 0 ]; then
                supported_platforms="$platform"
            else
                supported_platforms="$supported_platforms $platform"
            fi

            ((cnt++))
        fi
    done

    echo "$supported_platforms"

    if [ $cnt -eq 0 ]; then
        return 1
    fi
    if [ $cnt -gt 1 ]; then
        return 2
    fi

    return 0
}

platforms_for_target() {
    local supported_platforms
    local platform
    local cnt

    if [ $# -lt 1 ]; then
        echo "Error, function 'platforms_for_target' requires one argument: target_device"

        return 1
    fi

    cnt=0
    supported_platforms=""
    for platform in $(ls $platforms_folder); do
        platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
        platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
        platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"

        source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath

        ${platform}_is_target_build_id_supported $1
        if [ $? -eq 0 ]; then
            if [ $cnt -eq 0 ]; then
                supported_platforms="$platform"
            else
                supported_platforms="$supported_platforms $platform"
            fi

            ((cnt++))
        fi
    done

    echo "$supported_platforms"

    if [ $cnt -eq 0 ]; then
        return 1
    fi
    if [ $cnt -gt 1 ]; then
        return 2
    fi

    return 0
}

target_bitstream_fullpath() {
    if [ $# -lt 3 ]; then
        echo "Error, function 'target_bitstream_fullpath' requires two arguments: platform target_device bootrom_stack_size_kb"

        return 1
    fi

    device=$(device_for_platform_and_target "$platform" "$target")
    speed_grade=$(speed_grade_for_platform_and_target "$platform" "$target")
    bitstream_ext=$(${platform}_bitstream_extension_for_target_build_id "$target")

    bitstream_dir="${build_dir}/${platforms_folder}/${platform}/${devices_folder}/${device}/${speed_grade}/${output_folder}/${artifacts_folder}"
    echo "${bitstream_dir}/${project_name}_${bitstream_stack_prefix}${bootrom_stack_size_kb}${bitstream_stack_suffix}.${bitstream_ext}"

    return 0
}
