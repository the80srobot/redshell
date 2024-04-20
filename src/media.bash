# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

if [[ -z "${_REDSHELL_MEDIA}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_MEDIA=1

function yt-dl() {
    pkg_install_or_skip python ffmpeg
    local YTDL_DIR="$HOME/.redshell/yt-dl"
    mkdir -p "${YTDL_DIR}" && pushd "${YTDL_DIR}"
    {
        echo "ffmpeg-python>=0.2.0"
        echo "yt-dlp>=2023.11.16"
    } > requirements.txt
    venv
    popd
    yt-dlp "${@}"
    deactivate
}

fi # _REDSHELL_MEDIA
