# # SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# IMDB (and actually open movie database) helpers for bash.

source "crypt.bash"
source "keys.bash"

if [[ -z "${_REDSHELL_OMDB}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_OMDB=1

function __omdb_key_path() {
    keys_path omdb
}

# Usage: omdb_set_key KEY
function omdb_set_key() {
    local key="${1}"
    echo "${key}" > "$(__omdb_key_path)"
}

# Usage: omdb_register_key
function omdb_register_key() {
    echo "Register at http://www.omdbapi.com/apikey.aspx to get an API key."
    echo "Enter your API key:"
    read -r key
    omdb_set_key "${key}"
}

# Usage: omdb_get_key
function omdb_get_key() {
    if [[ -f "$(__omdb_key_path)" ]]; then
        cat "$(__omdb_key_path)"
    else
        echo "No API key set. Use omdb_register_key to set one." >&2
        return 1
    fi
}

function __omdb_query_string() {
    local key
    key="$(omdb_get_key)" || return 1
    local q="http://www.omdbapi.com/?apikey=${key}"

    while [[ "${#}" -gt 0 ]]; do
        # Each param is a key=value pair.
        local key="${1%%=*}"
        local value="${1#*=}"
        q="${q}&${key}=$(strings_urlencode "${value}")"
        shift
    done


    echo "${q}"
}

# Usage: omdb_query [-f] [QUERY ...]
#
# Query the OMDB API with the given query. Prints JSON to stdout. Results are
# cached. Use -f to force a fresh query.
#
# The query consists of a series of PARAMETER=QUERY pairs. Valid parameters are
# documented at http://www.omdbapi.com.
#
# Examples:
#   q omdb query "t=The Matrix"
#   q omdb query "i=tt0133093"
#
# Useful parameters include:
#
# - t: Title of the movie.
# - i: IMDB ID of the movie.
function omdb_query() {
    local force
    if [[ "${1}" == "-f" ]]; then
        force=1
        shift
    fi

    local q
    q="$(__omdb_query_string "${@}")" || return 1
    local h="$(crypt_hash md5  "${q}")"
    local cache_path="${REAL_HOME}/.redshell_omdb_cache/"
    mkdir -p "${cache_path}"
    local cache_file="${cache_path}/${h}.json"
    if [[ ! -f "${cache_file}" || -n "${force}" ]]; then
        curl "${q}" > "${cache_file}" || return 1
    fi
    cat "${cache_file}"
}

# Usage: omdb_guess_title FILE
#
# Guess the title of the movie based on the filename.
function omdb_guess_title() {
    local input="${1}"
    local base="$(basename "${input}")"
    base="${base%.*}"
    {
        perl -pe 's/[\._]/ /g' \
        | perl -pe 's/^\s*((?:[^ ]+ )+?)((19|20)\d{2}|1080|blu-?ray|web-?dl).*$/\1/i' \
        | perl -pe 's/ *$//g'
    } <<< " ${base} "
}

fi # _REDSHELL_OMDB
