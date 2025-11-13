if {$argc < 3} {
    error "Expecting TARGET_DEVICE BIT_FILE_FULLPATH FLASH_DEVICE"
}

set eelf_file_fullpath  [lindex $argv 0]
set bit_file_fullpath   [lindex $argv 1]
set flash_device        [lindex $argv 2]
set output_dir          [lindex $argv 3]

set supported_vivado_versions { 2024.2 }
set vivado_version [version -short]

if { [lsearch $supported_vivado_versions $vivado_version] == -1 } {
    error "Unsupported Vivado version $vivado_version. Supported versions: $supported_vivado_versions"
}

open_hw_manager

write_cfgmem -format mcs -size 16 -interface SPIx4 -loadbit [list up 0x00000000 "${bit_file_fullpath}"] \
-loaddata [list up 0x00300000 "${eelf_file_fullpath}"] -force -file "${output_dir}/BRS-100-GW1NR9_standalone_flash.mcs"
