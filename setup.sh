#!/bin/bash

set -e

>&2 echo "Starting redshell setup..."

[[ -z "${TERM}" ]] && export TERM=xterm
pushd ./src
for f in ./*.bash; do
    >&2 echo "Sourcing $f..."
    source $f || echo "That blew up: $?" >&2
done
popd

>&2 echo "Installing rc files..."
reinstall_file rc/bash_profile ~/.bash_profile
reinstall_file rc/screenrc ~/.screenrc
reinstall_file rc/bashrc ~/.bashrc

>&2 echo "Installing src..."
rm -rf ~/.redshell
mkdir -p ~/.redshell/src
cp -r rc ./src ~/.redshell/
cp -r ./util ~/.redshell/
# TODO: This should be removed later.
cp -r rc ./asciiart ~/.redshell/

>&2 echo "Installing Claude Code config..."
mkdir -p ~/.claude
# Copy skills directory
if [[ -d rc/claude/skills ]]; then
    rm -rf ~/.claude/skills
    cp -r rc/claude/skills ~/.claude/
fi
# Merge settings.json (new keys override existing)
if [[ -f rc/claude/settings.json ]]; then
    if [[ -f ~/.claude/settings.json ]]; then
        # Merge: existing settings as base, new settings override
        jq -s '.[0] * .[1]' ~/.claude/settings.json rc/claude/settings.json > ~/.claude/settings.json.tmp
        mv ~/.claude/settings.json.tmp ~/.claude/settings.json
    else
        cp rc/claude/settings.json ~/.claude/settings.json
    fi
fi

# Create the persistent directory, if it doesn't exist yet.
mkdir -p ~/.redshell_persist

>&2 echo "Running OS-specific setup..."
if [[ `uname -a` == *Darwin* ]]
then
    mac_setup
elif which dnf
then
    redhat_setup
elif which apt-get
then
    debian_setup
else
    >&2 echo "Unknown OS. Skipping OS-specific setup."
fi

if [[ -f ~/.redshell_visual ]]; then
    >&2 echo "Visual identity already set."
else
    >&2 echo "Setting default visual identity. Run select_visual to change."
    >&2 echo "bmo" > ~/.redshell_visual
fi

>&2 echo "Redshell installed. Will now try to rebuild the quick function index with any local modules."
quick_rebuild || >&2 echo "Failed to rebuild quick index. Local modules might not be available via 'q'."
