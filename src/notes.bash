# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

source "keys.bash"
source "file.bash"

if [[ -z "${_REDSHELL_NOTES}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_NOTES=1

# Note management based on git and markdown.

NOTES_ROOT="${HOME}/.mnotes"
NOTES_REPO="${NOTES_ROOT}/notes"

[[ -z "${TERM}" ]] && export TERM=xterm
_SGR0=$(tput sgr0)
_BOLD=$(tput bold)
_PATH_COLOR=$(tput setaf 6)
_SECTION_COLOR=$(tput setaf 3)
_TIME_COLOR=$(tput setaf 3)
_EXTRA_COLOR=$(tput setaf 4)
_DISABLED_COLOR=$(tput setaf 8)
_WARNING_COLOR=$(tput setaf 3)
_ERROR_COLOR=$(tput setaf 1)

NOTES_MAX_TODO_LEN=90

function __elide() {
    local text="${1}"
    local lim="${2}"
    local l="${#text}"
    if [[ "${l}" -gt "${lim}" ]]; then
        local llen=$(( lim - 25 ))
        echo "${text:0:$llen}${_DISABLED_COLOR}(...)${_SGR0}${text: -20}"
    else
        echo "${text}"
    fi
}

function __file_mtime_and_age() {
    local path="${1}"
    local d
    local ds
    local now=`date +%s`

    if [[ "$(uname)" == "Darwin" ]]; then
        d=`date -r "${path}" "+%Y-%m-%d %H:%M:%S"`
        ds=`date -j -f "%Y-%m-%d %H:%M:%S" "${d}" +%s`
    else
        ds=`stat -c %Y "${path}"`
        d=`date -d "@${ds}" "+%Y-%m-%d %H:%M:%S"`
    fi

    local a
    local age_seconds=$(( now - ds ))
    if (( age_seconds < 60 )); then
        a="${age_seconds} s"
    elif (( age_seconds < 3600 )); then
        a="$(( age_seconds / 60 )) m"
    elif (( age_seconds < 86400 )); then
        a="$(( age_seconds / 3600 )) h"
    else
        a="$(( age_seconds / 86400 )) d"
    fi

    printf "%s\t%s" "${d}" "${a}"
}

function __notes_api_list_notes_batch() {
    local filter
    if [[ "${1}" == "-a" ]]; then
        filter="not_archived"
    elif [[ "${1}" == "-A" ]]; then
        filter="all"
    else
        >&2 echo "Invalid call - batch function requires the first arg to be -a or -A"
        exit 1
    fi
    shift

    while [[ "${#}" -ne 0 ]]; do
        local path="${1}"
        local t
        local title
        shift

        local archived="-"
        if [[ -d "${path}" ]]; then
            t="d"
            title="-"
        else
            t="f"
            title="$(head -n1 "${path}")"
            title="${title:2}"
        fi
        if [[ "${#title}" -ge 9 && "${title:0:9}" == "ARCHIVED " ]]; then
            title="${title:9}"
            [[ "${filter}" == "not_archived" ]] && continue
            archived="A"
        fi

        local prefix=$(( "${#NOTES_REPO}" + 1 ))
        [[ "${path:0:$prefix}" == "${NOTES_REPO}/" ]] && local relpath="${path:$prefix}"
        local slashes="${relpath//[^\/]}"
        local depth="${#slashes}"
        

        local qtitle="${title}"
        [[ "${qtitle:0:10}" == "Quick todo" ]] && qtitle="$(grep TODO "${path}")"
        [[ -z "${qtitle}" ]] && qtitle="(Deleted TODO)"

        local location="g"
        # This is the proper check, however it's slow:
        # notes_api_git check-ignore -q "${path}" && location="l"
        # Therefore, hack:
        [[ "${relpath:0:6}" == "local/" ]] && location="l"

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "${relpath}" \
            "$(__file_mtime_and_age "${path}")" \
            "$(__nonempty_wc_l "${path}")" \
            "${depth}" \
            "${path}" \
            "${t}" \
            "${title}" \
            "${location}" \
            "$(dirname "${relpath}")" \
            "${qtitle}" \
            "${archived}"
    done
}

# Usage: notes_note [NOTE]
#
# Saves the provided note, intelligently placing it and generating a title. If
# run with no arguments, instead opens vim and saves whatever is entered into
# the file.
function notes_note() {
    __preamble

    if [[ "$1" == "-s" ]]; then
        local sync="sync"
        shift
        notes_api_git pull
    fi

    if [[ "${#}" -eq 0 ]]; then
        local tmp=`mktemp`
        >&2 echo "Editing temp file ${tmp}"
        vim "${tmp}"
        local input=`cat "${tmp}"`
    else
        local input="${*}"
    fi

    local f
    f=`__notes_gen "${input}"` || return 1
    notes_api_git commit -m "$(basename "${f}")" -m "${text}" > /dev/null
    
    if [[ "${sync}" == "sync" ]]; then
        notes_api_git push
    fi

    cat "${NOTES_REPO}/${f}"
}

function notes_list() {
    __preamble
    local data="$(notes_api_list_notes -f "${@}" | sort -r -k2)"
    local text
    local cols
    local width=0
    [[ -z "${data}" ]] && return 1

    # This might be empty, if we're running with no params.
    # Used to highlight matching text in the output.
    local grep_needle
    local grep_flags="iwnE"
    for arg in "${@}"; do
        [[ "${arg:0:1}" == "-" || "${arg:0:1}" == "@" || "${arg:0:1}" == "-" ]] || grep_needle+="${arg}|"
        # If notes_api_list_notes is getting the -W flag, then it'll return partial
        # word matches, and we should highlight those, so we need to drop the -w
        # flag for grep.
        [[ "${arg}" == "-W" ]] && grep_flags="inE"
    done
    [[ -z "${grep_needle}" ]] || grep_needle="${grep_needle:0:-1}"

    while IFS= read line; do
        IFS=$'\t' read -r -a cols <<< "${line}" # Faster than cut
        local title="${cols[10]}"
        local w="${#title}"
        (( width < w )) && width="${w}"
        (( width > 50 )) && width=50
    done <<< "${data}"

    while IFS= read line; do
        IFS=$'\t' read -r -a cols <<< "${line}"
        local archived="${cols[11]}"
        local title="${cols[10]}"
        local title_color=""
        local attribute_color="${_DISABLED_COLOR}"
        [[ "${archived}" == "A" ]] && title_color="${_DISABLED_COLOR}" && attribute_color="${_ERROR_COLOR}"
        local w="${#title}"
        (( w > 50 )) && title="$(__elide "${title}" 50)"
        text+="${_SGR0}${title_color}${title}${_SGR0}${_DISABLED_COLOR} ."
        for (( i=w; i < width; i++ )); do
            text+="."
        done
        local age="$(printf '%5s' "${cols[2]}")"
        local lines="$(printf '%3s' "${cols[3]}")"
        text+=" ${_SGR0}${attribute_color}${archived} ${_DISABLED_COLOR}${cols[1]} ${_TIME_COLOR}${age} ago ${_EXTRA_COLOR}${lines} lines ${_PATH_COLOR}@${cols[9]}${_SGR0}"$'\n'

        [[ -z "${grep_needle}" ]] && continue
        local grep_lines="$(grep --color=always -"${grep_flags}" "${grep_needle}" "${cols[5]}")"
        [[ -z "${grep_lines}" ]] && continue
        while IFS= read grep_line; do
            grep_line="$(perl -pe "s/^(\\d+):/${_PATH_COLOR}Line \\1: ${_SGR0}/" <<< "${grep_line}")"
            text+=$'\t'"${grep_line}"$'\n'
        done <<< "${grep_lines}"
    done <<< "${data}"
    
    text="${text:0:-1}" # trailing \n

    local i
    i="$(multiple_choice -n -i "${text}")" || return $?

    local record="$(echo "${data}" | tail "-n+${i}" | head -n1)"
    local path="$(echo "${record}" | cut -f1)"
    >&2 echo "Selected: ${_BOLD}$(echo "${record}" | cut -f8)${_SGR0}${_PATH_COLOR} ($(echo "${record}" | cut -f6))${_SGR0}"
    op=$(multiple_choice -n -i "Edit the file ${_PATH_COLOR}${path}${_SGR0}
Drop the file ${_PATH_COLOR}${path}${_SGR0}
Cat the file ${_PATH_COLOR}${path}${_SGR0}
HTTP serve ${_PATH_COLOR}${path}${_SGR0}
Return the absolute path" -m "Select operation" -a "edcsf") || notes_list "${@}"

    case "${op}" in
        1)
            notes_api_edit_note "${path}"
        ;;
        2)
            notes_api_drop_note "${path}"
        ;;
        3)
            [[ -z "${grep_needle}" ]] \
                && cat "${NOTES_REPO}/${path}" \
                || grep -C 100000 --color=always -iEw "${grep_needle}" "${NOTES_REPO}/${path}"
        ;;
        4)
            bash -c "sleep 1 && open http://127.0.0.1:8081" &
            cat "${NOTES_REPO}/${path}" | strings_strip_control | util_markdown | net_serve
        ;;
        5)
            echo "${NOTES_REPO}/${path}"
        ;;
        *)
            return 1
        ;;
    esac
    notes_list "${@}"
}

