#!/bin/bash

if [ $# -lt 1 ]; then
    # NOTE: full path to devices information file should
    # be provided

    return 1
fi

devices_information_file=$1
supported_system_clock_frequencies_file=$2
verbose_print="${3:-true}"


# supported targets devices lists
gowin_supported_devices_header=""

gowin_supported_devices_build_id=()
gowin_supported_devices_series=()
gowin_supported_devices_part_numbers=()
gowin_supported_devices_device_ids=()
gowin_supported_devices_device_versions=()
gowin_supported_devices_package=()
gowin_supported_devices_speed_grades=()
gowin_supported_devices_core_voltages=()
gowin_supported_devices_is_default=()
gowin_supported_devices_bootrom_update_only_supported=()
gowin_supported_devices_security_mode_supported=()

gowin_supported_system_clock_frequencies=()

gowin_load_supported_target_devices() {
    f=true
    while read line
    do
        if [ $f = true ]; then
            gowin_supported_devices_header=$line
        else
            IFS=',' read -r -a arr <<< "$line"

            gowin_supported_devices_build_id+=(${arr[0]})
            gowin_supported_devices_series+=(${arr[1]})
            gowin_supported_devices_part_numbers+=(${arr[2]})
            gowin_supported_devices_device_ids+=(${arr[3]})
            gowin_supported_devices_device_versions+=(${arr[4]})
            gowin_supported_devices_package+=(${arr[5]})
            gowin_supported_devices_speed_grades+=(${arr[6]})
            gowin_supported_devices_core_voltages+=(${arr[7]})
            gowin_supported_devices_is_default+=(${arr[8]})
            gowin_supported_devices_bootrom_update_only_supported+=(${arr[9]})
            gowin_supported_devices_security_mode_supported+=(${arr[10]})
        fi
        f=false
    done < $devices_information_file

    l=${#gowin_supported_devices_series[@]}
    if [ $l -gt 0 ]; then
        return 0
    fi

    # NOTE: failed to load a single
    # supported target device...
    return 1
}

gowin_list_supported_target_devices_information() {
    echo $gowin_supported_devices_header

    l=${#gowin_supported_devices_series[@]}
    for (( i=0; i<${l}; i++ )); do
        echo -e "${gowin_supported_devices_build_id[$i]}, ${gowin_supported_devices_series[$i]}, ${gowin_supported_devices_part_numbers[$i]}, \
${gowin_supported_devices_device_ids[$i]}, ${gowin_supported_devices_device_versions[$i]}, ${gowin_supported_devices_package[$i]}, \
${gowin_supported_devices_speed_grades[$i]}, ${gowin_supported_devices_core_voltages[$i]}, ${gowin_supported_devices_is_default[$i]}, \
${gowin_supported_devices_security_mode_supported[$i]}"
    done
}

gowin_list_supported_target_build_ids() {
    l=${#gowin_supported_devices_series[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ $i -gt 0 ]; then
            echo -n ", "
        fi
        echo -n "${gowin_supported_devices_build_id[$i]}"
    done
    echo ""

    return 0
}

gowin_list_supported_target_device_ids() {
    l=${#gowin_supported_devices_series[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ $i -gt 0 ]; then
            echo -n ", "
        fi
        echo -n "${gowin_supported_devices_device_ids[$i]}"
    done
    echo ""

    return 0
}

gowin_list_supported_target_devices_support_bootrom_update_only() {
    l=${#gowin_supported_devices_series[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ $i -gt 0 ]; then
            echo -n ", "
        fi
        echo -n "${gowin_supported_devices_bootrom_update_only_supported[$i]}"
    done
    echo ""

    return 0
}

gowin_default_target_device() {
    l=${#gowin_supported_devices_series[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "${gowin_supported_devices_is_default[$i]}" = "YES" ]; then
            echo "${gowin_supported_devices_device_ids[$i]}"

            return 0
        fi
    done

    return 1
}

gowin_default_build_id() {
    l=${#gowin_supported_devices_series[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "${gowin_supported_devices_is_default[$i]}" = "YES" ]; then
            echo "${gowin_supported_devices_build_id[$i]}"

            return 0
        fi
    done

    return 1
}

gowin_is_target_device_supported() {
    for st_dev in "${gowin_supported_devices_device_ids[@]}"; do
        if [ "$1" = "$st_dev" ]; then
            return 0
        fi
    done

    return 1
}

gowin_is_target_build_id_supported() {
    for st_build_id in "${gowin_supported_devices_build_id[@]}"; do
        if [ "$1" = "$st_build_id" ]; then
            return 0
        fi
    done

    return 1
}

gowin_part_number_for_target_build_id() {
    l=${#gowin_supported_devices_series[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "$1" = "${gowin_supported_devices_build_id[$i]}" ]; then
            echo ${gowin_supported_devices_part_numbers[$i]}

            break
        fi
    done

    return 0
}

gowin_device_for_target_build_id() {
    l=${#gowin_supported_devices_series[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "$1" = "${gowin_supported_devices_build_id[$i]}" ]; then
            echo ${gowin_supported_devices_device_ids[$i]}

            break
        fi
    done

    return 0
}

gowin_device_version_for_target_build_id() {
    l=${#gowin_supported_devices_series[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "$1" = "${gowin_supported_devices_build_id[$i]}" ]; then
            echo ${gowin_supported_devices_device_versions[$i]}

            break
        fi
    done

    return 0
}

gowin_speed_grade_for_target_build_id() {
    l=${#gowin_supported_devices_series[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "$1" = "${gowin_supported_devices_build_id[$i]}" ]; then
            echo ${gowin_supported_devices_speed_grades[$i]}

            break
        fi
    done

    return 0
}

gowin_does_target_build_id_support_bootrom_update_only() {
    l=${#gowin_supported_devices_series[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "${gowin_supported_devices_bootrom_update_only_supported[$i]}" = "YES" ]; then
            echo "YES"

            return 0
        fi
    done

    echo "NO"

    return 1
}

gowin_does_target_build_id_support_security_mode() {
    l=${#gowin_supported_devices_series[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "${gowin_supported_devices_security_mode_supported[$i]}" = "YES" ]; then
            echo "YES"

            return 0
        fi
    done

    echo "NO"

    return 1
}

gowin_load_supported_system_clock_frequencies() {
    f=true
    while read line
    do
        if [ $f = true ]; then
            header=$line
        else
            IFS=',' read -r -a arr <<< "$line"

            gowin_supported_system_clock_frequencies+=(${arr[0]})
                # TODO: check (${arr[1]}) matches current target...
        fi
        f=false
    done < $supported_system_clock_frequencies_file

    l=${#gowin_supported_system_clock_frequencies[@]}
    if [ $l -gt 0 ]; then
        return 0
    fi

    # NOTE: failed to load a single
    # supported target frequency...
    return 1
}

gowin_list_supported_system_clock_frequencies() {
    echo -e "----------------------------------------------------------------------------------"
    echo -e "Platform           : ${platform}"
    echo -e "Target             : ${target}"
    echo -ne "Sysclk Freq (MHz)  : "
    l=${#gowin_supported_system_clock_frequencies[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ $i -gt 0 ]; then
            echo -n ", "
        fi
        echo -n "${gowin_supported_system_clock_frequencies[$i]}"
    done
    echo -e "\n----------------------------------------------------------------------------------"

    return 0
}

gowin_is_supported_system_clock_frequency() {
    l=${#gowin_supported_system_clock_frequencies[@]}
    for (( i=0; i<${l}; i++ )); do
        if [ "$1" = "${gowin_supported_system_clock_frequencies[$i]}" ]; then
            return 0
        fi
    done

    return 1
}

gowin_get_default_system_clock_frequency() {
    echo "${gowin_supported_system_clock_frequencies[0]}"

    return 0
}


gowin_build_target() {
    if [ $# -lt 10 ]; then
        echo "Error, function 'gowin_build_target' requires seven arguments: build_tool_binary \
build_tcl_script project_name project_root_directory build_directory target_build_id system_clock_frequency_mhz \
embedded_logic_analyzer do_project_gen_only do_synthesis_only"

        return 1
    fi

    build_tool_binary=$1
    build_tcl_script=$2
    project_name=$3
    project_root_directory=$4
    build_directory=$5
    target_build_id=$6
    system_clock_frequency_mhz=$7
    embedded_logic_analyzer=$8
    do_project_gen_only=$9
    do_synthesis_only=$10

    part_number=$(gowin_part_number_for_target_build_id $target_build_id)
    device_version=$(gowin_device_version_for_target_build_id $target_build_id)
    speed_grade=$(gowin_speed_grade_for_target_build_id $target_build_id)

    $build_tool_binary $build_tcl_script $project_name $project_root_directory $build_directory $part_number \
$device_version $speed_grade $system_clock_frequency_mhz $embedded_logic_analyzer $do_project_gen_only $do_synthesis_only

    return 0
}

gowin_post_build_cleanup() {
    # REVISIT: Anything to do here ?
    :
}


############################################### Sourcing script functionality ###############################################

gowin_load_supported_target_devices
if [ $? -ne 0 ]; then
    return 2
fi

gowin_load_supported_system_clock_frequencies
if [ $? -ne 0 ]; then
    return 3
fi

return 0