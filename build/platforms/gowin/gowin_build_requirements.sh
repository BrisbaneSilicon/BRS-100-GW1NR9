#!/bin/bash

verbose_print="${1:-true}"

platform="gowin"

gowin_fpga_dsngr_ver_reqd=V1.9.12

gowin_fpga_dsngr_search_dirs=( "$HOME/Applications" "/opt/gowin" "/opt/GOWIN" "/opt/Gowin" $HOME"/Documents/Applications/" )
gowin_fpga_dsngr_install_linux_foldername="Gowin_${gowin_fpga_dsngr_ver_reqd}_linux"
gowin_fpga_dsngr_gw_sh="/IDE/bin/gw_sh"


print_build_requirements_error() {
    case $1 in
        1)
            echo "unable to locate GOWIN FPGA Designer install directory, '${gowin_fpga_dsngr_install_linux_foldername}'"
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

    vprint "Attempting to locate gowin fpga designer installation, '${gowin_fpga_dsngr_install_linux_foldername}'"
    for dir in "${gowin_fpga_dsngr_search_dirs[@]}"; do

        vprint_no_newline "Looking in ${dir}..."
        if [ -d "${dir}/${gowin_fpga_dsngr_install_linux_foldername}" ]; then
            vprint "found!"

            built_tool_binary_fullpath="${dir}/${gowin_fpga_dsngr_install_linux_foldername}${gowin_fpga_dsngr_gw_sh}"
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
