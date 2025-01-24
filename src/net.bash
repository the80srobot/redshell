# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Network and wifi helpers, netcat wrappers, etc.

if [[ -z "${_REDSHELL_NET}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_NET=1

# Hosts a folder contents over HTTPs.
#
# Also see net_serve.
#
# Usage: net_host [-l|--port PORT] [-u|--username USER] [-P|--password PASS] [-C|certfile FILE] [--keyfile FILE] [DIR]
#
# Options:
#   -l, --port PORT     Port to listen on. Default is 8080.
#   -u, --username USER Username for basic auth.
#   -P, --password PASS Password for basic auth.
#   --certfile FILE     Path to the certificate file, or "auto" to generate one.
#   --keyfile FILE      Path to the key file.
#
# By default, the server will listen for HTTP connections. If certfile and
# keyfile are specified, the server will listen for HTTPS connections.
#
# If certfile is set to "auto", the server will generate a self-signed cert.
# Otherwise, the keyfile must be specified.
#
# If username and password are specified, the server will require basic auth.
# Both or neither must be specified.
#
# The server will serve the contents of DIR. If DIR is not specified, the server
# will serve the current directory.
function net_host() {
    local port=8080
    local username
    local password
    local certfile
    local keyfile
    local dir="."

    while [[ "${#}" -ne 0 ]]; do
        case "${1}" in
            -l|--port)
                port="${2}"
                shift
                ;;
            -u|--username)
                username="${2}"
                shift
                ;;
            -P|--password)
                password="${2}"
                shift
                ;;
            -C|--certfile)
                certfile="${2}"
                shift
                ;;
            --keyfile)
                keyfile="${2}"
                shift
                ;;
            *)
                dir="${1}"
                ;;
        esac
        shift
    done
    dir="$(path_resolve "${dir}")"

    if [[ -n "${username}" && -z "${password}" ]]; then
        >&2 echo "Username specified without password."
        return 1
    fi

    if [[ -z "${username}" && -n "${password}" ]]; then
        >&2 echo "Password specified without username."
        return 1
    fi

    if [[ -n "${certfile}" && "${certfile}" != "auto" && -z "${keyfile}" ]]; then
        >&2 echo "Certificate file specified without key file."
        return 1
    fi

    if [[ -n "${certfile}" && "${certfile}" == "auto" ]]; then
        certfile="$HOME/.redshell_persist/net_host.crt"
        keyfile="$HOME/.redshell_persist/net_host.key"
        if [[ -f "${certfile}" && -f "${keyfile}" ]]; then
            >&2 echo "Certificate and key files already exist. Not regenerating."
        else
            openssl req \
                -x509 \
                -newkey rsa:4096 \
                -keyout "${keyfile}" \
                -out "${certfile}" \
                -days 365 \
                -nodes \
                -subj '/CN=localhost' \
                || return $?
        fi

        >&2 echo "Using certfile: ${certfile}"
        openssl x509 -noout -sha256 -fingerprint -in "${certfile}"
        openssl x509 -noout -sha1 -fingerprint -in "${certfile}"
    fi

    local proto="http"
    [[ -n "${certfile}" ]] && proto="https"
    >&2 echo "Serving ${dir} on:"
    net_ip4 | xargs -I{} echo "* ${proto}://{}:${port}/" >&2
    >&2 echo "* ${proto}://localhost:${port}/"
    >&2 echo ""
    >&2 echo "Press Ctrl+C to stop."

    python_func \
        -p "${HOME}/.redshell/src/net.py" \
        --no-venv \
        serve \
        --directory "${dir}" \
        --port "${port}" \
        --username "${username}" \
        --password "${password}" \
        --certfile "${certfile}" \
        --keyfile "${keyfile}"
}

# Check if you have a usable internet connection.
#
# Usage: net_online
function net_online() {
    timeout 1 curl https://captive.apple.com 2>/dev/null \
        | grep -q '<TITLE>Success</TITLE>'
}

