# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_CRYPT}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_CRYPT=1

function encrypt_symmetric() {
    tar -czf "$1.tgz" "$1"
    gpg --symmetric --output "$1.tgz.gpg" "$1.tgz"
    rm -rf "$1"
    rm -f "$1.tgz"
    echo "$1 -> ${$1}.tgz.gpg"
}

function decrypt_symmetric() {
    gpg --decrypt --output "$1.tgz" "$1"
    tar -xzf "$1.tgz"
    rm -f "$1"
    rm -f "$1.tgz"
    echo "$1 -> $(basename "$1" .tgz.gpg)"
}

fi # _REDSHELL_CRYPT
