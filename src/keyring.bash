# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_KEYRING}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_KEYRING=1

function keys_git() {
    GIT_SSH_COMMAND="ssh -i ~/.redshell_pass_git.key" pass git "${@}"
}

function keys_path() {
    mkdir -p "${REAL_HOME}/.redshell_keys"
    chmod 700 "${REAL_HOME}/.redshell_keys"
    pass "Redshell/${1}.key" > "${REAL_HOME}/.redshell_keys/${1}.key"
    chmod 600 "${REAL_HOME}/.redshell_keys/${1}.key"
    echo "${REAL_HOME}/.redshell_keys/${1}.key"
}

fi # _REDSHELL_KEYRING
