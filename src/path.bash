# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# UNIX style path helpers.

source "screen.bash"
source "strings.bash"

if [[ -z "${_REDSHELL_PATH}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_PATH=1

# Usage: path_expand PATH
#
# Expands tilde, safely, in the path.
function path_expand() {
  local path
  local -a pathElements resultPathElements
  IFS=':' read -r -a pathElements <<<"$1"
  : "${pathElements[@]}"
  for path in "${pathElements[@]}"; do
    : "$path"
    case $path in
      "~+"/*)
        path=$PWD/${path#"~+/"}
        ;;
      "~-"/*)
        path=$OLDPWD/${path#"~-/"}
        ;;
      "~"/*)
        path=$HOME/${path#"~/"}
        ;;
      "~"*)
        username=${path%%/*}
        username=${username#"~"}
        IFS=: read -r _ _ _ _ _ homedir _ < <(getent passwd "$username")
        if [[ $path = */* ]]; then
          path=${homedir}/${path#*/}
        else
          path=$homedir
        fi
        ;;
    esac
    resultPathElements+=( "$path" )
  done
  local result
  printf -v result '%s:' "${resultPathElements[@]}"
  printf '%s\n' "${result%:}"
}

# Usage: path_resolve PATH
#
# Prints the absolute path of PATH, with any tilde interpolated.
function path_resolve() {
  local path="$(path_expand "${1}")"
  if [[ -d "${path}" ]]; then
    (cd "${path}" && pwd)
  else
    (cd "$(dirname "${path}")" && echo "$(pwd)/$(basename "${path}")")
  fi
}

# Usage: path_push DIRECTORY
#
# This is like pushd, except it also updates the name of the screen window to
# the new path, if run from inside a screen session.
function path_push() {
  local path="$(path_expand "${1}")"
  pushd "${1}" >/dev/null || return 1
  screen_reset_dirname
}

# Usage: path_pop
#
# This is like popd, except it also updates the name of the screen window to the
# new path, if run from inside a screen session.
function path_pop() {
  popd >/dev/null || return 1
  screen_reset_dirname
}


fi # _REDSHELL_PATH
