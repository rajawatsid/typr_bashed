
#!/usr/bin/env bash

target="the quick brown fox jumps over the lazy dog"
typed=""

GREEN='\e[1;92m'
RED='\e[1;91m'
YELLOW='\e[1;93m'
GRAY='\e[1;90m'
RESET='\e[0m'

echo "welcome to typr! here we cloned monkeytype for a terminal user interface! (tui)"

# duration thingy
echo "How long do you wanna type for?"
echo "1) 10 seconds"
echo "2) 30 seconds"
echo "3) 60 seconds"

read -r choice

case "$choice" in
    1) duration=10 ;;
    2) duration=30 ;;
    3) duration=60 ;;
    *) echo "Invalid option!"; exit 1 ;;
esac


# draw the sentence
draw_text() {

    printf '\r'

    for ((i=0; i<${#target}; i++)); do

        if (( i < ${#typed} )); then

            if [[ ${typed:i:1} == "${target:i:1}" ]]; then
                printf "${GREEN}%s${RESET}" "${target:i:1}"
            else
                printf "${RED}%s${RESET}" "${target:i:1}"
            fi

        elif (( i == ${#typed} )); then
            printf "${YELLOW}%s${RESET}" "${target:i:1}"

        else
            printf "${GRAY}%s${RESET}" "${target:i:1}"
        fi

    done
}


# display the sentence immediately
draw_text

echo
echo "Timer starts when you type your first key!"


# wait for the first key
IFS= read -rsn1 key

# start timer
start_time=$SECONDS

# process first key
if [[ $key == $'\x7f' || $key == $'\x08' ]]; then
    typed="${typed%?}"
elif [[ -n $key ]]; then
    typed+="$key"
fi

draw_text


# typing loop
while true; do

    # for left time
    elapsed=$((SECONDS - start_time))
    remaining=$((duration - elapsed))

    (( remaining <= 0 )) && break

    # read input, but stop waiting when time runs out
    if IFS= read -rsn1 -t "$remaining" key; then

        # backspace
        if [[ $key == $'\x7f' || $key == $'\x08' ]]; then
            typed="${typed%?}"

        elif [[ -n $key ]]; then
            typed+="$key"
        fi

        draw_text

    else
        break
    fi

done

echo
echo "============================================"
echo
echo "Time's up!"