function notes_sync() {
    __preamble
    notes_api_git pull --rebase
    notes_api_git push
    notes_api_fsck
    notes_gc
}

# Usage: notes_todo [TERM ...]
#
# Shows an interactive listing of matching TODOs.
#
# Uses the following categories:
#   A - 💬 - Asynchronous Comms
#   B - 💰 - Bank
#   C - 📅 - Calendar
#   E - 🏃 - Errand
#   H - 🏠 - Home
#   M - 👥 - Meeting
#   L - 💩 - Long Task
#   O - 👔 - Office
#   R - 📚 - Reading
#   S - 🛒 - Shopping
#   T - 📞 - Telephone
#   W - 📝 - Writing
#   X - 🛠️ - Technical Task
#   Z - ⏩ - Misc Quick Task
#   📥 - Inbox
function notes_todo() {
    __preamble
    local todo
    todo=$(__select_todo "${@}") || return 2
    IFS=$'\t' read -r -a cols <<< "${todo}"

    local state="[ ]"
    [[ "${cols[2]}" == "DONE" ]] && state="${_DISABLED_COLOR}[x]"
    local text="${cols[3]}"
    local age="${cols[5]}"
    local path="${cols[0]}"
    local abspath="${cols[4]}"
    local lno="${cols[1]}"

    echo -e "Selected: ${state} ${text} ${_TIME_COLOR}(${age} ago) ${_PATH_COLOR}${path}:${lno}${_SGR0}"
    local op
    op=$(multiple_choice -n -i "Mark done
Mark not done
Delete the whole line $(tput setaf 6)${path}:${lno}$(tput sgr0)
Edit the file $(tput setaf 6)${path}$(tput sgr0)" -m "Select operation" -a "xXde") || notes_todo "${@}"

    local before=$(cat "${abspath}" | head -n$(( lno - 1 )))
    local after=$(cat "${abspath}" | tail -n+$(( lno + 1 )))
    local line=$(cat "${abspath}" | tail -n+$lno | head -n1)
    case "${op}" in
        1)
            >&2 echo "Mark done"
            echo "${before}" > "${abspath}"
            echo "${line}" | sed 's/TODO/DONE/' >> "${abspath}"
            echo "${after}" >> "${abspath}"
            notes_api_git add "${abspath}"
            notes_api_git commit -m "Mark ${path}:${lno} as done"
        ;;
        2)
            >&2 echo "Mark not done"
            echo "${before}" > "${abspath}"
            echo "${line}" | sed 's/DONE/TODO/' >> "${abspath}"
            echo "${after}" >> "${abspath}"
            notes_api_git add "${abspath}"
            notes_api_git commit -m "Mark ${path}:${lno} as TODO"
        ;;
        3)
            >&2 echo "Delete the whole line ${path}:${lno}"
            echo "${before}" > "${abspath}"
            echo "${after}" >> "${abspath}"
            notes_api_git add "${abspath}"
            notes_api_git commit -m "Delete TODO line ${path}:${lno}"
        ;;
        4)
            >&2 echo "Edit the file ${path}"
            notes_api_edit_note "${path}" "${lno}"
        ;;
        *)
        return 0
        ;;
    esac

    notes_todo "${@}"
}

# Usage: notes_undo [-f]
#
# Undoes the last note change. If the last change was to a local note, it will
# refuse to undo it, unless -f is passed.
function notes_undo() {
    # TODO: Rebuild this on top of notes_api_ functions.
    if [[ "$1" == "-f" ]]; then
        shift
        local force="force"
    fi

    local lastf=`nhist | head -n1 | cut -f3`

    if [[ "${lastf:0:6}" == "local/" ]]; then
        >&2 echo "Warning: the most recent change was to a local note, not tracked in git!"
        if [[ "${force}" != "force" ]]; then
            >&2 echo "Pass -f to force undo anyway."
            return 1
        fi
    fi

    notes_api_git reset HEAD~ --hard
}

# Usage: notes_perl PROG [TERM ...]
#
# Applies the provided perl program to matching notes to generate replacements.
# Then allows the user to select which replacements to save.
function notes_perl() {
    __preamble

    local preview
    local cols
    local marks=()
    local paths=()
    # TODO: This doesn't properly exit when the perl program is fucked up.
    preview="$(notes_api_perl_preview "${@}" | sort)" || return $?
    while IFS= read line; do
        IFS=$'\t' read -r -a cols <<< "${line}"
        [[ "${cols[2]}" == "-" ]] || continue
        marks+=(" ")
        paths+=("${cols[10]}")
    done <<< "${preview}"

    local text
    local choice
    local controls="Select All
Deselect All
Apply Changes"
    while true; do
        text="$(__nperl_render_preview "${preview}" "${marks[@]}")" || return 2
        choice="$(multiple_choice -n -i "${text}" -I "${controls}" -A 'ads' -m 'Select files to apply changes')" || return "$?"

        case "${choice}" in
            a)
                local i=0
                for _ in "${marks[@]}"; do
                    marks["$i"]="X"
                    (( i+=1 ))
                done
            ;;
            d)
                local i=0
                for _ in "${marks[@]}"; do
                    marks["$i"]=" "
                    (( i+=1 ))
                done
            ;;
            s)
                i=0
                local c=0
                local path
                for path in "${paths[@]}"; do
                    [[ "${marks[$i]}" == "X" ]] && __nperl_apply "${path}" "${@}" && (( c+=1 ))
                    (( i+=1 ))
                done
                notes_api_git commit -m "Apply perl -pe to ${c} files"
                return 0
            ;;
            *)
                (( i=choice-1 ))
                [[ "${marks[$i]}" == "X" ]] && marks["${i}"]=" " || marks["${i}"]="X"
            ;;
        esac
    done
}

