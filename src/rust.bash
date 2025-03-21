# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Manage rust toolchain and environment.

if [[ -z "${_REDSHELL_RUST}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_RUST=1

function rustup() {
    type -P rustup > /dev/null 2>&1 || {
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        source ~/.bash_profile
    }
    "$(type -P rustup)" "${@}"
}

function rust_install_goodies() {
    rustup component add rust-src --toolchain nightly
    rustup toolchain install nightly
    rustup toolchain install nightly --allow-downgrade -c rustfmt
}

fi # _REDSHELL_RUST
