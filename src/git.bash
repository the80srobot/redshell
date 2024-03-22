# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_GIT}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_GIT=1

function mkproject() {
    gh repo create "${1}" --private --add-readme --clone
}

fi # _REDSHELL_GIT
