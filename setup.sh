#!/bin/bash

set -e

echo "Starting redshell setup..."

[[ -z "${TERM}" ]] && export TERM=xterm
pushd ./src
for f in ./*.bash; do
    echo "Sourcing $f..."
    source $f || echo "That blew up: $?"
done
popd

echo "Installing rc files..."
reinstall_file rc/bash_profile ~/.bash_profile
reinstall_file rc/screenrc ~/.screenrc

echo "Installing src..."
rm -rf ~/.redshell
mkdir -p ~/.redshell/src
cp -r rc ./src ~/.redshell/
# TODO: This should be removed later.
cp -r rc ./asciiart ~/.redshell/

# Create the persistent directory, if it doesn't exist yet.
mkdir -p ~/.redshell_persist

echo "Running OS-specific setup..."
if [[ `uname -a` == *Darwin* ]]
then
    mac_setup
elif which dnf
then
    fedora_setup
fi

if [[ -f ~/.redshell_visual ]]; then
    echo "Visual identity already set."
else
    echo "Setting default visual identity. Run select_visual to change."
    echo "bmo" > ~/.redshell_visual
fi

quick_rebuild
