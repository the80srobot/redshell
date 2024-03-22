#!/bin/bash

function bg {
    tput setab 0
    tput setaf 195
}

function planet {
    tput setaf 76
}

function moon {
    tput setaf 203
}

function ring {
    tput setaf 61
}

function clr {
    tput sgr0
}

echo -e "`bg`        ~+                                    `clr`"
echo -e "`bg`                                              `clr`"
echo -e "`bg`                 *       +                    `clr`"
echo -e "`bg`            '                   |             `clr`"
echo -e "`bg`        `moon`()`planet`    `ring`.-.`planet`,=\"\`\`\"=.`bg`     - o -           `clr`"
echo -e "`bg`              `ring`'=`planet`/`ring`_`planet`       \\`bg`      |             `clr`"
echo -e "`bg`          *    `planet`|  `ring`'=._`planet`    |`bg`                   `clr`"
echo -e "`bg`                `planet`\\     `ring`\`=.`planet`/`ring`\`,`bg`        '         `clr`"
echo -e "`bg`            .    `planet`'=.__.=' `ring`\`='`bg`      *          `clr`"
echo -e "`bg`   +                         +                `clr`"
echo -e "`bg`        O      *        '       .             `clr`"
echo -e "`bg`                                              `clr`"
clr