#!/bin/bash

sky() { tput setab 233; }
hat() { tput setaf 106; }
coat() { tput setaf 94; }
rock() { tput setaf 195; }
clear() { tput sgr0; }
star() { tput setaf 255; }

echo -e "`sky``hat`          .-.      `star`*     `clear`"
echo -e "`sky``hat`       __/   (           `clear`"
echo -e "`sky``tput setaf 202`     , `hat`'-.____\      `star`*   `clear`"
echo -e "`sky``tput setaf 178`      u=='`coat`/  \           `clear`"
echo -e "`sky``coat`         /_/  \          `clear`"
echo -e "`sky`  `star`*`coat`    .-''   |          `clear`"
echo -e "`sky``coat`      (  ____/`rock`_____      `clear`"
echo -e "`sky``coat`      _>_/`rock`.--------      `clear`"
echo -e "`sky``coat`      \/`rock`//               `clear`"
echo -e "`sky``rock`       //                `clear`"
echo -e "`sky``rock`      //                 `clear`"
echo -e "`sky``rock`                         `clear`"
