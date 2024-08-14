# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Password manager based on pass and gpg.

if [[ -z "${_REDSHELL_KEYRING}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_KEYRING=1

# Wraps git for use with the keys repository.
#
# Usage: keys_git [ARGS ...]
function keys_git() {
    GIT_SSH_COMMAND="ssh -i ~/.redshell_pass_git.key" pass git "${@}"
}

# Usage: keys_path [-f] KEY
#
# Dumps the contents of the given key in a file and returns the path.
function keys_path() {
    local force
    if [[ "$1" == "-f" ]]; then
        force=1
        shift
    fi

    local path="${REAL_HOME}/.redshell_keys/${1}.key"
    if [[ -n "${force}" ]]; then
        rm -f "${path}"
    fi
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

# Usage: keys_var KEY
#
# Returns the conents of a given key in pass.
function keys_var() {
    pass "Redshell/${1}.var"
}

fi # _REDSHELL_KEYRING
