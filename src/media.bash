# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_MEDIA}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_MEDIA=1

function yt-dl() {
    local path="${HOME}/.readshell/yt-dl-env"
    pkg_install_or_skip python ffmpeg
    mkdir -p "${path}"
    pushd "${path}"
    venv
    pip install yt-dlp
    popd
    yt-dlp "${@}"
    deactivate
}


fi # _REDSHELL_MEDIA