# Usage: notes_api_list_notes [-f] [-a] [TERM ...]
# Outputs a list of notes files that match the given terms.
#
# Options:
# -f: Only match files, not directories.
# -a: Include archived files.
# -w: Match whole words.
#
# Outputs:
# 1. relative path
# 2. mtime
# 3. age
# 4. line count
# 5. depth
# 6. absolute path
# 7. type (f or d)
# 8. title
# 9. location (g=git or l=local)
# 10. base path
# 11. Quick-TODO-aware title
# 12. Archived (A if archived - if not)
function notes_api_list_notes() {
    local mode="all"
    # Filter for the xargs batch closure. -a means only live files, -A includes
    # archived files.
    local batch_filter="-a"
    local terms=()

    # Handle the flags -a and -f here, forward the remaining args.
    while [[ "${#}" -ne 0 ]]; do
        if [[ "${1}" == "-f" ]]; then
            mode="files"
        elif [[ "${1}" == "-a" ]]; then
            batch_filter="-A"
        else
            terms+=("${1}")
        fi
        shift
    done

    export -f __notes_api_list_notes_batch __file_mtime_and_age __nonempty_wc_l notes_api_git
    export NOTES_REPO NOTES_MAX_TODO_LEN _SGR0 _DISABLED_COLOR

    local data
    if [[ "${#terms[@]}" -ne 0 ]]; then
        notes_api_match_files "${terms[@]}" \
            | __NOTES_BATCH_FILTER="${batch_filter}" \
            xargs -P`nproc` -J{} -n 10 bash -c '__notes_api_list_notes_batch "${__NOTES_BATCH_FILTER}" "${@}"' _ {}
        [[ "${mode}" == "all" ]] && \
            notes_api_find -type d -and -not -ipath "*.git*" -and -not -iname ".*" \
                | __NOTES_BATCH_FILTER="${batch_filter}" \
                xargs -P`nproc` -J{} -n 10 bash -c '__notes_api_list_notes_batch "${__NOTES_BATCH_FILTER}" "${@}"' _ {}
    elif [[ "${mode}" == "files" ]]; then
        notes_api_find -iname "*.md" -depth +0 \
            | __NOTES_BATCH_FILTER="${batch_filter}" \
            xargs -P`nproc` -J{} -n 10 bash -c '__notes_api_list_notes_batch "${__NOTES_BATCH_FILTER}" "${@}"' _ {}
    else
        notes_api_find \( \( -type d -and -not -ipath "*.git*" -and -not -iname ".*" \) -or -iname "*.md" \) -depth +0 \
            | __NOTES_BATCH_FILTER="${batch_filter}" \
            xargs -P`nproc` -J{} -n 10 bash -c '__notes_api_list_notes_batch "${__NOTES_BATCH_FILTER}" "${@}"' _ {}
    fi
}

function __nonempty_wc_l() {
    if [[ ! -f "${1}" ]]; then
        echo "0"
        return
    fi
    local line
    local c=0
    # Much faster than wc -l.
    while IFS= read line; do
        [[ -z "${line}" ]] && continue
        (( c++ ))
    done < "${1}"
    echo "${c}"
}

# Usage: notes_backup
#
# Backs up the notes repository to a timestamped tarball in the notes root.
function notes_backup() {
    local olddir=$(pwd)
    cd "${NOTES_ROOT}"

    local h=`uname -n`
    local d=`date +"%Y%m%d%H%M%S%Z"`

    tar -czf "backup_${h}_${d}.tgz" notes

    echo "${NOTES_ROOT}/backup_${h}_${d}.tgz"

    cd "${olddir}"
}

# Usage: notes_api_edit_notes
#
# Lists empty notes.
function notes_api_empty_notes() {
    local prefix="${#NOTES_REPO}"
    export -f __nonempty_wc_l
    notes_api_find -iname "*.md" -exec bash -c 'echo -ne "{}\t" && __nonempty_wc_l "{}"' \; \
    | while IFS= read line; do
        local n=$(cut -f2 <<< "${line}")
        if (( n < 3 )); then
            local f=$(cut -f1 <<< "${line}")
            echo "${f:$prefix+1}"
        fi
    done
}

function __date_add() {
    local ref="${1}"
    local duration="${2}"
    local d=$(__parse_age "${duration}")
    if [[ "$(uname)" == "Darwin" ]]; then
        date -v "+${d}d" -j -f "%Y-%m-%d" "${ref}" +"%Y-%m-%d"
    else
        date -d "${ref} + ${d} days" +"%Y-%m-%d"
    fi
}

function __wday() {
    local ref="${1}"
    if [[ "$(uname)" == "Darwin" ]]; then
        date -j -f "%Y-%m-%d" "${ref}" +"%w"
    else
        date -d "${ref}" +"%w"
    fi
}

function __date_sub() {
    local d1
    local d2
    if [[ "$(uname)" == "Darwin" ]]; then
        d1=$(date -j -f "%Y-%m-%d" "${1}" +%s)
        d2=$(date -j -f "%Y-%m-%d" "${2}" +%s)
    else
        d1=$(date -d "${1}" +%s)
        d2=$(date -d "${2}" +%s)
    fi
    echo $(( (d1 - d2) / 86400 ))
}

function __date_convert() {
    local d="${3}"
    local from="${1}"
    local to="${2}"
    if [[ "$(uname)" == "Darwin" ]]; then
        date -j -f "${from}" "${d}" +"${to}"
    else
        # GNU date doesn't use -f, it auto-detects common formats
        # For the specific format used in this codebase (%Y-%m-%d %H:%M:%S to %Y-%m-%d)
        date -d "${d}" +"${to}"
    fi
}

function __wday_number() {
    local d=$(tr '[:upper:]' '[:lower:]' <<< "${1}")
    case "${d}" in
        sunday)
            echo "0"
        ;;
        monday)
            echo "1"
        ;;
        tuesday)
            echo "2"
        ;;
        wednesday)
            echo "3"
        ;;
        thursday)
            echo "4"
        ;;
        friday)
            echo "5"
        ;;
        saturday)
            echo "6"
        ;;
        *)
            return 1
        ;;
    esac
}

function __relative_moment() {
    local ref="${1}"
    local duration="${2}"
    local exact="${3}"
    local wday=$(tr '[:upper:]' '[:lower:]' <<< "${4}")

    if [[ ! -z "${duration}" ]]; then
        __date_add "${ref}" "${duration}"
    elif [[ ! -z "${exact}" ]]; then
        echo "${exact}"
    elif [[ "${wday}" == "today" ]]; then
        echo "${ref}"
    elif [[ ! -z "${wday}" ]]; then
        duration=$(__wday_number "${wday}") || return 2
        local ref_wday="$(__wday "${ref}")"
        duration=$(( duration - ref_wday ))
        (( duration < 0 )) && duration=$(( duration + 7 ))
        __date_add "${ref}" "${duration}d"
    else
        return 1
    fi
}

