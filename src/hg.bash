# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Mercurial helpers.

if [[ -z "${_REDSHELL_HG}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_HG=1

# Is the current directory a mercurial repo? Fast check. Prints the path to the
# repo root, or nothing.
function hg_root() {
    local root="$(pwd -P)"
    while [[ "${root}" && ! -d "${root}/.hg" ]]
    do
    root="${root%/*}"
    done

    if [[ -z "${root}" ]]; then
        return 1
    fi
    echo "${root}"
}

fi # _REDSHELL_HG
