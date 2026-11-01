#!/usr/bin/env sh
# shellcheck disable=SC2034 # color variables are used by scripts that source this file

# Define styling variables
BOLD='\033[1m'
WHITE='\033[37m'
# Define color variables
BLUE='\033[34m'
GREEN='\033[32m'
BLACK='\033[30m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
# Define background color variables
BG_YELLOW='\033[43m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_CYAN='\033[46m'
# Reset formatting
RESET='\033[0m'

log() {
	log_type="$1"
	log_message="$2"
	log_indent=${3:-0}

	# Define styling based on log type
	case "$log_type" in
		"info") log_style=${BLUE} ;;
		"success") log_style=${GREEN} ;;
		"error") log_style=${RED} ;;
		*) log_style=${RESET} ;;
	esac

	# Apply indent and styling
	log_prefix=""
	if [ "$log_indent" -gt 0 ]; then
		log_prefix=$(printf "%${log_indent}s" "")
	fi

	printf "%b\n" "${log_prefix}${log_style}${log_message}${RESET}"
}

# Prompt a yes/no question (default yes) and print "y" or "n"
ask() {
	printf "%s (Y/n) > " "$1" >&2
	read -r answer || answer=""
	case "$answer" in
		[nN]*) echo "n" ;;
		*) echo "y" ;;
	esac
}

# Put Homebrew on PATH for this shell
load_brew() {
	if [ -x /opt/homebrew/bin/brew ]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
		return 0
	fi
	command -v brew >/dev/null 2>&1
}

