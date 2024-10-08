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
    # Line by line
    local line
    while read -r line; do
        # Single pips
        line="$(sed "s/{W}/$(tput setaf 11){W}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{U}/$(tput setaf 14){U}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{B}/$(tput setaf 8){B}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{R}/$(tput setaf 9){R}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{G}/$(tput setaf 2){G}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{C}/$(tput setaf 7){C}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{S}/$(tput setaf 8){S}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{T}/$(tput setaf 8){T}$(tput sgr0)/g" <<< "${line}")"

        # Combination pips
        line="$(sed "s/{W\/U}/$(tput setaf 11)$(tput setab 14){W\/U}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{W\/B}/$(tput setaf 11)$(tput setab 8){W\/B}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{U\/B}/$(tput setaf 14)$(tput setab 8){U\/B}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{U\/R}/$(tput setaf 14)$(tput setab 9){U\/R}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{B\/R}/$(tput setaf 8)$(tput setab 9){B\/R}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{B\/G}/$(tput setaf 8)$(tput setab 2){B\/G}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{R\/W}/$(tput setaf 9)$(tput setab 11){R\/W}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{R\/G}/$(tput setaf 9)$(tput setab 2){R\/G}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{G\/W}/$(tput setaf 2)$(tput setab 11){G\/W}$(tput sgr0)/g" <<< "${line}")"
        line="$(sed "s/{G\/U}/$(tput setaf 2)$(tput setab 14){G\/U}$(tput sgr0)/g" <<< "${line}")"

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

    tput bold
    printf "%s" "${name}"
    tput sgr0
    printf "%s%s\n" "$(strings_repeat " " $((80 - ${#name} - ${#mana_cost})))" "${mana_cost_color}"
    tput setaf 6
    printf "%s\n\n" "${type_line}"
    tput sgr0
    printf "%s\n" "$(fold -s -w 80 <<< "${oracle_text}" | __colorize_mana)"
    tput setaf 8
    [[ "${flavor_text}" != "null" ]] && printf "\n%s\n" "$(fold -s -w 80 <<< "${flavor_text}")"
    tput sgr0
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

fi # _REDSHELL_MTG
