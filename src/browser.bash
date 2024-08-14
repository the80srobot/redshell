# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Browser automation, downloads, link generators.

if [[ -z "${_REDSHELL_BROWSER}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_BROWSER=1

function gdocs_id() {
    echo "$1" | perl -pe 's/^http.*\/d\/(.*)\/.*$/$1/'
}

function sheets_dl_link() {
    local format="csv"
    [[ -n "$2" ]] && format="$2"
    echo -n 
    printf "%s%s%s%s\n" \
        'https://docs.google.com/spreadsheets/d/' \
        "$(gdocs_id "$1")" \
        '/export?format=' \
        "$format"
}

function chrome_path() {    
    if [[ -f "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
        echo "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    else
        echo "google-chrome"
    fi
}

function downloads_path() {
    if [[ -d "$HOME/Downloads" ]]; then
        echo "$HOME/Downloads"
    else
        return 1
    fi

}

# Downloads a URL with the browser and returns the path to the downloaded file.
# This is finnicky and relies on the browser downloading to the default
# Downloads folder. If multiple new files are created around the same time, this
# might behave in unpredictable ways. You've been warned.
#
# Usage: browser_dl URL
function browser_dl() {
    local url="$1"
    local browser
    local old_files
    local cur_files
    local new_files
    browser="$(chrome_path)" || return 1
    local downloads
    downloads="$(downloads_path)" || return 2
    
    old_files="$(ls -1 "$downloads")"
    "$(chrome_path)" "$url" >&2
    echo "Waiting for download..." >&2
    while true; do
        cur_files="$(ls -1 "$downloads")"
        new_files="$(diff <(echo "$old_files") <(echo "$cur_files") | grep '^>')"
        [[ -n "$new_files" ]] && break
        sleep 1
    done
    # TODO(adam): What if there are multiple?
    echo "${downloads}/${new_files:2}"
    
    # On Darwin, try to switch back to the terminal.
    if [[ `uname -a` == *Darwin* ]]; then
        osascript -e 'tell application "Terminal" to activate'
    fi
}

fi # _REDSHELL_BROWSER
