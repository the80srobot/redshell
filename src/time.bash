# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_TIME}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_TIME=1

function file_mtime() {
    if [[ "${1}" == "-g" ]]; then
        shift
        local use_git="use_git"
    fi

    local path="${1}"
    local d
    # These two formats have to match
    [[ ! -z "${use_git}" ]] && d=`git log -1 --pretty="%ad" --date=format:"%Y-%m-%d %H:%M:%S" -- "${path}" 2>/dev/null`
    [[ -z "${d}" ]] && d=`date -r "${path}" "+%Y-%m-%d %H:%M:%S"`
    echo "${d}"
}

function file_age() {
    # TODO: Check Linux support
    # TODO: add a getopts to enable -g in file_mtime.
    if [[ "${1}" == "-s" ]]; then
        shift
        local format="seconds"
    fi

    local path="${1}"
    local d=`file_mtime "${path}"`
    local now=`date +%s`
    local ds=`date -j -f "%Y-%m-%d %H:%M:%S" "${d}" +%s`
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

fi # _REDSHELL_TIME
