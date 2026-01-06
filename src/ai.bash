# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# AI tools setup and configuration.

if [[ -z "${_REDSHELL_AI}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_AI=1

# Skills managed by redshell. Only these will be deleted/overwritten.
_REDSHELL_CLAUDE_SKILLS=(
    "local-code-review"
)

# Installs Claude Code configuration files from redshell.
#
# Copies skills to ~/.claude/skills and merges settings.json with any existing
# settings (new keys override existing ones). Only skills listed in
# _REDSHELL_CLAUDE_SKILLS are deleted/overwritten; other skills are preserved.
#
# Usage: ai_install_claude_config
function ai_install_claude_config() {
    local src_dir="${REDSHELL_ROOT}/rc/claude"

    if [[ ! -d "${src_dir}" ]]; then
        echo "Claude config source not found at ${src_dir}" >&2
        return 1
    fi

    echo "Installing Claude Code config..."
    mkdir -p ~/.claude/skills

    # Only delete and copy redshell-managed skills
    local skill
    for skill in "${_REDSHELL_CLAUDE_SKILLS[@]}"; do
        if [[ -d ~/.claude/skills/"${skill}" ]]; then
            rm -rf ~/.claude/skills/"${skill}"
        fi
        if [[ -d "${src_dir}/skills/${skill}" ]]; then
            cp -r "${src_dir}/skills/${skill}" ~/.claude/skills/
        fi
    done

    # Merge settings.json (new keys override existing)
    if [[ -f "${src_dir}/settings.json" ]]; then
        if [[ -f ~/.claude/settings.json ]]; then
            # Merge: existing settings as base, new settings override
            jq -s '.[0] * .[1]' ~/.claude/settings.json "${src_dir}/settings.json" > ~/.claude/settings.json.tmp
            mv ~/.claude/settings.json.tmp ~/.claude/settings.json
        else
            cp "${src_dir}/settings.json" ~/.claude/settings.json
        fi
    fi
}

fi # _REDSHELL_AI
