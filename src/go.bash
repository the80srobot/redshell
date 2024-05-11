# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_GO}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_GO=1

function go_pkg_do() {
    local pkg="${1}"
    shift
    local cmd="${1}"
    shift
    if [[ -z "${pkg}" || -z "${cmd}" ]]; then
        echo "Usage: go_pkg_do <pkg> <cmd> [args...]" >&2
        return 1
    fi

    mkdir -p "${HOME}/.redshell/go"
    pushd "${HOME}/.redshell/go" > /dev/null
    [[ -d "$(basename "${pkg}")" ]] || gh repo clone "${pkg}"
    pushd "$(basename "${pkg}")" > /dev/null
    "${cmd}" "${@}"
    local err="${?}"
    popd > /dev/null
    popd > /dev/null
    return "${err}"
}

fi # _REDSHELL_GO
