# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Cross-platform package management.

source "compat.sh"
source "mac.bash"

if [[ -z "${_REDSHELL_PKG}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_PKG=1

# Install packages using the system package manager, or skip, if the package is
# already installed.
#
# USAGE: pkg_install_or_skip [PACKAGE...]
function pkg_install_or_skip() {

    if which brew > /dev/null; then
        brew_install_or_skip "${@}"
    elif which apt-get > /dev/null; then
        debian_install_or_skip "${@}"
    elif which dnf > /dev/null; then
        dnf_install_or_skip "${@}"
    else
        echo "No package manager found." >&2
    fi
}

fi # _REDSHELL_PKG
