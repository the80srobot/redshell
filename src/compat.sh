# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Shell compatibility layer for bash/zsh portability.
# This file must be sourced before all other modules.
# It uses .sh extension because it is valid in both shells.

if [[ -n "${ZSH_VERSION:-}" ]]; then
    _REDSHELL_ZSH=1
    _REDSHELL_READ_ARRAY_FLAG="-A"
else
    _REDSHELL_ZSH=""
    _REDSHELL_READ_ARRAY_FLAG="-a"
fi

# Portable printf -v replacement.
# In bash, printf -v works natively. In zsh under emulate -L ksh it may not,
# so we provide a shim.
if [[ -n "${_REDSHELL_ZSH}" ]]; then
    _printf_v() {
        local _var="$1"
        local _fmt="$2"
        shift 2
        eval "$_var=\$(printf \"\$_fmt\" \"\$@\")"
    }
else
    _printf_v() {
        printf -v "$@"
    }
fi
