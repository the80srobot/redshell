#!/bin/bash

set -e

# Parse command line arguments
CONFIG_ONLY=""
INSTALL_PACKAGES=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config-only)
            CONFIG_ONLY=1
            shift
            ;;
        --install-packages)
            INSTALL_PACKAGES=1
            shift
            ;;
        --help|-h)
            echo "Usage: setup.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --config-only       Install configs only, skip package installation"
            echo "  --install-packages  Install packages (can be run after --config-only)"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "The --config-only preference is remembered in ~/.redshell_persist/setup_mode"
            echo "for future runs. Use --install-packages to install packages later."
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run setup.sh --help for usage information." >&2
            exit 1
            ;;
    esac
done

>&2 echo "Starting redshell setup..."

[[ -z "${TERM}" ]] && export TERM=xterm
pushd ./src
for f in ./*.bash; do
    >&2 echo "Sourcing $f..."
    source $f || echo "That blew up: $?" >&2
done
popd

# Create the persistent directory first (needed for setup_mode file)
mkdir -p ~/.redshell_persist

# Handle setup mode persistence
SETUP_MODE_FILE=~/.redshell_persist/setup_mode
if [[ -n "${CONFIG_ONLY}" ]]; then
    echo "config-only" > "${SETUP_MODE_FILE}"
    >&2 echo "Saving config-only preference to ${SETUP_MODE_FILE}"
elif [[ -n "${INSTALL_PACKAGES}" ]]; then
    # Clear config-only mode when explicitly installing packages
    rm -f "${SETUP_MODE_FILE}"
    >&2 echo "Cleared config-only preference"
elif [[ -f "${SETUP_MODE_FILE}" ]] && [[ "$(cat "${SETUP_MODE_FILE}")" == "config-only" ]]; then
    CONFIG_ONLY=1
    >&2 echo "Using saved config-only preference from ${SETUP_MODE_FILE}"
fi

# Export for use by platform-specific setup functions
export REDSHELL_CONFIG_ONLY="${CONFIG_ONLY}"
export REDSHELL_INSTALL_PACKAGES="${INSTALL_PACKAGES}"

# If --install-packages was specified, only run package installation
if [[ -n "${INSTALL_PACKAGES}" ]]; then
    >&2 echo "Installing packages only..."
    if [[ `uname -a` == *Darwin* ]]; then
        mac_install_packages
    elif which dnf > /dev/null 2>&1; then
        redhat_install_packages
    elif which apt-get > /dev/null 2>&1; then
        debian_install_packages
    else
        >&2 echo "Unknown OS. Cannot install packages."
    fi
    >&2 echo "Package installation complete."
    exit 0
fi

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

>&2 echo "Running OS-specific setup..."
if [[ `uname -a` == *Darwin* ]]
then
    mac_setup
elif which dnf > /dev/null 2>&1
then
    redhat_setup
elif which apt-get > /dev/null 2>&1
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