function net_health() {
    {
        echo "== ONLINE STATUS =="
        if net_online; then
            echo "[OK] - You are online."
        else
            echo "[No connection]"
            return 1
        fi

        echo "== ROUND TRIP TIME =="
        echo -n "RTT to facebook.com: "
        echo "$(net_rtt facebook.com)"

        echo -n "RTT to google.com: "
        echo "$(net_rtt google.com)"

        echo "== SPEED TEST =="
        python_pip_run speedtest-cli
    } >&2
}

function net_ssh_fingerprint() {
    local ip="${1}"
    2>/dev/null ssh-keyscan -T1 "${ip}" | ssh-keygen -lf -
}

function net_dump_cert() {
    echo \
        | openssl s_client -showcerts -servername gnupg.org -connect gnupg.org:443 2>/dev/null \
        | openssl x509 -inform pem -noout -text
}

# Usage: net_ccurl [-M|--max-age SECONDS] [-K|--key KEY] -- CURL_ARGS...
#
# Cached curl wrapper. Request parameters are converted to a key and used to
# cache the response.
#
# Options:
#   -M, --max-age SECONDS  Maximum age of the cache in seconds. Default is 3600.
#   -K, --key KEY          Use the given key instead of the request parameters.
function net_ccurl() {
    local max_age=3600
    local key
    local curl_args=()
    while [[ "${#}" -ne 0 ]]; do
        case "${1}" in
            -M|--max-age)
                max_age="${2}"
                shift
                ;;
            -K|--key)
                key="${2}"
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                >&2 echo "Unknown option: ${1}"
                return 1
                ;;
        esac
        shift
    done
    curl_args=("${@}")

    [[ -z "${key}" ]] && key="$(
        echo "${curl_args[@]}"
    )"
    key="$(perl -pe 's/[^a-zA-Z0-9]/_/g' <<< "${key}")"
    local cache_dir="${HOME}/.redshell_persist/net_ccurl"
    local cache_file="${cache_dir}/${key}"
    
    if [[ -f "${cache_file}" ]]; then
        local age="$(file_age -s "${cache_file}")"
        if [[ "${age}" -lt "${max_age}" ]]; then
            cat "${cache_file}"
            return
        fi
        # If we're offline, then even a stale cache is better than nothing.
        if ! net_online; then
            cat "${cache_file}"
            return
        fi
    fi

    mkdir -p "${cache_dir}"
    curl "${curl_args[@]}" > "${cache_file}" || return "$?"
    cat "${cache_file}"
}

