# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Install a file into another file, optionally with a keyword.

if [[ -z "${_REDSHELL_INSTALL}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_INSTALL=1

function reinstall_file() {
    uninstall_file "${2}" "${3}" "${4}"
    install_file "${@}"
}

function install_file() {
    mkdir -p `dirname "$2"`

    if [[ -z "$3" ]]; then
        q="###"
    else
        q="${3}"
    fi
    
    if [[ -z "$4" ]]; then
        kw="REDSHELL"
    else
        kw="$4"
    fi

    echo "${q} ${kw} ###" >> "$2"
    cat "$1" >> "$2"
    echo "" >> "$2"
    echo "${q} /${kw} ###" >> "$2"
}

function uninstall_file() {
    if [[ -z "$2" ]]; then
        q="###"
    else
        q="${2}"
    fi
    if [[ -z "$3" ]]; then
        kw="REDSHELL"
    else
        kw="$3"
    fi
    sed -i.bak "/${q} ${kw} ###/,/${q} \/${kw} ###/d" "$1" 2> /dev/null || true
}

fi # _REDSHELL_INSTALL
