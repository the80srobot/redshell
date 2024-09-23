# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Fedora setup and package management.

if [[ -z "${_REDSHELL_FEDORA}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_FEDORA=1

function fedora_setup() {
    dnf_install_or_skip \
        git \
        rsync \
        pass \
        jq \
        ugrep
}

# Install a package with dnf if it's not already installed.
# Usage: dnf_install_or_skip package1 package2 ...
function dnf_install_or_skip() {
    local package
    local installed
    installed="$(dnf list --installed | cut -d" " -f1 | tail -n+2)"
    for package in "${@}"; do
        if echo "${installed}" | grep -q "${package}"; then
            echo "Package ${package} is already installed."
        elif [[ -n "${_REDSHELL_SKIP_INSTALL}" ]]; then
            echo "Skipping package ${package} installation."
        else
            echo "Installing package ${package}..."
            sudo dnf -y install "${package}"
        fi
    done
}

fi # _REDSHELL_FEDORA
