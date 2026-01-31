# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# UNIX style path helpers.

source "compat.sh"
source "screen.bash"
source "strings.bash"

if [[ -z "${_REDSHELL_PATH}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_PATH=1

# Usage: path_expand PATH
#
# Expands tilde, safely, in the path.
function path_expand() {
  [[ -n "${_REDSHELL_ZSH}" ]] && emulate -L ksh
  local _p
  local -a pathElements resultPathElements
  IFS=':' read -r ${_REDSHELL_READ_ARRAY_FLAG} pathElements <<<"$1"
  : "${pathElements[@]}"
  for _p in "${pathElements[@]}"; do
    : "$_p"
    case $_p in
      "~+"/*)
        _p=$PWD/${_p#"~+/"}
        ;;
      "~-"/*)
        _p=$OLDPWD/${_p#"~-/"}
        ;;
      "~"/*)
        _p=$HOME/${_p#"~/"}
        ;;
      "~"*)
        username=${_p%%/*}
        username=${username#"~"}
        IFS=: read -r _ _ _ _ _ homedir _ < <(getent passwd "$username")
        if [[ $_p = */* ]]; then
          _p=${homedir}/${_p#*/}
        else
          _p=$homedir
        fi
        ;;
    esac
    resultPathElements+=( "$_p" )
  done
  local result
  _printf_v result '%s:' "${resultPathElements[@]}"
  printf '%s\n' "${result%:}"
}

# Usage: path_resolve PATH
#
# Prints the absolute path of PATH, with any tilde interpolated.
function path_resolve() {
  local _p="$(path_expand "${1}")"
  if [[ -d "${_p}" ]]; then
    (cd "${_p}" && pwd)
  else
    (cd "$(dirname "${_p}")" && echo "$(pwd)/$(basename "${_p}")")
  fi
}

# Usage: path_push DIRECTORY
#
# This is like pushd, except it also updates the name of the screen window to
# the new path, if run from inside a screen session.
function path_push() {
  local _p="$(path_expand "${1}")"
  pushd "${_p}" >/dev/null || return 1
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
