# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Mac setup, package management and various helpers.

source "compat.sh"

if [[ -z "${_REDSHELL_MAC}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_MAC=1

source multiple_choice.bash
source util.bash
source ai.bash

function mac_setup() {
    mac_enable_ipconfig_verbose
}

# Usage: mac_install_extras
#
# Install the full development environment on macOS. This includes switching to
# Homebrew bash, installing Xcode, VS Code, and various dev packages.
function mac_install_extras() {
    mac_switch_to_bash
    mac_install_devtools
}

function brew() {
    which brew > /dev/null || reinstall_brew
    "$(which brew)" "${@}"
}

function reinstall_brew() {
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    (echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') > ~/.bash_profile.brew_temp
    reinstall_file ~/.bash_profile.brew_temp ~/.bash_profile '#' REDSHELL_BREW
    eval "$(/opt/homebrew/bin/brew shellenv)"
}

function mac_enable_ipconfig_verbose() {
    if [[ "$(uname -r | cut -d. -f1)" -ge 24 ]]; then
        # On macOS 14 and later, Apple have decided that wifi names are super
        # duper secret and the user must not be allowed to see what wifi they're
        # on. This should be a one-time operation that enables net_wifi_name to
        # work.
        sudo ipconfig setverbose 1
    fi
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
        coreutils \
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
        jq \
        ugrep \
        links \
        cpulimit \
        pidof \
        ripgrep
    
    echo "Claude code..."
    which claude || { curl -fsSL https://claude.ai/install.sh | bash ; }
    ai_install_claude_config
}

# Kills Microsoft Defender in a way that tends to persist for an hour or so.
# This is useful for working around bugs or surviving when they push and update
# that breaks the OS.
#
# Use at your own risk, and only after discussing with your IT department. This
# action is likely to be detected.
#
# Usage: mac_kill_defender
function mac_kill_defender() {
    launchctl unload /Library/LaunchAgents/com.microsoft.wdav.tray.plist
    sudo launchctl unload /Library/LaunchDaemons/com.microsoft.fresno.plist
    sudo launchctl unload /Library/LaunchDaemons/com.tanium.taniumclient.plist
}

# Keeps Microsoft Defender from restarting.
#
# Use at your own risk, and only after discussing with your IT department. This
# action is likely to be detected.
#
# Usage: mac_suppress_defender
function mac_suppress_defender() {
    sudo bash -c 'while true; do launchctl unload /Library/LaunchAgents/com.microsoft.wdav.tray.plist ; launchctl unload /Library/LaunchDaemons/com.microsoft.fresno.plist ; launchctl unload /Library/LaunchDaemons/com.tanium.taniumclient.plist; sleep 10; done'
}

# Stops CrashPlan from running. CrashPlan is a very poorly optimized backup
# service. When you're running IO intensive workloads, it can slow them down
# massively and eat up 2-3 CPU cores.
#
# Usage: mac_kill_crashplan
function mac_kill_crashplan() {
    sudo launchctl unload /Library/LaunchDaemons/com.crashplan.service.plist
}

function mac_hogs() {
    local hogs
    hogs="$(mac_cpu_hogs --current 20 --lifetime 5 | sort -k2 -nr)"
    if [[ -z "${hogs}" ]]; then
        echo "No CPU hogs found."
        return
    fi
    local header
    header="PID"$'\t'"Lifetime CPU %"$'\t'"Current CPU %"$'\t'"Command"
    # Make sure the width of the columns in the header and the data match.
    local cols
    cols="$(echo -e "${header}\n${hogs}" | column -t -s $'\t')"
    header="$(echo "${cols}" | head -n1)"
    hogs="$(echo "${cols}" | tail -n +2)"

    local choice
    choice="$(multiple_choice \
        -i "${hogs}" \
        -m "Select CPU hogging tasks to suspend" \
        -H "     ${header}")" || return $?
    
    local pid="$(echo "${choice}" | awk '{print $1}')"
    >&2 echo "Suspending PID ${pid}..."
    mac_pid_suspend --suspend "${pid}" || return $?
    >&2 echo "PID ${pid} suspended. To resume, run 'mac_pid_suspend --resume ${pid}'."
    mac_hogs
}

# Lists PIDs of processes using too much CPU.
#
# Checks both current CPU % and lifetime CPU % (accumulated CPU time divided
# by process elapsed time). Lists processes exceeding either threshold.
#
# Output: tab-separated pid, lifetime cpu %, current cpu %, command name
#
# Usage: mac_cpu_hogs [--current PERCENT] [--lifetime PERCENT]
function mac_cpu_hogs() {
    local current_thresh=50
    local lifetime_thresh=50

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --current)
                current_thresh="$2"
                shift 2
                ;;
            --lifetime)
                lifetime_thresh="$2"
                shift 2
                ;;
            *)
                echo "Usage: mac_cpu_hogs [--current PERCENT] [--lifetime PERCENT]" >&2
                return 1
                ;;
        esac
    done

    # pid, current cpu%, cputime (accumulated), etime (elapsed since start), comm
    ps -eo pid,%cpu,cputime,etime,comm | awk -v cur_thresh="$current_thresh" -v life_thresh="$lifetime_thresh" '
        function parse_time(t) {
            secs = 0
            # Handle dd-hh:mm:ss or hh:mm:ss or mm:ss
            if (match(t, /-/)) {
                split(t, parts, "-")
                secs = parts[1] * 86400
                t = parts[2]
            }
            n = split(t, parts, ":")
            if (n == 3) {
                secs += parts[1] * 3600 + parts[2] * 60 + parts[3]
            } else if (n == 2) {
                secs += parts[1] * 60 + parts[2]
            } else {
                secs += parts[1]
            }
            return secs
        }
        NR > 1 {
            pid = $1
            cur_cpu = $2
            cpu_secs = parse_time($3)
            elapsed = parse_time($4)

            # Ignore processes running less than 10 seconds
            if (elapsed < 10) next

            # Capture command from field 5 to end of line, then take basename
            comm = ""
            for (i = 5; i <= NF; i++) {
                comm = comm (i > 5 ? " " : "") $i
            }
            n = split(comm, parts, "/")
            comm = parts[n]

            life_cpu = (elapsed > 0) ? (cpu_secs / elapsed * 100) : 0

            if (cur_cpu >= cur_thresh || life_cpu >= life_thresh) {
                printf "%s\t%.1f\t%.1f\t%s\n", pid, life_cpu, cur_cpu, comm
            }
        }'
}

# Limits the CPU usage of processes to a certain percentage.
#
# Usage: mac_cpulimit LIMIT PID [PID ...]
function mac_cpulimit() {
    [[ -n "${_REDSHELL_ZSH}" ]] && emulate -L ksh
    which pidof > /dev/null || {
        echo "pidof not found. Install with brew install pidof." >&2
        return 1
    }
    which cpulimit > /dev/null || {
        echo "cpulimit not found. Install with brew install cpulimit." >&2
        return 1
    }

    local pids=()
    local limit="$1"
    shift

    for pid in "${@}"; do
        if [[ -z "${pid}" ]]; then
            continue
        fi
        if [[ "$pid" =~ ^[0-9]+$ ]]; then
            pids+=("$pid")
        else
            pids+=($(pidof "$pid"))
        fi
    done
    
    echo "Removing previous cpu limits..." >&2
    sudo killall -9 cpulimit

    if [[ "${#pids[@]}" -eq 0 ]]; then
        echo "No PIDs to limit - bailing." >&2
        return
    fi

    echo "Limiting CPU usage of ${pids[@]} to ${limit}%" >&2
    for pid in "${pids[@]}"; do
        if [[ -z "${pid}" ]]; then
            continue
        fi
        sudo nohup `which cpulimit` -l "$limit" -i -p "${pid}" &
    done
}

# Usage: mac_disable_powernap
#
# Stop the computer from waking up to do random things and exhausting the
# battery.
function mac_disable_powernap() {
    sudo pmset -a tcpkeepalive 0
    sudo pmset -a powernap 0
}

# Usage: mac_power_stats
#
# Prints out some debug information about power management.
function mac_power_stats() {
    echo "== Wake Requests =="
    pmset -g log | grep "Wake Requests"
    echo "== Wake Requests (darkwake) =="
    pmset -g log | grep "darkwake"
    echo "== Assertions =="
    pmset -g assertions
    echo "== Stats =="
    pmset -g stats
}

# macOS uses the non-existent locale LC_CTYPE=UTF-8 by default, which breaks SSH
# sessions. This function fixes that by way of global ssh client config.
function mac_fix_ssh_locale_config() {
    reinstall_file "${HOME}/.redshell/rc/mac_ssh_config" ~/.ssh/config
}

# Usage: mac_pid_suspend [--resume|--suspend] PID
function mac_pid_suspend() {
    util_run --sudo pid_suspend "$@"
}

function mac_setup_iterm2() {
    brew install --cask iterm2
    # Install the bundled plist config.
    cp "${REDSHELL_ROOT}/rc/com.googlecode.iterm2.plist" "${HOME}/Library/Preferences/"
}

fi # _REDSHELL_MAC
