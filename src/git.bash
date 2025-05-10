# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Automate git and github operations.

if [[ -z "${_REDSHELL_GIT}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_GIT=1

function mkproject() {
    gh repo create "${1}" --private --add-readme --clone
}

function git_ssh_init() {
    local remote="$1"
    local path="$2"
    local ssh="${GIT_SSH_COMMAND}"
    [[ -z "${ssh}" ]] && ssh="ssh"
    "${ssh}" "${remote}" "mkdir -p ${path} && cd ${path} && git init --bare"
    git remote add origin "${remote}:${path}"
    git push origin master
}

function git_get_origin() {
    git remote get-url origin | sed -e 's/.*@//' -e 's/:/\//'
}

function git_master_branch() {
    git remote show origin | sed -n '/HEAD branch/s/.*: //p'
}

function git_cherrypick_branch() {
    git cherry-pick $(git merge-base $(git_master_branch) "${1}").."${1}"
}

# Usage: git_sparse_clone REPO [-b BRANCH] [-p PATH] [DIR ...]
#
# Clones a git repository with only the specified subdirectories.
function git_sparse_clone() {
    local repo=""
    local path=""
    local branch="master"
    local subdirs=()
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -b|--branch)
                branch="$2"
                shift
                ;;
            -p|--path)
                path="$2"
                shift
                ;;
            *)
                if [[ -z "${repo}" ]]; then
                    repo="$1"
                else
                    subdirs+=("$1")
                fi
                ;;
        esac
        shift
    done

    git init "${path}"
    cd "${path}"
    git remote add -f origin "${repo}"
    git sparse-checkout init
    git sparse-checkout set "${subdirs[@]}"
    git pull origin "${branch}"
}

function git_changed_lines() {
    local cmd="git diff HEAD"
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -a)
                cmd="git diff HEAD~1"
                ;;
            *)
                break
                ;;
        esac
        shift
    done
    cmd+=" --unified=0 --no-color"
    local maybe_path
    local current_path
    local range
    local line_start
    local line_count
    bash -c "${cmd}" | while read -r line; do
        maybe_path="$(perl -ne 'print $1 if m/^\+\+\+ b\/(.*)$/' <<< "${line}")"
        [[ -n "${maybe_path}" ]] && current_path="${maybe_path}"
        [[ -z "${current_path}" ]] && continue
        range="$(perl -ne 'print "$1\t$2" if m/^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/' <<< "${line}")"
        [[ -z "${range}" ]] && continue
        line_start="$(cut -f 1 <<< "${range}")"
        line_count="$(cut -f 2 <<< "${range}")"
        [[ -z "${line_count}" ]] && line_count=1
        echo -e "${current_path}\t${line_start}\t${line_count}"
    done
}

fi # _REDSHELL_GIT
