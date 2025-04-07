#!/bin/bash

GHOST1=$(tput setaf 39)
GHOST2=$(tput setaf 160)
PACMAN=$(tput setaf 220)
WALL=$(tput setaf 21)
CHERRY=$(tput setaf 216)
COLOR_88=$(tput setaf 88)
RESET=$(tput sgr0)

echo -e "${RESET}${WALL}================================================.${RESET}"
echo -e "${WALL}  ${GHOST1}   .-.  ${GHOST2} .-.  ${PACMAN}   .--. ${WALL}                        |${RESET}"
echo -e "${WALL}  ${GHOST1}  | OO| ${GHOST2}| OO| ${PACMAN}  / _.-' ${CHERRY}.-.   .-.  .-.   .''.  ${WALL}|${RESET}"
echo -e "${WALL}  ${GHOST1}  |   | ${GHOST2}|   | ${PACMAN}  \\  '-. ${CHERRY}'-'   '-'  '-'   '..'  ${WALL}|${RESET}"
echo -e "${WALL}  ${GHOST1}  '^^^' ${GHOST2}'^^^' ${PACMAN}   '--'  ${WALL}                       |${RESET}"
echo -e "${WALL}===============. ${COLOR_88} .-. ${WALL} .================. ${CHERRY} .-.  ${WALL}|${RESET}"
echo -e "${WALL}               | ${COLOR_88}|   |${WALL} |                | ${CHERRY} '-'  ${WALL}|${RESET}"
echo -e "${WALL}               | ${COLOR_88}|   |${WALL} |                |       |${RESET}"
echo -e "${WALL}               | ${COLOR_88}':-:'${WALL} |                | ${CHERRY} .-.  ${WALL}|${RESET}"
echo -e "${WALL}               | ${COLOR_88} '-' ${WALL} |                | ${CHERRY} '-'  ${WALL}|${RESET}"
echo -e "${WALL}==============='       '================'       |${RESET}"