function __when() {
    local text="${1}"
    local ref="${2}"
    [[ -z "${ref}" ]] && ref=$(date +"%Y-%m-%d")
    
    local specs=$(grep -oE '(AFTER|BEFORE|ON)\s*(\d+\s?[dwm]|\d{4}-\d{2}-\d{2}|[a-zA-Z]+day)' <<< "${text}" \
        | perl -pe 's/(AFTER|BEFORE|ON)\s*(\d+\s?[dwm])?(\d{4}-\d{2}-\d{2})?([a-zA-Z]+day)?/\1,\2,\3,\4/')
    
    local start
    local end
    # An interval may be given in four ways:
    # 1. ON - specified an interval lasting a single day
    # 2. AFTER - an interval beginning on the day and ending never, inclusive of
    #    the first day
    # 3. BEFORE - inverse of AFTER
    # 4. Both AFTER and BEFORE - a finite interval
    #
    # All other combinations are invalid.
    while IFS= read line; do
        IFS=',' read -r -a cols <<< "${line}"
        # 0. verb: AFTER|BEFORE|ON
        # 1. duration
        # 2. exact date
        # 3. day of the week
        case "${cols[0]}" in
            ON)
                [[ ! -z "${start}" ]] && return 1
                [[ ! -z "${end}" ]] && return 1
                start=$(__relative_moment "${ref}" "${cols[1]}" "${cols[2]}" "${cols[3]}")
                end="${start}"
            ;;
            AFTER)
                [[ ! -z "${start}" ]] && return 1
                start=$(__relative_moment "${ref}" "${cols[1]}" "${cols[2]}" "${cols[3]}")
            ;;
            BEFORE)
                [[ ! -z "${end}" ]] && return 1
                end=$(__relative_moment "${ref}" "${cols[1]}" "${cols[2]}" "${cols[3]}")
            ;;
            *)
                # We can get her if the input is invalid or empty.
                echo -e "\t" # We promise to output two columns.
                return 3
        esac
    done <<< "${specs}"
    echo -e "${start}\t${end}"
}

function __notes_api_list_todos_batch() {
    local prefix="${#NOTES_REPO}"
    local today="$(date +'%Y-%m-%d')"
    local want_context="$(echo "${1}" | xargs)"
    shift
    while [[ "${#}" -ne 0 ]]; do
        local line="${1}"
        shift

        IFS=$'\t' read -r -a cols <<< "${line}"
        local path="${cols[0]:$prefix + 1}"
        local age="$(file_age "${cols[0]}")"
        local mtime="$(file_mtime "${cols[0]}")"

        # Skip if file_mtime or file_age failed (file doesn't exist or is inaccessible)
        if [[ -z "${mtime}" || -z "${age}" ]]; then
            >&2 echo "Warning: Skipping ${cols[0]} - could not get file modification time"
            continue
        fi

        local mdate="$(__date_convert "%Y-%m-%d %H:%M:%S" "%Y-%m-%d" "${mtime}")"
        local interval="$(__when "${cols[4]}" "${mdate}")"
        local start="$(cut -f1 <<< "${interval}")"
        local end="$(cut -f2 <<< "${interval}")"
        local context="$(echo "${cols[3]}" | xargs)"

        if [[ ! -z "${want_context}" && "${context}" != "${want_context}" ]]; then
            continue
        fi

        local state="TODO"

        if [[ ! -z "${end}" && "${end}" < "${today}" ]]; then
            state="OVERDUE"
        elif [[ ! -z "${start}" && "${start}" > "${today}" ]]; then
            state="LATER"
        elif [[ ! -z "${end}" && "$(__date_sub "${end}" "${today}")" -le 3 ]]; then
            state="SOON"
        fi

        [[ "${cols[2]}" == "DONE" ]] && state="DONE"

        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "${path}" \
            "${cols[1]}" \
            "${cols[2]}" \
            "${cols[4]}" \
            "${cols[0]}" \
            "${age}" \
            "${mtime}" \
            "${state}" \
            "${interval}" \
            "${context}"
    done
}

# Usage: notes_api_list_todos [CONTEXT] [TERM ...]
# Lists TODOs matching the given context and terms.
#
# Outputs:
#
# 1. Path
# 2. Line number
# 3. State (TODO or DONE)
# 4. Text of the TODO
# 5. Absolute path
# 6. File age
# 7. File mtime
# 8. Current state: TODO|DONE|LATER|OVERDUE|SOON
# 9. Earliest date (if any)
# 10. Due date (if any)
# 11. Context (one letter)
function notes_api_list_todos() {
    export NOTES_REPO
    export -f __notes_api_list_todos_batch file_age file_mtime __when __relative_moment __wday_number __wday __date_add __parse_age __date_unit __date_sub __date_convert
    local context=""
    if [[ "${#1}" -eq 1 ]]; then
        context="$1"
        shift
    fi

    notes_api_match_files "${@}" \
        | xargs -J{} grep --color=never -nwHE "(TODO|DONE)" {} \
        | perl -pe 's/^(.*md):(\d+):.*(TODO|DONE):?\s*((?:[A-Z]\s)|\s)\s*(.*)\n/\1\t\2\t\3\t\4\t\5\0/' \
        | xargs -0 -P`nproc` -J{} -n 4 bash -c '__notes_api_list_todos_batch '"'${context}'"' "${@}"' _ {} \
        | sort -r -k7 -t $'\t'
}

function print_todo_categories() {
    echo "ntodo emoji:"
    echo "  A - 💬"
    echo "  B - 💰"
    echo "  C - 📅"
    echo "  E - 🏃"
    echo "  H - 🏠"
    echo "  M - 👥"
    echo "  L - 💩"
    echo "  O - 👔"
    echo "  R - 📚"
    echo "  S - 🛒"
    echo "  T - 📞"
    echo "  W - 📝"
    echo "  X - 🛠️"
    echo "  Z - ⏩"
    echo "  * - 📥"
}

function __todo_context_emoji() {
    local context="${1}"
    case "${context}" in
        A)
            echo -n "💬"
            ;;
        B)
            echo -n "💰"
        ;;
        C)
            echo -n "📅"
            ;;
        E)
            echo -n "🏃"
            ;;
        H)
            echo -n "🏠"
            ;;
        M)
            echo -n "👥"
            ;;
        L)
            echo -n "💩"
            ;;
        O)
            echo -n "👔"
            ;;
        R)
            echo -n "📚"
            ;;
        S)
            echo -n "🛒"
            ;;
        T)
            echo -n "📞"
            ;;
        W)
            echo -n "📝"
            ;;
        X)
            echo -n "🛠️"
            ;;
        Z)
            echo -n "⏩"
            ;;
        "")
            echo -n "📥"
            ;;
        *)
            echo -n " ${context}"
            ;;
    esac
}

