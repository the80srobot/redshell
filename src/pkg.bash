# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

source "mac.bash"

if [[ -z "${_REDSHELL_PKG}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_PKG=1

function pkg_install_or_skip() {
    if which brew > /dev/null; then
        brew_install_or_skip "${@}"
    elif which apt-get > /dev/null; then
        # TODO(adam): Actually implement this.
        apt_install_or_skip "${@}"
    elif which dnf > /dev/null; then
        dnf_install_or_skip "${@}"
    else
        echo "No package manager found." >&2
    fi
}

fi # _REDSHELL_PKG
