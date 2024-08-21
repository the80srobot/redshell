# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# String helpers for bash.

source "go.bash"

if [[ -z "${_REDSHELL_STRINGS}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_STRINGS=1

# Usage: strip_control
# Strips terminal escape sequences from standard input.
function strip_control() {
    # The sed call strips escape characters from the string. The
    # additional perl one-liner deletes the literal ^(B which `tput
    # sgr0` outputs on some systems for unknown reasons. (It's not in
    # the standard, so WTF?)
    sed "s,$(printf '\033')\\[[0-9;]*[a-zA-Z],,g" \
    | perl -pe 's/\033\(B//g'
}

# Usage: repeat STRING N
# Prints STRING N times.
function repeat() {
    local c="${1}"
    local n="${2}"
    for (( i=0; i < n; i++ )); do
        echo -n "${c}"
    done
}

# Usage: strings_join DELIMITER [STRING ...]
function strings_join {
  local d=${1-} f=${2-}
  if shift 2; then
    printf %s "$f" "${@/#/$d}"
  fi
}

# Usage: sgrep [-C NUM]
function sgrep() {
  # https://github.com/arunsupe/semantic-grep
  # go_pkg_do
  echo TODO
  return 1
}

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
