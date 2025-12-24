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
        ugrep \
        gh \
        vim \
        ripgrep \
        bc \
        ed \
        psmisc \
        htop
    
    echo "Claude code..."
    which claude || { curl -fsSL https://claude.ai/install.sh | bash ; }
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

function debian_install_imgcat() {
    curl -L https://iterm2.com/utilities/imgcat -o ~/bin/imgcat
    chmod +x ~/bin/imgcat
}

function debian_setup_mc() {
    sudo apt-get -y install mc
    debian_install_imgcat
    local ini_path="${HOME}/.config/mc/mc.ext.ini"
    mkdir -p "$(dirname "${ini_path}")"
    touch "${ini_path}"
    reinstall_file "${REDSHELL_ROOT}/rc/mc.ext.ini" "${ini_path}"
}

fi # _REDSHELL_DEBIAN
