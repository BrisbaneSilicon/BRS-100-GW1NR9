proc this_script_path {} {
    return [file normalize [info script]]
}

proc this_script_dir {} {
    return [file dirname [this_script_path]]
}