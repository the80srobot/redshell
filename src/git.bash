# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_GIT}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_GIT=1

function mkproject() {
    gh repo create "${1}" --private --add-readme --clone
}

function git-ssh-init() {
    local remote="$1"
    local path="$2"
    local ssh="${GIT_SSH_COMMAND}"
    [[ -z "${ssh}" ]] && ssh="ssh"
    "${ssh}" "${remote}" "mkdir -p ${path} && cd ${path} && git init --bare"
    git remote add origin "${remote}:${path}"
    git push origin master
}

fi # _REDSHELL_GIT
