#!/bin/bash

red() {
    tput setab 160
    tput setaf 160
}

white() {
    tput setab 15
    tput setaf 15
}

snow() {
    tput setaf 231
}

rock() {
    tput setaf 244
}

clr() {
    tput sgr0
}

pole() {
    tput setaf 130
}

cow() {
    tput setaf 215
}

spot() {
    tput setaf 231
}

leaf() {
    tput setaf 118
}

flower() {
    tput setaf 231
}

sky() {
    tput setab 16
}

echo -e "`sky`                                `pole`|`red`##########`sky`                      `clr`"
echo -e "`sky`                                `pole`|`red`####`white`  `red`####`sky`                      `clr`"
echo -e "`sky`                                `pole`|`red`##`white`      `red`##`sky`                      `clr`"
echo -e "`sky`              `snow`_                 `pole`|`red`####`white`  `red`####`sky`                      `clr`"
echo -e "`sky`             `snow`/ \\_               `pole`|`red`##########`sky`                      `clr`"
echo -e "`sky`            `snow`/    \\              `pole`|                                `clr`"
echo -e "`sky`           `rock`/`snow`\\/\\  /`rock`\\  _          `pole`|`cow`       /;    ;\\                 `clr`"
echo -e "`sky`          `rock`/    `snow`\\/`rock`  \\/ \\         `pole`|`cow`   __  \\____//                  `clr`"
echo -e "`sky`        `rock`/\\  .-   \`. \\  \\        `pole`|`cow`  /{_\\_/   \`'\\____              `clr`"
echo -e "`sky`       `rock`/  \`-.__ ^   /\\  \\       `pole`|`cow`  \\___ (o)  (o)   }             `clr`"
echo -e "`sky`      `rock`/ `cow`_____________________________/          :--'             `clr`"
echo -e "`sky`    `cow`,-,'\``spot`@@@@@@@@       @@@@@@`cow`         \\_    \`__\\                `clr`"
echo -e "`sky``cow`   ;:(  `spot`@@@@@@@@@        @@@`cow`             \\___(o'o)               `clr`"
echo -e "`sky``cow`   :: )  `spot`@@@@          @@@@@@`cow`        ,'`spot`@@`cow`(  \`===='               `clr`"
echo -e "`sky``cow`   :: : `spot`@@@@@`cow`:          `spot`@@@@`cow`         \``spot`@@@`cow`:                       `clr`"
echo -e "`sky``cow`   :: \\  `spot`@@@@@`cow`:       `spot`@@@@@@@`cow`)    (  '`spot`@@@`cow`'                       `clr`"
echo -e "`sky``cow`   :; /\\      /      `spot`@@@@@@@@@`cow`\\   :`spot`@@@@@`cow`)                        `clr`"
echo -e "`sky``cow`   ::/  )    {_----------------:  :~\`,~~;               `flower` __/)    `clr`"
echo -e "`sky``cow`  ;; \`; :   )                  :  / \`; ;              `leaf`.-`flower`(__(=:   `clr`"
echo -e "`sky``cow` ;;;  : :   ;                  :  ;  ; :          `leaf`|\ | `flower`    \)    `clr`"
echo -e "`sky``cow` \`'\`  / :  :                   :  :  : :          `leaf`\ ||           `clr`"
echo -e "`sky``cow`     )_ \\__;                   :_ ;  \\_\\          `leaf` \||           `clr`"
echo -e "`sky``cow`     :__\\  \\                   \\  \\  :  \\         `leaf`  \|           `clr`"
echo -e "`sky``cow`         \`^'                    \`^'  \`-^-'        `leaf`   |           `clr`"

