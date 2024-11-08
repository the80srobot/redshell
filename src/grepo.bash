# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Automate grepo (aosp repo tool) operations.

if [[ -z "${_REDSHELL_GREPO}" || -n "${_REDSHELL_RELOAD}" ]]; then
_GREPO_GREPO=1

function grepo_checkout() {
    local branch="${1}"
    repo forall -c "git branch | grep -q "${branch}" && pwd && git checkout ${branch}" || true
}

function grepo_lfs_pull() {
    repo forall -c 'pwd ; git lfs pull'
}

function grepo_remove_branch() {
    local branch="${1}"
    repo forall -c "git branch | grep -q "${branch}" && pwd && repo sync . -d && git branch -D ${branch}" || true
}

fi # _REDSHELL_GREPO
