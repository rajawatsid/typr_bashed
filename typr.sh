#!/usr/bin/env bash


VERSION="0.0.1"

: "${HOME:?HOME is not set}"

# where installed code lives (install.sh puts things here)
BIN_DIR="${TYPR_BIN_DIR:-$HOME/.local/bin}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/typr"

# look next to the script first (for development), then in the install folder
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORD_FILE="$SCRIPT_DIR/words/english.txt"
[[ -f $WORD_FILE ]] || WORD_FILE="$DATA_DIR/words/english.txt"

target=""
typed=""

drawn_lines=0

# for how many word to add at once
WORDS_TO_ADD=30

# how many lines of text are shown at once
WINDOW_LINES=5


duration=0
start_time=0

cols=78
top_line=0
total_lines=1
prev_len=0
resized=0
started=0

line_of=()
col_of=()
line_start=(0)


# colors

GREEN='\e[1;92m'
RED='\e[1;91m'
YELLOW='\e[1;93m'
GRAY='\e[1;90m'
RESET='\e[0m'


if (( BASH_VERSINFO[0] < 4 )); then
    echo "typr needs bash 4 or newer (you have $BASH_VERSION)." >&2
    echo "On macOS you can get it with: brew install bash" >&2
    exit 1
fi


usage() {
    cat << 'EOF'
typr - a tiny typing test for your terminal

Usage:
  typr              start a test
  typr --help       show this help
  typr --version    show the version
  typr --uninstall  remove typr from your system
EOF
}

uninstall() {

    local bin="$BIN_DIR/typr"

    if [[ ! -f $bin && ! -d $DATA_DIR ]]; then
        echo "typr doesn't seem to be installed."
        return
    fi

    read -rp "Remove typr? [y/N] " yn

    if [[ $yn == [yY]* ]]; then
        rm -f "$bin"
        rm -rf "$DATA_DIR"
        echo "typr removed."
    else
        echo "Cancelled."
    fi

}

case "${1:-}" in
    "") ;;
    -h|--help) usage; exit 0 ;;
    -v|--version) echo "typr $VERSION"; exit 0 ;;
    --uninstall) uninstall; exit 0 ;;
    *)
        echo "typr: unknown option: $1" >&2
        echo "Try 'typr --help'." >&2
        exit 1
        ;;
esac

if [[ ! -t 0 || ! -t 1 ]]; then
    echo "typr needs to run in a terminal." >&2
    exit 1
fi

if [[ ! -s $WORD_FILE ]]; then
    echo "typr: word list not found: $WORD_FILE" >&2
    exit 1
fi


# put the cursor back if game gets interrupted
trap 'printf "\033[?25h\n"; exit' INT TERM

# remember when the terminal gets resized
trap 'resized=1' WINCH


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
echo "  1. Enlarge your text in the editor"
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


# how wide the text area is
set_cols() {

    cols=$(( $(tput cols 2>/dev/null || echo 80) - 2 ))

    (( cols < 10 )) && cols=10

}


