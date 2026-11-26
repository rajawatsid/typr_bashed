#!/usr/bin/env bash


WORD_FILE="$(dirname "$0")/words/english.txt"

target=""
typed=""

drawn_lines=0

# for how many word to add at once
WORDS_TO_ADD=30


duration=0
start_time=0


# colors

GREEN='\e[1;92m'
RED='\e[1;91m'
YELLOW='\e[1;93m'
GRAY='\e[1;90m'
RESET='\e[0m'


# put the cursor back if game gets interrupted
trap 'printf "\033[?25h\n"; exit' INT TERM


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
echo "A few suggestions to increase your wpm:"
echo
echo "  1. Enlarge your text in the edior"
echo "  2. Sit in a comfortable position"
echo "  3. Use a keyboard you are comfortable with"
echo "  4. Remove any distracting elements if you can"

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



# for more words  in target
add_words() {
    new_words=$(shuf -n "$WORDS_TO_ADD" "$WORD_FILE" | paste -sd ' ' -)

    if [[ -z $target ]]; then
        target="$new_words"
    else
        target+=" $new_words"
    fi
}

# for more check wordings
check_words() {
    remaining=$((${#target} - ${#typed}))

    if (( remaining < 100 )); then
        add_words
    fi
}


# text comes out
draw_text() {

    cols=$(($(tput cols) - 2))
    row=5
    col=1

    for ((i=0; i<${#target}; i++)); do

        char="${target:i:1}"

        # move to next line if needed
        if [[ $char == " " ]]; then

            next_word="${target:i+1}"
            next_word="${next_word%% *}"

            if (( col + ${#next_word} > cols )); then
                ((row++))
                col=1
                continue
            fi

        fi

        # only redraw characters that have changed
        if (( i < ${#typed} )); then

            if [[ ${typed:i:1} == "${target:i:1}" ]]; then
                color="$GREEN"
            else
                color="$RED"
            fi

        elif (( i == ${#typed} )); then
            color="$YELLOW"

        else
            color="$GRAY"
        fi

        # position cursor
        printf '\033[%d;%dH' "$row" "$col"

        if (( i == ${#typed} )); then
            printf '\033[4m%b%s%b\033[24m' "$color" "$char" "$RESET"
        else
            printf '%b%s%b' "$color" "$char" "$RESET"
        fi

        ((col++))

        if (( col > cols )); then
            ((row++))
            col=1
        fi

    done

    drawn_lines=$((row - 5 + 1))

}



# times

draw_timer() {

    elapsed=$((SECONDS - start_time))
    remaining=$((duration - elapsed))

    (( remaining < 0 )) && remaining=0

    # timer goes on the third line
    printf '\033[3;1H'
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

    elif [[ $key == $'\e' ]]; then
        read -rsn2 -t 0.01 _
        return

    elif (( ${#typed} < ${#target} )); then
        typed+="$key"
    fi

}

check_words


printf '\033[H\033[2J'

choose_duration

printf '\033[H\033[2J'

# hide cursor while playing
printf '\033[?25l'

echo "Type the sentence below!"
echo
echo "Timer starts with your first keypress."


printf '\n\n'

draw_text


# wait for first keypress then do timer
IFS= read -rsn1 key

start_time=$SECONDS

update_input
check_words
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
        check_words
        # redraw sentence
        draw_text

    fi

    # update timer
    draw_timer

done


# move cursor below game
printf '\033[%d;1H' "$((6 + drawn_lines))"

# show the cursor again
printf '\033[?25h'

elapsed=$duration
typed_chars=${#typed}
correct_chars=0

for ((i=0; i<typed_chars; i++)); do

    if (( i < ${#target} )) && [[ ${typed:i:1} == "${target:i:1}" ]]; then
        ((correct_chars++))
    fi

done

# only correct characters to count towards wpm
wpm=$(( (correct_chars * 12 + elapsed / 2) / elapsed ))

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