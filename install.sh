#!/usr/bin/env bash
#
# typr installer
#
#   curl -fsSL https://github.com/rajawatsid/typr_bashed/releases/latest/download/install.sh | bash
#

main() {

    set -euo pipefail

    local repo="${TYPR_REPO:-rajawatsid/typr_bashed}"
    local ref="${TYPR_REF:-}"
    local base_url=""

    # checks
    [[ -n ${HOME:-} ]] || fail "HOME is not set"

    local bin_dir="${TYPR_BIN_DIR:-$HOME/.local/bin}"
    local data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/typr"

    local tmp
    tmp="$(mktemp -d)"
    # double quotes so $tmp is filled in now, not when the trap fires after main returns
    trap "rm -rf '$tmp'" EXIT

    say()  { printf '%s\n' "$*"; }
    fail() { printf 'install failed: %s\n' "$*" >&2; exit 1; }

    download() {
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL "$1" -o "$2"
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "$2" "$1"
        else
            fail "you need curl or wget"
        fi
    }

    if [[ -z $ref ]]; then
        download "https://api.github.com/repos/$repo/releases/latest" "$tmp/release.json" || fail "couldn't find the latest release"

        ref="$(sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' "$tmp/release.json" | head -n 1)"

        [[ -n $ref ]] || fail "couldn't find the latest release tag"
    fi

    base_url="https://raw.githubusercontent.com/$repo/$ref"



    command -v bash >/dev/null 2>&1 || fail "bash is required"
    command -v tput >/dev/null 2>&1 || fail "tput is required (install ncurses: on Debian/Ubuntu, sudo apt install ncurses-bin)"

    if (( BASH_VERSINFO[0] < 4 )); then
        say "Warning: you are running bash $BASH_VERSION, but typr needs bash 4+."
        say "         On macOS: brew install bash"
    fi

    # download

    # splash screen
    cat << 'EOF'
 _______  ___    _   ____ _______   ___     _      _      _______  ___    _   _____
|__   __||   \  | |/ ___||__   __| / _ \   | |    | |    |__   __||   \  | | /  ___|
   | |   | |\ \ | |\_\__    |_|   / /_\ \  | |    | |       | |   | |\ \ | ||  /  __
 __| |__ | | \ \| | __\ \   |_|  / /---\ \ | |___ | |___  __| |__ | | \ \| ||  \__\ \
|_______||_|  \___||____/   |_| /_/     \_\|_____||_____||_______||_|  \___| \______/
                         _______ __   __ ____   ____
                        |__   __|\ \ / /  _  \ |  _  \
                           |_|    \ V /| |_)  ||_|_)_/
                           |_|     | | |  ___/ | | \ \
                           |_|     |_| |_|     |_|  \_\

EOF
    say "                      Downloading typr ($ref)..."

    download "$base_url/typr.sh" "$tmp/typr" || fail "couldn't download typr.sh from $base_url (does the tag '$ref' exist?)"
    download "$base_url/words/english.txt" "$tmp/english.txt" || fail "couldn't download the word list from $base_url"

    # make sure we got what we expected and not an error page
    [[ -s $tmp/typr ]] || fail "downloaded script is empty"
    [[ -s $tmp/english.txt ]] || fail "downloaded word list is empty"
    head -n 1 "$tmp/typr" | grep -q '^#!.*bash' || fail "downloaded script doesn't look right"

    # install
    if [[ -f $bin_dir/typr ]]; then
        say "Updating existing install..."
    fi

    mkdir -p "$bin_dir" "$data_dir/words"

    cp "$tmp/typr" "$bin_dir/typr"
    chmod 755 "$bin_dir/typr"

    cp "$tmp/english.txt" "$data_dir/words/english.txt"
    printf '%s\n' "$ref" > "$data_dir/version"

    say
    say "typr installed!"
    say "  command:    $bin_dir/typr"
    say "  word list:  $data_dir/words/english.txt"
    say


    case ":$PATH:" in
        *":$bin_dir:"*)
            say "Run it with:  typr"
            ;;
        *)
            local rc=""
            local path_line="export PATH=\"$bin_dir:\$PATH\""

            case "$(basename "${SHELL:-}")" in
                zsh)  rc="$HOME/.zshrc" ;;
                bash)
                    rc="$HOME/.bashrc"
                    [[ $(uname) == "Darwin" ]] && rc="$HOME/.bash_profile"
                    ;;
            esac

            # a script can't change the terminal that started it, so we add the line to the rc file and the user reloads it (set TYPR_NO_MODIFY_PATH=1 to skip)
            if [[ -n $rc && -z ${TYPR_NO_MODIFY_PATH:-} ]]; then

                if grep -qsF "$bin_dir" "$rc"; then
                    say "$bin_dir is already set up in $rc."
                else
                    printf '\n# added by the typr installer\n%s\n' "$path_line" >> "$rc"
                    say "Added $bin_dir to your PATH in $rc."
                fi

                say
                say "To use typr right now, run:  source $rc"
                say "(new terminals pick it up on their own)"

            else
                say "$bin_dir is not on your PATH yet. Add this line to your shell's rc file:"
                say
                say "  $path_line"
                say
                say "Then restart your terminal and run:  typr"
            fi
            ;;
    esac

    say
    say "To remove it later:  typr --uninstall"

}

main "$@"