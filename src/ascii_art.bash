# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Assorted ascii art, screen drawing and speech bubbles.

source "strings.bash"
source "xterm_colors.bash"

if [[ -z "${_REDSHELL_ASCII_ART}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_ASCII_ART=1

function print_speech_bubble() {
    local width=0
    while IFS= read -r line; do
        local stripped="$(strings_strip_control <<< "${line}")"
        local w="${#stripped}"
        if (( w > width )); then
            width="${w}"
        fi
    done <<< "${1}"
    (( width++ ))

    echo "   $(repeat _ $width)_ "
    echo "  /$(repeat ' ' $width) \\"
    while IFS= read -r line; do
        echo -n "  | ${line}"
        local stripped="$(strings_strip_control <<< "${line}")"
        local l="${#stripped}"
        local p=$((width-l))
        for (( c=0; c<p; c++ )); do
            echo -n " "
        done
        echo "|"
    done <<< "$1"

    (( rpad = width ))
    echo "  / $(repeat _ $rpad)/"
    echo " / /$(repeat ' ' $rpad) "
    echo "/_/$(repeat ' ' $rpad)  "
    echo "$(repeat ' ' $rpad)   "
}

function erase_lines() {
    local n="${1}"
    local erase_cmd="el"
    [[ "${2}" == "-q" ]] && erase_cmd=""
    local cmd=""
    for (( i=0; i < n; i++ )); do
        cmd+="cuu1
${erase_cmd}
"
    done
    tput -S <<< "${cmd}"
}

function cursor_position() {
    local pos
    read -sdR -p $'\E[6n' pos
    pos=${pos#*[} # Strip decoration characters <ESC>[
    echo "${pos}" # Return position in "row;col" format
}

function cursor_row() {
    local row
    local col
    IFS=';' read -sdR -p $'\E[6n' row col
    echo "${row#*[}"
}

# echo -e "${bg}     ._________          `clr`" 
# echo -e "${bg}    /_________/|         `clr`" 
# echo -e "${bg}    |`light`.-------.`dark`||         `clr`" 
# echo -e "${bg}    |`light`|o   o  |`dark`||         `clr`" 
# echo -e "${bg}    |`light`|  -    |`dark`||         `clr`" 
# echo -e "${bg}    |`light`'-------'`dark`||         `clr`" 
# echo -e "${bg}    | ___  .  ||         `clr`" 
# echo -e "${bg}   /|         |\\         `clr`" 
# echo -e "${bg}  / | $(tput setaf 226)+   $(tput setaf 27)^`dark` $(tput setaf 34)o`dark` ||\\        `clr`" 
# echo -e "${bg}    | --   $(tput setaf 160)O`dark`  ||         `clr`" 
# echo -e "${bg}    '---------/          `clr`" 
# echo -e "${bg}      I     I            `clr`" 
# clr

function print_bmo() {
    # local bg="$(tput setab 235)$(tput setaf 50)"
    # local light="$(tput setaf 159)"
    # local dark="$(tput setaf 50)"
    local bg="$(tfmt 50 235)"
    local light="$(tfmt 159)"
    
}

function print_pedro() {
    local bgc=$(($RANDOM % 256))
    local fgc=$(($RANDOM % 256))
    while [[ $(contrast $(xterm_to_rgb $bgc) $(xterm_to_rgb $fgc)) -lt 70 ]]; do
        bgc=$(($RANDOM % 256))
        fgc=$(($RANDOM % 256))
    done

    local fc="$(tput setaf "${fgc}")"
    local bc="$(tput setab "${bgc}")"
    local clr="$(tput sgr0)"

    if [[ ! -z "${1}" ]]; then
        IFS=$'\n' read -r -d '' -a  lines <<< "${1}"
    fi

    local cols="$(tput cols)"
    ((cols -= 30))

    printf "
%s  ___            ___ %s %-${cols}s
%s /   \          /   \%s %-${cols}s
%s \__  \        /   _/%s %-${cols}s
%s  __\  \      /   /_ %s %-${cols}s
%s  \__   \____/  ___/ %s %-${cols}s
%s     \_       _/     %s %-${cols}s
%s  ____/  @ @ |       %s %-${cols}s
%s             |       %s %-${cols}s
%s       /\     \_     %s %-${cols}s
%s     _/ /\o)  (o\    %s %-${cols}s
%s        \ \_____/    %s %-${cols}s
%s         \____/      %s %-${cols}s\n" \
        "${fc}${bc}" "${clr}" "${lines[0]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[1]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[2]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[3]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[4]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[5]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[6]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[7]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[8]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[9]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[10]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[11]:0:${cols}}"
}

function scroll_output_pedro() {
    local path="${1}"
    print_pedro
    while IFS= read -r line; do
        erase_lines 13 -q
        print_pedro "$(tail -n 12 "${path}")"
    done
    echo
}


function select_visual() {
    # Make sure there's nothing there as we source bash_profile, to get the color
    # functions.
    VISUAL_CONFIG_PATH="$HOME/.redshell_visual"
    echo "" > "$VISUAL_CONFIG_PATH"

    if [[ -n "${1}" ]]; then
        echo "${1}" > "$VISUAL_CONFIG_PATH"
        source ~/.bash_profile
        return
    fi

    echo "Select visual identity"
    echo "(1)   None (DEFAULT)"
    echo -e "(2)   $(__prompt_color bmo)BMO$(tput sgr0)"
    echo -e "(3)   $(__prompt_color lighthouse)Lighthouse$(tput sgr0)"
    echo -e "(4)   $(__prompt_color astronaut)Astronaut$(tput sgr0)"
    echo -e "(5)   $(__prompt_color pacman)Pac-Man$(tput sgr0)"
    echo -e "(6)   $(__prompt_color dachshund)Eddie the Sausage Dog$(tput sgr0)"
    echo -e "(7)   $(__prompt_color saturn)Planet$(tput sgr0)"
    echo -e "(8)   $(__prompt_color drwho)TARDIS$(tput sgr0)"
    echo -e "(9)   $(__prompt_color snufkin)Snufkin$(tput sgr0)"
    echo -e "(a)   $(__prompt_color moose)Moose$(tput sgr0)"
    echo -e "(b)   $(__prompt_color bessy)Bessy$(tput sgr0)"

    read -n1 -p "Select 1-b or ENTER for default: " OPTION

    case "$OPTION" in
        1) echo "" > "$VISUAL_CONFIG_PATH" ;;
        2) echo "bmo" > "$VISUAL_CONFIG_PATH" ;;
        3) echo "lighthouse" > "$VISUAL_CONFIG_PATH";;
        4) echo "astronaut" > "$VISUAL_CONFIG_PATH";;
        5) echo "pacman" > "$VISUAL_CONFIG_PATH";;
        6) echo "dachshund" > "$VISUAL_CONFIG_PATH";;
        7) echo "saturn" > "$VISUAL_CONFIG_PATH";;
        8) echo "drwho" > "$VISUAL_CONFIG_PATH";;
        9) echo "snufkin" > "$VISUAL_CONFIG_PATH";;
        a) echo "moose" > "$VISUAL_CONFIG_PATH";;
        b) echo "bessy" > "$VISUAL_CONFIG_PATH";;
        *) echo "" > "$VISUAL_CONFIG_PATH" ;;
    esac

    echo
    echo "Done"

    source ~/.bash_profile
}

fi # _REDSHELL_ASCII_ART
