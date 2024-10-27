# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Time and date helpers.

if [[ -z "${_REDSHELL_TIME}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_TIME=1

# List all time zones.
# Usage: time_zones
function time_zones() {
    find -L /usr/share/zoneinfo -depth 2 -type f -exec file {} \+ \
        | grep 'timezone data' \
        | perl -pe 's/.*\/zoneinfo\/(.*?):.*$/\1/' \
        | sort
}

TIME_ZONE_ALIASES="
CET:Europe/Paris
CEST:Europe/Paris
CST:America/Chicago
CDT:America/Chicago
Central:America/Chicago
EST:America/New_York
EDT:America/New_York
NYC:America/New_York
Eastern:America/New_York
PST:America/Los_Angeles
PDT:America/Los_Angeles
Pacific:America/Chicago
America/San Francisco:America/Los_Angeles
Asia/Bangalore:Asia/Kolkata
Asia/New Delhi:Asia/Kolkata
Asia/Mumbai:Asia/Kolkata
Asia/Chennai:Asia/Kolkata
Asia/Beijing:Asia/Shanghai
Asia/Guangzhou:Asia/Shanghai
"

# Translates a time zone alias to a canonical time zone name.
# Uses ug for fuzzy string matching.
function __time_get_tz_alias() {
    local alias="${1}"
    local keys
    local values
    local tmp="$(mktemp)"

    cut -d: -f1 <<< "${TIME_ZONE_ALIASES[*]}" > "${tmp}"
    values="$(cut -d: -f2 <<<"${TIME_ZONE_ALIASES[*]}"))"
    # Find the index, if any, of the alias in the keys.
    local i
    i=$(ug -n -i --fuzzy=best1 "${alias}" "${tmp}" | cut -d: -f1)
    rm -f "${tmp}"

    [[ -z "${i}" ]] && return 1
    tail -n "+${i}" <<<"${values}" | head -n 1
}

function __time_get_tz() {
    local input="${*}"
    local query
    query="$(__time_get_tz_alias "${input}")" || query="${input}"
    local tmp=$(mktemp)
    time_zones > "${tmp}"
    ug -iw --fuzzy=best1 "${query}" "${tmp}"
}

function time_get_tz() {
    local lines
    local c
    local tz="$(strings_trim "${*}")"
    lines=$(__time_get_tz "${tz}")
    [[ -z "${lines}" ]] && {
        >&2 echo "No time zone found for '${tz}'"
        return 1
    }
    c=$(wc -l <<<"${lines}")
    (( c == 1 )) && echo "${lines}" && return
    >&2 echo "Ambiguous entry: multiple time zones match '${tz}'"
    return 2
}

function time_local() {
    date "${@}"
}

function time_utc() {
    TZ=UTC date "${@}"
}

# Usage time_in TIMEZONE [FORMAT]
function time_in() {
    local tz
    local tz_match
    local fmt
    while [[ "${#}" -gt 0 ]]; do
        # Until $1 starts with + or is equal to --, it's part of the timezone.
        if [[ "${1}" == +* || "${1}" == -- ]]; then
            break
        fi
        tz="${tz} ${1}"
        shift
    done
    [[ -z "${tz}" ]] && return 254
    tz_match=$(time_get_tz "${tz}") || return $?
    TZ="${tz_match}" date "${@}"
}

function time_tz_diff() {
    local tz1
    local tz2
    if [[ "${#}" == 2 ]]; then
        tz1="${1}"
        tz2="${2}"
    else
        while [[ "${#}" -gt 0 ]]; do
            if [[ "${1}" == -- ]]; then
                shift
                tz2="${*}"
                break
            fi
            tz1="${tz1} ${1}"
            shift
        done
    fi
    [[ -z "${tz1}" || -z "${tz2}" ]] && return 254

    local offset1
    local offset2
    offset1="$(time_in "${1}" +%z)" || return $?
    offset2="$(time_in "${2}" +%z)" || return $?
    
    local hours1="$(cut -c1-3 <<<"${offset1}" | perl -pe 's/0(\d)/\1/')"
    local hours2="$(cut -c1-3 <<<"${offset2}" | perl -pe 's/0(\d)/\1/')"
    local mins1="$(cut -c4-5 <<<"${offset1}")"
    local mins2="$(cut -c4-5 <<<"${offset2}")"
    local secs1="$((hours1 * 3600 + mins1 * 60))"
    local secs2="$((hours2 * 3600 + mins2 * 60))"
    
    local dir="ahead of"
    local diff="$((secs1 - secs2))"
    local real_diff="${diff}"
    if [[ "${diff}" -lt 0 ]]; then
        dir="behind"
        diff="$((secs2 - secs1))"
    fi
    >&2 echo "$(time_get_tz "${tz1}") is ${dir} $(time_get_tz "${tz2}") by:"
    printf "%02d:%02d hours\t(%d seconds)\n" $(( diff / 3600 )) $(( (diff % 3600) / 60 )) "${real_diff}"
}

fi # _REDSHELL_TIME
