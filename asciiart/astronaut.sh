#!/bin/bash
_srcdir="$(dirname "$(readlink -f "$0")")/../src"
pushd "${_srcdir}" > /dev/null
source ./ascii_art.bash
popd > /dev/null
ascii_art_astronaut
