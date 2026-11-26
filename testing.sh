#!/usr/bin/env bash

target="the quick brown fox jumps over the lazy dog"
typed=""


GREEN='\e[1;92m'     # correct characters
RED='\e[1;91m'       # incorrect characters
YELLOW='\e[1;93m'    # current character
GRAY='\e[1;90m'      # upcoming characters
RESET='\e[0m'


while true; do


    IFS= read -rsn1 key

    # backspace
    if [[ $key == $'\x7f' || $key == $'\x08' ]]; then
        typed="${typed%?}"

    # ignore enter
    elif [[ $key == "" ]]; then
        continue

    else
        typed+="$key"
    fi

    # redraw the sentence
    printf '\r'

    for ((i=0; i<${#target}; i++)); do

        if (( i < ${#typed} )); then

            # correctly typed character
            if [[ ${typed:i:1} == "${target:i:1}" ]]; then
                printf "${GREEN}%s${RESET}" "${target:i:1}"

            # incorrectly typed character
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

    # finish when the entire sentence has been typed
    (( ${#typed} >= ${#target} )) && break

done

echo