# Clone or update the dotfiles repo, then link everything into place
sync_repo() {
	if [ -d "$DOTFILES_ROOT/.git" ]; then
		log "info" "Updating dotfiles..."
		if ! git -C "$DOTFILES_ROOT" pull --ff-only origin main; then
			log "error" "Could not update $DOTFILES_ROOT (local changes or diverged history). Commit or stash them and retry."
			return 1
		fi
		log "success" "Dotfiles updated"
	else
		log "info" "Installing dotfiles..."
		git clone https://github.com/akellbl4/dotfiles.git "$DOTFILES_ROOT"
		log "success" "Dotfiles downloaded"
	fi

	link_files "$DOTFILES_ROOT/src" "$HOME" "Dotfiles"
	link_files "$DOTFILES_ROOT/src/custom" "$HOME/.oh-my-zsh/custom" "ZSH files"

	# Each folder in src/.config/ is linked into ~/.config/ (e.g. ghostty)
	for config_dir in "$DOTFILES_ROOT"/src/.config/*/; do
		[ -d "$config_dir" ] || continue
		app_name=$(basename "$config_dir")
		link_files "$config_dir" "$HOME/.config/$app_name" "$app_name config"
	done
}

link_files() {
	src_dir=$1
	target_dir=$2
	name=$3

	if [ ! -d "$src_dir" ]; then
		log "error" "$name directory not found"
		return 1
	fi
	mkdir -p "$target_dir"

	log "info" "Linking $name..."
	# read files from source directory avoiding subdirectories
	find "$src_dir" -maxdepth 1 -type f | while read -r source_file; do
		target_file="$target_dir/$(basename "$source_file")"

		# if target is a real file, back it up
		if [ -f "$target_file" ] && [ ! -L "$target_file" ]; then
			mv "$target_file" "$target_file.$(date "+%Y%m%d%H%M%S").bak"
		fi

		log "info" "$(ln -sfv "$source_file" "$target_file")" 1
	done
	log "success" "$name linked"
}

configure_git_user() {
	log "info" "Configuring Git user settings..."
	printf "Enter your full name (or press Enter to skip): " >&2
	read -r full_name || full_name=""
	printf "Enter your email (or press Enter to skip): " >&2
	read -r email || email=""
	printf "Enter your GPG signing key (or press Enter to skip): " >&2
	read -r signing_key || signing_key=""

	user_config="$DOTFILES_ROOT/src/.gitconfig.user"
	echo "[user]" > "$user_config"
	if [ -n "$full_name" ]; then printf "\tname = %s\n" "$full_name" >> "$user_config"; fi
	if [ -n "$email" ]; then printf "\temail = %s\n" "$email" >> "$user_config"; fi
	# Only sign commits when a key is configured, otherwise every commit would fail
	if [ -n "$signing_key" ]; then
		printf "\tsigningkey = %s\n" "$signing_key" >> "$user_config"
		printf "[commit]\n\tgpgsign = true\n" >> "$user_config"
	fi
	ln -sf "$user_config" "$HOME/.gitconfig.user"

	log "info" "Git user settings configured."
}

# Offer to create a GPG signing key and configure Git to use it
setup_gpg_key() {
	user_config="$DOTFILES_ROOT/src/.gitconfig.user"

	load_brew || true
	if ! command -v gpg >/dev/null 2>&1; then
		log "error" "gpg not found, skipping key setup. Run 'dotfiles bundle' to install gnupg."
		return 0
	fi

	existing_key=$(git config -f "$user_config" user.signingkey 2>/dev/null || true)
	if [ -n "$existing_key" ]; then
		log "info" "Git signing key already configured ($existing_key)"
		return 0
	fi

	if [ -n "$(gpg --list-secret-keys --with-colons 2>/dev/null)" ]; then
		log "info" "Existing GPG keys:"
		gpg --list-secret-keys --keyid-format long 2>/dev/null | sed 's/^/  /'
		log "info" "To use one of them, run 'dotfiles config-user' and enter its key ID."
	fi

	if [ "$(ask "No Git signing key configured. Create a new GPG key?")" != "y" ]; then
		return 0
	fi

	key_name=$(git config -f "$user_config" user.name 2>/dev/null || true)
	key_email=$(git config -f "$user_config" user.email 2>/dev/null || true)
	if [ -z "$key_name" ]; then
		printf "Name for the key: " >&2
		read -r key_name || key_name=""
	fi
	if [ -z "$key_email" ]; then
		printf "Email for the key (should match your GitHub email): " >&2
		read -r key_email || key_email=""
	fi
	if [ -z "$key_name" ] || [ -z "$key_email" ]; then
		log "error" "Name and email are required to create a key, skipping."
		return 0
	fi

	# pinentry needs to know which terminal to ask for the passphrase on
	GPG_TTY=$(tty) || true
	export GPG_TTY

	log "info" "Creating GPG key for $key_name <$key_email> (you will be asked for a passphrase)..."
	key_fpr=$(gpg --status-fd 1 --quick-generate-key "$key_name <$key_email>" ed25519 sign 2y \
		| awk '/KEY_CREATED/ {print $NF}')
	if [ -z "$key_fpr" ]; then
		log "error" "GPG key creation failed"
		return 0
	fi
	log "success" "GPG key created: $key_fpr"

	git config -f "$user_config" user.name "$key_name"
	git config -f "$user_config" user.email "$key_email"
	git config -f "$user_config" user.signingkey "$key_fpr"
	git config -f "$user_config" commit.gpgsign true
	ln -sf "$user_config" "$HOME/.gitconfig.user"
	log "success" "Git configured to sign commits with $key_fpr"

	if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 \
		&& [ "$(ask "Add the public key to your GitHub account?")" = "y" ]; then
		if gpg --armor --export "$key_fpr" | gh gpg-key add -; then
			log "success" "Public key added to GitHub"
			return 0
		fi
		log "error" "Upload failed. You may need: gh auth refresh -s write:gpg_key"
	fi

	log "info" "Add this public key at https://github.com/settings/gpg/new:"
	gpg --armor --export "$key_fpr"
}

user_folders() {
	log "info" "Creating user folders..."
	for folder in Screenshots Developer; do
		if [ ! -d "$HOME/$folder" ]; then
			mkdir "$HOME/$folder"
			log "success" "$HOME/$folder folder created"
		else
			log "info" "$folder folder already exists"
		fi
	done
}

macos_defaults() {
	log "info" "Setting up macOS defaults..."
	# Disable font smoothing
	defaults -currentHost write -g AppleFontSmoothing -int 0

	# Change default settings of printing
	# If your printer support two sides print then it's off by default while you printing
	defaults write -g PMPrintingExpandedStateForPrint -bool TRUE

	# Simple window scale effect
	defaults write com.apple.dock mineffect -string scale

	# Zero timeout to show hidden Dock
	defaults write com.apple.dock autohide-delay -float 0

	# Fast Dock showing animation (300ms)
	defaults write com.apple.dock autohide-time-modifier -float 0.3

	# Set default folder for screenshots
	defaults write com.apple.screencapture location "$HOME/Screenshots"

	# Sort folders on top in Finder
	defaults write com.apple.finder _FXSortFoldersFirst -boolean TRUE
	defaults write com.apple.finder _FXSortFoldersFirstOnDesktop -boolean TRUE

	# Restart services
	killall Dock >/dev/null 2>&1 || true
	killall SystemUIServer >/dev/null 2>&1 || true
	killall Finder >/dev/null 2>&1 || true

	log "success" "macOS defaults set"
}
