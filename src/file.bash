# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# File helpers.

source "compat.sh"

if [[ -z "${_REDSHELL_FILE}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_FILE=1

# Usage: file_mktemp [TITLE]
#
# Cross-platform version of mktemp across BSD and GNU. Creates a temp file and
# prints its path. If TITLE is supplied, it will be used as prefix or suffix.
function file_mktemp() {

    if [[ "$(uname)" == "Darwin" ]]; then
        mktemp -t "${1}"
    else
        mktemp --suffix="${1}"
    fi
}

# Usage: file_mtime [-g] PATH
#
# Returns the modification time of PATH in "YYYY-MM-DD HH:MM:SS" format.
#
# Options:
#
#   -g    Use git to get the last modified time if the file is tracked.
function file_mtime() {

    local use_git
    local use_utc
    while [[ "$1" == -* ]]; do
        case "$1" in
            -g)
                use_git=1
                ;;
            *)
                break
                ;;
        esac
        shift
    done

    local _path="${1}"

    # Return empty if path is empty or doesn't exist
    if [[ -z "${_path}" || ! -e "${_path}" ]]; then
        return 1
    fi

    local d
    # These two formats have to match
    [[ ! -z "${use_git}" ]] && d=`git log -1 --pretty="%ad" --date=format:"%Y-%m-%d %H:%M:%S" -- "${_path}" 2>/dev/null`
    if [[ -z "${d}" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            d="$(date -r "${_path}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)"
        else
            d="$(date -d "@$(stat -c %Y "${_path}")" "+%Y-%m-%d %H:%M:%S" 2>/dev/null)"
        fi
    fi

    # Return error if date is still empty
    if [[ -z "${d}" ]]; then
        return 1
    fi

    echo "${d}"
}

# Usage: file_age [-s] PATH
function file_age() {

    # TODO: add a getopts to enable -g in file_mtime.
    if [[ "${1}" == "-s" ]]; then
        shift
        local format="seconds"
    fi

    local _path="${1}"
    local d
    d=`file_mtime "${_path}"` || return 1

    # Return error if date is empty
    if [[ -z "${d}" ]]; then
        return 1
    fi

    local now=`date +%s`
    local ds
    if [[ "$(uname)" == "Darwin" ]]; then
        ds=`date -j -f "%Y-%m-%d %H:%M:%S" "${d}" +%s 2>/dev/null` || return 1
    else
        ds=`date -d "${d}" +%s 2>/dev/null` || return 1
    fi

    if [[ -z "${ds}" ]]; then
        return 1
    fi

    local age_seconds=$(( now - ds ))

    if [[ "${format}" == "seconds" ]]; then
        echo "${age_seconds}"
        return 0
    fi

    if (( age_seconds < 60 )); then
        echo "${age_seconds} s"
    elif (( age_seconds < 3600 )); then
        echo "$(( age_seconds / 60 )) m"
    elif (( age_seconds < 86400 )); then
        echo "$(( age_seconds / 3600 )) h"
    else
        echo "$(( age_seconds / 86400 )) d"
    fi
}

fi # _REDSHELL_FILE
