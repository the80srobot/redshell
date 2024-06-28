# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_MAC}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_MAC=1

function mac_setup() {
    mac_switch_to_bash
    mac_install_devtools
}

function brew() {
    which brew > /dev/null || {
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> ~/.bash_profile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    }
    "$(which brew)" "${@}"
}

function mac_get_user_shell() {
    dscl . -read /Users/"$(whoami)" UserShell | awk '{print $2}'
}

function mac_brew_bash_path() {
    echo "/opt/homebrew/bin/bash"
}

function mac_switch_to_bash() {
    local user_shell
    local brew_bash_path
    user_shell=$(mac_get_user_shell)
    brew_bash_path=$(mac_brew_bash_path)
    if [[ "${user_shell}" != "${brew_bash_path}" ]]; then
        echo "Switching to Homebrew-installed bash."
        brew install bash
        sudo grep "${brew_bash_path}" -q /etc/shells || sudo bash -c "echo ${brew_bash_path} >> /etc/shells"
        chsh -s "$(which bash)"
    else
        echo "Already using Homebrew-installed bash."
    fi
}

function icloud() {
    pushd ${HOME}'/Library/Mobile Documents/com~apple~CloudDocs'
}

function icloud_evict() {
    brctl evict "$1"
}

function brew_install_or_skip() {
    local package
    local installed
    installed="$(brew ls)"
    for package in "${@}"; do
        if echo "${installed}" | grep -q "${package}"; then
            echo "Package ${package} is already installed."
        else
            echo "Installing package ${package}..."
            brew install "${package}"
        fi
    done
}

function mac_install_miniconda() {
    if which conda > /dev/null; then
        echo "Miniconda is already installed."
    else
        echo "Installing Miniconda..."
        curl -O https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh
        sh Miniconda3-latest-MacOSX-arm64.sh
        rm Miniconda3-latest-MacOSX-arm64.sh
    fi
}

function mac_install_devtools() {
    if [[ $(which xcodes > /dev/null && xcodes installed | wc -l) -ge 1 ]]; then
        echo "Xcode is already installed."
    else
        echo "Installing Xcode..."
        brew install aria2 xcodes
        xcodes install --latest --experimental-unxip
    fi

    if [[ -d "/Applications/Visual Studio Code.app" ]]; then
        echo "Visual Studio Code is already installed."
    else
        echo "Installing Visual Studio Code..."
        pushd ~/Downloads
        curl -L https://update.code.visualstudio.com/latest/darwin-arm64/stable -o vscode.zip
        unzip vscode.zip
        mv "Visual Studio Code.app" /Applications
        popd
    fi

    echo "Installing other devtools..."
    brew_install_or_skip \
        python \
        virtualenv \
        git \
        buildifier \
        clang-format \
        ffmpeg \
        rsync \
        gpg \
        orbstack \
        gh \
        pass \
        watch \
        go \
        diffutils \
        bash-completion \
        launchctl-completion \
        pip-completion \
        rustc-completion \
        swiftdefaultappsprefpane \
        jq
}

fi # _REDSHELL_MAC
