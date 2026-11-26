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
        if