# Presents an interactive dialog to select a TODO in the same format as
# notes_api_list_todos.
#
# This is the function that ntodo et al use to filter out stuff based on status.
function __select_todo() {
    if [[ "${1}" == "-a" ]]; then
        local match="all"
        shift
    else
        local match="todo"
    fi

    local todo_data=""
    local width=0
    while IFS= read line; do
        IFS=$'\t' read -r -a cols <<< "${line}"
        [[ ( "${cols[7]}" == "DONE" || "${cols[7]}" == "LATER" ) && "${match}" != "all" ]] && continue
        todo_data+="${line}"$'\n'
        [[ "${width}" -lt "${#cols[3]}" ]] && width="${#cols[3]}"
    done <<< "$(notes_api_list_todos "${@}")"
    [[ -z "${todo_data}" ]] && return 1
    todo_data="${todo_data:0:-1}" # Trailing \n
    (( width > NOTES_MAX_TODO_LEN )) && width="${NOTES_MAX_TODO_LEN}"

    local todo_text=""
    local pad
    local today="$(date +'%Y-%m-%d')"

    while IFS= read line; do
        # Bash 'read' gobbles repeated \t. If there are empty columns, we must
        # use the ASCII unit separator.
        IFS=$'\037' read -r -a cols <<< "$(echo "${line}" | tr $'\t' $'\037')"
        local icon="$(__todo_context_emoji "${cols[10]}") "
        todo_text+="${icon}"

        case "${cols[7]}" in
            DONE)
                todo_text+="${_DISABLED_COLOR}[x] "
            ;;
            TODO)
                todo_text+="[ ] "
            ;;
            LATER)
                todo_text+="${_DISABLED_COLOR}[W] "
            ;;
            SOON)
                todo_text+="${_WARNING_COLOR}[!] "
            ;;
            OVERDUE)
                todo_text+="${_ERROR_COLOR}[!] "
            ;;
        esac

        local text="${cols[3]}"
        local l="${#text}"
        if [[ "${l}" -gt "${NOTES_MAX_TODO_LEN}" ]]; then
            local llen=$(( NOTES_MAX_TODO_LEN - 25 ))
            text="${text:0:$llen}${_DISABLED_COLOR}(...)${_SGR0}${text: -20}"
            l="${NOTES_MAX_TODO_LEN}"
        fi

        pad=""
        for (( i=l-1; i<width; i++ )); do
            pad+="."
        done

        local age="$(printf '%5s' "${cols[5]}")"
        local context
        if [[ -z "${cols[10]}" ]]; then
            context="${_DISABLED_COLOR}-"
        else
            context="${_EXTRA_COLOR}${cols[10]}"
        fi

        todo_text+="${text}${_DISABLED_COLOR} ${pad} ${_TIME_COLOR}${age} ago ${context} ${_PATH_COLOR}${cols[0]}:${cols[1]}${_SGR0}"$'\n'
    done <<< "${todo_data}"
    todo_text="${todo_text:0:-1}" # Trailing \n

    local choice
    choice="$(multiple_choice -n -i "${todo_text}")" || return 2
    tail "-n+${choice}" <<< "${todo_data}" | head -n1
}

# Usage: notes_api_git [ARGS ...]
# Forwards its args to git running with the correct key and in the notes root.
function notes_api_git() {
    local old=`pwd`
    cd "${NOTES_REPO}"
    GIT_SSH_COMMAND="ssh -i $(keys_path notes)" git "$@"
    local status=$?
    cd "${old}"

    return "${status}"
}

function notes_api_pushd() {
    pushd "${NOTES_REPO}"
}

# Usage: notes_api_clone
# Clones the git reposity.
function notes_api_clone() {
    mkdir -p "${NOTES_ROOT}"
    local old=`pwd`
    cd "${NOTES_ROOT}"
    GIT_SSH_COMMAND="ssh -i $(keys_path notes)" git clone $(keys_var notes_repo)
    cd "${old}"
}

function __fix_mtime_from_git() {
    local path="${1}"

    local git_date=`git log -1 --pretty="%ad" --date=format:"%Y-%m-%d %H:%M:%S" -- "${path}" 2>/dev/null`
    local fs_date
    if [[ "$(uname)" == "Darwin" ]]; then
        fs_date=`date -r "${path}" "+%Y-%m-%d %H:%M:%S"`
    else
        fs_date=`date -d "@$(stat -c %Y "${path}")" "+%Y-%m-%d %H:%M:%S"`
    fi

    [[ -z "${git_date}" ]] && return 1
    if [[ "${fs_date}" == "${git_date}" ]]; then
        return 2
    else
        >&2 echo -e "\t${path}\t$(tput setaf 1)${fs_date}$(tput sgr0)\t->\t$(tput setaf 2)${git_date}$(tput sgr0)"
        local ts
        if [[ "$(uname)" == "Darwin" ]]; then
            ts=`date -j -f "%Y-%m-%d %H:%M:%S" "${git_date}" +"%Y%m%d%H%M.%S"`
        else
            ts=`date -d "${git_date}" +"%Y%m%d%H%M.%S"`
        fi
        touch -m -t "${ts}" "${path}" || return 3
    fi
}

# Resets the mtime of notes files from git.
function notes_api_fsck() {
    # Can't use notes_api_find here, because it relies on the timestamps we're about to set.
    local old=`pwd`
    cd "${NOTES_REPO}"
    
    >&2 echo -e "NFSCK – Setting mtime from git commit times..."
    local fixed=0
    local total=0
    while IFS= read line; do
        total=$(( total + 1 ))
        local path="${line:2}"
        __fix_mtime_from_git "${path}" && fixed=$(( fixed + 1 ))
    done <<< $(find . -iname "*.md")
    cd "${old}"

    >&2 echo -e "Fixed ${fixed}/${total} timestamps."
}

function __date_unit() {
    case "${1}" in
        day | d | days)
            echo 1
            ;;
        week | w | weeks)
            echo 7
            ;;
        month | m | months)
            echo 30
            ;;
        year | y | years)
            echo 365
            ;;
        *)
            return 1
    esac
}

function __parse_age() {
    local mul
    local unit
    
    if mul=`__date_unit "${1:0-1}"`; then
        unit=$"${1:0:0-1}"
    else
        unit="${1}"
        mul=1
    fi

    echo $(( unit * mul ))
}

function nw() {
    [[ -z "${NSTART}" ]] && NSTART=365
    [[ -z "${NEND}" ]] && NEND=0
    while true; do
        (( NSTART < 0 )) && NSTART=0
        local prompt="NSTART=${NSTART} NEND=${NEND}"
        read -n1 -p "${prompt}" x || return 2
        case "${x}" in
            d)
                (( NSTART++ ))
            ;;
            D)
                (( NSTART-- ))
            ;;
            w)
                (( NSTART += 7 ))
            ;;
            W)
                (( NSTART -= 7 ))
            ;;
            m)
                (( NSTART += 30 ))
            ;;
            M)
                (( NSTART -= 30 ))
            ;;
            y)
                (( NSTART += 365 ))
            ;;
            Y)
                (( NSTART -= 365 ))
            ;;
            0)
                (( NSTART = 0 ))
            ;;
            q)
                return 0
            ;;
            "")
                tput cuu1
                tput el
                break
            ;;
            *)
            ;;
        esac
        echo
        tput cuu1
        tput el
    done

    while true; do
        (( NEND >= NSTART )) && NEND="${NSTART}"
        (( NEND < 0 )) && NEND=0
        local prompt="NSTART=${NSTART} NEND=${NEND}"
        read -n1 -p "${prompt}" x || return 2
        case "${x}" in
            d)
                (( NEND++ ))
            ;;
            D)
                (( NEND-- ))
            ;;
            w)
                (( NEND += 7 ))
            ;;
            W)
                (( NEND -= 7 ))
            ;;
            m)
                (( NEND += 30 ))
            ;;
            M)
                (( NEND -= 30 ))
            ;;
            y)
                (( NEND += 365 ))
            ;;
            Y)
                (( NEND -= 365 ))
            ;;
            0)
                (( NEND = 0 ))
            ;;
            q)
                return 0
            ;;
            "")
                tput cuu1
                tput el
                break
            ;;
            *)
            ;;
        esac
        echo
        tput cuu1
        tput el
    done
}

