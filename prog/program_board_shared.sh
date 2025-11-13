exec_from_build_directory() {
    project_root_dir=$(git rev-parse --show-toplevel)

    cd "${project_root_dir}/build"
}

exec_end() {
    project_root_dir=$(git rev-parse --show-toplevel)

    cd "${project_root_dir}/prog"
}