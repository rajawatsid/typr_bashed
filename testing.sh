#!/usr/bin/env bash


target="the quick brown fox jumps over the lazy dog"
typed=""

duration=0
start_time=0



GREEN='\e[1;92m'
RED='\e[1;91m'
YELLOW='\e[1;93m'
GRAY='\e[1;90m'
RESET='\e[0m'

# duration thingy

choose_duration() {

    echo "=============================="
    echo "       Welcome to Typr!"
    echo "=============================="
    echo
    echo "How long do you wanna type for?"
    echo
    echo "1) 10 seconds"
    echo "2) 30 seconds"
    echo "3) 60 seconds"
    echo

    while true; do

        read -rp "Your choice: " choice

        case "$choice" in
            1) duration=10; break ;;
            2) duration=30; break ;;
            3) duration=60; break ;;
            *) echo "Invalid choice! Try again." ;;
        esac

    done
}


# for showing text

draw_text() {

    printf '\r\033[2K'

    for ((i=0; i<${#target}; i++)); do

        if (( i < ${#typed} )); then

            # correctly typed
            if [[ ${typed:i:1} == "${target:i:1}" ]]; then
                printf "${GREEN}%s${RESET}" "${target:i:1}"

            # incorrectly typed
            else
                printf "${RED}%s${RESET}" "${target:i:1}"
            fi

        elif (( i == ${#typed} )); then

            # current character
            printf "${YELLOW}%s${RESET}" "${target:i:1}"

        else

            # upcoming characters
            printf "${GRAY}%s${RESET}" "${target:i:1}"

        fi

    done
}


# for timer display

draw_timer() {

    elapsed=$((SECONDS - start_time))
    remaining=$((duration - elapsed))

    (( remaining < 0 )) && remaining=0

    printf '\r\033[2KTime left: %s seconds' "$remaining"
}


update_input() {

    # backspace
    if [[ $key == $'\x7f' || $key == $'\x08' ]]; then
        typed="${typed%?}"

    # ignore enter
    elif [[ -z $key ]]; then
        return

    else
        typed+="$key"
    fi

}


# game

choose_duration

clear

echo "Type the sentence below!"
echo
echo "Timer starts with your first keypress."

# wait for first keypress
IFS= read -rsn1 key

# NOW draw the sentence
echo
draw_text

# start timer
start_time=$SECONDS

update_input

# put cursor on the timer line
echo
draw_timer


# main game loop
while true; do

    elapsed=$((SECONDS - start_time))
    remaining=$((duration - elapsed))

    (( remaining <= 0 )) && break

    # wait for input for up to one second
    if IFS= read -rsn1 -t 1 key; then

        update_input

        # redraw sentence
        printf '\033[1A'
        draw_text
        printf '\n'

    fi

    # update timer
    draw_timer

done



echo
echo
echo "=============================="
echo "          Time's up!"
echo "=============================="
echo
echo "You typed ${#typed} characters!"
echo