function notes_window() {
    if [[ -z "${1}" ]]; then
        >&2 echo "Default -> nwin 7"
        nwin 7
        return 0
    fi

    if [[ "${1}" == "this" ]]; then
        local unit
        if unit=`__date_unit "${2}"`; then
            nwin "${unit}"
            >&2 echo "${1} ${2} -> ${unit}"
        else
            >&2 echo "Can't parse ${2} as a unit"
            return 1
        fi
    elif [[ "${1}" == "last" ]]; then
        local mul=1
        local unit
        if [[ "${2}" =~ [0-9]+ ]]; then
            >&2 echo "${2} is a digit"
            local mul="${2}"
            if unit=`__date_unit "${3}"`; then
                nwin $(( unit * mul )) 0
            else
                >&2 echo "Can't parse ${3} as a unit"
                return 1
            fi
        else
            >&2 echo "${2} is not a digit"
            if unit=`__date_unit "${2}"`; then
                nwin $(( unit * mul + unit )) $(( unit * mul ))
            else
                >&2 echo "Can't parse ${2} as a unit"
            fi
        fi
    else
        local x
        if x=`__parse_age "${1}"`; then
            >&2 echo "${1} -> NSTART=${x}"
            export NSTART="${x}"
        else
            >&2 echo "Can't parse ${1} as age"
            return 1
        fi

        export NEND=0
        [[ -z "${2}" ]] && return 0
        
        if x=`__parse_age "${2}"`; then
            >&2 echo "${2} -> NEND=${x}"
            export NEND="${x}"
        else
            >&2 echo "Can't parse ${2} as age"
            return 1
        fi 
    fi
}

alias nwin=notes_window
alias nwd='nwin 1d'
alias nww='nwin 1w'
alias nwm='nwin 1m'
alias nwy='nwin 1y'
alias nwa='nwin 10y'

# Runs find automatically scoped to the right mtime by the NEND and NSTART env
# variables.
function notes_api_find() {
    local end_age="${NEND}"
    [[ -z "${end_age}" ]] && end_age=0

    local start_age="${NSTART}"
    [[ -z "${start_age}" ]] && start_age=365

    local oldpwd="$(pwd)"
    cd "${NOTES_REPO}"
    export NOTES_REPO
    find . \( \
            \( -type f -and -mtime -$(( start_age + 1 )) -and -mtime +$(( end_age - 1 )) \) \
            -or \( -type d \) \
        \) -and \( "${@}" \) \
    | perl -pe 's/^\./$ENV{"NOTES_REPO"}/'
    cd "${oldpwd}"
}

function notes_api_quick_title() {
    local w="${1}"
    [[ -z "${w}" ]] && w="note"
    local h=`uname -n`
    local d=`date +"%Y-%m-%d %H:%M:%S %Z"`
    echo "Quick ${w} ${h} ${d}"
}

function __notes_filename() {
    local base=`echo "$1" | tr -d '\n' | tr -cs '[:alnum:]' '_' | tr '[:upper:]' '[:lower:]'`
    echo "${base}.md"
}

function notes_log() {
    notes_api_git log --name-status
}

function __match_files_one() {
    local grep_flags="${__GREP_FLAGS}"
    local by_grep=$(notes_api_find -iname "*.md" -exec grep -${grep_flags} "${1}" {} \+)
    local by_path=$(notes_api_find -ipath "*${1}*.md")
    local matches=$(echo -e "${by_grep}\n${by_path}" | sort -u | grep -vE '^$')
    echo "${matches}"
}

function __match_files_all() {
    local grep_flags="${1}"
    shift
    if [[ "${#}" -eq 0 ]]; then
        notes_api_find -ipath "*${1}*.md"
        return 0
    fi
    export -f __match_files_one notes_api_find
    export NOTES_REPO NSTART NEND
    export __GREP_FLAGS="${grep_flags}"
    local n="${#}"
    echo "${@}" | xargs -I{} -n1 -P`nproc` bash -c '__match_files_one "{}"' \
        | sort | uniq -c \
        | grep -E "^\\s*${n}\s" \
        | cut -wf3
}

function __match_files_regex() {
    local grep_flags="${1}"
    shift
    [[ -z "${1}" ]] && return
    local by_grep=$(notes_api_find -iname "*.md" -exec grep -${grep_flags} -E "${1}" {} \+)
    export __NEEDLE="${1}"
    local by_path=$(notes_api_find -iname "*.md" | perl -ne 'print if m/^$ENV{"NOTES_REPO"}\/.*$ENV{"__NEEDLE"}.*\.md/')
    echo "${by_grep}"$'\n'"${by_path}" | sort -u | grep -vE '^$'
}

# Returns a list of files, as absolute paths, that match a search query. The
# query is a list of terms, separated by spaces. Each term is either a
# pro-pattern, or an anti-pattern:
#
# Pro-pattern terms are regular words (e.g. 'foo') that MUST appear in the file.
# If there are multiple pro-pattern terms, then they all must appear for a file
# to match (match all).
#
# Anti-pattern terms start with a tilde `~` (e.g. `~bar`). Any file containing
# even one of the anti-pattern terms is excluded from the results.
#
# Without any pro-patterns, starts with matching all files.
#
# Additional flags start with a dash '-', to be supplied in any position:
#
# -w match only complete words (DEFAULT) -W match substrings
function notes_api_match_files() {
    # First, find all the files that match, then remove the files that match the
    # anti-pattern. The behavior for the pro-pattern and the anti-pattern are
    # different: pro-pattern is match-all, anti-pattern match-any.

    local add_args=()
    local rem_re=""
    local grep_flags="ilw"
    # We have three types of args:
    #
    # 0) Empty strings are ignored as bash-related noise.
    # 1) If it starts with '~' then it's an ANTI-PATTERN (see above).
    # 2) If it starts with '-' then it's a flag.
    # 3) Otherwise it's a PRO-PATTERN (see above).
    while [[ "${#}" -ne 0 ]]; do
        [[ -z "${1}" ]] && shift && continue

        if [[ "${1:0:1}" == "~" ]]; then
            rem_re+="${1:1}|"
        elif [[ "${1:0:1}" == "-" ]]; then
            case "${1:1}" in
                w) grep_flags="ilw" ;;
                W) grep_flags="il" ;;
                *)
                    >&2 echo "Invalid flag ${1}"
                    return 1
                ;;
            esac
        else
            add_args+=("${1}")
        fi
        shift
    done
    [[ -z "${rem_re}" ]] || rem_re="${rem_re::-1}"

    local add=$(__match_files_all "${grep_flags}" "${add_args[@]}" | sort)
    local rem=$(__match_files_regex "${grep_flags}" "${rem_re}"| sort)

    # The below work with read -a, but bash seems iredeemably broken.
    # This doesn't work for some stupid reason:
    # `IFS=$'\n' read -r -d'' -a addv <<< "${add}"`
    local addv
    while IFS= read -r line; do
        addv+=("${line}")
    done <<< "${add}"
    
    local remv
    while IFS= read -r line; do
        remv+=("${line}")
    done <<< "${rem}"

    local i
    local j=0
    local max_i="${#addv[@]}"
    local max_j="${#remv[@]}"
    for (( i=0; i<max_i; i++ )); do
        while [[ "${j}" -lt "${max_j}" && "${addv[$i]}" > "${remv[$j]}" ]]; do
            (( j++ ))
        done
        if [[ "${addv[$i]}" != "${remv[$j]}" ]]; then
            echo "${addv[$i]}"
        fi
    done
}

