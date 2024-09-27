# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Transit helpers.

if [[ -z "${_REDSHELL_TRANSIT}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_TRANSIT=1

function transit_sbb() {
    local dir=~/.redshell/transit_venv
    mkdir -p "${dir}"
    pushd "${dir}" > /dev/null
    venv --quiet || return 1
    which fahrplan > /dev/null || pip install fahrplan
    fahrplan --full "${@}"
    deactivate
    popd > /dev/null
}

fi # _REDSHELL_TRANSIT
