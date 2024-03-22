#!/bin/bash

function setaf {
    tput setaf $1
}

function setab {
    tput setab $1
}


tput sgr0; tput setab 0; tput setaf 21; 
echo -n -e "================================================."
tput sgr0; echo; tput setab 0; tput setaf 21; 
echo -n -e "  $(setaf 39)   .-.  $(setaf 160) .-.  $(setaf 220)   .--. $(setaf 21)                        |"
tput sgr0; echo; tput setab 0; tput setaf 21; 
echo -n -e "  $(setaf 39)  | OO| $(setaf 160)| OO| $(setaf 220)  / _.-' $(setaf 216).-.   .-.  .-.   .''.  $(setaf 21)|"
tput sgr0; echo; tput setab 0; tput setaf 21; 
echo -n -e "  $(setaf 39)  |   | $(setaf 160)|   | $(setaf 220)  \  '-. $(setaf 216)'-'   '-'  '-'   '..'  $(setaf 21)|"
tput sgr0; echo; tput setab 0; tput setaf 21; 
echo -n -e "  $(setaf 39)  '^^^' $(setaf 160)'^^^' $(setaf 220)   '--'  $(setaf 21)                       |"
tput sgr0; echo; tput setab 0; tput setaf 21; 
echo -n -e "===============. $(setaf 88) .-. $(setaf 21) .================. $(setaf 216) .-.  $(setaf 21)|"
tput sgr0; echo; tput setab 0; tput setaf 21; 
echo -n -e "               | $(setaf 88)|   |$(setaf 21) |                | $(setaf 216) '-'  $(setaf 21)|"
tput sgr0; echo; tput setab 0; tput setaf 21; 
echo -n -e "               | $(setaf 88)|   |$(setaf 21) |                |       |"
tput sgr0; echo; tput setab 0; tput setaf 21; 
echo -n -e "               | $(setaf 88)':-:'$(setaf 21) |                | $(setaf 216) .-.  $(setaf 21)|"
tput sgr0; echo; tput setab 0; tput setaf 21; 
echo -n -e "               | $(setaf 88) '-' $(setaf 21) |                | $(setaf 216) '-'  $(setaf 21)|"
tput sgr0; echo; tput setab 0; tput setaf 21; 
echo -n -e "==============='       '================'       |"
tput sgr0; echo