function __todo_title() {
    local input="${1}"
    [[ "$(wc -l <<< "${input}")" -eq 1 \
        && "$(echo "${input}" | grep TODO | wc -l)" -eq 1 ]] \
            && notes_api_quick_title "todo"
}

function __notes_title() {
    local input="$(cat)"
    local title="$(perl -ne 'print "$1$2\n" while /(?:^|\s)(?::([\w\/]+)|# ([\w\?\!\(\)\.\-\:;'"'"' ]+)\n)/g;' <<< "${input}")"
    if [[ "$(wc -l <<< "${title}")" -gt 1 ]]; then
        >&2 echo -e "Warning: More than one title found:\n${title}"
        head -n1 <<< "${title}"
        return 0
    fi

    [[ -z "${title}" ]] && title="$(__todo_title "${input}")"
    [[ -z "${title}" ]] && title="$(notes_api_quick_title)"

    echo "${title}"
}

function __notes_category() {
    local category=`perl -ne 'print "$1\n" while /(?:^|\s)@([\w\/]+)/g;'`
    if [[ `wc -l <<< "${category}"` -gt 1 ]]; then
        >&2 echo -e "More than one @category found:\n${category}"
        return 1
    fi

    [[ -z "${category}" ]] && category="inbox"

    echo "${category}"
}

function __preamble() {
    [[ ! -d "${NOTES_REPO}" ]] && notes_api_clone
    
    [[ ! -z "${NSTART}" ]] && >&2 echo "(Active interval ${NSTART} - ${NEND})"
}

# Usage: notes_list [TERM ...]
#
# Prints a tree of notes, with the TERM as a filter.
function notes_ls() {
    __preamble
    local lpad
    local rpad
    local depth
    local name
    local notes=$(notes_api_list_notes "${@}")
    local width=0
    local len

    while IFS= read line; do
        IFS=$'\t' read -r -a cols <<< "${line}"
        len="${#cols[0]}"
        depth="${cols[4]}"
        l=$(( len + depth * 2 ))
        [[ "${len}" -gt "${width}" ]] && width="${len}"
    done <<< "${notes}"

    echo "${notes}" | sort \
    | while IFS= read line; do
        # 1. relative path
        # 2. mtime
        # 3. age
        # 4. line count
        # 5. depth
        # 6. absolute path
        # 7. type (f or d)
        IFS=$'\t' read -r -a cols <<< "${line}"
        name=$(basename "${cols[0]}")
        len="${#name}"
        lpad=""
        rpad=""
        depth="${cols[4]}"
        for (( i=0; i<depth; i++ )); do
            lpad+="    "
        done

        for (( i=len+depth*4; i<width; i++ )); do
            rpad+="."
        done

        if [[ "${cols[6]}" == "f" ]]; then
            local archived="${cols[11]}"
            local title="${cols[10]}"
            local title_color=""
            local attribute_color="${_DISABLED_COLOR}"
            [[ "${archived}" == "A" ]] && title_color="${_DISABLED_COLOR}" && attribute_color="${_ERROR_COLOR}"

            printf "%s${_BOLD}${title_color}%s${_SGR0}${_DISABLED_COLOR} %s ${attribute_color}%s ${_DISABLED_COLOR}%s  ${_TIME_COLOR}%5s ago  ${_EXTRA_COLOR}(%s lines)${_SGR0}\n" \
                "${lpad}" \
                "${name}" \
                "${rpad}" \
                "${archived}" \
                "${cols[1]}" \
                "${cols[2]}" \
                "${cols[3]}"
        else
            echo "${lpad}${_SECTION_COLOR}${name}${_SGR0}"
        fi
    done
}

# Usage: notes_hist [N]
# Prints the N most recent notes.
function notes_hist() {
    __preamble
    if [[ -z "$1" ]]; then
        local i=10
    else
        local i="$1"
    fi

    notes_api_list_notes -f | sort -r -k2 | head -n$i \
    | while IFS= read line; do
        IFS=$'\t' read -r -a cols <<< "${line}"
        echo -e "${cols[1]}\t${_TIME_COLOR}(${cols[2]} ago)${_SGR0}\t${cols[0]}"
    done
}

# Usage: notes_api_drop_note NOTE
#
# Delete the note at the provided relative path.
function notes_api_drop_note() {
    local f="${1}"
    rm -f "${NOTES_REPO}/${f}"
    notes_api_git add "$f"
    notes_api_git commit -m "Delete ${f}"
}

# Actually writes the note to disk.
function __notes_gen() {
    local title
    local category
    local input="${*}"
    title=`__notes_title <<< "${input}"` || return 1
    category=`__notes_category <<< "${input}"` || return 1
    
    # Get rid of @foo and :bar.
    local text=`perl -pe 's/(^|\s)[:@][\w\/]+//g' <<< "${input}"`
    # Skip a leading whitespace.
    [[ "${text:0:1}" == " " ]] && text="${text:1}"
    # Skip the title, if there is title.
    [[ "${text:0:1}" == "#" ]] && text=`tail -n +2 <<< "${text}"`
    # Get rid of leading blank lines.
    local text=`sed -e '/./,$!d' <<< "${text}"`

    local filename
    filename=`__notes_filename "${title}"` || return 1
    local path="${NOTES_REPO}/${category}/${filename}"

    mkdir -p `dirname "${path}"` > /dev/null
    echo -e "# ${title}\n" > "${path}"
    echo -e "@${category}\n" >> "${path}"
    echo "${text}" >> "${path}"

    if [[ ! $(notes_api_git check-ignore "${path}") ]]; then
        notes_api_git add "${path}" > /dev/null
        # notes_api_git commit -m "${filename}" -m "${text}" > /dev/null
    fi

    echo "${category}/${filename}"
}

# Usage: notes_gc
#
# Deletes empty notes and runs git gc.
function notes_gc() {
    find $NOTES_REPO -empty -and -not -ipath "*.git*" -delete
    notes_api_git gc
    notes_api_empty_notes | while IFS= read line; do
        grep -qE "/quick_(note|todo)_" <<< "${line}" || continue
        >&2 echo "Deleting empty quick note ${line}..."
        rm -f "${NOTES_REPO}/${line}"
        notes_api_git add "${line}"
    done
    notes_api_git commit -m "Deleted empty notes" || true
}

