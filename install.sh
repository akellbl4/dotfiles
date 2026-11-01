#!/usr/bin/env sh
# Entry point for installing and updating dotfiles.
#
#   curl -L https://github.com/akellbl4/dotfiles/raw/main/install.sh | bash
#   sh ~/.dotfiles/install.sh [install|update] [-y]   (what `dotfiles install|update` runs)
#
# Extra options (--pulled, --restarted) are passed through to bin/dotfiles.

set -e

DOTFILES_ROOT="$HOME/.dotfiles"
DOTFILES_REPO="https://github.com/akellbl4/dotfiles.git"

COMMAND=${1:-install}
[ $# -gt 0 ] && shift

assume_yes=""
already_pulled=""
for arg in "$@"; do
	case "$arg" in
		-y) assume_yes=1 ;;
		--pulled) already_pulled=1 ;;
	esac
done

# git is needed to download the dotfiles; install it on Linux if missing
if ! command -v git >/dev/null 2>&1; then
	if command -v apt-get >/dev/null 2>&1; then
		sudo apt-get update && sudo apt-get install -y git
	elif command -v dnf >/dev/null 2>&1 && [ ! -e /run/ostree-booted ]; then
		sudo dnf install -y git
	fi
fi
if ! command -v git >/dev/null 2>&1; then
	printf "\033[31mgit is required. On macOS run: xcode-select --install\033[0m\n" >&2
	exit 1
fi

if [ ! -d "$DOTFILES_ROOT/.git" ]; then
	printf "\033[34mCloning dotfiles into %s...\033[0m\n" "$DOTFILES_ROOT"
	git clone "$DOTFILES_REPO" "$DOTFILES_ROOT"
elif [ -z "$already_pulled" ]; then
	# Already installed: update first so the latest version of the scripts runs
	printf "\033[34mUpdating dotfiles in %s...\033[0m\n" "$DOTFILES_ROOT"
	if ! git -C "$DOTFILES_ROOT" pull --ff-only origin main; then
		printf "\033[31mCould not update %s, see the git error above. Continuing with the current version.\033[0m\n" "$DOTFILES_ROOT" >&2
	fi
fi


chmod +x "$DOTFILES_ROOT/bin/dotfiles"

# When piped from curl, stdin is the script itself, so prompts must read from the terminal.
# Without a terminal, or with -y, run non-interactively.
# The repo is up to date now, so tell bin/dotfiles not to pull again
if [ -z "$assume_yes" ] && [ -r /dev/tty ] && (: < /dev/tty) 2>/dev/null; then
	exec sh "$DOTFILES_ROOT/bin/dotfiles" "$COMMAND" "$@" --pulled < /dev/tty
else
	exec sh "$DOTFILES_ROOT/bin/dotfiles" "$COMMAND" "$@" --pulled -y
fi
