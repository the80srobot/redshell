# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# String helpers for bash and zsh.

source "compat.sh"
source "go.bash"

if [[ -z "${_REDSHELL_STRINGS}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_STRINGS=1

# Usage strings_urlencode STRING
#
# URL-encodes a string. DO NOT USE with curl: prefer --data-urlencode.
function strings_urlencode() {

    jq -rn --arg x "${1}" '$x|@uri'
}

# Usage: strings_strip_control
#
# Strips terminal escape sequences from standard input.
function strings_strip_control() {

    # The sed call strips escape characters from the string. The
    # additional perl one-liner deletes the literal ^(B which `tput
    # sgr0` outputs on some systems for unknown reasons. (It's not in
    # the standard, so WTF?)
    sed "s,$(printf '\033')\\[[0-9;]*[a-zA-Z],,g" \
    | perl -pe 's/\033\(B//g'
}

# Usage: strings_repeat STRING N
#
# Prints STRING N times.
function strings_repeat() {

    local c="${1}"
    local n="${2}"
    for (( i=0; i < n; i++ )); do
        echo -n "${c}"
    done
}

# Usage: strings_join DELIMITER [STRING ...]
function strings_join() {

    local d=${1-} f=${2-}
    if shift 2; then
      printf %s "$f" "${@/#/$d}"
    fi
}

# Usage: strings_sgrep [-C NUM]
function strings_sgrep() {

    go_pkg_do https://github.com/arunsupe/semantic-grep go run w2vgrep.go -- "${@}"
}

alias sgrep=strings_sgrep

# Usage: strings_strip_prefix PREFIX STRING
#
# Strips the prefix from the string if it's there.
function strings_strip_prefix() {

    local prefix="${1}"
    local string="${2}"

    if [[ "${string}" != "${prefix}"* ]]; then
        echo "${string}"
        return 1
    fi

    echo "${string#${prefix}}"
}

# Usage: strings_trim STRING
#
# Strips leading and trailing whitespace from a string.
function strings_trim() {

    local var="$*"
    [[ -z "${var}" ]] && var="$(cat)"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Usage: strings_elide TEXT LIMIT [COLOR]
#
# Elides TEXT to LIMIT characters, inserting "(...)" in the middle if needed.
# If COLOR is provided, it will be used to color the ellipsis.
function strings_elide() {

    local text="${1}"
    local lim="${2}"
    local color="${3}"
    if [[ -n "${color}" ]]; then
        local rst="\033[0m"
    else
        local rst=""
    fi
    local l="${#text}"
    if [[ "${l}" -gt "${lim}" ]]; then
        local llen=$(( lim - 25 ))
        echo "${text:0:$llen}${color}(...)${rst}${text: -20}"
    else
        echo "${text}"
    fi
}

# Usage: strings_strip_prefix PREFIX STRING
#
# Strips the prefix from the string if it's there.
function strings_strip_prefix() {

    local prefix="${1}"
    local string="${2}"

    if [[ "${string}" != "${prefix}"* ]]; then
        echo "${string}"
        return 1
    fi

    echo "${string#${prefix}}"
}

fi # _REDSHELL_STRINGS
