# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Kagi search and API wrappers.

if [[ -z "${_REDSHELL_KAGI}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_KAGI=1

function kagi_search_json() {
     python_func \
        -p "${HOME}/.redshell/src/kagi/search.py" \
        search \
        --api_key "$(keys_key kagi)" \
        --query "${1}"
}

function kagi_summarize_json() {
    python_func \
        -p "${HOME}/.redshell/src/kagi/search.py" \
        summarize \
        --api_key "$(keys_key kagi)" \
        --url "${1}"
}

fi # _REDSHELL_KAGI