# Usage: notes_api_update_note RELPATH CONTENTS
#
# Updates the note at the given relative path with the given contents.
function notes_api_update_note() {
    local relpath="${1}"
    local abspath="${NOTES_REPO}/${relpath}"
    local contents="${2}"

    local new_relpath

    new_relpath=$(__notes_gen "${contents}") || return 1
    if [[ "${new_relpath}" == "${relpath}" ]]; then
        notes_api_git check-ignore "${relpath}" && return 0
        notes_api_git add "${relpath}"
        notes_api_git commit -m "Edit ${new_relpath}"
    else
        rm -f "${abspath}"
        notes_api_git check-ignore "${relpath}" || notes_api_git add "${relpath}"
        notes_api_git check-ignore "${new_relpath}" || notes_api_git add "${new_relpath}"
        [[ -z "$(notes_api_git status -s)" ]] || notes_api_git commit -m "Edit and rename ${relpath} -> ${new_relpath}"
    fi
}

# Usage: notes_api_edit_note PATH [LINE]
#
# Opens vim for the given relative note path, then updates the notes tree using
# the result. Optional second argument is the line number to open vim at.
function notes_api_edit_note() {
    if [[ ! -z "$(notes_api_git status -s)" ]]; then
        >&2 echo "The working tree is not clean - run notes_api_git status and deal with whatever's going on."
        return 1
    fi

    local relpath="${1}"
    local abspath="${NOTES_REPO}/${relpath}"
    local line="${2}"

    [[ ! -f "${abspath}" ]] && return 1

    local oldsum=`cat "${abspath}" | h md5`

    if [[ -z "${line}" ]]; then
        vim "${abspath}"
    else
        vim "${abspath}" "+${line}"
    fi

    local contents=`cat "${abspath}"`
    local newsum=`h md5 <<< "${contents}"`
    [[ "${newsum}" == "${oldsum}" ]] && return 0

    notes_api_update_note "${relpath}" "${contents}"
}

function __notes_api_perl_preview_batch() {
    local notes
    local prog="${1}"
    shift

    while IFS= read line; do
        local cols
        local after
        IFS=$'\t' read -r -a cols <<< "${line}"
        after="$(cat "${cols[5]}" | perl -pe "${prog}")" || return 2

        local diff="$(echo "${after}" \
            | diff -aB \
            --suppress-common-lines \
            --old-line-format="${cols[5]}"$'\t''%08dn'$'\t''A'$'\t''%L' \
            --new-line-format="${cols[5]}"$'\t''%08dn'$'\t''B'$'\t''%L' \
            --unchanged-line-format='' \
            "${cols[5]}" -)"
        local lc="$(wc -l <<< "${diff}")"
        (( lc=lc/2 ))
        [[ "${lc}" -eq 0 ]] && continue
        # Print the file header:
        # 1. Absolute path
        # 2. The number 0 (to match the diff format)
        # 3. Dash '-'' (to match the diff format)
        # 4. The number of changed lines
        # 5. Title
        # 6. Modified time
        # 7. Age
        # 8. Number of lines in the note
        # 9. Location (folder)
        # 10. A if archived, - if not
        # 11. Relative path
        printf "%s\t00000000\t-\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n"\
            "${cols[5]}" \
            "${lc}" \
            "${cols[10]}" \
            "${cols[1]}" \
            "${cols[2]}" \
            "${cols[3]}" \
            "${cols[9]}" \
            "${cols[11]}" \
            "${cols[0]}"

        # Print the diff ignoring empty lines. (diff can't be persuaded not to
        # output blank lines when stdout is not a terminal)
        echo "${diff}" | grep -ve '^$'

    # List the notes files including archived ones (the -A switch).
    # Archived/non-archived filter will have already been decided in
    # notes_api_perl_preview.
    done <<< "$(__notes_api_list_notes_batch -A "${@}")"
}

# Usage: notes_api_perl_preview PROG [TERM ...]
#
# Applies the provided perl program to matching notes to generate replacements.
# Returns the potential replacements.
function notes_api_perl_preview() {
    __preamble

    local prog="${1}"
    if [[ -z "${prog}" ]]; then
        >&2 echo "No program specified"
        >&2 echo "Usage: nperl PROG [TERM ...]"
        return 1
    fi

    shift

    export NOTES_REPO NOTES_ROOT
    export -f __notes_api_perl_preview_batch __notes_api_list_notes_batch __file_mtime_and_age __nonempty_wc_l notes_api_git
    notes_api_match_files "${@}" \
        | __PERL_PROG="${prog}" \
        xargs -P`nproc` -J{} -n 4 bash -c '__notes_api_perl_preview_batch "${__PERL_PROG}" "${@}"' _ {} || return "$?"
}

function __nperl_render_preview() {
    local preview="$1" ; shift
    local marks=("$@")
    local i=0

    while IFS= read line; do
        local cols
        IFS=$'\t' read -r -a cols <<< "${line}"
        
        case "${cols[2]}" in
            -)
                printf "[%s] ${_BOLD}%-30s\t${_SGR0} ${_DISABLED_COLOR}%s %s ${_TIME_COLOR}%5s ago ${_EXTRA_COLOR}%4d/%d lines\t${_PATH_COLOR}@%s${_SGR0}\n" \
                    "${marks[$i]}" \
                    "${cols[4]}" \
                    "${cols[9]}" \
                    "${cols[5]}" \
                    "${cols[6]}" \
                    "${cols[3]}" \
                    "${cols[7]}" \
                    "${cols[8]}"
                (( i+=1 ))
            ;;
            A)
                local lno="${cols[1]}"
                printf "\t${_PATH_COLOR}Line %d:${_SGR0}\n\t\t BEFORE: %s\n" \
                    "$((10#$lno))" \
                    "${cols[3]}"
            ;;
            B)
                printf "\t\t AFTER:  %s\n" "${cols[3]}"
            ;;
        esac
    done <<< "${preview}"
}

function __nperl_apply() {
    local relpath="${1}"
    local abspath="${NOTES_REPO}/${relpath}"
    local prog="${2}"
    local contents="$(cat "${abspath}" | perl -pe "${prog}")"

    new_relpath=$(__notes_gen "${contents}") || return 1
    if [[ "${new_relpath}" == "${relpath}" ]]; then
        notes_api_git check-ignore "${relpath}" && return 0
        notes_api_git add "${relpath}"
    else
        rm -f "${abspath}"
        notes_api_git check-ignore "${relpath}" || notes_api_git add "${relpath}"
        notes_api_git check-ignore "${new_relpath}" || notes_api_git add "${new_relpath}"
    fi
}

# Usage: notes_claude
# Opens a Claude Code session in the notes repository.
function notes_claude() {
    __preamble
    notes_api_pushd
    claude
    popd
}

# Usage: notes_api_pushd
# Changes to the notes repository directory. (With pushd.)
function notes_api_pushd() {
    path_push "${NOTES_REPO}"
}

fi # _REDSHELL_NOTES
