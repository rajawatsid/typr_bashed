#!/usr/bin/env bash
#
# typr installer
#
#   curl -fsSL https://raw.githubusercontent.com/rajawatsid/typr/v1.0.0/install.sh | bash
#

main() {

    set -euo pipefail

    local repo="${TYPR_REPO:-rajawatsid/typr}"
    local ref="${TYPR_REF:-v1.0.0}"
    local base_url="https://raw.githubusercontent.com/$repo/$ref"

    local bin_dir="${TYPR_BIN_DIR:-$HOME/.local/bin}"
    local data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/typr"

    local tmp
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

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

    # checks
    [[ -n ${HOME:-} ]] || fail "HOME is not set"

    command -v bash >/dev/null 2>&1 || fail "bash is required"
    command -v tput >/dev/null 2>&1 || fail "tput is required (install ncurses)"

    if (( BASH_VERSINFO[0] < 4 )); then
        say "Warning: you are running bash $BASH_VERSION, but typr needs bash 4+."
        say "         On macOS: brew install bash"
    fi

    # download
    say "Downloading typr ($ref)..."

    download "$base_url/typr.sh" "$tmp/typr"
    download "$base_url/words/english.txt" "$tmp/english.txt"

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
            local rc="your shell's rc file"
            case "$(basename "${SHELL:-}")" in
                zsh)  rc="~/.zshrc" ;;
                bash) rc="~/.bashrc" ;;
            esac

            say "$bin_dir is not on your PATH yet. Add this line to $rc:"
            say
            say "  export PATH=\"$bin_dir:\$PATH\""
            say
            say "Then restart your terminal and run:  typr"
            ;;
    esac

    say
    say "To remove it later:  typr --uninstall"

}

main "$@"