# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_UTIL}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_UTIL=1

function sud() {
    sudo bash -c "REDSHELL_SILENT=1 source ${HOME}/.bash_profile && $*"
}


# Print a cryptographic hash of the input.
#
# Usage: h ALGO [INPUT]
# If no INPUT is provided, read from stdin.
#
# h 256 foo -> b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c
# h md5 foo -> d3b07384d113edec49eaa6238ad5ff00
function h() {
    case "$1" in
        md5)
            which md5 2> /dev/null > /dev/null
            if [[ $? -eq 0 ]]; then
                local cmd="md5"
            else
                local cmd="md5sum"
            fi
            if [[ -z "$2" ]]; then
                "${cmd}"
            else
                "${cmd}" <<< "$2"
            fi
        ;;
        *)
            which shasum 2> /dev/null  > /dev/null
            if [[ $? -eq 0 ]]; then    
                if [[ -z "$2" ]]; then
                    shasum -a "$1" | cut -d' ' -f1
                else
                    shasum -a "$1" <<< "$2" | cut -d' ' -f1
                fi
            else
                if [[ -z "$2" ]]; then
                    "sha${1}sum" | cut -d' ' -f1
                else
                    "sha${1}sum" <<< "$2" | cut -d' ' -f1
                fi
            fi
        ;;
    esac
}


function reload() {
    tput reset
    history -a
    exec $(which bash) -l
}


function markdown() {
    local path="$HOME/.Markdown.pl"
    if [[ ! -x "${path}" ]]; then
        curl https://raw.githubusercontent.com/the80srobot/markdown/master/Markdown.pl \
            > "${path}" || return 1
        chmod u+x "${path}"
    fi
    echo "<!doctype html>"
    "${path}" "${@}"
}


function human_size() {
    local units
    local div
    local x
    local sep=" "
    case "${1}" in
        -b)
            units=(bit kbit Mbit Gbit Tbit)
            div=1000
            x="${2}"
            (( x *= 8 ))
        ;;
        -bb)
            units=(b K M G T)
            div=1000
            x="${2}"
            (( x *= 8 ))
            sep=""
        ;;
        -S)
            units=(B kB MB GB TB)
            div=1000
            x="${2}"
        ;;
        -h)
            units=(o KiB MiB GiB TiB)
            div=1024
            x="${2}"
        ;;
        -hh)
            units=(B K M G T)
            div=1024
            x="${2}"
            sep=""
        ;;
        *)
            units=(o KiB MiB GiB TiB)
            div=1024
            x="${1}"
        ;;
    esac
    
    local unit
    for unit in "${units[@]}"; do
        if (( x < div )); then
            echo "${x}${sep}${unit}"
            return
        fi
        (( x /= div ))
    done
    (( x *= div ))  # Ran out of units, go back a step.
    echo "${x}${sep}${unit}"
}


