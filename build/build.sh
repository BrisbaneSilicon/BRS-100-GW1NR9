#!/bin/bash

source build_globals.sh
source build_utils.sh
    # NOTE: initialise build script
    # utilities...


do_project_gen_only=false
do_synthesis_only=false

init_build() {
    # NOTE: fetch device
    device=$(device_for_platform_and_target "$platform" "$target")
    speed_grade=$(speed_grade_for_platform_and_target "$platform" "$target")


    # NOTE: Check build requirements satisfied
    pdir=$(pwd)"/$platforms_folder/$platform"
    ddir="$pdir/$devices_folder/$device"
    odir="$ddir/$speed_grade/$output_folder"
    artifacts_dir="$odir/$artifacts_folder"
    build_script_fullpath="$ddir/${device_build_tcl_script}"

    platform_check_build_requirements_script_fullpath="$pdir/${platform}${platform_check_build_requirements_script_suffix}"
    source $platform_check_build_requirements_script_fullpath
    if [ $? -ne 0 ]; then
        echo "Build initialization failed: unable to successfully source '$platform_check_build_requirements_script_fullpath'"
        exit
    fi

    build_initialized=true
}

init_build_utils() {
    platform_utils_script_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_utils_script_suffix}"
    platform_supported_devices_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_devices_csv_file_suffix}"
    platform_supported_system_clock_frequencies_csv_file_fullpath=$(pwd)"/${platforms_folder}/${platform}/${platform}${platform_supported_system_clock_frequencies_csv_file_suffix}"
    source $platform_utils_script_fullpath $platform_supported_devices_csv_file_fullpath $platform_supported_system_clock_frequencies_csv_file_fullpath
    if [ $? -ne 0 ]; then
        echo "Build initialization failed: unable to successfully source '$platform_utils_script_fullpath'"
        exit
    fi

    build_utils_initialized=true
}

setup_build_output_directory() {
    clean_platform_device $platform $device $speed_grade
    mkdir -p "$artifacts_dir"
}

generate_build_top_wrapper() {
    source "$ddir/$device_generate_top_wrapper_script" "$artifacts_dir" "$device_top_wrapper_filename" "$target" "$system_clock_frequency_mhz" "$test_string" "$test_string_len"
}

init_platform_exit_on_failure() {
    platform=$(platforms_for_target "$target")

    ret=$?
    if [ $ret -eq 1 ]; then
        echo "ERROR: Build target '$target' is not supported"
        echo -e "Try './build.sh --help' for more information."

        exit
    fi
    if [ $ret -eq 2 ]; then
        echo "Build target '$target' supported by multiple platforms: "$platform
        echo -e "Try './build.sh --help' for more information."

        exit
    fi
}

check_target_supported_for_platform_exit_on_failure() {
    is_target_build_id_supported_for_platform "$platform" "$target"
    if [ $? -ne 0 ]; then
        echo "Platform '$platform' does not support build target '$target'"
        echo -e "Try './build.sh --help' for more information."

        exit
    fi
}

embedded_logic_analyzer=0
board_demonstration=0
pushbutton_reset=1
uart_baud=115200
target=BRS-100-GW1NR9
test_string="abcdefghijklmnopqrstuvwxyz123456"
test_string_len=32
test_string_was_provided=0

while [ $# -gt 0 ]; do
    case $1 in
        -h|--help)
            print_build_help
            exit
            ;;
        -p| --proj_only)
            do_project_gen_only=true
            shift 1
            ;;
        -s| --synth_only)
            do_synthesis_only=true
            shift 1
            ;;
        -c|--clean)
            c_opt=$1
            do_clean_platform_target=true
            shift 1
            ;;
        -m|--clean_platform)
            c_opt=$1
            do_clean_platform=true
            shift 1
            ;;
        -a|--clean_all_platforms)
            c_opt=$1
            do_clean_all_platforms=true
            shift 1
            ;;
        -d|--list_default_target)
            echo "$target"
            exit
            ;;
        -i|--list_supported_platforms)
            list_supported_platforms
            exit
            ;;
        -l|--list_supported_targets)
            if [ $# -gt 1 ]; then
                list_supported_targets_for_platform $2
                if [ $? -ne 0 ]; then
                    echo "Unable to ascertain supported build targets for platform: $2"
                    echo -e "Try './build.sh --help' for more information."

                    exit
                fi
            else
                list_supported_targets_for_all_platforms
            fi

            exit
            ;;
        -y|--list_supported_system_clock_frequencies)
            if [ ! -v platform ]; then
                init_platform_exit_on_failure
            else
                check_target_supported_for_platform_exit_on_failure
            fi
            if [ ! -v build_utils_initialized ]; then
                init_build_utils
            fi

            ${platform}_list_supported_system_clock_frequencies

            exit
            ;;
        -t|--custom_target)
            chk_opt $@

            target=$2
            shift 2
            ;;
        -u|--uart_baud)
            chk_opt $@

            uart_baud=$2
            shift 2
            ;;
        -r|--disable_pushbutton_reset)
            pushbutton_reset=0
            shift 1
            ;;
        -b|--board_demonstration)
            board_demonstration=1
            shift 1
            ;;
        -o|-teststring|--teststring)
            chk_opt $@

            test_string=$2
            test_string_len=${#test_string}
            test_string_was_provided=1
            shift 2
            ;;
        -e|--embedded_logic_analyzer)
            embedded_logic_analyzer=1
            shift 1
            ;;
        -f|--platform)
            chk_opt $@

            is_supported_platform $2
            if [ $? -ne 0 ]; then
                echo "Platform unsupported: "$2
                echo -e "Try './build.sh --help' for more information."

                exit
            fi

            platform=$2
            shift 2
            ;;

        -k|--system_clock_frequency_mhz)
            chk_opt $@

            if [ ! -v platform ]; then
                init_platform_exit_on_failure
            else
                check_target_supported_for_platform_exit_on_failure
            fi
            if [ ! -v build_utils_initialized ]; then
                init_build_utils
            fi

            ${platform}_is_supported_system_clock_frequency $2
            if [ $? -ne 0 ]; then
                echo "System clock frequency unsupported: "$2" MHz"
                echo -e "Try './build.sh --help' for more information."

                exit
            fi

            system_clock_frequency_mhz=$2
            shift 2
            ;;

        *)
            echo -e "Invalid option: '$1'."
            echo -e "Try './build.sh --help' for more information."

            exit
            ;;
    esac