# Create a data URL from a file.
#
# Usage: dataurl FILE
function net_dataurl() {
    local mimeType=$(file -b --mime-type "$1")
    if [[ $mimeType == text/* ]]; then
            mimeType="${mimeType};charset=utf-8"
    fi
    echo "data:${mimeType};base64,$(openssl base64 -in "$1" | tr -d '\n')"
}

alias dataurl='net_dataurl'

# Decode a dataurl from stdin onto stdout.
#
# Usage: undataurl
function net_undataurl() {
    cut -d"," -f2 | base64 -d
}

alias undataurl=net_undataurl

# Average round-trip time to the specified host.
#
# Usage: rtt HOST
function net_rtt() {
    local times=$(ping -c5 $1 | grep time= | perl -pe 's/.*time=(.*?) \w.\n*/$1 +/' | sed 's/+$//g') || return 1
    bc -l <<< "(${times}) / 5"
}

# Print the non-localhost IPv4 addresses of this machine. One address per line.
#
# Usage: net_ip4
function net_ip4() {
    which ip > /dev/null
    if [[ $? -eq 0 ]]; then
        ip a | grep 'inet ' | perl -pe 's/.*inet (\d{1,3}\..*?) .*/$1/' | grep -v 127.0.0.1
    else
        ifconfig | grep 'inet ' | perl -pe 's/.*inet (\d{1,3}\..*?) .*/$1/' | grep -v 127.0.0.1
    fi
}

alias ip4=net_ip4

# Print the default gateway's IP address.
#
# Usage: net_ip4gw
function net_ip4gw() {
    netstat -nr | perl -ne 'm/^default\s*(\d+\.\d+\.\d+\.\d+)/ and print "$1\n"' | sort | uniq
}

alias ip4gw=net_ip4gw

# Serves the contents of a file or stdin over HTTP once, then exits.
#
# Also see net_host.
#
# Usage: net_serve [-l PORT] [FILE]
function net_serve() {
    # TODO: Safari is dumb and loads twice.
    local port=8081
    if [[ "${1}" == "-l" ]]; then
        port="${2}"
        shift
        shift
    fi

    # No path? No problem! Read stdin.
    local path="${1}"
    local cleanup=""
    if [[ -z "${path}" ]]; then
        path=$(mktemp)
        cleanup="cleanup"
        cat > "${path}"
        >&2 echo "Staged stdin contents in ${path}"
    fi

    >&2 echo "NOW: Serving on 0.0.0.0:${port}"

    local mime
    local data
    local resp

    mime=$(file -b --mime-type "${path}") || return 1
    >&2 echo "Mime-Type is: ${mime}"
    data=$(cat "${path}") || return 2
    resp=$"HTTP/1.1 200 OK
Content-Type: ${mime}
Server: netcat

${data}"
    echo "${resp}" | nc -l "${port}"

    [[ -z "${cleanup}" ]] || rm -f "${path}"
}


function dump_url() {
    links -dump "${@}"
}

function wiki() {
    if [[ "$1" == "-d" ]]; then
        local viewer="dump_url"
        shift
    else
        local viewer="links"
    fi

    local q=$(echo ${*} | sed 's/+/%2B/g' | tr '\ ' '\+')
    local resp=`curl -sL "https://en.wikipedia.org/w/api.php?action=opensearch&search=${q}"`
    local terms=`echo "${resp}" | jq '.[1][]' | tr -d '"'`
    local urls=`echo "${resp}" | jq '.[3][]' | tr -d '"'`

    local i=`__multiple_choice -n "${terms}"`
    local url=`echo "${urls}" | tail -n+$i | head -n1`
    "${viewer}" "${url}"
}

function wifi_device() {
    uname -a | grep -q "Darwin" || return 1
    networksetup -listnetworkserviceorder \
        | grep -A1 Wi-Fi \
        | tail -n+2 \
        | head -1 \
        | perl -pe 's/.*Device: (\w+).*/$1/'
}

# Print the name of the currently connected wifi network.
#
# Usage: net_wifi_name
function net_wifi_name() {
    # On mac, there's networksetup.
    if [[ "$(uname -a)" == *Darwin* ]]; then
        # On Sequoia and up, Apple have once again fucked up their own
        # replacement for the interface they fucked up in the previous version.
        if [[ "$(uname -r | cut -d. -f1)" -ge 24 ]]; then
            ipconfig getsummary en0 | awk -F ' SSID : '  '/ SSID : / {print $2}'
        else
            networksetup -getairportnetwork "$(wifi_device)" | perl -pe 's/.*Network: //'
        fi
        return
    fi

    # On linux, we can use iwgetid or nmcli.
    which iwgetid > /dev/null && iwgetid -r && return
    which nmcli > /dev/null || return 1
    nmcli -t -f NAME connection show --active
}


# Usage: net_ssh_fingerprint HOST
function net_ssh_fingerprint() {
    local ip="${1}"
    2>/dev/null ssh-keyscan -T1 "${ip}" | ssh-keygen -lf -
}

# Prints the aliases and hostnames from the ssh config file.
#
# Usage: net_ssh_aliases
function net_ssh_aliases() {
    cat ~/.ssh/config \
        | perl -0pe 's/(?:^|\n)Host\s*(\w+).*?HostName\s*(.*?)\n/ALIAS\t$1\t$2\n/sg' \
        | grep ALIAS \
        | cut -f2,3
}

# Based on SSH config, looks up the full hostname of the given alias.
#
# Usage: net_ssh_fqdn ALIAS
function net_ssh_fqdn() {
    local alias="${1}"
    net_ssh_aliases | grep -w "${alias}" | cut -f2
}

fi # _REDSHELL_NET
