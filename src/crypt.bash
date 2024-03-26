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
