#!/bin/bash

set -e

>&2 echo "Starting redshell setup..."

[[ -z "${TERM}" ]] && export TERM=xterm

# Source all modules to make their functions available for setup.
pushd ./src > /dev/null
for f in ./*.bash; do
    >&2 echo "Sourcing $f..."
    source $f || echo "That blew up: $?" >&2
done
popd > /dev/null

# Install source tree.
>&2 echo "Installing src..."
rm -rf ~/.redshell
mkdir -p ~/.redshell/src
cp -r rc ./src ~/.redshell/
cp -r ./util ~/.redshell/
cp -r ./asciiart ~/.redshell/

# Create the persistent directory, if it doesn't exist yet.
mkdir -p ~/.redshell_persist

# Detect the user's shell and install appropriate profile files.
>&2 echo "Installing profile files..."
user_shell="${SHELL##*/}"
if [[ "${user_shell}" == "zsh" ]]; then
    >&2 echo "Detected zsh as default shell."
    reinstall_file rc/zprofile ~/.zprofile
    reinstall_file rc/zshrc ~/.zshrc
else
    >&2 echo "Detected bash (or other) as default shell."
    reinstall_file rc/bash_profile ~/.bash_profile
    reinstall_file rc/bashrc ~/.bashrc
fi
reinstall_file rc/screenrc ~/.screenrc

# Run lightweight OS-specific setup (no package installation).
>&2 echo "Running OS-specific setup..."
if [[ "$(uname -a)" == *Darwin* ]]; then
    mac_setup
elif which dnf > /dev/null 2>&1; then
    redhat_setup
elif which apt-get > /dev/null 2>&1; then
    debian_setup
else
    >&2 echo "Unknown OS. Skipping OS-specific setup."
fi

# Set up visual identity.
if [[ -f ~/.redshell_visual ]]; then
    >&2 echo "Visual identity already set."
else
    >&2 echo "Setting default visual identity. Run select_visual to change."
    echo "bmo" > ~/.redshell_visual
fi

# Rebuild the quick function index.
>&2 echo "Rebuilding quick function index..."
quick_rebuild || >&2 echo "Failed to rebuild quick index. Local modules might not be available via 'q'."

>&2 echo ""
>&2 echo "Redshell installed successfully."
>&2 echo ""
>&2 echo "To install full dev environment, run one of:"
>&2 echo "  q mac install_extras    (macOS)"
>&2 echo "  q debian install_extras (Debian/Ubuntu)"
>&2 echo "  q redhat install_extras (RHEL/Fedora/Rocky)"
