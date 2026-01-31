# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Encrypt/decrypt, signing, keypairs. SSH and GPG helpers.

source "compat.sh"

if [[ -z "${_REDSHELL_CRYPT}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_CRYPT=1

# Usage: encrypt_symmetric FILE
function encrypt_symmetric() {

    tar -czf "$1.tgz" "$1"
    gpg --symmetric --output "$1.tgz.gpg" "$1.tgz"
    rm -rf "$1"
    rm -f "$1.tgz"
    echo "$1 -> ${$1}.tgz.gpg"
}

# Usage: decrypt_symmetric FILE
function decrypt_symmetric() {

    gpg --decrypt --output "$1.tgz" "$1"
    tar -xzf "$1.tgz"
    rm -f "$1"
    rm -f "$1.tgz"
    echo "$1 -> $(basename "$1" .tgz.gpg)"
}

function gen_github_keypair() {

    ssh-keygen -t ed25519 -C "$1"
}

function package() {

    local payload_path
    local payload_name
    local encrypt
    local tmp_prefix="_pack_"
    local install_script
    local output_path

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -e|--encrypt)
                encrypt=1
                ;;
            -p|--payload-path)
                payload_path="$2"
                shift
                ;;
            -i|--install-script)
                install_script="$2"
                shift
                ;;
            -o|--output-path)
                output_path="$2"
                shift
                ;;
            *)
                payload_path="$1"
                ;;
        esac
        shift
    done

    if [[ -z "${payload_path}" ]]; then
        echo "No payload path specified." >&2
        return 1
    fi

    payload_name=$(basename "${payload_path}")
    local tar_name="${tmp_prefix}${payload_name}.tgz"
    tar -czf "${tar_name}" "${payload_path}" || return 1
    if [[ -n "${encrypt}" ]]; then
        gpg --symmetric --output "${tar_name}.gpg" "${tar_name}"
        rm -f "${tar_name}"
        tar_name="${tar_name}.gpg"
    fi

    if [[ -z "${output_path}" ]]; then
        output_path="${payload_name}.pack.sh"
    fi
    {
        echo "#!/bin/sh"
        if [[ -n "${encrypt}" ]]; then
            echo "export GPG_TTY=\`tty\`"
        fi
        echo "echo '"
        cat "${tar_name}" | base64
        echo "' | cat | base64 -d > \"${tmp_prefix}_stage_1\""

        if [[ -n "${encrypt}" ]]; then
            echo "gpg --pinentry loopback --symmetric --output \"${tmp_prefix}_stage_2\" \"${tmp_prefix}_stage_1\""
        else
            echo "mv \"${tmp_prefix}_stage_1\" \"${tmp_prefix}_stage_2\""
        fi

        echo "tar -xzf \"${tmp_prefix}_stage_2\""
        echo "rm -f \"${tmp_prefix}_stage_1\""
        echo "rm -f \"${tmp_prefix}_stage_2\""
    } > "${output_path}"

    if [[ -n "${install_script}" ]]; then
        cat "${install_script}" >> "${output_path}"
    fi

    rm -f "${tar_name}"
}

# Usage: payloadify FILE
function payloadify() {

    local payload="$1"
    gpg --symmetric --output "${payload}.gpg" "${payload}"
    {
        echo "export GPG_TTY=\`tty\`"
        echo "echo '"
        cat "${payload}.gpg" | base64
        echo "' | cat | base64 -d > _tmp_decrypt.gpg"
        echo "gpg --pinentry loopback --decrypt --output _tmp_decrypt _tmp_decrypt.gpg"
        echo "source _tmp_decrypt"
        echo "rm -f _tmp_decrypt _tmp_decrypt.gpg"
    } > "${payload}.packed"
    rm -f "${payload}.gpg"
}

# Usage: downloadify FILE
#
# Encrypt a file and wrap it in a base64 self-unpacking shell script.
function downloadify() {

    local payload="$1"
    gpg --symmetric --output "${payload}.gpg" "${payload}"
    {
        echo "echo '"
        cat "${payload}.gpg" | base64
        echo "' | cat | base64 -d > _tmp_decrypt.gpg"
        echo "gpg --pinentry loopback --decrypt --output ${payload} _tmp_decrypt.gpg"
        echo "rm -f _tmp_decrypt.gpg"
    } > "${payload}.packed"
    rm -f "${payload}.gpg"
}

# Print a cryptographic hash of the input.
#
# Usage: crypt_hash ALGO [INPUT]
# If no INPUT is provided, read from stdin.
#
# Supported ALGO values: md5 or SHA version (1, 128, 224, 256, 512).
#
# hash 256 foo -> b5bb9d8014a0f9b1d61e21e796d78dccdf1352f23cd32812f4850b878ae4944c
# hash md5 foo -> d3b07384d113edec49eaa6238ad5ff00
function crypt_hash() {

    case "$1" in
        md5)
            which md5 2> /dev/null > /dev/null
            if [[ $? -eq 0 ]]; then
                local cmd="md5"
            else
                local cmd="md5sum"
            fi
            if [[ -z "$2" ]]; then
                "${cmd}" | cut -d' ' -f1
            else
                "${cmd}" <<< "$2" | cut -d' ' -f1
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

alias h=crypt_hash

# Generate a self-signed certificate.
#
# Usage: crypt_selfsign [NAME] [OPTIONS]
#
# Options are the same as for openssl req
function crypt_selfsign() {

    local name="cert"
    local keyout
    local newkey
    local days
    local out
    if [[ "$1" != -* ]]; then
        name="$1"
        shift
    fi
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                name="$2"
                shift
                ;;
            -keyout|--keyout)
                keyout="$2"
                shift
                ;;
            -newkey|--newkey)
                newkey="$2"
                shift
                ;;
            -days|--days)
                days="$2"
                shift
                ;;
            -out|--out)
                out="$2"
                shift
                ;;
            --)
                shift
                break
                ;;
            *)
                break
                ;;
        esac
        shift
    done

    if [[ -z "${keyout}" ]]; then
        keyout="$name.key"
    fi
    if [[ -z "${newkey}" ]]; then
        newkey="rsa:2048"
    fi
    if [[ -z "${days}" ]]; then
        days=365
    fi
    if [[ -z "${out}" ]]; then
        out="$name.crt"
    fi

    openssl req \
        -x509 \
        -nodes \
        -days "${days}" \
        -newkey "${newkey}" \
        -keyout "${keyout}" \
        -out "${out}" \
        "$@"
}

fi # _REDSHELL_CRYPT
