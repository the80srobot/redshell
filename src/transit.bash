# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Transit helpers.

source "python.bash"

if [[ -z "${_REDSHELL_TRANSIT}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_TRANSIT=1

function transit_sbb() {
    python_pip_run fahrplan --full "${@}"
}

fi # _REDSHELL_TRANSIT
