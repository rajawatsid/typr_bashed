#!/usr/bin/env bash


target="the quick brown fox jumps over the lazy dog"
typed=""

duration=0
start_time=0


# colors

GREEN='\e[1;92m'
RED='\e[1;91m'
YELLOW='\e[1;93m'
GRAY='\e[1;90m'
RESET='\e[0m'


# duration thingy
choose_duration() {

    cat << 'EOF'
 _______ __   __ ____   ____
|__   __|\ \ / /  _  \ |  _  \
   | |    \ V /| |_)  ||_|_)_/
   | |     | | |  ___/ | | \ \
   |_|     |_| |_|     |_|  \_\

EOF

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


# text comes out

draw_text() {

    # go to the sentence line
    printf '\033[5;1H'
    printf '\033[2K'

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


# times

draw_timer() {

    elapsed=$((SECONDS - start_time))
    remaining=$((duration - elapsed))

    (( remaining < 0 )) && remaining=0

    # timer goes on the third line
    printf '\033[7;1H'
    printf '\033[2K'
    printf "Time left: %s seconds" "$remaining"

}


# user type it and color change
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


# to clear terminal and start from the top
printf '\033[H\033[2J'

choose_duration

printf '\033[H\033[2J'

echo "Type the sentence below!"
echo
echo "Timer starts with your first keypress."


printf '\n\n'

draw_text


# wait for first keypress then do timer
IFS= read -rsn1 key

start_time=$SECONDS

update_input

draw_text
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
        draw_text

    fi

    # update timer
    draw_timer

done


# move cursor to down the game
printf '\033[9;1H'

elapsed=$((SECONDS - start_time))
typed_chars=${#typed}
correct_chars=0

for ((i=0; i<typed_chars; i++)); do

    if (( i < ${#target} )) && [[ ${typed:i:1} == "${target:i:1}" ]]; then
        ((correct_chars++))
    fi

done

if (( elapsed > 0 )); then
    wpm=$(( (typed_chars * 12 + elapsed / 2) / elapsed ))
else
    wpm=0
fi

if (( typed_chars > 0 )); then
    accuracy=$(( (correct_chars * 100 + typed_chars / 2) / typed_chars ))
else
    accuracy=0
fi

echo
echo "=============================="
echo "          Time's up!"
echo "=============================="
echo
echo "You typed $typed_chars characters in $elapsed seconds!"
echo
echo "Your WPM is ~$wpm"
echo
echo "Your accuracy is ~$accuracy%"
echo