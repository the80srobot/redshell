# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar


source "python.bash"
source "quick.gen.bash"

if [[ -z "${_REDSHELL_QUICK}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_QUICK=1

# Usage: quick_rebuild REDSHELL_PATH [EXTRA_PATH ...]
function quick_rebuild() {
    local rs_path="${1}"
    if [[ -n "${rs_path}" ]]; then
        shift
    else
        rs_path="$(cd ~/.redshell/src && pwd)"
    fi

    local all_paths=("${rs_path}")
    while [[ "${#}" -ne 0 ]]; do
        all_paths+=("$(cd "${1}" && pwd)")
        shift
    done
    local paths_arg="$(strings_join "," "${all_paths[@]}")"
    python_func --clean -p "${rs_path}/quick.py" build_all --paths "${paths_arg}" --output "${rs_path}/quick.gen.bash"
}

function q() {
    __q "${@}"
}

fi # _REDSHELL_QUICK