function install_heroku_cli() {
    local wd="$(pwd)"
    trap "cd \"${wd}\"" RETURN

    local target="$HOME/code/heroku"
    rm -rf "${target}" && mkdir -p "${target}" && cd "${target}" || return 2
    
    local sig
    local arch
    local os
    sig="$(uname -a)" || return 3
    grep -q "Darwin" <<< "${sig}" && os="darwin"
    grep -q "Linux" <<< "${sig}" && os="linux"
    grep -q "arm64" <<< "${sig}" && arch="arm64"
    grep -q "aarch64" <<< "${sig}" && arch="arm"
    grep -q "x86_64" <<< "${sig}" && arch="x64"
    grep -q "i386" <<< "${sig}" && arch="x64"

    [[ -z "${os}" || -z "${arch}" ]] && return 4

    wget "https://cli-assets.heroku.com/channels/stable/heroku-${os}-${arch}.tar.gz"
    tar -xzf "heroku-${os}-${arch}.tar.gz"
    mv heroku/* ./ # Pop one level up

    echo "export PATH=\$PATH:${target}/bin" > ./heroku_profile
    uninstall_file ~/.bash_profile '#' 'HEROKU'
    install_file ./heroku_profile ~/.bash_profile '#' 'HEROKU'

    >&2 echo "heroku CLI installed in ${target} and added to PATH - you may need to reload bash"
    >&2 echo "NOW:"
    >&2 echo "  heroku login && heroku container:login"
}

alias heroku_install_cli=install_heroku_cli

function bazel() {
    which bazel > /dev/null || {
        >&2 echo "No bazel installation - downloading bazelisk..."
        local os="unknown"
        local arch="unknown"
        case "$(uname)" in
        Darwin)
            os="darwin"
            ;;
        Linux)
            os="linux"
            ;;
        esac

        case "$(uname -m)" in
        arm64|aarch64)
            arch="arm64"
            ;;
        x86_64)
            arch="amd64"
            ;;
        esac

        local file="bazelisk-${os}-${arch}"
        local url="https://github.com/bazelbuild/bazelisk/releases/latest/download/${file}"
        curl -L "${url}" > "${HOME}/mbin/bazel"
        chmod a+x "${HOME}/mbin/bazel"
    }
    "$(which bazel)" "${@}"
}

function jup() {
    open http://localhost:10000
    docker run -it --rm -p 10000:8888 -v "${PWD}":/home/jovyan/work quay.io/jupyter/datascience-notebook:latest
}

function wait_for_file() {
    local path
    local timeout=60
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -t)
                timeout="$2"
                shift
                ;;
            *)
                path="$1"
                ;;
        esac
        shift
    done

    local deadline
    deadline="$(date +%s)"
    (( deadline += timeout ))
    while [[ "$(date +%s)" -lt "${deadline}" ]]; do
        if [[ -f "${path}" ]]; then
            return 0
        fi
        sleep 1
    done
    echo "Timed out waiting for ${path} after ${timeout} s." >&2
    return 1
}

function forex() {
    local from
    local to
    local date="today"
    local amount=
    local verbose
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -f|--from)
                from="$2"
                shift
                ;;
            -t|--to)
                to="$2"
                shift
                ;;
            -d|--date)
                date="$2"
                shift
                ;;
            -a|--amount)
                amount="$2"
                shift
                ;;
            -v|--verbose)
                verbose=1
                ;;
            -h|--help)
                echo "Usage: forex [-f] <from> [-t] <to> [-d <date>] [[-a] <amount>] [-v]"
                return 0
                ;;
            *)
                # Positional argument?
                if [[ -z "${from}" ]]; then
                    from="$1"
                elif [[ -z "${to}" ]]; then
                    to="$1"
                elif [[ -z "${amount}" ]]; then
                    amount="$1"
                else
                    echo "Unknown argument: $1" >&2
                    return 1
                fi
                ;;
        esac
        shift
    done

    if [[ -z "${from}" || -z "${to}" ]]; then
        echo "Usage: forex [-f] <from> [-t] <to> [-d <date>] [[-a] <amount>] [-v]" >&2
        return 2
    fi

    local output
    local answer
    if [[ -n "${verbose}" ]]; then
        output="$(go_pkg_do \
            wowsignal-io/go-forex \
            go run cmd/forex-convert/forex-convert.go \
            -from "${from}" \
            -date "${date}" \
            -to "${to}" \
            -v)" || return "$?"
        answer="$(echo "${output}" | tail -1 | sed 's/Computed rate: //')"
    else
        output="$(go_pkg_do \
            wowsignal-io/go-forex \
            go run cmd/forex-convert/forex-convert.go \
            -from "${from}" \
            -date "${date}" \
            -to "${to}" 2>/dev/null )" || return "$?"
        answer="${output}"
    fi

    if [[ -n "${amount}" ]]; then
        local result
        result="$(echo "${amount} * ${answer}" | bc)"
        if [[ -n "${verbose}" ]]; then
            echo "${output}"
            echo "Converted amount: ${result}"
        else
            echo "${result}"
        fi
    else
        echo "${output}"
    fi
    
}

fi # _REDSHELL_UTIL
