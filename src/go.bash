# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Helpers for dealing with Go packages.

if [[ -z "${_REDSHELL_GO}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_GO=1

function go_pkg_do() {
    local pkg
    local cmd
    local vendor_deps

    while [[ "${#}" -ne 0 ]]; do
        case "${1}" in
            -h|--help)
                echo "Usage: go_pkg_do <pkg> <cmd> [args...]" >&2
                return 0
            ;;
            -V|--vendor-deps)
                vendor_deps="1"
            ;;
            -c|--cmd)
                cmd="${2}"
                shift
            ;;
            -r|--repo)
                pkg="${2}"
                shift
            ;;
            --)
                break
            ;;
            *)
                # Positional args: pkg then cmd.
                if [[ -z "${pkg}" ]]; then
                    pkg="${1}"
                elif [[ -z "${cmd}" ]]; then
                    cmd="${1}"
                else
                    break
                fi
        esac
        shift
    done

    if [[ -z "${pkg}" || -z "${cmd}" ]]; then
        echo "Usage: go_pkg_do <pkg> <cmd> [args...]" >&2
        return 1
    fi

    mkdir -p "${HOME}/.redshell/go"
    pushd "${HOME}/.redshell/go" > /dev/null
    if [[ -d "$(basename "${pkg}")" ]]; then
        pushd "$(basename "${pkg}")" > /dev/null
        git pull > /dev/null
        popd > /dev/null
    else
        gh repo clone "${pkg}"
    fi
    pushd "$(basename "${pkg}")" > /dev/null

    if [[ -n "${vendor_deps}" ]]; then
        echo "Vendoring dependencies..." >&2
        go mod vendor
    fi

    "${cmd}" "${@}"
    local err="${?}"
    popd > /dev/null
    popd > /dev/null
    return "${err}"
}

fi # _REDSHELL_GO
