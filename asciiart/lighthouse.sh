#!/bin/bash

sky() { tput setab 233; }
red() { tput setaf 9; }
white() { tput setaf 255; }
rock() { tput setaf 246; }
light() { tput setaf 221; }
water() { tput setaf 33; }
clear() { tput sgr0; }

echo -e "`sky`                                                  `clear`"
echo -e "`sky`           `red`__                                     `clear`"
echo -e "`sky`          `red`/  \\\\`light`____                                `clear`"
echo -e "`sky`          `white`| o|`light`    ---____                         `clear`"
echo -e "`sky`         `red`[IIII]`light`--___     ---____                  `clear`"
echo -e "`sky`          `white`|  |      `light`--___       ---____           `clear`"
echo -e "`sky`          `red`|  |           `light`--___         ---____    `clear`"
echo -e "`sky`          `white`|  |                `light`--___           --- `clear`"
echo -e "`sky`          `red`|_:|                     `light`--___          `clear`"
echo -e "`sky`         `rock`/    \                         `light`--___     `clear`"
echo -e "`sky`        `rock`/     |                              `light`--__ `clear`"
echo -e "`sky``water` _-_-_-_`rock`|      \\\\`water`_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_ `clear`"
echo -e "`sky`                                                  `clear`"