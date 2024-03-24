# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_KEYRING}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_KEYRING=1

function keys_git() {
    GIT_SSH_COMMAND="ssh -i ~/.redshell_pass_git.key" pass git "${@}"
}

function keys_path() {
    local path="${REAL_HOME}/.redshell_keys/${1}.key"
    if [[ -f "${path}" ]]; then
        echo "${path}"
        return 0
    fi

    mkdir -p "${REAL_HOME}/.redshell_keys"
    chmod 700 "${REAL_HOME}/.redshell_keys"
    mkdir -p "${REAL_HOME}/.redshell_keys/$(dirname "${1}")"
    pass "Redshell/${1}.key" > "${path}"
    chmod 600 "${path}"
    echo "${path}"
}

function keys_var() {
    pass "Redshell/${1}.var"
}

fi # _REDSHELL_KEYRING
