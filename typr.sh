#!/usr/bin/env bash


VERSION="DEVELOPMENT"

: "${HOME:?HOME is not set}"

# where installed code lives (install.sh puts things here)
BIN_DIR="${TYPR_BIN_DIR:-$HOME/.local/bin}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/typr"
HISTORY_FILE="$DATA_DIR/history.csv"
[[ -s "$DATA_DIR/version" ]] && IFS= read -r VERSION < "$DATA_DIR/version"

# look next to the script first (for development), then in the install folder
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORD_FILE="$SCRIPT_DIR/words/english.txt"
[[ -f $WORD_FILE ]] || WORD_FILE="$DATA_DIR/words/english.txt"

target=""
typed=""


layout_start=0


# wrong red letters
extra_at=()

# wrong letters can pile up in front of one real letter
MAX_EXTRA=8

layout_changed=0

total_keys=0
wrong_keys=0

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


display=""
cell_src=()
cell_of=()
cell_line=()
cell_col=()
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
  typr                  start a test
  typr --help           show this help
  typr --version        show the version
  typr --update         update typr to the latest version
  typr --show-history   show saved sessions
  typr --uninstall      remove typr from your system
EOF
}



update_typr() {

    local installer
    local latest_version
    local latest_release
    local current_version="${VERSION#v}"

    local repo="rajawatsid/typr_bashed"
    local api_url="https://api.github.com/repos/$repo/releases/latest"
    local update_url="https://github.com/$repo/releases/latest/download/install.sh"

    if ! command -v curl >/dev/null 2>&1; then
        echo "typr: curl is required to update typr." >&2
        return 1
    fi

    echo "Checking for the latest version of typr..."

    # get the latest release information from github
    latest_release=$(curl -fsSL \
        -H "Accept: application/vnd.github+json" \
        -H "User-Agent: typr" \
        "$api_url") || {
        echo "typr: couldn't get the latest release from github." >&2
        return 1
    }

    latest_version=$(printf '%s\n' "$latest_release" |
        sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p')

    if [[ -z $latest_version ]]; then
        echo "typr: couldn't find the latest version on github." >&2
        return 1
    fi

    latest_version="${latest_version#v}"

    # check if typr is already up to date
    if [[ $current_version == "$latest_version" ]]; then
        echo "You're already using the latest version of typr!"
        echo "Current version: $VERSION"
        return 0
    fi

    cat << 'EOF'
 _    _  _____   _____      ___   _______  _______  ___    _   _____
| |  | ||  _  \ |  __  \   / _ \ |__   __||__   __||   \  | | /  ___|
| |  | || |_)  || |  \  \ / /_\ \   | |      | |   | |\ \ | |/  /  __
| \__/ ||  ___/ | |__/  // /---\ \  | |    __| |__ | | \ \| |\  \__\ \
 \____/ |_|     |_____ //_/     \_\ |_|   |_______||_|  \___| \_____ /
                 _______ __   __ ____   ____
                |__   __|\ \ / /  _  \ |  _  \
                   | |    \ V /| |_)  ||_|_)_/
                   | |     | | |  ___/ | | \ \
                   |_|     |_| |_|     |_|  \_\

EOF

    echo "                            To v$latest_version"
    echo "==========================================================================="
    echo "A new version of typr is available!"
    echo "Current version: $VERSION"
    echo "Latest version:  v$latest_version"
    echo

    installer=$(mktemp) || {
        echo "typr: couldn't create a temporary file for the update." >&2
        return 1
    }

    # download the installer
    if ! curl -fsSL "$update_url" -o "$installer"; then
        rm -f "$installer"
        echo "typr: couldn't download the update installer." >&2
        return 1
    fi

    echo "Running the installer..."

    if bash "$installer"; then
        rm -f "$installer"
        echo "typr update complete!"
    else
        local status=$?
        rm -f "$installer"
        echo "typr: update failed." >&2
        return "$status"
    fi

}


update_personal_best() {

    local personal_best_file="$DATA_DIR/personal_best_${duration}"
    local previous_best=0
    local found=0
    local session_date session_time session_duration session_wpm
    local session_accuracy characters correct incorrect

    if [[ -s $personal_best_file ]]; then
        IFS= read -r previous_best < "$personal_best_file"
        if [[ $previous_best =~ ^[0-9]+$ ]]; then
            found=1
        else
            previous_best=0
        fi
    elif [[ -s $HISTORY_FILE ]]; then
        while IFS=, read -r session_date session_time session_duration session_wpm \
            session_accuracy characters correct incorrect; do
            [[ $session_date == "date" ]] && continue
            if [[ $session_duration == "$duration" && $session_wpm =~ ^[0-9]+$ ]]; then
                if (( ! found || session_wpm > previous_best )); then
                    previous_best=$session_wpm
                    found=1
                fi
            fi
        done < "$HISTORY_FILE"
    fi

    mkdir -p "$DATA_DIR" || return 1

    if (( ! found )); then
        printf '%s\n' "$wpm" > "$personal_best_file" || return 1
        personal_best=$wpm
        personal_best_status="first"
    elif (( wpm > previous_best )); then
        printf '%s\n' "$wpm" > "$personal_best_file" || return 1
        personal_best=$wpm
        personal_best_status="new"
    else
        personal_best=$previous_best
        personal_best_status="same"
    fi

}

