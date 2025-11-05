# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Key management utils using pass and gpg.

if [[ -z "${_REDSHELL_KEYS}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_KEYS=1

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

    local home="${REAL_HOME}"
    if [[ -z "${home}" ]]; then
        home="${HOME}"
    fi

    local path="${home}/.redshell_keys/${1}.key"
    if [[ -n "${force}" ]]; then
        rm -f "${path}"
    fi
    if [[ -f "${path}" ]]; then
        echo "${path}"
        return 0
    fi

    mkdir -p "${home}/.redshell_keys"
    chmod 700 "${home}/.redshell_keys"
    mkdir -p "${home}/.redshell_keys/$(dirname "${1}")"
    pass "Redshell/${1}.key" > "${path}"
    chmod 600 "${path}"
    echo "${path}"
}

# Usage: keys_var KEY
#
# Returns the conents of a given .var key in pass.
function keys_var() {
    pass "Redshell/${1}.var"
}

# Usage: keys_key KEY
#
# Returns the contents of a given .key key in pass.
function keys_key() {
    pass "Redshell/${1}.key"
}

fi # _REDSHELL_KEYS
