#!/bin/bash

verbose_print="${1:-true}"

platform="xilinx"

vivado_search_dirs=( "$HOME/Applications" "/opt/xilinx" "/opt/XILINX" "/opt/Xilinx" $HOME"/Documents/Applications/" )
vivado_version_supported=2024.2
vivado_install_linux_foldername="Vivado"
vivado_setup_script="settings64.sh"


print_build_requirements_error() {
    case $1 in
        1)
            echo "Unable to locate Xilinx Vivado install directory, '${vivado_install_linux_foldername}'"
            ;;
        *)
            echo "Unknown error code: "$1
            ;;
    esac
}

# NOTE: after calling this, a global variable 'built_tool_binary_fullpath' will be defined, which defines the full path to
# the build tool, for the given platform.
check_build_requirements() {
    vprint "Checking system requirements for platform='"$platform"'  build."

    vprint "Attempting to locate Vivado installation, '${vivado_install_linux_foldername} ${vivado_version_supported}'."
    for dir in "${vivado_search_dirs[@]}"; do

        vprint_no_newline "Looking in ${dir}..."
        if [ -d "${dir}/${vivado_install_linux_foldername}" ]; then
            vprint "found!"

            source "${dir}/${vivado_install_linux_foldername}/${vivado_version_supported}/${vivado_setup_script}"
            built_tool_binary_fullpath=vivado
                # NOTE: no need to provide full path as set
                # script was sourced (sets up PATH env variable).
            break
        else
            vprint "not there."
        fi
    done

    if [ ! -v built_tool_binary_fullpath ]; then
        echo -e "Build requirements check failed: "$(print_build_requirements_error 1)

        return 2
    fi

    vprint "System requirements check pass."

    return 0
}


############################################### Sourcing script functionality ###############################################

check_build_requirements
if [ $? -ne 0 ]; then
    return 1
fi

return 0
