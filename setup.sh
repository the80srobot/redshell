#!/bin/bash

set -e

echo "Starting redshell setup..."

pushd ./src
for f in ./*.bash; do
    echo "Sourcing $f..."
    source $f
done
popd

echo "Installing rc files..."
reinstall_file rc/bash_profile ~/.bash_profile
reinstall_file rc/screenrc ~/.screenrc

echo "Installing src..."
rm -rf ~/.redshell
mkdir -p ~/.redshell/src
cp -r rc ./src ~/.redshell/
cp -r rc ./asciiart ~/.redshell/

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

_REDSHELL_RELOAD=1 source ~/.bash_profile
