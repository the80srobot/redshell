# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# News and weather.

if [[ -z "${_REDSHELL_NEWS}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_NEWS=1

function news_all() {
    news_weather "${@}"
    news_nytimes
    news_npr
    news_pbs
    news_register
    news_cnbc
}

function news_stocks() {
    python_pip_run tstock "${@}"
}

function news_weather() {
    curl wttr.in/"${1}"
}

function news_brutalist_report_source() {
    local source="${1}"
    links -dump "https://brutalist.report/source/${source}" \
        | tail -n +10 | grep "Previous Day" -B999 | grep -v "Previous Day"
}

function news_nytimes() {
    news_brutalist_report_source nytimes
}

function news_npr() {
    news_brutalist_report_source npr
}

function news_pbs() {
    news_brutalist_report_source pbsnewshour
}

function news_register() {
    news_brutalist_report_source register
}

function news_cnbc() {
    news_brutalist_report_source CNBC
}

fi # _REDSHELL_NEWS
