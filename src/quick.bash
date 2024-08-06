# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar


source "python.bash"

if [[ -z "${_REDSHELL_QUICK}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_QUICK=1

# Usage: quick_rebuild [PATH]
function quick_rebuild() {
    local path="${1}"
    if [[ -z "${path}" ]]; then
        path=~/.redshell/src
    fi
    abs_path="$(cd "${path}" && pwd)"
    
    python_func --clean -p "${abs_path}/quick.py" gen_all --path "${abs_path}" --output "${abs_path}/quick.gen.bash"
}

function q() {
    __q "${@}"
}

fi # _REDSHELL_QUICK
