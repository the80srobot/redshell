# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Network and wifi helpers, netcat wrappers, etc.

source "compat.sh"

if [[ -z "${_REDSHELL_NET}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_NET=1

source util.bash

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

# Usage: net_dl URL
#
# Recursively downloads the URL even if it's a folder. Accepts all wget options.
#
# This is basically only useful if you can't remember wget options.
function net_dl() {
    wget -r -nH --no-parent "${@}"
}

# Check if you have a usable internet connection.
#
# Usage: net_online
function net_online() {
    timeout 1 curl https://captive.apple.com 2>/dev/null \
        | grep -q '<TITLE>Success</TITLE>'
}

# Convert a CIDR notation (e.g. 24) to a netmask.
#
# Usage: net_cidr_to_netmask CIDR
function net_cidr_to_netmask() {
    local cidr="${1}"
    local mask=""
    local full_bytes=$((cidr / 8))
    local partial_bits=$((cidr % 8))
    local i

    for ((i=0; i<4; i++)); do
        if [[ $i -lt $full_bytes ]]; then
            mask+="255"
        elif [[ $i -eq $full_bytes ]]; then
            local byte=0
            for ((j=0; j<partial_bits; j++)); do
                byte=$((byte + 2**(7-j)))
            done
            mask+="${byte}"
        else
            mask+="0"
        fi
        [[ $i -lt 3 ]] && mask+="."
    done

    echo "${mask}"
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
    [[ -n "${_REDSHELL_ZSH}" ]] && emulate -L ksh
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
        ip a | grep 'inet ' | perl -pe 's/.*inet\s+([\d\.]{8,}).*$/$1/' | grep -v 127.0.0.1
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

# Find the process using a TCP port.
#
# Useful when you get "address already in use" errors and need to find
# what's hogging the port.
#
# Usage: net_port_hog PORT
function net_port_hog() {
    local port="${1}"
    if [[ -z "${port}" ]]; then
        >&2 echo "Usage: net_port_hog PORT"
        return 1
    fi

    # Validate port is numeric
    if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
        >&2 echo "Error: PORT must be a number"
        return 1
    fi

    local result
    if command -v lsof > /dev/null; then
        # lsof works on both macOS and Linux
        result=$(lsof -iTCP:"${port}" -sTCP:LISTEN -P -n 2>/dev/null)
        if [[ -z "${result}" ]]; then
            >&2 echo "No process is listening on TCP port ${port}"
            return 1
        fi
        echo "${result}"
    elif command -v ss > /dev/null; then
        # ss is common on Linux
        result=$(ss -tlnp "sport = :${port}" 2>/dev/null)
        if [[ $(echo "${result}" | wc -l) -le 1 ]]; then
            >&2 echo "No process is listening on TCP port ${port}"
            return 1
        fi
        echo "${result}"
    else
        >&2 echo "Error: Neither lsof nor ss found"
        return 1
    fi
}

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
    local _path="${1}"
    local cleanup=""
    if [[ -z "${_path}" ]]; then
        _path=$(mktemp)
        cleanup="cleanup"
        cat > "${_path}"
        >&2 echo "Staged stdin contents in ${_path}"
    fi

    >&2 echo "NOW: Serving on 0.0.0.0:${port}"

    local mime
    local data
    local resp

    mime=$(file -b --mime-type "${_path}") || return 1
    >&2 echo "Mime-Type is: ${mime}"
    data=$(cat "${_path}") || return 2
    resp=$"HTTP/1.1 200 OK
Content-Type: ${mime}
Server: netcat

${data}"
    echo "${resp}" | nc -l "${port}"

    [[ -z "${cleanup}" ]] || rm -f "${_path}"
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

# Prints a link to WhatsApp Web for the given phone number.
#
# Usage: net_wa_link PHONE_NUMBER
function net_wa_link() {
    local phone="${*}"
    # Delete spaces and non-numeric characters.
    phone=$(echo "${phone}" | tr -d '[:space:]' | tr -cd '[:digit:]')
    echo "https://api.whatsapp.com/send?phone=${phone}"
}

# Ensure the gallery virtual environment exists with pillow installed.
# Creates ~/.redshell/gallery/ with a venv and gallery.py symlink.
function __net_gallery_ensure_venv() {
    local gallery_workspace="${HOME}/.redshell/gallery"
    local gallery_src="${HOME}/.redshell/src/gallery.py"

    if [[ ! -d "${gallery_workspace}" ]]; then
        >&2 echo "Creating gallery workspace..."
        mkdir -p "${gallery_workspace}"
    fi

    # Symlink gallery.py if not present or outdated
    if [[ ! -L "${gallery_workspace}/gallery.py" ]] || \
       [[ "$(readlink "${gallery_workspace}/gallery.py")" != "${gallery_src}" ]]; then
        ln -sf "${gallery_src}" "${gallery_workspace}/gallery.py"
    fi

    # Create/update requirements.txt
    local requirements="pillow
tqdm"
    if [[ ! -f "${gallery_workspace}/requirements.txt" ]] || \
       [[ "$(cat "${gallery_workspace}/requirements.txt")" != "${requirements}" ]]; then
        echo "${requirements}" > "${gallery_workspace}/requirements.txt"
        # Force venv reinstall if requirements changed
        [[ -d "${gallery_workspace}/.venv" ]] && rm -rf "${gallery_workspace}/.venv"
    fi

    # Create/activate venv and install requirements
    pushd "${gallery_workspace}" > /dev/null
    if [[ ! -d ".venv" ]]; then
        >&2 echo "Setting up gallery virtualenv with pillow..."
        python_venv -I || { popd > /dev/null; return 1; }
        deactivate
    fi
    popd > /dev/null
}

# Scan a directory for photos and serve a browsable gallery.
#
# This command scans a directory tree for photos, generates thumbnails and
# mid-size images for fast browsing, and serves an HTML gallery.
#
# The gallery data (thumbnails, mid-size images, JSON index) is stored in a
# .gallery hidden directory. The original photos can either be left in place
# (referenced by path) or copied to a new directory with date-based names.
#
# Usage: net_gallery [--dedupe] [--copy-to DIR] [--scan-only] [--serve-only] [--force] [--clean] [--title TITLE] [-l|--port PORT] [-u|--username USER] [-P|--password PASS] [-C|--certfile FILE] [--keyfile FILE] [DIR]
#
# Options:
#   --dedupe              Deduplicate photos by hash before indexing.
#   --copy-to DIR         Copy photos to DIR with date-based names. If not
#                         specified, photos are referenced in place.
#   --scan-only           Generate gallery data without serving. Useful for
#                         preparing a gallery to be served later.
#   --serve-only          Skip scanning and serve existing gallery data.
#   --force               Regenerate thumbnails even if they exist.
#   --clean               Delete all generated gallery files (.gallery/ and
#                         gallery.html) and exit.
#   --title TITLE         Gallery title. Defaults to the directory name.
#   -l, --port PORT       Port to serve on. Default is 8080.
#   -u, --username USER   Username for basic auth.
#   -P, --password PASS   Password for basic auth.
#   -C, --certfile FILE   Certificate file for HTTPS, or "auto" to generate.
#   --keyfile FILE        Key file for HTTPS.
#
# Examples:
#   net_gallery                     # Scan current dir and serve gallery
#   net_gallery ~/Photos            # Scan ~/Photos and serve gallery
#   net_gallery --dedupe ~/Backup   # Dedupe and serve photos from backup
#   net_gallery --scan-only .       # Generate gallery data only
#   net_gallery --copy-to ~/Clean ~/Messy  # Copy deduped photos to new dir
function net_gallery() {
    [[ -n "${_REDSHELL_ZSH}" ]] && emulate -L ksh
    local dir="."
    local port=8080
    local dedupe=""
    local copy_to=""
    local scan_only=""
    local force=""
    local clean=""
    local serve_only=""
    local title=""
    local username=""
    local password=""
    local certfile=""
    local keyfile=""

    while [[ "${#}" -ne 0 ]]; do
        case "${1}" in
            --dedupe)
                dedupe="True"
                ;;
            --copy-to)
                copy_to="${2}"
                shift
                ;;
            --scan-only)
                scan_only="True"
                ;;
            --force)
                force="True"
                ;;
            --serve-only)
                serve_only="True"
                ;;
            --clean)
                clean="True"
                ;;
            --title)
                title="${2}"
                shift
                ;;
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

    # Default title to directory name
    if [[ -z "${title}" ]]; then
        title="$(basename "${dir}")"
    fi

    # Determine gallery directory location
    local gallery_dir
    if [[ -n "${copy_to}" ]]; then
        copy_to="$(path_resolve "${copy_to}")"
        gallery_dir="${copy_to}"
    else
        gallery_dir="${dir}"
    fi

    # Handle --clean: remove generated files and exit
    if [[ -n "${clean}" ]]; then
        local removed=""
        if [[ -d "${gallery_dir}/.gallery" ]]; then
            rm -rf "${gallery_dir}/.gallery"
            >&2 echo "Removed ${gallery_dir}/.gallery/"
            removed="1"
        fi
        if [[ -f "${gallery_dir}/gallery.html" ]]; then
            rm -f "${gallery_dir}/gallery.html"
            >&2 echo "Removed ${gallery_dir}/gallery.html"
            removed="1"
        fi
        if [[ -z "${removed}" ]]; then
            >&2 echo "No gallery files found in ${gallery_dir}"
        fi
        return 0
    fi

    # Skip scanning if --serve-only is set
    if [[ -n "${serve_only}" ]]; then
        if [[ ! -f "${gallery_dir}/.gallery/photos.json" ]]; then
            >&2 echo "Error: No gallery data found in ${gallery_dir}/.gallery/"
            >&2 echo "Run without --serve-only to generate gallery data first."
            return 1
        fi
        >&2 echo "Skipping scan, using existing gallery data."
    else
        # Ensure the gallery venv exists with pillow
        __net_gallery_ensure_venv || return $?

        >&2 echo "Scanning for photos in ${dir}..."

        # Run the gallery scanner using the gallery workspace venv
        python_func \
            -p "${HOME}/.redshell/gallery/gallery.py" \
            scan \
            --directory "${dir}" \
            --dedupe "${dedupe}" \
            --copy_to "${copy_to}" \
            --gallery_dir "${gallery_dir}" \
            --force "${force}" \
            --title "${title}" \
            || return $?
    fi

    # Copy the gallery HTML to the gallery directory
    local gallery_html_src="${HOME}/.redshell/src/gallery.html"
    local gallery_html_dst="${gallery_dir}/gallery.html"
    if [[ ! -f "${gallery_html_dst}" ]] || [[ "${gallery_html_src}" -nt "${gallery_html_dst}" ]]; then
        cp "${gallery_html_src}" "${gallery_html_dst}"
        >&2 echo "Copied gallery.html to ${gallery_html_dst}"
    fi

    if [[ -n "${scan_only}" ]]; then
        >&2 echo ""
        >&2 echo "Gallery data generated. To view, run:"
        >&2 echo "  net_host ${gallery_dir}"
        >&2 echo "  # Then open http://localhost:8080/gallery.html"
        return 0
    fi

    >&2 echo ""
    >&2 echo "Starting gallery server..."
    >&2 echo "Open http://localhost:${port}/gallery.html in your browser."
    >&2 echo ""

    local host_args=(--port "${port}")
    [[ -n "${username}" ]] && host_args+=(--username "${username}")
    [[ -n "${password}" ]] && host_args+=(--password "${password}")
    [[ -n "${certfile}" ]] && host_args+=(--certfile "${certfile}")
    [[ -n "${keyfile}" ]] && host_args+=(--keyfile "${keyfile}")
    host_args+=("${gallery_dir}")

    net_host "${host_args[@]}"
}

