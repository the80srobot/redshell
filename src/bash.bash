# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Parse bash files and automate bash scripting.

if [[ -z "${_REDSHELL_BASH}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_BASH=1

function get_bash_functions() {
    python_func -p ~/.redshell/src/bash_parser/functions.py get_bash_functions "$@"
}

fi # _REDSHELL_BASH
