# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Mercurial helpers.

if [[ -z "${_REDSHELL_HG}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_HG=1

# Fast check for mercurial. (About 100 times faster than `hg root`.) Prints the
# root directory of the repository if the current directory is in a repository.
# Otherwise returns 1.
#
# Usage: hg_root
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

function hg_repo_name() {
    local root
    root="$(hg_root)" || return 1
    cat "${root}/.hg/reponame" || basename "${root}"
}

function hg_branch_name() {
    local root
    root="$(hg_root)" || return 1
    cat "${root}/.hg/branch" || hg branch
}

function hg_ps1_widget() {
    local root
    root="$(hg_root)" || return
    local branch
    branch="$(hg_branch_name)" || return
    local changes
    changes="$(hg status -mard 2> /dev/null | wc -l | tr -d ' ')"
    local hash
    hash="$(hg id -i 2> /dev/null)"
    echo -n "(hg ${branch}:${hash}"
    if [[ "${changes}" -ne "0" ]]; then
        echo -n "+${changes}"
    fi
    echo -n ") "
}


fi # _REDSHELL_HG