### Some functions for managing static DHCP IP4 config on Debian-based systems. ###

# Installs the given config for the given interface on Debian.
#
# Usage: net_write_static_ip4_dhcp_config_debian INTERFACE CONFIG
function __net_write_static_ip4_dhcp_config_debian() {
    local interface="${1}"
    local config="${2}"
    # Write to a temp file, then install with a guard specific to the interface.
    local tmpfile
    tmpfile=$(mktemp) || return 1
    echo "${config}" > "${tmpfile}"
    util_sudo reinstall_file \
        "${tmpfile}" \
        "/etc/network/interfaces.d/${interface}.cfg" \
        '#' \
        "GREENSHELL_"${interface^^}"_STATIC_DHCP_IP4" \
        || return $?
    
    sudo systemctl restart networking
}

# Generates a static DHCP IPv4 configuration for the given interface on Debian.
#
# Usage: net_set_static_dhcp_ip4_debian INTERFACE IP GATEWAY DNS NETMASK
function __net_make_static_dhcp_ip4_config_debian() {
    local interface="${1}"
    local ip="${2}"
    local gateway="${3}"
    local dns="${4}"
    local netmask="${5}"

    echo "auto ${interface}
iface ${interface} inet static
    address ${ip}
    netmask ${netmask}
    gateway ${gateway}
    dns-nameservers ${dns}"
}

