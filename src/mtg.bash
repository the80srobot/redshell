# # SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Stuff for Magic: The Gathering.

source "time.bash"
source "multiple_choice.bash"

if [[ -z "${_REDSHELL_MTG}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_MTG=1

function __mtg_latest_scryfall_oracle_cards_uri() {
    curl https://api.scryfall.com/bulk-data \
        | jq -r '.data[] | select(.type == "oracle_cards") | .download_uri'
}

# Usage: mtg_oracle_json
#
# Fetch the latest oracle cards from Scryfall and return the path to the JSON
# dump. The dump is cached for about two weeks.
function mtg_oracle_json() {
    local persist=~/.scryfall/oracle-cards.json
    local max_age=1000000
    local age
    [[ -f "${persist}" ]] && age="$(file_age -s "${persist}")"
    if [[ -z "${age}" || ( "${age}" -gt "${max_age}" && net_online ) ]]; then
        echo "Fetching latest oracle cards from Scryfall..." >&2
        mkdir -p "$(dirname "${persist}")"
        local uri=$(__mtg_latest_scryfall_oracle_cards_uri)
        curl "${uri}" > "${persist}" || {
            rm -f "${persist}"
            return 1
        }
    fi
    echo "${persist}"
}

function mtg_rules() {
    local url="https://gist.githubusercontent.com/the80srobot/6f9b83a7b930830ab454d1697c547120/raw/17572b00ccddee652eabf1028945aa17093f7f24/MTG%2520Rules"
    local persist=~/.scryfall/mtg-rules.txt
    local max_age=1000000
    local age
    [[ -f "${persist}" ]] && age="$(file_age -s "${persist}")"
    if [[ -z "${age}" || "${age}" -gt "${max_age}" ]]; then
        echo "Fetching latest MTG rules from gist..." >&2
        mkdir -p "$(dirname "${persist}")"
        curl "${url}" > "${persist}" || {
            rm -f "${persist}"
            return 1
        }
    fi
    cat "${persist}"
}

# Usage: mtg_card_json NAME
#
# Return the JSON object for the card with the given name. (Case sensitive.)
function mtg_card_json() {
    local name="${*}"
    local json_path=$(mtg_oracle_json)
    jq -r "map(select(.name == \"${name}\"))" "${json_path}"
}

function __mtg_approx_match() {
    local tmp=$(mktemp)
    local matches
    jq -r '.[].name' "$(mtg_oracle_json)" > "${tmp}"
    matches="$(ug -iw --fuzzy=best2 "${*}" "${tmp}")"
    [[ -z "${matches}" ]] && {
        return 1
    }
    rm -f "${tmp}"
    echo "${matches}"
}

function __colorize_mana() {
    # ANSI color codes for mana symbols
    local RST=$'\033[0m'
    local W=$'\033[93m'      # bright yellow (White)
    local U=$'\033[96m'      # bright cyan (Blue)
    local B=$'\033[90m'      # gray (Black)
    local R=$'\033[91m'      # bright red (Red)
    local G=$'\033[32m'      # green (Green)
    local C=$'\033[37m'      # white (Colorless)
    # Background colors for hybrid mana
    local BG_W=$'\033[48;5;11m'
    local BG_U=$'\033[48;5;14m'
    local BG_B=$'\033[48;5;8m'
    local BG_R=$'\033[48;5;9m'
    local BG_G=$'\033[48;5;2m'

    # Line by line
    local line
    while read -r line; do
        # Single pips
        line="${line//\{W\}/${W}\{W\}${RST}}"
        line="${line//\{U\}/${U}\{U\}${RST}}"
        line="${line//\{B\}/${B}\{B\}${RST}}"
        line="${line//\{R\}/${R}\{R\}${RST}}"
        line="${line//\{G\}/${G}\{G\}${RST}}"
        line="${line//\{C\}/${C}\{C\}${RST}}"
        line="${line//\{S\}/${B}\{S\}${RST}}"
        line="${line//\{T\}/${B}\{T\}${RST}}"

        # Combination pips
        line="${line//\{W\/U\}/${W}${BG_U}\{W\/U\}${RST}}"
        line="${line//\{W\/B\}/${W}${BG_B}\{W\/B\}${RST}}"
        line="${line//\{U\/B\}/${U}${BG_B}\{U\/B\}${RST}}"
        line="${line//\{U\/R\}/${U}${BG_R}\{U\/R\}${RST}}"
        line="${line//\{B\/R\}/${B}${BG_R}\{B\/R\}${RST}}"
        line="${line//\{B\/G\}/${B}${BG_G}\{B\/G\}${RST}}"
        line="${line//\{R\/W\}/${R}${BG_W}\{R\/W\}${RST}}"
        line="${line//\{R\/G\}/${R}${BG_G}\{R\/G\}${RST}}"
        line="${line//\{G\/W\}/${G}${BG_W}\{G\/W\}${RST}}"
        line="${line//\{G\/U\}/${G}${BG_U}\{G\/U\}${RST}}"

        echo -e "${line}"
    done
}

function __print_card() {
    local name="$(jq -r ".name" <<< "${1}")"
    local mana_cost="$(jq -r ".mana_cost" <<< "${1}")"
    local mana_cost_color="$(__colorize_mana <<< "${mana_cost}")"
    local type_line="$(jq -r ".type_line" <<< "${1}")"
    local oracle_text="$(jq -r ".oracle_text" <<< "${1}")"
    local flavor_text="$(jq -r ".flavor_text" <<< "${1}")"
    local power="$(jq -r ".power" <<< "${1}")"
    local toughness="$(jq -r ".toughness" <<< "${1}")"

    echo -ne '\033[1m'
    printf "%s" "${name}"
    echo -ne '\033[0m'
    printf "%s%s\n" "$(strings_repeat " " $((80 - ${#name} - ${#mana_cost})))" "${mana_cost_color}"
    echo -ne '\033[36m'
    printf "%s\n\n" "${type_line}"
    echo -ne '\033[0m'
    printf "%s\n" "$(fold -s -w 80 <<< "${oracle_text}" | __colorize_mana)"
    echo -ne '\033[90m'
    [[ "${flavor_text}" != "null" ]] && printf "\n%s\n" "$(fold -s -w 80 <<< "${flavor_text}")"
    echo -ne '\033[0m'
    [[ "${power}" != "null" ]] && printf "%*s %s/%s\n" $(( 78 - ${#power} - ${#toughness} )) " " "${power}" "${toughness}"
    echo
}

# Usage: mtg_card NAME
#
# Print the Magic: The Gathering card with the given name. (Case sensitive.)
function mtg_card() {
    local card_json=$(mtg_card_json "${@}")
    local count=$(jq 'length' <<< "${card_json}")

    [[ "${count}" -eq 0 ]] && {
        echo "No card named '${*}' found - checking approximate matches." >&2
        local approx
        approx=$(__mtg_approx_match "${@}") || {
            echo "No approximate matches found." >&2
            return 1
        }

        local choice
        choice=$(multiple_choice -L -i "${approx}" -m "Did you mean any of these?") || {
            echo "User cancelled." >&2
            return 2
        }
        mtg_card "${choice}"
    }

    local i=0
    # TODO: Multiple faces. Do them like separate cards.
    while [[ "${i}" -lt "${count}" ]]; do
        if [[ $(jq ".[${i}][\"card_faces\"] | length" <<< "${card_json}") -eq 2 ]]; then
            __print_card "$(jq -r ".[${i}][\"card_faces\"][0]" <<< "${card_json}")"
            __print_card "$(jq -r ".[${i}][\"card_faces\"][1]" <<< "${card_json}")"
        else
            __print_card "$(jq -r ".[${i}]" <<< "${card_json}")"
        fi
        ((i++))
    done
}

# Lists cards that are relevant for normal 60-card play.
function __relevant_cards() {
    jq -r '
        .[]
        | select(
            .object == "card"
            and (.lang == "en")
            and (.layout != "token")
            and (.games | index("paper") != null)
            and .oversized == false
            and .digital == false
            # Filter out layouts that are not real cards
            and (.layout != "art_series" and .layout != "double_faced_token"
                 and .layout != "emblem" and .layout != "vanguard")
            # Filter out cards that are not legal in normal formats.
            and (.legalities.standard == "legal"
                 or .legalities.future == "legal"
                 or .legalities.modern == "legal"
                 or .legalities.pioneer == "legal"
                 or .legalities.legacy == "legal")
        )' \
        "$(mtg_oracle_json)"
}

fi # _REDSHELL_MTG
