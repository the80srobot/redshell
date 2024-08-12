# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Redshell function help, switch and autocomplete.

source "python.bash"
source "quick.gen.bash"

if [[ -z "${_REDSHELL_QUICK}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_QUICK=1

# Usage: __quick_build_all REDSHELL_PATH [EXTRA_PATH ...]
function __quick_build_all() {
    local rs_path="${1}"
    local all_paths=()
    while [[ "${#}" -ne 0 ]]; do
        all_paths+=("$(cd ${1} && pwd)")
        shift
    done
    local paths_arg="$(strings_join "," "${all_paths[@]}")"
    python_func \
        -p "${rs_path}/quick.py" \
        build_all \
        --paths "${paths_arg}" \
        --output "${rs_path}/quick.gen.bash"
}

# Usage: quick_rebuild [--src-path PATH] [--skip-extra-paths]
function quick_rebuild() {
    local extra_paths=()
    if [[ -f "${HOME}/.redshell_persist/module_paths.txt" ]]; then
        while read -r line; do
            if [[ -z "${line}" || "${line}" == "#"* ]]; then
                continue
            fi
            # Replace the fucking tilde manually, because apparently this is too
            # complicated for the bash interpreter.
            line="$(path_expand "${line}")"
            extra_paths+=("${line}")
        done < "${HOME}/.redshell_persist/module_paths.txt"
    fi
    local src_path="$(cd ~/.redshell/src && pwd)"

    while [[ "${#}" -ne 0 ]]; do
        case "${1}" in
            --src-path)
                local src_path="${2}"
                if [[ -z "${src_path}" ]]; then
                    return 1
                fi
                src_path="$(cd "${src_path}" && pwd)"
                ;;
            --skip-extra-paths)
                local extra_paths=()
                ;;
        esac
        shift
    done

    __quick_build_all "${src_path}" "${extra_paths[@]}"
}

function q() {
    __q "${@}"
}

fi # _REDSHELL_QUICK