# Gets the live IPv4 configuration for the given interface on Debian.
#
# Prints IP, GATEWAY, DNS, NETMASK in that order.
function __net_get_ip4_config_debian() {
    local interface="${1}"
    local ip gateway dns netmask
    ip=$(ip -4 addr show dev "${interface}" \
        | grep 'inet ' \
        | perl -pe 's/.*inet (\d+\.\d+\.\d+\.\d+)\/(\d+).*/$1/') || return 1
    gateway=$(ip route show dev "${interface}" default \
        | perl -pe 's/.*default via (\d+\.\d+\.\d+\.\d+).*/$1/') || return 2
    dns=$(grep '^nameserver ' /etc/resolv.conf \
        | perl -pe 's/nameserver (\d+\.\d+\.\d+\.\d+)/$1 /g' \
        | tr -d '\n') || return 3
    netmask=$(ip -4 addr show dev "${interface}" \
        | grep 'inet ' \
        | perl -pe 's/.*inet (\d+\.\d+\.\d+\.\d+)\/(\d+).*/$2/') || return 4
    # Convert CIDR to netmask
    netmask=$(net_cidr_to_netmask "${netmask}") || return 5

    printf "%s\t%s\t%s\t%s" "${ip}" "${gateway}" "${dns}" "${netmask}"
}

