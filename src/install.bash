# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Install a file into another file, optionally with a keyword.

source "file.bash"

if [[ -z "${_REDSHELL_INSTALL}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_INSTALL=1

# Usage: install_file -s|--sfile SFILE -d|--dfile DFILE [-c|--char CHAR] [-k|--section SECTION] [-d|--append] [--uninstall]
#
# Installs the contents of DFILE into SFILE, guarded by a comment at the first
# and last line. Optional arguments CHAR and SECTION control what the commend
# guard looks like. Default CHAR is '#' and default SECTION is 'REDSHELL' for:
#
# # REDSHELL
# ... contents
# # /REDSHELL
#
# Subsequent calls to install_file remove the old contents before intalling the
# new contents. New contents replace the old contents in-place.
#
# Pass --append to install the contents always at the end of the file, rather
# than in-place. Pass --uninstall to only uninstall the file.
#
# On Linux, this attempts to flock DFILE. If the file is already locked, the
# function will immediately return 254.
function install_file() {
    local sfile
    local dfile
    local char
    local section
    local append
    local uninstall

    while [[ "$#" -ne 0 ]]; do
        case "$1" in
            --sfile|-s)
                sfile="$2"
                shift
                ;;
            --dfile|-d)
                dfile="$2"
                shift
                ;;
            --char|-c)
                char="$2"
                shift
                ;;
            --section|-k)
                section="$2"
                shift
                ;;
            --append|-a)
                append=1
                ;;
            --uninstall)
                uninstall=1
                ;;
            *)
                echo "Unknown argument: $1" >&2
                return 1
                ;;
        esac
        shift
    done

    if [[ -z "${dfile}" || ( -z "${sfile}" && -z "${uninstall}" ) ]]; then
        echo "Usage: install_file --sfile SFILE --dfile DFILE [--char CHAR] [--section SECTION] [--append] [--uninstall]" >&2
        return 2
    fi

    # Can we lock files?
    if command -v flock > /dev/null; then
        local lockfile="${dfile}.lock"
        exec 137<>"${lockfile}"
        flock -x --timeout 0 137 || return 254
        # Unlock in the return trap by closing the fd. It seems bash refuses to
        # close file descriptors in the trap for some reason - it looks like
        # they are always closed already at this point.
        trap "trap - RETURN ; rm -f '${lockfile}'" RETURN
    fi

    [[ -z "${char}" ]] && char="###"
    [[ -z "${section}" ]] && section="REDSHELL"

    # Special case if the file doesn't exist yet.
    if [[ ! -f "${dfile}" ]]; then
        >&2 echo "Copying ${sfile} -> ${dfile} (${section})."
        mkdir -p "$(dirname "${dfile}")" || return 3
        echo "${char} ${section} ###" > "${dfile}" || return 3
        cat "${sfile}" >> "${dfile}" || return 3
        echo "" >> "${dfile}" || return 3
        echo "${char} /${section} ###" >> "${dfile}" || return 3
        return
    fi

    local tmp
    tmp="$(mktemp)"

    # Read the file line by line and print each line. Stop printing if we find
    # the section we're replacing. When we find the end of the section we're
    # replacing, print the new contents and continue printing the rest of the
    # file. Special handling is there for uninstall-only and append.
    local replaced
    while IFS= read -r line; do
        local in_section # Are we between the section guards?

        # Look for section start.
        if [[ "${line}" == "${char} ${section} ###" ]]; then
            in_section=1
            [[ -z "${append}" && -z "${uninstall}" ]] && echo "${line}" >> "${tmp}"
        fi

        # Print.
        [[ -z "${in_section}" ]] && echo "${line}" >> "${tmp}"

        # Look for section end.
        if [[ "${line}" == "${char} /${section} ###" ]]; then
            in_section=
            if [[ -z "${append}" && -z "${uninstall}" ]]; then
                [[ -n "${sfile}" ]] && cat "${sfile}" >> "${tmp}"
                echo "" >> "${tmp}"
                replaced=1
            fi
            [[ -z "${append}" && -z "${uninstall}" ]] && echo "${line}" >> "${tmp}"
        fi
    done < "${dfile}"

    # If no replacement has been made yet, either because it's a first install
    # or we're appending, then append the new contents at the end.
    if [[ -z "${uninstall}" && -z "${replaced}" ]]; then
        echo "${char} ${section} ###" >> "${tmp}"
        cat "${sfile}" >> "${tmp}"
        echo "" >> "${tmp}"
        echo "${char} /${section} ###" >> "${tmp}"
    fi

    local bak="$(file_mktemp "$(basename "${dfile}")")"
    >&2 echo "Installing ${sfile} -> ${dfile} (${section}). Backup up to ${bak}..."
    mv "${dfile}" "${bak}" || return 3
    mv "${tmp}" "${dfile}" || return 4
}

# Usage: reinstall_file SFILE DFILE [CHAR] [SECTION]
#
# This is a legacy form of install_file. It is kept for backwards compatibility.
#
# Installs the contents of DFILE into SFILE, guarded by a comment at the first
# and last line. Optional arguments CHAR and SECTION control what the commend
# guard looks like. Default CHAR is '#' and default SECTION is 'REDSHELL' for:
#
# # REDSHELL
# ... contents
# # /REDSHELL
#
# Subsequent calls to reinstall_file remove the old contents before intalling
# the new contents.
function reinstall_file() {
    install_file --sfile "${1}" --dfile "${2}" --char "${3}" --section "${4}"
}

function __install_file() {
    mkdir -p `dirname "$2"`

    if [[ -z "$3" ]]; then
        q="###"
    else
        q="${3}"
    fi
    
    if [[ -z "$4" ]]; then
        kw="REDSHELL"
    else
        kw="$4"
    fi

    echo "${q} ${kw} ###" >> "$2"
    cat "$1" >> "$2"
    echo "" >> "$2"
    echo "${q} /${kw} ###" >> "$2"
}

function __uninstall_file() {
    if [[ -z "$2" ]]; then
        q="###"
    else
        q="${2}"
    fi
    if [[ -z "$3" ]]; then
        kw="REDSHELL"
    else
        kw="$3"
    fi
    sed -i.bak "/${q} ${kw} ###/,/${q} \/${kw} ###/d" "$1" 2> /dev/null || true
}

fi # _REDSHELL_INSTALL
