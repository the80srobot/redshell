# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Debian setup and package management.

if [[ -z "${_REDSHELL_DEBIAN}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_DEBIAN=1

function debian_setup() {
    sudo apt-get update
    debian_install_or_skip \
        python3-venv \
        jq \
        pass \
        git \
        rsync \
        python3-pip \
        ugrep
}


function debian_install_or_skip() {
    local package
    local installed
    installed="$(dpkg-query -W -f='${Status}\t${Package}\n' | grep -v deinstall)"
    for package in "${@}"; do
        if echo "${installed}" | grep -q "${package}"; then
            echo "Package ${package} is already installed."
        else
            echo "Installing package ${package}..."
            sudo apt-get -y install "${package}"
        fi
    done
}

fi # _REDSHELL_DEBIAN
