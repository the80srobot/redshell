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

fi # _REDSHELL_FILE