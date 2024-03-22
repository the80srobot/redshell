# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_HG}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_HG=1

# Is the current directory a mercurial repo? Fast check.
function is_dir_hg() {
    local root="$(pwd -P)"
    while [[ $root && ! -d $root/.hg ]]
    do
    root="${root%/*}"
    done

    echo "$root"
}

fi # _REDSHELL_HG
