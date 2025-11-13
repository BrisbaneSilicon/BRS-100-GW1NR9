#!/bin/bash

if [ $# -lt 1 ]; then
    # NOTE: full path to devices information file should
    # be provided

    return 1
fi

devices_information_file=$1

verbose_print="${2:-true}"

# supported targets devices lists
xilinx_supported_devices_header=""

xilinx_supported_devices_build_id=()
xilinx_supported_devices_family=()
xilinx_supported_devices_part_numbers=()
xilinx_supported_devices_device_ids=()
xilinx_supported_devices_device_versions=()
xilinx_supported_devices_package=()
xilinx_supported_devices_speed_grades=()
xilinx_supported_devices_board_parts=()
xilinx_supported_devices_bitstream_ext=()
xilinx_supported_devices_is_default=()
xilinx_supported_devices_bootrom_update_only_supported=()
xilinx_supported_devices_security_mode_supported=()

xilinx_load_supported_target_devices() {
    f=true
    while read line
    do
        if [ $f = true ]; then
            xilinx_supported_devices_header=$line
        else
            IFS=, read -r -a arr <<< "$line"

            xilinx_supported_devices_build_id+=("${arr[0]}")
            xilinx_supported_devices_family+=("${arr[1]}")
            xilinx_supported_devices_part_numbers+=("${arr[2]}")
            xilinx_supported_devices_device_ids+=("${arr[3]}")
            xilinx_supported_devices_device_versions+=("${arr[4]}")
            xilinx_supported_devices_package+=("${arr[5]}")
            xilinx_supported_devices_speed_grades+=("${arr[6]}")
            xilinx_supported_devices_board_parts+=("${arr[7]}")
            xilinx_supported_devices_bitstream_ext+=("${arr[8]}")
            xilinx_supported_devices_is_default+=("${arr[9]}")
            xilinx_supported_devices_bootrom_update_only_supported+=("${arr[10]}")
            xilinx_supported_devices_security_mode_supported+=("${arr[11]}")
        fi
        f=false
    done < $devices_information_file

    l=${#xilinx_supported_devices_family[@]}
    if [ $l -gt 0 ]; then
        return 0
    fi

    # NOTE: failed to load a single
    # supported target device...
    return 1
}

xilinx_list_supported_target_devices_information() {
    echo $xilinx_supported_devices_header

    l=${#xilinx_supported_devices_family[@]}
    for (( i=0; i<${l}; i++ )); do
        echo -e "${xilinx_supported_devices_build_id[$i]}, ${xilinx_supported_devices_family[$i]}, ${xilinx_supported_devices_part_numbers[$i]}, \
${xilinx_supported_devices_device_ids[$i]}, ${xilinx_supported_devices_device_versions[$i]}, ${xilinx_supported_devices_package[$i]}, \
${xilinx_supported_devices_speed_grades[$i]}, ${xilinx_supported_devices_board_parts[$i]}, ${xilinx_supported_devices_bitstream_ext[$i]}, \
${xilinx_supported_devices_is_default[$i]}, ${xilinx_supported_devices_bootrom_update_only_supported[$i]}, ${xilinx_supported_devices_security_mode_supported[$i]}"
    done
}

xilinx_list_supported_target_build_ids() {

    l=${#xilinx_supported_devices_family[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ $i -gt 0 ]; then
            echo -n ", "
        fi
        echo -n "${xilinx_supported_devices_build_id[$i]}"
    done
    echo ""

    return 0
}

xilinx_list_supported_target_device_ids() {
    l=${#xilinx_supported_devices_family[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ $i -gt 0 ]; then
            echo -n ", "
        fi
        echo -n "${xilinx_supported_devices_device_ids[$i]}"
    done
    echo ""

    return 0
}

xilinx_list_supported_target_devices_support_bootrom_update_only() {
    l=${#xilinx_supported_devices_family[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ $i -gt 0 ]; then
            echo -n ", "
        fi
        echo -n "${xilinx_supported_devices_bootrom_update_only_supported[$i]}"
    done
    echo ""

    return 0
}

xilinx_default_target_device() {
    l=${#xilinx_supported_devices_family[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "${xilinx_supported_devices_is_default[$i]}" = "YES" ]; then
            echo "YES"

            return 0
        fi
    done

    echo "NO"

    return 1
}

xilinx_is_target_device_supported() {
    for st_dev in "${xilinx_supported_devices_device_ids[@]}"; do
        if [ "$1" = "$st_dev" ]; then
            return 0
        fi
    done

    return 1
}

xilinx_part_number_for_target_build_id() {
    l=${#xilinx_supported_devices_family[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "$1" = "${xilinx_supported_devices_build_id[$i]}" ]; then
            echo ${xilinx_supported_devices_part_numbers[$i]}

            return 0
        fi
    done

    return 1
}

xilinx_board_part_for_target_build_id() {
    l=${#xilinx_supported_devices_family[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "$1" = "${xilinx_supported_devices_build_id[$i]}" ]; then
            echo ${xilinx_supported_devices_board_parts[$i]}

            return 0
        fi
    done

    return 1
}

xilinx_device_for_target_build_id() {
    l=${#xilinx_supported_devices_family[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "$1" = "${xilinx_supported_devices_build_id[$i]}" ]; then
            echo ${xilinx_supported_devices_device_ids[$i]}

            return 0
        fi
    done

    return 1
}

xilinx_device_version_for_target_build_id() {
    l=${#xilinx_supported_devices_family[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "$1" = "${xilinx_supported_devices_build_id[$i]}" ]; then
            echo ${xilinx_supported_devices_device_versions[$i]}

            return 0
        fi
    done

    return 1
}

xilinx_is_target_build_id_supported() {
    for st_build_id in "${xilinx_supported_devices_build_id[@]}"; do
        if [ "$1" = "$st_build_id" ]; then
            return 0
        fi
    done

    return 1
}

xilinx_speed_grade_for_target_build_id() {
    l=${#xilinx_supported_devices_family[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "$1" = "${xilinx_supported_devices_build_id[$i]}" ]; then
            echo ${xilinx_supported_devices_speed_grades[$i]}

            return 0
        fi
    done

    return 1
}

xilinx_does_target_build_id_support_bootrom_update_only() {
    l=${#xilinx_supported_devices_family[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "$1" = "${xilinx_supported_devices_build_id[$i]}" ]; then
            if [ "${xilinx_supported_devices_bootrom_update_only_supported[$i]}" = "YES" ]; then
                echo "YES"

                return 0
            fi
        fi
    done

    echo "NO"

    return 1
}

xilinx_does_target_build_id_support_security_mode() {
    l=${#xilinx_supported_devices_family[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "$1" = "${xilinx_supported_devices_build_id[$i]}" ]; then
            if [ "${xilinx_supported_devices_security_mode_supported[$i]}" = "YES" ]; then
                echo "YES"

                return 0
            fi
        fi
    done

    echo "NO"

    return 1
}

xilinx_bitstream_extension_for_target_build_id() {
    l=${#xilinx_supported_devices_family[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "$1" = "${xilinx_supported_devices_build_id[$i]}" ]; then
            echo ${xilinx_supported_devices_bitstream_ext[$i]}

            return 0
        fi
    done

    return 1
}

xilinx_build_target() {
    if [ $# -lt 7 ]; then
        echo "Error, function 'xilinx_build_target' requires minimum seven arguments: build_tool_binary \
build_tcl_script project_name project_root_directory build_directory target clock_frequency stack_size_bytes [build_proj_only] [build_synth_only]"

        return 1
    fi

    build_tool_binary=$1
    build_tcl_script=$2
    project_name=$3
    project_root_directory=$4
    build_directory=$5
    target=$6
    clock_frequency=$7
    stack_size_bytes=$8
    if [ $# -gt 8 ]; then
        build_proj_only=$9
    else
        build_proj_only=false
    fi
    if [ $# -gt 9 ]; then
        build_synth_only=$10
    else
        build_synth_only=false
    fi

    part_number=$(xilinx_part_number_for_target_build_id $target)
    target_board=$(xilinx_board_part_for_target_build_id $target)

    $build_tool_binary -mode batch -log $build_directory/build.log -journal $build_directory/journal.jou -source $build_tcl_script \
-tclargs $project_name $project_root_directory $build_directory $part_number $target_board $stack_size_bytes $build_proj_only $build_synth_only

    return 0
}

xilinx_post_build_cleanup() {
    jou_present=`ls -1 *.jou 2>/dev/null | wc -l`
    if [ $jou_present != 0 ]; then
        rm *.jou
    fi
    jou_present_above_dir=`ls -1 ../*.jou 2>/dev/null | wc -l`
    if [ $jou_present_above_dir != 0 ]; then
        rm ../*.jou
    fi

    log_present=`ls -1 *.log 2>/dev/null | wc -l`
    if [ $log_present != 0 ]; then
        rm *.log
    fi
    log_present_above_dir=`ls -1 ../*.log 2>/dev/null | wc -l`
    if [ $log_present_above_dir != 0 ]; then
        rm ../*.log
    fi

    if [ -e ".Xil" ]; then
        rm -r .Xil
    fi
    if [ -e "../.Xil" ]; then
        rm -r ../.Xil
    fi

    vivado_pid_str_present=`ls -1 vivado_pid*.str 2>/dev/null | wc -l`
    if [ $vivado_pid_str_present != 0 ]; then
        rm vivado_pid*.str
    fi
    vivado_pid_str_present_dir_above=`ls -1 ../vivado_pid*.str 2>/dev/null | wc -l`
    if [ $vivado_pid_str_present_dir_above != 0 ]; then
        rm ../vivado_pid*.str
    fi
}



############################################### Sourcing script functionality ###############################################

xilinx_load_supported_target_devices
if [ $? -ne 0 ]; then
    return 2
fi

return 0