# works out where every character goes on screen
compute_layout() {

    local i char next_word
    local row=0
    local col=1

    line_of=()
    col_of=()
    line_start=(0)

    for ((i=0; i<${#target}; i++)); do

        char="${target:i:1}"

        line_of[i]=$row
        col_of[i]=$col
        ((col++))

        # move to next line if needed
        if [[ $char == " " ]]; then

            next_word="${target:i+1}"
            next_word="${next_word%% *}"

            if (( col + ${#next_word} - 1 > cols )); then
                col=$((cols + 2))
            fi

        fi

        # a space is allowed to sit one cell past the end of the line
        if (( col > cols + 1 )); then
            ((row++))
            col=1
            line_start[row]=$((i + 1))
        fi

    done

    total_lines=$((row + 1))

}


# for more words  in target
add_words() {

    local new_words

    if command -v shuf >/dev/null 2>&1; then
        new_words=$(shuf -n "$WORDS_TO_ADD" "$WORD_FILE" | tr -d '\r' | paste -sd ' ' -)
    else
        new_words=$(sort -R "$WORD_FILE" | head -n "$WORDS_TO_ADD" | tr -d '\r' | paste -sd ' ' -)
    fi

    if [[ -z $target ]]; then
        target="$new_words"
    else
        target+=" $new_words"
    fi

    compute_layout

}

# for more check wordings
check_words() {

    local left=$((${#target} - ${#typed}))

    if (( left < 100 )); then
        add_words
    fi

}


# keeps the current line on the second row once you get going
update_top() {

    local cur_line

    if (( ${#typed} >= ${#target} )); then
        cur_line=$((total_lines - 1))
    else
        cur_line=${line_of[${#typed}]}
    fi

    if (( cur_line > 1 )); then
        top_line=$((cur_line - 1))
    else
        top_line=0
    fi

}


# draws a single character of the text
draw_char() {

    local i=$1
    local char color screen_row

    (( i >= ${#target} )) && return

    screen_row=$((5 + line_of[i] - top_line))

    # skip anything outside of the shown lines
    (( screen_row < 5 || screen_row >= 5 + WINDOW_LINES )) && return

    char="${target:i:1}"

    # only redraw characters that have changed
    if (( i < ${#typed} )); then

        if [[ ${typed:i:1} == "$char" ]]; then
            color="$GREEN"
        else
            color="$RED"

            # a wrong space would be invisible otherwise
            [[ $char == " " ]] && char="_"
        fi

    elif (( i == ${#typed} )); then
        color="$YELLOW"

    else
        color="$GRAY"
    fi

    # position cursor
    printf '\033[%d;%dH' "$screen_row" "${col_of[i]}"

    if (( i == ${#typed} )); then
        printf '\033[4m%b%s%b\033[24m' "$color" "$char" "$RESET"
    else
        printf '%b%s%b' "$color" "$char" "$RESET"
    fi

}


# text comes out
draw_text() {

    local r i from to

    update_top

    for ((r=0; r<WINDOW_LINES; r++)); do
        printf '\033[%d;1H\033[2K' "$((5 + r))"
    done

    from=${line_start[top_line]:-${#target}}
    to=${line_start[top_line + WINDOW_LINES]:-${#target}}

    for ((i=from; i<to; i++)); do
        draw_char "$i"
    done

    drawn_lines=$WINDOW_LINES

}


# only touches the characters around the cursor
redraw_changed() {

    local old_top=$top_line
    local i from to

    update_top

    # the text scrolled so everything moves
    if (( top_line != old_top )); then
        draw_text
        return
    fi

    if (( prev_len < ${#typed} )); then
        from=$prev_len
        to=${#typed}
    else
        from=${#typed}
        to=$prev_len
    fi

    for ((i=from; i<=to; i++)); do
        draw_char "$i"
    done

}


# times

draw_timer() {

    local elapsed=$((SECONDS - start_time))
    local remaining=$((duration - elapsed))

    (( remaining < 0 )) && remaining=0

    # timer goes on the third line
    printf '\033[3;1H'
    printf '\033[2K'
    printf "Time left: %s seconds" "$remaining"

}


draw_header() {

    echo "Type the sentence below!"
    echo
    echo "Timer starts with your first keypress."

}


# redo everything after the terminal size changed
handle_resize() {

    resized=0

    set_cols
    compute_layout

    printf '\033[H\033[2J'

    draw_header
    draw_text

    (( started )) && draw_timer

}


# user type it and color change
update_input() {

    # backspace
    if [[ $key == $'\x7f' || $key == $'\x08' ]]; then
        typed="${typed%?}"

    # ignore enter
    elif [[ -z $key ]]; then
        return

    # ignore arrow keys and other escape sequences
    elif [[ $key == $'\e' ]]; then
        read -rsn2 -t 0.01 _
        return

    # don't let it grow past the sentence
    elif (( ${#typed} < ${#target} )); then
        typed+="$key"
    fi

}

set_cols
check_words


printf '\033[H\033[2J'

choose_duration

# the window might have changed size while in the menu
resized=0
set_cols
compute_layout

printf '\033[H\033[2J'

# hide cursor while playing
printf '\033[?25l'

draw_header


printf '\n\n'

draw_text


# wait for first keypress then do timer
while true; do

    IFS= read -rsn1 key
    status=$?

    # interrupted by a resize
    if (( status > 128 )); then
        (( resized )) && handle_resize
        continue
    fi

    # input is gone
    (( status != 0 )) && exit 1

    # only a real character starts the timer
    case "$key" in
        "") continue ;;
        $'\e') read -rsn2 -t 0.01 _; continue ;;
        $'\x7f'|$'\x08') continue ;;
    esac

    break

done

start_time=$SECONDS
started=1

prev_len=${#typed}
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

        prev_len=${#typed}
        update_input
        check_words
        # redraw sentence
        redraw_changed

    fi

    (( resized )) && handle_resize

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