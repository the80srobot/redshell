# # SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Stuff for Magic: The Gathering.

source "time.bash"

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
    if [[ -z "${age}" || "${age}" -gt "${max_age}" ]]; then
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

# function mtg_card_search() {
# 
# }

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

# Usage: mtg_card NAME
#
# Print the Magic: The Gathering card with the given name. (Case sensitive.)
function mtg_card() {
    local card_json=$(mtg_card_json "${@}")
    local count=$(jq 'length' <<< "${card_json}")

    [[ "${count}" -eq 0 ]] && {
        echo "Card not found." >&2
        return 1
    }

    local i=0
    while [[ "${i}" -lt "${count}" ]]; do
        local name="$(jq -r ".[${i}].name" <<< "${card_json}")"
        local mana_cost="$(jq -r ".[${i}].mana_cost" <<< "${card_json}")"
        local type_line="$(jq -r ".[${i}].type_line" <<< "${card_json}")"
        local oracle_text="$(jq -r ".[${i}].oracle_text" <<< "${card_json}")"
        local flavor_text="$(jq -r ".[${i}].flavor_text" <<< "${card_json}")"
        local power="$(jq -r ".[${i}].power" <<< "${card_json}")"
        local toughness="$(jq -r ".[${i}].toughness" <<< "${card_json}")"

        tput bold
        printf "%s %*s\n" "${name}" $((80 - ${#name})) "${mana_cost}"
        tput sgr0
        tput setaf 6
        printf "%s\n\n" "${type_line}"
        tput sgr0
        printf "%s\n" "${oracle_text}"
        tput setaf 8
        [[ "${flavor_text}" != "null" ]] && printf "\n%s\n" "${flavor_text}"
        tput sgr0
        [[ "${power}" != "null" ]] && printf "%*s %s/%s\n" $(( 79 - ${#power} - ${#toughness} )) " " "${power}" "${toughness}"
        echo
        ((i++))
    done
}

fi # _REDSHELL_MTG
