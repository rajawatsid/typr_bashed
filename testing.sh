#!/usr/bin/env bash
target="the quick brown fox jumps over the lazy dog"
typed=""

while IFS= read -rsn key; do
    #\x7f should be backspace
    if [[ $key == $'\x7f' ]]; then 
        typed="${typed%?}"
    else
        typed+="$key"
    fi

    printf '\r'
    for ((i=0; i<{#target}; i++)); do
        if   (( i >= ${#typed} ));            then printf '\e[2m%s\e[0m'  "${target:i:1}"
        elif [[ ${typed:i:1} == ${target:i:1} ]]; then printf '\e[32m%s\e[0m' "${target:i:1}"
        else                                       printf '\e[31m%s\e[0m' "${target:i:1}"
        fi
    done

    (( ${#typed} >= ${#target} )) && break
done
echo