# Usage: __net_modified_static_dhcp4_config_debian INTERFACE [--ip IP] [--gateway GATEWAY] [--dns DNS] [--netmask NETMASK]
function __net_modified_static_dhcp4_config_debian() {
    local interface="${1}"
    shift
    local ip gateway dns netmask
    while [[ "${#}" -ne 0 ]]; do
        case "${1}" in
            --ip)
                ip="${2}"
                shift
                ;;
            --gateway)
                gateway="${2}"
                shift
                ;;
            --dns)
                dns="${2}"
                shift
                ;;
            --netmask)
                netmask="${2}"
                shift
                ;;
            *)
                >&2 echo "Unknown option: ${1}"
                return 1
                ;;
        esac
        shift
    done
    local current
    current="$(__net_get_ip4_config_debian "${interface}")" || return $?
    [[ -z "${ip}" ]] && ip="$(echo "${current}" | cut -f1)"
    [[ -z "${gateway}" ]] && gateway="$(echo "${current}" | cut -f2)"
    [[ -z "${dns}" ]] && dns="$(echo "${current}" | cut -f3)"
    [[ -z "${netmask}" ]] && netmask="$(echo "${current}" | cut -f4)"
    __net_make_static_dhcp_ip4_config_debian "${interface}" "${ip}" "${gateway}" "${dns}" "${netmask}"
}


fi # _REDSHELL_NET
