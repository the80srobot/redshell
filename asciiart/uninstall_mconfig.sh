#!/bin/bash

echo "Removing mconfig..."

source ~/.functions

cd $HOME/.mconfig_uninstall
for f in *.sh; do
    echo "Running uninstall script ${f}..."
    source "$f"
done

rm -rf ~/.mconfig_uninstall

uninstall_file ~/.bash_profile
uninstall_file ~/.screenrc
uninstall_file ~/.gitconfig
uninstall_file ~/.functions
uninstall_file ~/.vimrc '"'
uninstall_file ~/.gnupg/gpg-agent.conf

rm -rf ~/mbin/
rm -rf ~/.mconfig_status*
rm -rf ~/.mconfig_packs*
rm -rf ~/.mconfig_visual*
