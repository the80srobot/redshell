# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_CRYPT}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_CRYPT=1

function encrypt_symmetric() {
    tar -czf "$1.tgz" "$1"
    gpg --symmetric --output "$1.tgz.gpg" "$1.tgz"
    rm -rf "$1"
    rm -f "$1.tgz"
    echo "$1 -> ${$1}.tgz.gpg"
}

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

fi # _REDSHELL_CRYPT
