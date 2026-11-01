#!/usr/bin/env sh
# Entry point for installing and updating dotfiles.
#
#   curl -L https://github.com/akellbl4/dotfiles/raw/main/install.sh | bash
#   sh ~/.dotfiles/install.sh [install|update] [-y]   (what `dotfiles install|update` runs)

set -e

DOTFILES_ROOT="$HOME/.dotfiles"
DOTFILES_REPO="https://github.com/akellbl4/dotfiles.git"

COMMAND=${1:-install}
FLAGS=$2

if ! command -v git >/dev/null 2>&1; then
	printf "\033[31mgit is required. On macOS run: xcode-select --install\033[0m\n" >&2
	exit 1
fi

if [ ! -d "$DOTFILES_ROOT/.git" ]; then
	printf "\033[34mCloning dotfiles into %s...\033[0m\n" "$DOTFILES_ROOT"
	git clone "$DOTFILES_REPO" "$DOTFILES_ROOT"
elif [ -z "$DOTFILES_PULLED" ]; then
	# Already installed: update first so the latest version of the scripts runs
	printf "\033[34mUpdating dotfiles in %s...\033[0m\n" "$DOTFILES_ROOT"
	if ! git -C "$DOTFILES_ROOT" pull --ff-only origin main; then
		printf "\033[31mCould not update %s, see the git error above. Continuing with the current version.\033[0m\n" "$DOTFILES_ROOT" >&2
	fi
fi

# The repo is up to date, so bin/dotfiles doesn't need to pull again
DOTFILES_PULLED=1
export DOTFILES_PULLED

chmod +x "$DOTFILES_ROOT/bin/dotfiles"

# When piped from curl, stdin is the script itself, so prompts must read from the terminal.
# Without a terminal, or with -y, run non-interactively.
if [ "$FLAGS" != "-y" ] && [ -r /dev/tty ] && (: < /dev/tty) 2>/dev/null; then
	exec sh "$DOTFILES_ROOT/bin/dotfiles" "$COMMAND" < /dev/tty
else
	exec sh "$DOTFILES_ROOT/bin/dotfiles" "$COMMAND" -y
fi
