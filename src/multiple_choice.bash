# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Interactive multiple choice prompts.

if [[ -z "${_REDSHELL_MULTIPLE_CHOICE}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_MULTIPLE_CHOICE=1

function __prompt() {
    local input="${1}"
    local page="${2}"
    local alphabet="${3}"
    local controls="${4}"
    local control_alphabet="${5}"

    local per_page="${#alphabet}"
    local offset=$(( page * per_page ))
    local limit=$(( offset + per_page ))

    # Control options appear on every page.
    local i=0
    [[ -z "${controls}" ]] || while IFS= read line; do
        local num="${control_alphabet:$i:1}"
        echo "$(tput setaf 3)(${num}):$(tput sgr0) ${line}"
        i=$(( i + 1))
    done <<< "${controls}"

    i=0
    while IFS= read line; do
        if [[ "${line:0:1}" == "	" ]]; then
            # Tab - don't count this line, but print it if we're within range.
            [[ "${i}" -gt "${offset}" ]] && echo "${line}"
        elif [[ "${i}" -lt "${offset}" ]]; then
            # Line is counted, but we're below the visible range.
            i=$(( i + 1))
        else
            if [[ "${i}" -ge "${limit}" ]]; then
                echo "$(tput setaf 5)(n)$(tput sgr0) Next page"
                break
            fi
            local j=$(( i % per_page ))
            local num="${alphabet:$j:1}"
            echo "$(tput setaf 2)(${num}):$(tput sgr0) ${line}"
            i=$(( i + 1))
        fi
    done <<< "${input}"

    [[ "${page}" -ge 1 ]] && echo "$(tput setaf 5)(p)$(tput sgr0) Previous page"
    echo "$(tput setaf 5)(q)$(tput sgr0) Cancel"
}

# Usage: __multiple_choice [-L|-n] INPUT [PAGE] [MSG] [ALPHABET] [CONTROLS] [CONTROL_ALPHABET]
function __multiple_choice() {
    local mode="-L"
    if [[ "${1}" == "-n" ]]; then
        mode="${1}"
        shift
    elif [[ "${1}" == "-L" ]]; then
        shift
    fi

    local input="${1}"
    local page="${2}"
    local msg="${3}"
    local alphabet="${4}"
    local controls="${5}"
    local control_alphabet="${6}"
    
    [[ -z "${page}" ]] && page=0
    [[ -z "${msg}" ]] && msg="Pick one"
    [[ -z "${alphabet}" ]] && alphabet="1234567890"

    local choices=`grep -vE --color=never '^\t' <<< "${input}"`
    local count=`echo "${choices}" | wc -l | tr -d ' '`
    local per_page="${#alphabet}"
    local max_page=$(( (count - 1) / per_page ))

    local prompt=`__prompt "${input}" "${page}" "${alphabet}" "${controls}" "${control_alphabet}"`
    prompt+="
Page $(( page + 1 ))/$(( max_page + 1 )) ${msg}: "

    read -n1 -p "${prompt}" x || return 2
    >&2 echo

    if [[ "${x}" == "q" ]]; then
        >&2 echo "Cancelled"
        return 3
    elif [[ "${x}" == "p" ]]; then
        if [[ "${page}" -eq 0 ]]; then
            __multiple_choice "${mode}" "${input}" "${max_page}" "${msg}" "${alphabet}" "${controls}" "${control_alphabet}"
        else
            __multiple_choice "${mode}" "${input}" $(( page - 1 )) "${msg}" "${alphabet}" "${controls}" "${control_alphabet}"
        fi
    elif [[ "${x}" == "n" ]]; then
        if [[ "${page}" == "${max_page}" ]]; then
            __multiple_choice "${mode}" "${input}" "0" "${msg}" "${alphabet}" "${controls}" "${control_alphabet}"
        else
            __multiple_choice "${mode}" "${input}" $(( page + 1 )) "${msg}" "${alphabet}" "${controls}" "${control_alphabet}"
        fi
    elif [[ "${control_alphabet}" == *"${x}"* ]]; then
        echo "${x}"
    elif [[ "${alphabet}" != *"${x}"* ]]; then
        >&2 echo "Invalid selection"
        __multiple_choice "${mode}" "${@}"
    else
        # Find the position of `x` in `alphabet`.
        local tmp="${alphabet%%$x*}"
        local n="${#tmp}"
        n=$(( n + page * per_page + 1 ))
        if [[ "${mode}" == "-n" ]]; then
            echo "${n}"
        else
            echo "${choices}" | tail -n+${n} | head -n1 | strip_control
        fi
    fi
}

# Usage: multiple_choice [-n|-L] [-i INPUT] [-p PAGE] [-m MSG] [-a ALPHABET] [-I CONTROLS] [-A CONTROL_ALPHABET]
#
# Display an interactive menu with multiple choices, and then print the selected option to stdout.
#
# -n: return the number of the selected option
# -L: return the string of the selected option
# -p: page number to show
# -m: prompt message
# -a: alphabet
# -I: control options
# -A: control alphabet
# -i: input (options to pick from)
function multiple_choice() {
    local mode="-L"
    local input
    local page
    local msg
    local alphabet
    local controls
    local control_alphabet

    while [[ "${#}" -ne 0 ]]; do
        if [[ "${1:0:1}" != "-" ]]; then
            >&2 echo "Invalid flag ${1}"
            return 1
        fi

        case "${1:1}" in
            n)
                mode="-n"
                shift
            ;;
            L)
                mode="-L"
                shift
            ;;
            i)
                input="${2}"
                shift
                shift
            ;;
            p)
                page="${2}"
                shift
                shift
            ;;
            m)
                msg="${2}"
                shift
                shift
            ;;
            a)
                alphabet="${2}"
                shift
                shift
            ;;
            I)
                controls="${2}"
                shift
                shift
            ;;
            A)
                control_alphabet="${2}"
                shift
                shift
            ;;
            *)
                >&2 echo "Invalid flag ${1}"
                return 1
            ;;
        esac
    done

    __multiple_choice "${mode}" "${input}" "${max_page}" "${msg}" "${alphabet}" "${controls}" "${control_alphabet}"
}

fi # _REDSHELL_MULTIPLE_CHOICE
