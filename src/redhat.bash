# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Red Hat family (RHEL, Fedora, Rocky, Alma, CentOS) setup and package management.

if [[ -z "${_REDSHELL_REDHAT}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_REDHAT=1

source ai.bash

# Run the full Red Hat family setup (configs + packages).
# Respects REDSHELL_CONFIG_ONLY environment variable.
# Usage: redhat_setup
function redhat_setup() {
    redhat_setup_config
    if [[ -z "${REDSHELL_CONFIG_ONLY}" ]]; then
        redhat_install_packages
    else
        >&2 echo "Skipping package installation (config-only mode)."
        >&2 echo "Run 'setup.sh --install-packages' to install packages later."
    fi
}

# Install Red Hat config settings (no packages).
# Usage: redhat_setup_config
function redhat_setup_config() {
    ai_install_claude_config
}

# Install Red Hat packages.
# Can be run independently after config-only setup.
# Usage: redhat_install_packages
function redhat_install_packages() {
    sudo dnf install epel-release -y || true
    dnf_install_or_skip \
        python3-pip \
        jq \
        pass \
        git \
        rsync \
        gh \
        vim \
        ripgrep \
        bc \
        ed \
        psmisc \
        htop

    echo "Claude code..."
    which claude || { curl -fsSL https://claude.ai/install.sh | bash ; }
    ai_install_claude_config
}

# Install a package with dnf if it's not already installed.
# Usage: dnf_install_or_skip PACKAGE...
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

function redhat_install_imgcat() {
    curl -L https://iterm2.com/utilities/imgcat -o ~/bin/imgcat
    chmod +x ~/bin/imgcat
}

function redhat_setup_mc() {
    sudo dnf -y install mc
    redhat_install_imgcat
    local ini_path="${HOME}/.config/mc/mc.ext.ini"
    mkdir -p "$(dirname "${ini_path}")"
    touch "${ini_path}"
    reinstall_file "${REDSHELL_ROOT}/rc/mc.ext.ini" "${ini_path}"
}

fi # _REDSHELL_REDHAT
