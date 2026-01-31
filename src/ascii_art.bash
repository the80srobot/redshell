# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Assorted ascii art, screen drawing and speech bubbles.

source "compat.sh"
source "strings.bash"
source "xterm_colors.bash"

if [[ -z "${_REDSHELL_ASCII_ART}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_ASCII_ART=1

_AA_RESET=$'\033[0m'

# Picks a random element from positional args.
# Example: result=$(_aa_random_element "a" "b" ...)
function _aa_random_element() {
    local idx=$(( RANDOM % $# ))
    shift $idx
    echo "$1"
}

function print_speech_bubble() {
    local width=0
    while IFS= read -r line; do
        local stripped="$(strings_strip_control <<< "${line}")"
        local w="${#stripped}"
        if (( w > width )); then
            width="${w}"
        fi
    done <<< "${1}"
    (( width++ ))

    echo "   $(strings_repeat _ $width)_ "
    echo "  /$(strings_repeat ' ' $width) \\"
    while IFS= read -r line; do
        echo -n "  | ${line}"
        local stripped="$(strings_strip_control <<< "${line}")"
        local l="${#stripped}"
        local p=$((width-l))
        for (( c=0; c<p; c++ )); do
            echo -n " "
        done
        echo "|"
    done <<< "$1"

    (( rpad = width ))
    echo "  / $(strings_repeat _ $rpad)/"
    echo " / /$(strings_repeat ' ' $rpad) "
    echo "/_/$(strings_repeat ' ' $rpad)  "
    echo "$(strings_repeat ' ' $rpad)   "
}

function erase_lines() {
    local n="${1}"
    local erase_seq='\033[K'
    [[ "${2}" == "-q" ]] && erase_seq=""
    for (( i=0; i < n; i++ )); do
        echo -ne "\033[A${erase_seq}"
    done
}

function cursor_position() {
    local pos
    printf '\E[6n'
    read -s -d R pos
    pos=${pos#*[} # Strip decoration characters <ESC>[
    echo "${pos}" # Return position in "row;col" format
}

function cursor_row() {
    local row
    local col
    printf '\E[6n'
    IFS=';' read -s -d R row col
    echo "${row#*[}"
}

function ascii_art_astronaut() {
    local sky=$'\033[48;5;0m\033[38;5;195m'
    local red=$'\033[38;5;196m'
    local nasa_bg=$'\033[48;5;17m'
    local white=$'\033[38;5;231m'
    local reset=$'\033[0m'

    echo -e "${sky}             _..._                *       ${reset}"
    echo -e "${sky}           .'     '.      _               ${reset}"
    echo -e "${sky}     *    /    .-\"\"-\\   _/ \\              ${reset}"
    echo -e "${sky}        .-|   /:.   |  |   |              ${reset}"
    echo -e "${sky}        |  \\  |:.   /.-'-./               ${reset}"
    echo -e "${sky}        | .-'-;:__.'    =/                ${reset}"
    echo -e "${sky}        .'=  *${red}=${sky}|${nasa_bg}${white}NASA${sky} _.='      *          ${reset}"
    echo -e "${sky}       /   _.  |    ;                     ${reset}"
    echo -e "${sky}      ;-.-'|    \\   |                     ${reset}"
    echo -e "${sky}     /   | \\    _\\  _\\                *   ${reset}"
    echo -e "${sky}     \\__/'._;.  ==' ==\\                   ${reset}"
    echo -e "${sky}              \\    \\   |                  ${reset}"
    echo -e "${sky}              /    /   /                  ${reset}"
    echo -e "${sky}              /-._/-._/                   ${reset}"
    echo -e "${sky}              \\   \`\\  \\                   ${reset}"
    echo -e "${sky} *             \`-._/._/                   ${reset}"
    echo -e "${sky}            *                             ${reset}"
}

function ascii_art_bessy() {
    local red=$'\033[48;5;160m\033[38;5;160m'
    local white=$'\033[48;5;15m\033[38;5;15m'
    local snow=$'\033[38;5;231m'
    local rock=$'\033[38;5;244m'
    local pole=$'\033[38;5;130m'
    local cow=$'\033[38;5;215m'
    local spot=$'\033[38;5;231m'
    local leaf=$'\033[38;5;118m'
    local flower=$'\033[38;5;231m'
    local sky=$'\033[48;5;16m'
    local clr=$'\033[0m'

    echo -e "${sky}                                ${pole}|${red}##########${sky}                      ${clr}"
    echo -e "${sky}                                ${pole}|${red}####${white}  ${red}####${sky}                      ${clr}"
    echo -e "${sky}                                ${pole}|${red}##${white}      ${red}##${sky}                      ${clr}"
    echo -e "${sky}              ${snow}_                 ${pole}|${red}####${white}  ${red}####${sky}                      ${clr}"
    echo -e "${sky}             ${snow}/ \\_               ${pole}|${red}##########${sky}                      ${clr}"
    echo -e "${sky}            ${snow}/    \\              ${pole}|                                ${clr}"
    echo -e "${sky}           ${rock}/${snow}\\/\\  /${rock}\\  _          ${pole}|${cow}       /;    ;\\                 ${clr}"
    echo -e "${sky}          ${rock}/    ${snow}\\/${rock}  \\/ \\         ${pole}|${cow}   __  \\____//                  ${clr}"
    echo -e "${sky}        ${rock}/\\  .-   \`. \\  \\        ${pole}|${cow}  /{_\\_/   \`'\\____              ${clr}"
    echo -e "${sky}       ${rock}/  \`-.__ ^   /\\  \\       ${pole}|${cow}  \\___ (o)  (o)   }             ${clr}"
    echo -e "${sky}      ${rock}/ ${cow}_____________________________/          :--'             ${clr}"
    echo -e "${sky}    ${cow},-,'\`${spot}@@@@@@@@       @@@@@@${cow}         \\_    \`__\\                ${clr}"
    echo -e "${sky}${cow}   ;:(  ${spot}@@@@@@@@@        @@@${cow}             \\___(o'o)               ${clr}"
    echo -e "${sky}${cow}   :: )  ${spot}@@@@          @@@@@@${cow}        ,'${spot}@@${cow}(  \`===='               ${clr}"
    echo -e "${sky}${cow}   :: : ${spot}@@@@@${cow}:          ${spot}@@@@${cow}         \`${spot}@@@${cow}:                       ${clr}"
    echo -e "${sky}${cow}   :: \\  ${spot}@@@@@${cow}:       ${spot}@@@@@@@${cow})    (  '${spot}@@@${cow}'                       ${clr}"
    echo -e "${sky}${cow}   :; /\\      /      ${spot}@@@@@@@@@${cow}\\   :${spot}@@@@@${cow})                        ${clr}"
    echo -e "${sky}${cow}   ::/  )    {_----------------:  :~\`,~~;               ${flower} __/)    ${clr}"
    echo -e "${sky}${cow}  ;; \`; :   )                  :  / \`; ;              ${leaf}.-${flower}(__(=:   ${clr}"
    echo -e "${sky}${cow} ;;;  : :   ;                  :  ;  ; :          ${leaf}|\\ | ${flower}    \\)    ${clr}"
    echo -e "${sky}${cow} \`'\`  / :  :                   :  :  : :          ${leaf}\\ ||           ${clr}"
    echo -e "${sky}${cow}     )_ \\__;                   :_ ;  \\_\\          ${leaf} \\||           ${clr}"
    echo -e "${sky}${cow}     :__\\  \\                   \\  \\  :  \\         ${leaf}  \\|           ${clr}"
    echo -e "${sky}${cow}         \`^'                    \`^'  \`-^-'        ${leaf}   |           ${clr}"
}

function ascii_art_bmo() {
    [[ -n "${_REDSHELL_ZSH}" ]] && emulate -L ksh
    local light=$'\033[38;5;159m'
    local dark=$'\033[38;5;50m'
    local bg=$'\033[48;5;235m\033[38;5;50m'
    local clr=$'\033[0m'
    local yellow=$'\033[38;5;226m'
    local blue=$'\033[38;5;27m'
    local green=$'\033[38;5;34m'
    local red=$'\033[38;5;160m'

    local quotes=(
        "YOU DRIVE A HARD\nBURGER!"
        "USE THE COMBO MOVE!"
        "RED-HOT\nLIKE PIZZA SUPPER"
        "CHECK PLEASE!"
    )
    local idx=$(( RANDOM % ${#quotes[@]} ))
    local quote="${quotes[$idx]}"

    local w=20
    echo -e "${bg}  $(printf '_%.0s' $(seq 1 $w))   ${clr}"
    echo -e "${bg} /$(printf ' %.0s' $(seq 1 $w))\\  ${clr}"
    while IFS= read -r line; do
        local len=${#line}
        local pad=$(( w - len ))
        local lpad=$(( pad / 2 ))
        local rpad=$(( pad - lpad ))
        echo -e "${bg} |$(printf ' %.0s' $(seq 1 $lpad))${line}$(printf ' %.0s' $(seq 1 $rpad))|  ${clr}"
    done < <(echo -e "${quote}")
    echo -e "${bg} \\____   _____________/  ${clr}"
    echo -e "${bg}      \\ |                ${clr}"
    echo -e "${bg}       \\|                ${clr}"

    echo -e "${bg}     ._________          ${clr}"
    echo -e "${bg}    /_________/|         ${clr}"
    echo -e "${bg}    |${light}.-------.${dark}||         ${clr}"
    echo -e "${bg}    |${light}|o   o  |${dark}||         ${clr}"
    echo -e "${bg}    |${light}|  -    |${dark}||         ${clr}"
    echo -e "${bg}    |${light}'-------'${dark}||         ${clr}"
    echo -e "${bg}    | ___  .  ||         ${clr}"
    echo -e "${bg}   /|         |\\         ${clr}"
    echo -e "${bg}  / | ${yellow}+   ${blue}^${dark} ${green}o${dark} ||\\        ${clr}"
    echo -e "${bg}    | --   ${red}O${dark}  ||         ${clr}"
    echo -e "${bg}    '---------/          ${clr}"
    echo -e "${bg}      I     I            ${clr}"
    echo -e "${clr}"
}

function ascii_art_dachshund() {
    [[ -n "${_REDSHELL_ZSH}" ]] && emulate -L ksh
    local dog=$'\033[38;5;130m'
    local nose=$'\033[38;5;236m'
    local clr=$'\033[0m'

    local quotes=(
"Tomorrow, and tomorrow, and tomorrow,
Creeps in this petty pace from day to day,
To the last syllable of recorded time;
And all our yesterdays have lighted fools
The way to dusty death. Out, out, brief candle!
Life's but a walking shadow, a poor player
That struts and frets his hour upon the stage,
And then is heard no more. It is a tale
Told by an idiot, full of sound and fury,
Signifying nothing."

"Full fathom five thy father lies;
Of his bones are coral made;
Those are pearls that were his eyes;
Nothing of him that doth fade,
But doth suffer a sea-change
Into something rich and strange."

"Now is the winter of our discontent
Made glorious summer by this sun of York;
And all the clouds, that lour'd upon our house,
In the deep bosom of the ocean buried."

"O Romeo, Romeo! wherefore art thou Romeo?
Deny thy father and refuse thy name;
Or, if thou wilt not, be but sworn my love,
And I'll no longer be a Capulet."

"To be, or not to be, -- that is the question: --
Whether 'tis nobler in the mind to suffer
The slings and arrows of outrageous fortune,
Or to take arms against a sea of troubles,
And by opposing end them? -- To die, to sleep, --
No more; and by a sleep to say we end
The heart-ache, and the thousand natural shocks
That flesh is heir to, -- 'tis a consummation
Devoutly to be wish'd."

"This is the excellent foppery of the world, that,
when we are sick in fortune,
often the surfeit of our own behaviour,
we make guilty of our disasters the sun,
the moon, and the stars;
as if we were villains by necessity,
fools by heavenly compulsion,
knaves, thieves, and treachers
by spherical predominance,
drunkards, liars, and adulterers
by an enforced obedience of planetary influence;
and all that we are evil in,
by a divine thrusting on:
an admirable evasion of whore-master man,
to lay his goatish disposition
to the charge of a star!"

"Men at some time are masters of their fates:
The fault, dear Brutus, is not in our stars,
But in ourselves, that we are underlings."

"Thou, nature, art my goddess; to thy law
My services are bound. Wherefore should I
Stand in the plague of custom, and permit
The curiosity of nations to deprive me?
For that I am some twelve or fourteen moon-shines
Lag of a brother? Why bastard? Wherefore base?
When my dimensions are as well compact,
My mind as generous, and my shape as true,
As honest madam's issue? Why brand they us
With base? With baseness? Bastardy? Base, base?
Who, in the lusty stealth of nature, take
More composition and fierce quality
Than doth, within a dull, stale, tired bed,
Go to the creating a whole tribe of fops,
Got 'tween asleep and wake? Well, then,
Legitimate Edgar, I must have your land.
Our father's love is to the bastard Edmund
As to the legitimate: fine word, legitimate!
Well, my legitimate, if this letter speed,
And my invention thrive, Edmund the base
Shall top the legitimate. I grow; I prosper.
Now, gods, stand up for bastards!"

"What's in a name? That which we call a rose
By any other name would smell as sweet."

"Cry 'Havoc!', and let slip the dogs of war;
That this foul deed shall smell above the earth
With carrion men, groaning for burial."

"The quality of mercy is not strain'd,
It droppeth as the gentle rain from heaven
Upon the place beneath. It is twice blest:
It blesseth him that gives
and him that takes."

"I could be bounded in a nutshell, and count
myself a king of infinite space, were it not
that I have bad dreams."
    )
    local idx=$(( RANDOM % ${#quotes[@]} ))
    local quote="${quotes[$idx]}"

    echo " ____________________________________________________ "
    echo "/                                                    \\"
    while IFS= read -r line; do
        echo -n "| ${line}"
        local l="${#line}"
        local p=$((51-l))
        for (( c=0; c<p; c++ )); do
            echo -n " "
        done
        echo "|"
    done <<< "${quote}"
    echo "\\____________________________    ____________________/"
    echo "                             |  /"
    echo "                             | /"
    echo "                             |/"

    echo "${dog}                        __      "
    echo "${dog} (\\,-------------------/()'--${nose}o  "
    echo "${dog}  (_    ______________    /~\"   "
    echo "${dog}   (_)_)             (_)_)      "
    echo "${clr}"
}

function ascii_art_drwho() {
    local blue=$'\033[38;5;27m'
    local reset=$'\033[0m'
    local dalek=$'\033[38;5;215m'

    echo -e "${blue}         ___                                "
    echo -e "${blue} _______(_@_)_______                          "
    echo -e "${blue} | ${reset}POLICE      BOX${blue} |                          "
    echo -e "${blue} |_________________|                          "
    echo -e "${blue}  | _____ | _____ |                           "
    echo -e "${blue}  | |###| | |###| |       ${reset}                          EXTERMINATE! EXTERMINATE!               "
    echo -e "${blue}  | |###| | |###| |       ${reset}                        /               "
    echo -e "${blue}  | _____ | _____ |       ${dalek}                   ___               "
    echo -e "${blue}  | || || | || || |       ${dalek}         ())>=G==='   '.               "
    echo -e "${blue}  | ||_|| | ||_|| |       ${dalek}                 |======|               "
    echo -e "${blue}  | _____ |\$_____ |      ${dalek}                  |======|               "
    echo -e "${blue}  | || || | || || |       ${dalek}             )--/]IIIIII]               "
    echo -e "${blue}  | ||_|| | ||_|| |       ${dalek}                |_______|               "
    echo -e "${blue}  | _____ | _____ |       ${dalek}                C O O O D               "
    echo -e "${blue}  | || || | || || |       ${dalek}               C O  O  O D               "
    echo -e "${blue}  | ||_|| | ||_|| |       ${dalek}              C  O  O  O  D               "
    echo -e "${blue}  |       |       |       ${dalek}              C__O__O__O__D               "
    echo -e "${blue}  *****************       ${dalek}             [_____________]${reset}"
}

function ascii_art_lighthouse() {
    local sky=$'\033[48;5;233m'
    local red=$'\033[38;5;9m'
    local white=$'\033[38;5;255m'
    local rock=$'\033[38;5;246m'
    local light=$'\033[38;5;221m'
    local water=$'\033[38;5;33m'
    local clr=$'\033[0m'

    echo -e "${sky}                                                  ${clr}"
    echo -e "${sky}           ${red}__                                     ${clr}"
    echo -e "${sky}          ${red}/  \\\\${light}____                                ${clr}"
    echo -e "${sky}          ${white}| o|${light}    ---____                         ${clr}"
    echo -e "${sky}         ${red}[IIII]${light}--___     ---____                  ${clr}"
    echo -e "${sky}          ${white}|  |      ${light}--___       ---____           ${clr}"
    echo -e "${sky}          ${red}|  |           ${light}--___         ---____    ${clr}"
    echo -e "${sky}          ${white}|  |                ${light}--___           --- ${clr}"
    echo -e "${sky}          ${red}|_:|                     ${light}--___          ${clr}"
    echo -e "${sky}         ${rock}/    \\                         ${light}--___     ${clr}"
    echo -e "${sky}        ${rock}/     |                              ${light}--__ ${clr}"
    echo -e "${sky}${water} _-_-_-_${rock}|      \\\\${water}_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_-_ ${clr}"
    echo -e "${sky}                                                  ${clr}"
}

function ascii_art_moose() {
    [[ -n "${_REDSHELL_ZSH}" ]] && emulate -L ksh
    local bgc=$(($RANDOM % 256))
    local fgc=$(($RANDOM % 256))
    while [[ $(contrast $(xterm_to_rgb $bgc) $(xterm_to_rgb $fgc)) -lt 70 ]]; do
        bgc=$(($RANDOM % 256))
        fgc=$(($RANDOM % 256))
    done

    local color=$'\033[38;5;'"${fgc}"'m\033[48;5;'"${bgc}"'m'
    local clr=$'\033[0m'

    echo -e "${color} ___            ___  ${clr}"
    echo -e "${color}/   \\          /   \\ ${clr}"
    echo -e "${color}\\_   \\        /  __/ ${clr}"
    echo -e "${color} _\\   \\      /  /__  ${clr}"
    echo -e "${color} \\___  \\____/   __/  ${clr}"
    echo -e "${color}     \\_       _/     ${clr}"
    echo -e "${color}       | @ @  \\_     ${clr}"
    echo -e "${color}       |             ${clr}"
    echo -e "${color}     _/     /\\       ${clr}"
    echo -e "${color}    /o)  (o/\\ \\_     ${clr}"
    echo -e "${color}    \\_____/ /        ${clr}"
    echo -e "${color}      \\____/         ${clr}"
    echo "${clr}"
}

function ascii_art_pacman() {
    local ghost1=$'\033[38;5;39m'
    local ghost2=$'\033[38;5;160m'
    local pacman=$'\033[38;5;220m'
    local wall=$'\033[38;5;21m'
    local cherry=$'\033[38;5;216m'
    local color88=$'\033[38;5;88m'
    local reset=$'\033[0m'

    echo -e "${reset}${wall}================================================.${reset}"
    echo -e "${wall}  ${ghost1}   .-.  ${ghost2} .-.  ${pacman}   .--. ${wall}                        |${reset}"
    echo -e "${wall}  ${ghost1}  | OO| ${ghost2}| OO| ${pacman}  / _.-' ${cherry}.-.   .-.  .-.   .''.  ${wall}|${reset}"
    echo -e "${wall}  ${ghost1}  |   | ${ghost2}|   | ${pacman}  \\  '-. ${cherry}'-'   '-'  '-'   '..'  ${wall}|${reset}"
    echo -e "${wall}  ${ghost1}  '^^^' ${ghost2}'^^^' ${pacman}   '--'  ${wall}                       |${reset}"
    echo -e "${wall}===============. ${color88} .-. ${wall} .================. ${cherry} .-.  ${wall}|${reset}"
    echo -e "${wall}               | ${color88}|   |${wall} |                | ${cherry} '-'  ${wall}|${reset}"
    echo -e "${wall}               | ${color88}|   |${wall} |                |       |${reset}"
    echo -e "${wall}               | ${color88}':-:'${wall} |                | ${cherry} .-.  ${wall}|${reset}"
    echo -e "${wall}               | ${color88} '-' ${wall} |                | ${cherry} '-'  ${wall}|${reset}"
    echo -e "${wall}==============='       '================'       |${reset}"
}

function ascii_art_saturn() {
    local bg=$'\033[48;5;0m\033[38;5;195m'
    local planet=$'\033[38;5;76m'
    local moon=$'\033[38;5;203m'
    local ring=$'\033[38;5;61m'
    local clr=$'\033[0m'

    echo -e "${bg}        ~+                                    ${clr}"
    echo -e "${bg}                                              ${clr}"
    echo -e "${bg}                 *       +                    ${clr}"
    echo -e "${bg}            '                   |             ${clr}"
    echo -e "${bg}        ${moon}()${planet}    ${ring}.-.${planet},=\"\`\"=.${bg}     - o -           ${clr}"
    echo -e "${bg}              ${ring}'=${planet}/${ring}_${planet}       \\${bg}      |             ${clr}"
    echo -e "${bg}          *    ${planet}|  ${ring}'=._${planet}    |${bg}                   ${clr}"
    echo -e "${bg}                ${planet}\\     ${ring}\`=./${planet}\\${ring}\`,${bg}        '         ${clr}"
    echo -e "${bg}            .    ${planet}'=.__.=' ${ring}\`='${bg}      *          ${clr}"
    echo -e "${bg}   +                         +                ${clr}"
    echo -e "${bg}        O      *        '       .             ${clr}"
    echo -e "${bg}                                              ${clr}"
    echo -e "${clr}"
}

function ascii_art_snufkin() {
    local sky=$'\033[48;5;233m'
    local hat=$'\033[38;5;106m'
    local coat=$'\033[38;5;94m'
    local rock=$'\033[38;5;195m'
    local clr=$'\033[0m'
    local star=$'\033[38;5;255m'
    local feather=$'\033[38;5;202m'
    local face=$'\033[38;5;178m'

    echo -e "${sky}${hat}          .-.      ${star}*     ${clr}"
    echo -e "${sky}${hat}       __/   (           ${clr}"
    echo -e "${sky}${feather}     , ${hat}'-.____\\      ${star}*   ${clr}"
    echo -e "${sky}${face}      u=='${coat}/  \\           ${clr}"
    echo -e "${sky}${coat}         /_/  \\          ${clr}"
    echo -e "${sky}  ${star}*${coat}    .-''   |          ${clr}"
    echo -e "${sky}${coat}      (  ____/${rock}_____      ${clr}"
    echo -e "${sky}${coat}      _>_/${rock}.--------      ${clr}"
    echo -e "${sky}${coat}      \\/${rock}//               ${clr}"
    echo -e "${sky}${rock}       //                ${clr}"
    echo -e "${sky}${rock}      //                 ${clr}"
    echo -e "${sky}${rock}                         ${clr}"
}

# Print the pedro raccoon with random contrasting colors.
# Usage: ascii_art_pedro [TEXT]
function ascii_art_pedro() {
    [[ -n "${_REDSHELL_ZSH}" ]] && emulate -L ksh
    local bgc=$(($RANDOM % 256))
    local fgc=$(($RANDOM % 256))
    while [[ $(contrast $(xterm_to_rgb $bgc) $(xterm_to_rgb $fgc)) -lt 70 ]]; do
        bgc=$(($RANDOM % 256))
        fgc=$(($RANDOM % 256))
    done

    local fc=$'\033[38;5;'"${fgc}"'m'
    local bc=$'\033[48;5;'"${bgc}"'m'
    local clr=$'\033[0m'

    if [[ ! -z "${1}" ]]; then
        IFS=$'\n' read -r -d '' ${_REDSHELL_READ_ARRAY_FLAG} lines <<< "${1}"
    fi

    local cols="${COLUMNS:-80}"
    ((cols -= 30))

    printf "
%s  ___            ___ %s %-${cols}s
%s /   \          /   \%s %-${cols}s
%s \__  \        /   _/%s %-${cols}s
%s  __\  \      /   /_ %s %-${cols}s
%s  \__   \____/  ___/ %s %-${cols}s
%s     \_       _/     %s %-${cols}s
%s  ____/  @ @ |       %s %-${cols}s
%s             |       %s %-${cols}s
%s       /\     \_     %s %-${cols}s
%s     _/ /\o)  (o\    %s %-${cols}s
%s        \ \_____/    %s %-${cols}s
%s         \____/      %s %-${cols}s\n" \
        "${fc}${bc}" "${clr}" "${lines[0]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[1]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[2]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[3]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[4]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[5]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[6]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[7]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[8]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[9]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[10]:0:${cols}}" \
        "${fc}${bc}" "${clr}" "${lines[11]:0:${cols}}"
}

function print_pedro() {
    ascii_art_pedro "$@"
}

function scroll_output_pedro() {
    local _path="${1}"
    ascii_art_pedro
    while IFS= read -r line; do
        erase_lines 13 -q
        ascii_art_pedro "$(tail -n 12 "${_path}")"
    done
    echo
}


function select_visual() {
    # Make sure there's nothing there as we source bash_profile, to get the color
    # functions.
    VISUAL_CONFIG_PATH="$HOME/.redshell_visual"
    echo "" > "$VISUAL_CONFIG_PATH"

    if [[ -n "${1}" ]]; then
        echo "${1}" > "$VISUAL_CONFIG_PATH"
        source ~/.bash_profile
        return
    fi

    echo "Select visual identity"
    echo "(1)   None (DEFAULT)"
    echo -e "(2)   $(__prompt_color bmo)BMO\033[0m"
    echo -e "(3)   $(__prompt_color lighthouse)Lighthouse\033[0m"
    echo -e "(4)   $(__prompt_color astronaut)Astronaut\033[0m"
    echo -e "(5)   $(__prompt_color pacman)Pac-Man\033[0m"
    echo -e "(6)   $(__prompt_color dachshund)Eddie the Sausage Dog\033[0m"
    echo -e "(7)   $(__prompt_color saturn)Planet\033[0m"
    echo -e "(8)   $(__prompt_color drwho)TARDIS\033[0m"
    echo -e "(9)   $(__prompt_color snufkin)Snufkin\033[0m"
    echo -e "(a)   $(__prompt_color moose)Moose\033[0m"
    echo -e "(b)   $(__prompt_color bessy)Bessy\033[0m"

    echo -n "Select 1-b or ENTER for default: "
    if [[ -n "${_REDSHELL_ZSH}" ]]; then
        read -k1 OPTION
    else
        read -n1 OPTION
    fi

    case "$OPTION" in
        1) echo "" > "$VISUAL_CONFIG_PATH" ;;
        2) echo "bmo" > "$VISUAL_CONFIG_PATH" ;;
        3) echo "lighthouse" > "$VISUAL_CONFIG_PATH";;
        4) echo "astronaut" > "$VISUAL_CONFIG_PATH";;
        5) echo "pacman" > "$VISUAL_CONFIG_PATH";;
        6) echo "dachshund" > "$VISUAL_CONFIG_PATH";;
        7) echo "saturn" > "$VISUAL_CONFIG_PATH";;
        8) echo "drwho" > "$VISUAL_CONFIG_PATH";;
        9) echo "snufkin" > "$VISUAL_CONFIG_PATH";;
        a) echo "moose" > "$VISUAL_CONFIG_PATH";;
        b) echo "bessy" > "$VISUAL_CONFIG_PATH";;
        *) echo "" > "$VISUAL_CONFIG_PATH" ;;
    esac

    echo
    echo "Done"

    if [[ -n "${_REDSHELL_ZSH}" ]]; then
        source ~/.zprofile
    else
        source ~/.bash_profile
    fi
}

fi # _REDSHELL_ASCII_ART
