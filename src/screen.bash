# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Manage screen sessions.

source "strings.bash"

if [[ -z "${_REDSHELL_SCREEN}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_SCREEN=1

function screen_session() {
    echo "${STY}" | cut -d'.' -f2
}

function screen_window() {
    echo "${WINDOW}"
}

function screen_rename() {
    local newname="$1"
    screen -x "${STY}" -p "${WINDOW}" -X title "${newname}"
}

function screen_home() {
    local tmp="$(mktemp)"
    local tmp_bin="$(mktemp)"
    chmod +x "${tmp_bin}"
    echo "pwd > ${tmp}" > "${tmp_bin}"
    screen -x "${STY}" -X exec "${tmp_bin}"

    while true; do
        local c="$(cat "${tmp}" | wc -c)"
        if [[ "${c}" -gt 1 ]]; then
            break
        fi
        sleep 1
    done
    cat "${tmp}"
}

function screen_reset_dirname() {
    [[ -z "${WINDOW}" ]] && return 0
    local name="$(strings_strip_prefix "$(screen_home)/" "$(pwd)")"
    screen_rename "${name}"
}

fi # _REDSHELL_SCREEN
