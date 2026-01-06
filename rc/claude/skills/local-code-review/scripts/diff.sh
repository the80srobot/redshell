#!/bin/bash

# Script to generate a diff of code under review.
#
# Usage:
#   diff.sh              - Show diff of current branch against master,
#                          or last 20 commits if on master/main
#   diff.sh <commit>...  - Show diff for each commit or range
#
# Each argument can be:
#   - A single commit (e.g., abc123) - shows that commit's changes
#   - A range (e.g., abc123..def456) - shows changes in that range

set -euo pipefail

if [[ $# -eq 0 ]]; then
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$current_branch" == "master" || "$current_branch" == "main" ]]; then
        # On master/main: show up to 20 most recent commits
        commit_count=$(git rev-list --count HEAD)
        if [[ $commit_count -gt 20 ]]; then
            commit_count=20
        fi
        git diff HEAD~${commit_count}..HEAD
    else
        # Default behavior: diff against master
        git diff master
    fi
else
    # Process each argument as a commit or range
    for arg in "$@"; do
        if [[ "$arg" == *..* ]]; then
            # Range: use git diff
            git diff "$arg"
        else
            # Single commit: use git show (displays commit info + diff)
            git show "$arg"
        fi
    done
fi
