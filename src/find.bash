# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Shorthands for find and grep.

if [[ -z "${_REDSHELL_FIND}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_FIND=1

# Shorthand for find
function f() {
    find . -iname "*${1}*"
}


function __f_args() {
    local dir
    local switch
    local needle
    case "${#}" in
        0) return 1;;
        1)
            dir="."
            switch="-F"
            needle="${1}"
        ;;
        2)
            dir="${1}"
            switch="-F"
            needle="${2}"
        ;;
        3)
            dir="${1}"
            switch="${2}"
            needle="${3}"
        ;;
        *) return 2 ;;
    esac
    echo -e "${dir}\t${switch}\t${needle}"
}

function fcc() {
    IFS=$'\t' read -r -a args <<< "$(__f_args "${@}")"
    find "${args[0]}" \
        -iname "*.c" -or -iname "*.h" -or -iname "*.cc" -or -iname "*.h" -or -iname "*.cpp" \
        -exec grep --color -B 2 -A 4 "${args[1]}" "${args[2]}" {} \+
}

function fgo() {
    IFS=$'\t' read -r -a args <<< "$(__f_args "${@}")"
    find "${args[0]}" \
        -iname "*.go" \
        -exec grep --color -B 2 -A 4 "${args[1]}" "${args[2]}" {} \+
}

function fjava() {
    IFS=$'\t' read -r -a args <<< "$(__f_args "${@}")"
    find "${args[0]}" \
        -iname "*.java" -or -iname "*.kt" \
        -exec grep --color -B 2 -A 4 "${args[1]}" "${args[2]}" {} \+
}

function faidl() {
    IFS=$'\t' read -r -a args <<< "$(__f_args "${@}")"
    find "${args[0]}" \
        -iname "*.aidl" \
        -exec grep --color -B 2 -A 4 "${args[1]}" "${args[2]}" {} \+
}

function fd() {
    local needle="$1"
    local path
    path="$(find "." -ipath "*${1}*" | head -1)"
    [[ -n "${path}" ]] && pushd "$(dirname "${path}")"
}

fi # _REDSHELL_FIND
