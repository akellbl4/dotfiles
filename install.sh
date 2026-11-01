#!/usr/bin/env sh
# Bootstrap script: curl -L https://github.com/akellbl4/dotfiles/raw/main/install.sh | bash

set -e

DOTFILES_ROOT="$HOME/.dotfiles"
DOTFILES_REPO="https://github.com/akellbl4/dotfiles.git"

if ! command -v git >/dev/null 2>&1; then
	printf "\033[31mgit is required. On macOS run: xcode-select --install\033[0m\n" >&2
	exit 1
fi

if [ ! -d "$DOTFILES_ROOT/.git" ]; then
	printf "\033[34mCloning dotfiles into %s...\033[0m\n" "$DOTFILES_ROOT"
	git clone "$DOTFILES_REPO" "$DOTFILES_ROOT"
fi

chmod +x "$DOTFILES_ROOT/bin/dotfiles"

# When piped from curl, stdin is the script itself, so prompts must read from the terminal.
if [ -r /dev/tty ] && (: < /dev/tty) 2>/dev/null; then
	exec sh "$DOTFILES_ROOT/bin/dotfiles" install < /dev/tty
else
	exec sh "$DOTFILES_ROOT/bin/dotfiles" install -y
fi