done

if [ $test_string_was_provided -eq 1 ] && [ $board_demonstration -eq 0 ]; then
    echo ""
    echo "Teststring is only valid with -b / --board_demonstration."
    echo -e "Try './build.sh --help' for more information."
    echo ""
    exit 1
fi

if [ $board_demonstration -eq 1 ] && [ $test_string_was_provided -eq 1 ]; then
    if [ -z "$test_string" ] || [ ${#test_string} -gt 32 ]; then
        echo ""
        echo "Teststring must be 1 to 32 characters."
        echo -e "Try './build.sh --help' for more information."
        echo ""
        exit 1
    fi

    test_string_has_invalid_chars=0
    if [ -v LC_ALL ]; then
        old_lc_all=$LC_ALL
        old_lc_all_was_set=1
    else
        old_lc_all_was_set=0
    fi
    LC_ALL=C
    if [[ "$test_string" =~ [^[:print:]] ]] || [[ "$test_string" == *\"* ]] || [[ "$test_string" == */* ]] || [[ "$test_string" == *\\* ]] || [[ "$test_string" == *\`* ]]; then
        test_string_has_invalid_chars=1
    fi
    if [ $old_lc_all_was_set -eq 1 ]; then
        LC_ALL=$old_lc_all
    else
        unset LC_ALL
    fi

    if [ $test_string_has_invalid_chars -eq 1 ]; then
        echo ""
        echo "Teststring must contain only printable ASCII and custom strings cannot contain double quote, slash, backtick, backslash, CR, or LF."
        echo -e "Try './build.sh --help' for more information."
        echo ""
        exit 1
    fi

    test_string_len=${#test_string}
fi

if [ ! -v platform ]; then
    init_platform_exit_on_failure
else
    check_target_supported_for_platform_exit_on_failure
fi

if [ ! -v build_initialized ]; then
    init_build
fi
if [ ! -v build_utils_initialized ]; then
    init_build_utils
fi

if [ ! -v system_clock_frequency_mhz ]; then
    if [ ! -v platform ]; then
        init_platform_exit_on_failure
    else
        check_target_supported_for_platform_exit_on_failure
    fi

    system_clock_frequency_mhz=$(${platform}_get_default_system_clock_frequency)
fi

# NOTE: Handle cleanup
if [ -v do_clean_platform_target ]; then
    if [ ! -v platform ]; then
        echo "Option '$c_opt' requires PLATFORM explicitly defined"
        echo -e "Try './build.sh --help' for more information."

        exit
    fi
    if [ ! -v target ]; then
        echo "Option '$c_opt' requires TARGET explicitly defined"
        echo -e "Try './build.sh --help' for more information."

        exit
    fi

    check_target_supported_for_platform_exit_on_failure

    device=$(device_for_platform_and_target "$platform" "$target")
    speed_grade=$(speed_grade_for_platform_and_target "$platform" "$target")
    clean_platform_device $platform $device $speed_grade
    exit
fi
if [ -v do_clean_platform ]; then
    if [ ! -v platform ]; then
        echo "Option '$c_opt' requires PLATFORM explicitly defined"
        echo -e "Try './build.sh --help' for more information."

        exit
    fi

    clean_platform $platform
    exit
fi
if [ -v do_clean_all_platforms ]; then
    clean_all_platforms
    exit
fi


# REVISIT: check no invalid build switches vs target
# For example, if 'arty_s7_board_config_mode_enable'
# is set, and the target is TangNano... something
# has gone wrong!


# NOTE: Pre-build tasks
setup_build_output_directory
generate_build_top_wrapper

# NOTE: build
arg1=$built_tool_binary_fullpath
arg2=$build_script_fullpath
arg3=$build_project_name
arg4=$project_root_dir
arg5=$odir
arg6=$target
arg7=$system_clock_frequency_mhz
if [ $embedded_logic_analyzer -eq 0 ]; then
    arg8=false
else
    arg8=true
fi
arg9=$do_project_gen_only
arg10=$do_synthesis_only
${platform}_build_target $arg1 $arg2 $arg3 $arg4 $arg5 $arg6 $arg7 $arg8 $arg9 $arg10

# NOTE: post-build
${platform}_post_build_cleanup
