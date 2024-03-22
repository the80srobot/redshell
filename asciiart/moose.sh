#!/bin/bash


bgc=$(($RANDOM % 256))
fgc=$(($RANDOM % 256))
while [[ $(contrast `xterm_to_rgb $bgc` `xterm_to_rgb $fgc`) -lt 70 ]]; do
    bgc=$(($RANDOM % 256))
    fgc=$(($RANDOM % 256))
done

color() {
    tput setaf $fgc
    tput setab $bgc
}

clr() {
    tput sgr0
}

echo -e "`color` ___            ___  `clr`"
echo -e "`color`/   \          /   \ `clr`"
echo -e "`color`\_   \        /  __/ `clr`"
echo -e "`color` _\   \      /  /__  `clr`"
echo -e "`color` \___  \____/   __/  `clr`"
echo -e "`color`     \_       _/     `clr`"
echo -e "`color`       | @ @  \_     `clr`"
echo -e "`color`       |             `clr`"
echo -e "`color`     _/     /\       `clr`"
echo -e "`color`    /o)  (o/\ \_     `clr`"
echo -e "`color`    \_____/ /        `clr`"
echo -e "`color`      \____/         `clr`"
echo
clr
