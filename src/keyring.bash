# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_KEYRING}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_KEYRING=1

function keys_priv_path() {
    # TODO: This is terrible, but I only have 5 minutes right now.
    echo "${REAL_HOME}/.redshell_keys/${1}.key"
}

fi # _REDSHELL_KEYRING
