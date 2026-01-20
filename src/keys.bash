# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Key management utils using pass and gpg.
#
# All keys managed by this code are stored under the "Redshell/" folder in pass.
#
# We support two types of keys which are treated slightly differently:
# - .key: Typically larger secrets that are exported as files, e.g. SSH keys or
#   certificates. You should take care to periodically expire these when not
#   needed, or further protect them with passwords and file permissions.
# - .var keys: Small secrets used as ENV variables or arguments. They are not
#   cached as files during use.

source "compat.sh"

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
#
# If -f is given, forces regeneration of the file. The file is also regenerated
# if it exists but is empty.
#
# Caution: the file will persist until keys_flush is called, so be sure to
# manage its lifecycle appropriately.
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

    local _path="${home}/.redshell_keys/${1}.key"
    if [[ -n "${force}" ]]; then
        rm -f "${_path}"
    elif [[ -f "${_path}" && ! -s "${_path}" ]]; then
        rm -f "${_path}"
    fi
    if [[ -f "${_path}" ]]; then
        echo "${_path}"
        return 0
    fi

    mkdir -p "${home}/.redshell_keys"
    chmod 700 "${home}/.redshell_keys"
    mkdir -p "${home}/.redshell_keys/$(dirname "${1}")"
    pass "Redshell/${1}.key" > "${_path}"
    chmod 600 "${_path}"
    echo "${_path}"
}

# Usage: keys_var KEY [VALUE|--delete]
#
# Returns the conents of a given .var key in pass. If VALUE is provided, instead
# the value is stored in the key. If --delete is provided, the key is removed.
function keys_var() {

    if [[ -n "${2}" ]]; then
        if [[ "${2}" == "--delete" ]]; then
            pass rm "Redshell/${1}.var"
            return $?
        fi
        echo -n "${2}" | pass insert -m "Redshell/${1}.var"
        return $?
    fi
    pass "Redshell/${1}.var"
}

# Usage: keys_key KEY [VALUE|--delete]
#
# Returns the contents of a given .key key in pass. If VALUE is provided,
# instead the value is stored in the key. If --delete is provided, the key is
# removed.
function keys_key() {

    if [[ -n "${2}" ]]; then
        if [[ "${2}" == "--delete" ]]; then
            pass rm "Redshell/${1}.key"
            return $?
        fi
        echo -n "${2}" | pass insert -m "Redshell/${1}.key"
        return $?
    fi
    pass "Redshell/${1}.key"
}

# Usage: keys_flush
#
# Removes all cached key files.
function keys_flush() {

    local home="${REAL_HOME}"
    if [[ -z "${home}" ]]; then
        home="${HOME}"
    fi

    rm -rf "${home}/.redshell_keys"
}

# Usage: keys_sync
#
# Pulls the latest changes from the keys git repository and pushes any local
# changes.
function keys_sync() {

    keys_git pull --rebase
    keys_git push
}

fi # _REDSHELL_KEYS
