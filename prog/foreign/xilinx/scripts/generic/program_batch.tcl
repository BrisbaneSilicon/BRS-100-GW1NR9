if {$argc < 2} {
    error "Expecting TARGET_DEVICE BITSTREAM_FULLPATH"
}

set target_device       [lindex $argv 0]
set bitstream_fullpath  [lindex $argv 1]

set supported_vivado_versions { 2024.2 }
set vivado_version [version -short]

if { [lsearch $supported_vivado_versions $vivado_version] == -1 } {
    error "Unsupported Vivado version $vivado_version. Supported versions: $supported_vivado_versions"
}

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set_property PROGRAM.FILE $bitstream_fullpath   [get_hw_devices "${target_device}_0"]

current_hw_device                               [get_hw_devices "${target_device}_0"]
refresh_hw_device -update_hw_probes false       [lindex [get_hw_devices "${target_device}_0"] 0]

set_property PROBES.FILE {}                     [get_hw_devices "${target_device}_0"]
set_property FULL_PROBES.FILE {}                [get_hw_devices "${target_device}_0"]
set_property PROGRAM.FILE $bitstream_fullpath   [get_hw_devices "${target_device}_0"]

program_hw_devices                              [get_hw_devices "${target_device}_0"]
refresh_hw_device                               [lindex [get_hw_devices "${target_device}_0"] 0]
