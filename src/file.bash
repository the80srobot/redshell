# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# File helpers.

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

function file_mtime() {
    if [[ "${1}" == "-g" ]]; then
        shift
        local use_git="use_git"
    fi

    local path="${1}"
    local d
    # These two formats have to match
    [[ ! -z "${use_git}" ]] && d=`git log -1 --pretty="%ad" --date=format:"%Y-%m-%d %H:%M:%S" -- "${path}" 2>/dev/null`
    if [[ -z "${d}" ]]; then
        if [[ "$(uname)" == "Darwin" ]]; then
            d=`date -r "${path}" "+%Y-%m-%d %H:%M:%S"`
        else
            # GNU stat to get modification time
            d=`date -d "@$(stat -c %Y "${path}")" "+%Y-%m-%d %H:%M:%S"`
        fi
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

    local path="${1}"
    local d=`file_mtime "${path}"`
    local now=`date +%s`
    if [[ "$(uname)" == "Darwin" ]]; then
        local ds=`date -j -f "%Y-%m-%d %H:%M:%S" "${d}" +%s`
    else
        local ds=`date -d "${d}" +%s`
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