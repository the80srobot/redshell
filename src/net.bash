# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_NET}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_NET=1

# Create a data URL from a file
function dataurl() {
    local mimeType=$(file -b --mime-type "$1")
    if [[ $mimeType == text/* ]]; then
            mimeType="${mimeType};charset=utf-8"
    fi
    echo "data:${mimeType};base64,$(openssl base64 -in "$1" | tr -d '\n')"
}

# Decode a dataurl onto stdout
alias undataurl='cut -d"," -f2 | base64 -d'


# Average round-trip time to the specified host.
function rtt() {
    local times=$(ping -c5 $1 | grep time= | perl -pe 's/.*time=(.*?) \w.\n*/$1 +/' | sed 's/+$//g') || return 1
    bc -l <<< "(${times}) / 5"
}

# Print the non-localhost IPv4 addresses of this machine. One address per line.
function ip4() {
    which ip > /dev/null
    if [[ $? -eq 0 ]]; then
        ip a | grep 'inet ' | perl -pe 's/.*inet (\d{1,3}\..*?) .*/$1/' | grep -v 127.0.0.1
    else
        ifconfig | grep 'inet ' | perl -pe 's/.*inet (\d{1,3}\..*?) .*/$1/' | grep -v 127.0.0.1
    fi
}

function ip4gw() {
    netstat -nr | perl -ne 'm/^default\s*(\d+\.\d+\.\d+\.\d+)/ and print "$1\n"' | sort | uniq
}


function serve() {
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

function wifi_name() {
    networksetup -getairportnetwork "$(wifi_device)" | perl -pe 's/.*Network: //'
}

fi # _REDSHELL_NET
