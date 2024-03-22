# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_RUST}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_RUST=1

function rustup() {
    which rustup > /dev/null || {
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
        source ~/.bash_profile
    }
    "$(which rustup)" "${@}"
}

function rust_install_goodies() {
    rustup component add rust-src --toolchain nightly
    rustup toolchain install nightly
    rustup toolchain install nightly --allow-downgrade -c rustfmt
}

fi # _REDSHELL_RUST