save_session() {

    mkdir -p "$DATA_DIR" || {
        echo "typr: couldn't create the history folder." >&2
        return 1
    }

    if [[ ! -s $HISTORY_FILE ]]; then
        echo "date,time,duration,wpm,accuracy,characters,correct,incorrect" > "$HISTORY_FILE"
    fi

    printf '%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$(date +%F)" \
        "$(date +%H:%M)" \
        "$duration" \
        "$wpm" \
        "$accuracy" \
        "$total_keys" \
        "$((total_keys - wrong_keys))" \
        "$wrong_keys" >> "$HISTORY_FILE"

}

show_history() {

    local i line session_date session_time session_duration session_wpm
    local session_accuracy characters correct incorrect
    local -a sessions=()

    echo
    echo "==================================="
    echo "          SESSION HISTORY"
    echo "==================================="
    echo

    if [[ ! -s $HISTORY_FILE ]]; then
        echo "No sessions saved yet."
    else
        while IFS= read -r line; do
            [[ $line == date,* ]] && continue
            [[ -n $line ]] && sessions+=("$line")
        done < "$HISTORY_FILE"

        if (( ${#sessions[@]} == 0 )); then
            echo "No sessions saved yet."
        else
            printf '%-12s %-6s %-5s %-9s %s\n' "DATE" "TIME" "WPM" "ACCURACY" "DURATION"
            echo "------------------------------------------------"
            for ((i=${#sessions[@]}-1; i>=0; i--)); do
                IFS=, read -r session_date session_time session_duration session_wpm \
                    session_accuracy characters correct incorrect <<< "${sessions[i]}"

                printf '%-12s %-6s %-5s %-9s %ss\n' \
                    "$session_date" "$session_time" "$session_wpm" \
                    "${session_accuracy}%" "$session_duration"
            done
        fi
    fi

    echo
    if [[ ${1:-} != "--no-pause" ]]; then
        read -rsn1 -p "Press any key to return..."
        echo
    fi

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
    --update) update_typr; exit $? ;;
    --show-history) show_history --no-pause; exit 0 ;;
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
echo "version: $VERSION"

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
            q|Q)
                echo
                echo "bye bye"
                exit 0
                ;;
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

    local i j k char next_word extras
    local row=0
    local col=1

    display=""
    cell_src=()
    cell_of=()
    cell_line=()
    cell_col=()
    line_start=(0)

    # put the wrong letters in front of the real letter they were typed at
    k=0

    for ((i=0; i<${#target}; i++)); do

        extras="${extra_at[i]-}"

        for ((j=0; j<${#extras}; j++)); do
            display+="${extras:j:1}"
            cell_src[k]=-1
            ((k++))
        done

        display+="${target:i:1}"
        cell_src[k]=$i
        cell_of[i]=$k
        ((k++))

    done

    for ((k=0; k<${#display}; k++)); do

        char="${display:k:1}"

        cell_line[k]=$row
        cell_col[k]=$col
        ((col++))

        # move to next line if needed
        if [[ $char == " " ]]; then

            next_word="${display:k+1}"
            next_word="${next_word%% *}"

            if (( col + ${#next_word} - 1 > cols )); then
                col=$((cols + 2))
            fi

        fi

        # a space is allowed to sit one cell past the end of the line
        if (( col > cols + 1 )); then
            ((row++))
            col=1
            line_start[row]=$((k + 1))
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

    local cur_line k

    if (( ${#typed} >= ${#target} )); then
        cur_line=$((total_lines - 1))
    else
        k=${cell_of[${#typed}]}
        cur_line=${cell_line[k]}
    fi

    if (( cur_line > 1 )); then
        top_line=$((cur_line - 1))
    else
        top_line=0
    fi

}


# draws a single character of the text
draw_char() {

    local k=$1
    local char color screen_row src

    (( k >= ${#display} )) && return

    screen_row=$((5 + cell_line[k] - top_line))

    # skip anything outside of the shown lines
    (( screen_row < 5 || screen_row >= 5 + WINDOW_LINES )) && return

    char="${display:k:1}"
    src=${cell_src[k]}

    # only redraw characters that have changed
    if (( src < 0 )); then

        color="$RED"

    elif (( src < ${#typed} )); then

        color="$GREEN"

    elif (( src == ${#typed} )); then
        color="$YELLOW"

    else
        color="$GRAY"
    fi

    # position cursor
    printf '\033[%d;%dH' "$screen_row" "${cell_col[k]}"

    if (( src == ${#typed} )); then
        printf '\033[4m%b%s%b\033[24m' "$color" "$char" "$RESET"
    else
        printf '%b%s%b' "$color" "$char" "$RESET"
    fi

}


# text comes out
draw_text() {

    local r k from to

    update_top

    for ((r=0; r<WINDOW_LINES; r++)); do
        printf '\033[%d;1H\033[2K' "$((5 + r))"
    done

    from=${line_start[top_line]:-${#display}}
    to=${line_start[top_line + WINDOW_LINES]:-${#display}}

    for ((k=from; k<to; k++)); do
        draw_char "$k"
    done

    drawn_lines=$WINDOW_LINES

}


# only touches the characters around the cursor
redraw_changed() {

    local old_top=$top_line
    local start=$layout_start
    local old_count=${#display}
    local k screen_row key

    local -a old_line=("${cell_line[@]}")
    local -a old_col=("${cell_col[@]}")

    local -A occupied=()

    # a wrong letter went in or out so everything after it moves
    if (( layout_changed )); then
        layout_changed=0
        compute_layout
        update_top

        if (( top_line != old_top )); then
            draw_text
            return
        fi

        for ((k=0; k<${#display}; k++)); do
            occupied["${cell_line[k]},${cell_col[k]}"]=1
        done

        for ((k=start; k<old_count; k++)); do
            screen_row=$((5 + old_line[k] - top_line))

            if (( screen_row >= 5 && screen_row < 5 + WINDOW_LINES )); then
                key="${old_line[k]},${old_col[k]}"

                if [[ -z ${occupied[$key]+yes} ]]; then
                    printf '\033[%d;%dH ' "$screen_row" "${old_col[k]}"
                fi
            fi
        done

        for ((k=start; k<${#display}; k++)); do
            draw_char "$k"
        done

        return
    fi

    update_top

    # the text scrolled so everything moves
    if (( top_line != old_top )); then
        draw_text
        return
    fi

    local a b

    if (( prev_len < ${#typed} )); then
        a=$prev_len
        b=${#typed}
    else
        a=${#typed}
        b=$prev_len
    fi

    local from=${cell_of[a]}
    local to=${cell_of[b]}

    for ((k=from; k<=to; k++)); do
        draw_char "$k"
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

    local n=${#typed}

    # backspace
    if [[ $key == $'\x7f' || $key == $'\x08' ]]; then

        # take away the wrong letters first if there are any
        if [[ -n ${extra_at[n]-} ]]; then
            layout_start=$(( cell_of[n] - ${#extra_at[n]} ))
            extra_at[n]="${extra_at[n]%?}"
            layout_changed=1
        else
            typed="${typed%?}"
        fi

    # ignore enter
    elif [[ -z $key ]]; then
        return

    # ignore arrow keys and other escape sequences
    elif [[ $key == $'\e' ]]; then
        read -rsn2 -t 0.01 _
        return

    # ignore tab and other control keys
    elif [[ $key == [[:cntrl:]] ]]; then
        return

    # don't let it grow past the sentence
    elif (( n < ${#target} )); then

        ((total_keys++))

        if [[ $key == "${target:n:1}" ]]; then
            typed+="$key"
        else
            ((wrong_keys++))

            if (( ${#extra_at[n]} < MAX_EXTRA )); then

            # wrong space was invisible
                [[ $key == " " ]] && key="_"

                layout_start=$(( cell_of[n] - ${#extra_at[n]} ))
                extra_at[n]+="$key"
                layout_changed=1

            fi
        fi

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
        [[:cntrl:]]) continue ;;
    esac

    break

done

start_time=$SECONDS
started=1

prev_len=${#typed}
update_input
check_words

if (( layout_changed )); then
    layout_changed=0
    compute_layout
fi

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

correct_chars=$typed_chars

# only correct characters to count towards wpm
wpm=$(( (correct_chars * 12 + elapsed / 2) / elapsed ))

if (( total_keys > 0 )); then
    accuracy=$(( ((total_keys - wrong_keys) * 100 + total_keys / 2) / total_keys ))
else
    accuracy=0
fi

update_personal_best
save_session

sleep 3

echo
echo "==================================="
echo "             Time's up!"
echo "==================================="
echo
echo "You typed $typed_chars characters in $elapsed seconds!"
echo
echo "Your WPM is ~$wpm"
echo
echo "Your accuracy is ~$accuracy%"
echo

if [[ $personal_best_status == "new" ]]; then
    echo "You broke your score! Your new personal best is now $personal_best WPM!"
elif [[ $personal_best_status == "first" ]]; then
    echo "Your first personal best for ${duration} seconds is $personal_best WPM!"
else
    echo "Your personal best for ${duration} seconds is $personal_best WPM."
fi

while true; do
    echo
    echo "==================================="
    echo " [R] Retry  [H] History  [Q] Quit"
    echo "==================================="

    IFS= read -rsn1 choice

    case "$choice" in
        [rR])
            exec bash "$0"
            ;;
        [hH])
            show_history
            ;;
        [qQ])
            echo
            exit 0
            ;;
    esac
done