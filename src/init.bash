# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_INIT}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_INIT=1

alias l='ls -lh'
alias la='ls -lha'

# Set the editor to vim by default, vscode if available.
EDITOR=`which vim`
export EDITOR

if [[ `uname -a` == *Darwin* ]]
then
    function e() {
        if which open && [[ -d /Applications/Visual\ Studio\ Code.app/ ]]; then
            open -a "visual studio code" "${@}"
        else
            "${EDITOR}" "${@}"
        fi
    }

    alias o='open .'

    function wget() {
        if which wget; then
            "$(which wget)" "${@}"
        else
            curl -O --retry 999 --retry-max-time 0 -C - "${@}"
        fi
    }
    function nproc() {
        sysctl -n hw.logicalcpu
    }
    PATH=/opt/local/bin:$HOME/go/bin:$PATH
else
    function e() {
        "${EDITOR}" "${@}"
    }
fi

if [[ `uname -a` == *debian* ]]
then
    PATH=/usr/sbin:/sbin:$PATH
fi

fi # _REDSHELL_INIT
