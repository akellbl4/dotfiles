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

# Path to the personal Git config (name, email, signing key)
git_user_config() {
	echo "$DOTFILES_ROOT/src/.gitconfig.user"
}

# Read a value from the personal Git config, empty if unset
git_user_get() {
	git config -f "$(git_user_config)" "$1" 2>/dev/null || true
}

# Prompt for a value, showing the current one; Enter keeps it
prompt_value() {
	if [ -n "$2" ]; then
		printf "%s [%s]: " "$1" "$2" >&2
	else
		printf "%s: " "$1" >&2
	fi
	read -r value || value=""
	echo "${value:-$2}"
}

# Prompt a yes/no question that defaults to no and print "y" or "n"
ask_no() {
	printf "%s (y/N) > " "$1" >&2
	read -r answer || answer=""
	case "$answer" in
		[yY]*) echo "y" ;;
		*) echo "n" ;;
	esac
}

# Print "Name <email>" from the personal Git config, empty if not configured
git_user_summary() {
	summary_name=$(git_user_get user.name)
	summary_email=$(git_user_get user.email)
	if [ -n "$summary_name" ] || [ -n "$summary_email" ]; then
		echo "${summary_name:-?} <${summary_email:-?}>"
	fi
}

# Ask for Git name and email, keeping current values on Enter.
# The signing key is managed separately by setup_gpg_key.
configure_git_user() {
	log "info" "Configuring Git user settings (press Enter to keep the current value)..."
	user_config=$(git_user_config)
	new_name=$(prompt_value "Full name" "$(git_user_get user.name)")
	new_email=$(prompt_value "Email" "$(git_user_get user.email)")

	touch "$user_config"
	if [ -n "$new_name" ]; then git config -f "$user_config" user.name "$new_name"; fi
	if [ -n "$new_email" ]; then git config -f "$user_config" user.email "$new_email"; fi
	ln -sf "$user_config" "$HOME/.gitconfig.user"

	log "success" "Git user: $(git_user_summary)"
}

# List usable secret signing keys, one per line: fingerprint|key id|user id|expiry (epoch, empty if none)
list_signing_keys() {
	gpg --list-secret-keys --with-colons --fixed-list-mode 2>/dev/null | awk -F: '
		$1 == "sec" { usable = ($2 != "r" && $2 != "e" && $2 != "d" && $12 ~ /S/); keyid = $5; expiry = $7; fpr = ""; printed = 0; next }
		$1 == "fpr" && fpr == "" { fpr = $10; next }
		$1 == "uid" && $2 != "r" && usable && !printed && fpr != "" { printf "%s|%s|%s|%s\n", fpr, keyid, $10, expiry; printed = 1 }
	'
}

# Human-readable expiry for an epoch timestamp
format_expiry() {
	if [ -n "$1" ]; then
		echo "expires $(date -r "$1" "+%Y-%m-%d")"
	else
		echo "never expires"
	fi
}

# Describe a key by fingerprint or id: "KEYID  Name <email>, expires ..."
describe_key() {
	list_signing_keys | awk -F'|' -v k="$1" 'toupper($1) == toupper(k) || toupper($2) == toupper(k) || toupper(substr($1, length($1) - length(k) + 1)) == toupper(k)' | head -n 1 \
		| while IFS='|' read -r d_fpr d_id d_uid d_exp; do
			echo "$d_id  $d_uid, $(format_expiry "$d_exp")"
		done
}

# Configure Git to sign commits with the given key
use_signing_key() {
	user_config=$(git_user_config)
	touch "$user_config"
	git config -f "$user_config" user.signingkey "$1"
	git config -f "$user_config" commit.gpgsign true
	ln -sf "$user_config" "$HOME/.gitconfig.user"
}

# Create a new ed25519 signing key and print its fingerprint
create_signing_key() {
	key_name=$(git_user_get user.name)
	key_email=$(git_user_get user.email)
	if [ -z "$key_name" ] || [ -z "$key_email" ]; then
		log "info" "The key needs a name and email (these are also saved as your Git user)." >&2
		key_name=$(prompt_value "Full name" "$key_name")
		key_email=$(prompt_value "Email (should match your GitHub email)" "$key_email")
	fi
	if [ -z "$key_name" ] || [ -z "$key_email" ]; then
		log "error" "Name and email are required to create a key." >&2
		return 1
	fi
	git config -f "$(git_user_config)" user.name "$key_name"
	git config -f "$(git_user_config)" user.email "$key_email"

	# pinentry needs to know which terminal to ask for the passphrase on
	GPG_TTY=$(tty) || true
	export GPG_TTY

	log "info" "Creating a new GPG key for $key_name <$key_email> (you will be asked for a passphrase)..." >&2
	gpg --status-fd 1 --quick-generate-key "$key_name <$key_email>" ed25519 sign 2y \
		| awk '/KEY_CREATED/ {print $NF}'
}

# Offer to upload a public key to GitHub unless it is already there
offer_github_upload() {
	upload_fpr=$1
	upload_id=$2
	if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
		log "info" "Add the public key at https://github.com/settings/gpg/new:"
		gpg --armor --export "$upload_fpr"
		return 0
	fi
	if gh gpg-key list 2>/dev/null | grep -qi "$upload_id"; then
		log "info" "Key $upload_id is already on your GitHub account."
		return 0
	fi
	if [ "$(ask "Add key $upload_id to your GitHub account?")" != "y" ]; then
		return 0
	fi
	if gpg --armor --export "$upload_fpr" | gh gpg-key add -; then
		log "success" "Key $upload_id added to GitHub"
	else
		log "error" "Upload failed. You may need: gh auth refresh -s write:gpg_key"
	fi
}

# Choose an existing GPG key or create a new one, and configure Git to sign commits with it
setup_gpg_key() {
	load_brew || true
	if ! command -v gpg >/dev/null 2>&1; then
		log "error" "gpg not found, skipping signing key setup. Run 'dotfiles bundle' to install gnupg."
		return 0
	fi

	current_key=$(git_user_get user.signingkey)
	if [ -n "$current_key" ]; then
		current_desc=$(describe_key "$current_key")
		log "info" "Git signs commits with: ${current_desc:-$current_key (not found in your GPG keyring!)}"
		if [ "$(ask_no "Change the signing key?")" != "y" ]; then
			return 0
		fi
	fi

	keys=$(list_signing_keys)
	choice=""
	if [ -z "$keys" ]; then
		log "info" "No GPG signing keys found in your keyring."
		if [ "$(ask "Create a new GPG signing key?")" = "y" ]; then
			choice="c"
		fi
	else
		log "info" "Choose a GPG key for signing commits:"
		index=0
		echo "$keys" | while IFS='|' read -r k_fpr k_id k_uid k_exp; do
			index=$((index + 1))
			log "" "$index) Use existing key $k_id  $k_uid, $(format_expiry "$k_exp")" 2
		done
		log "" "c) Create a new key" 2
		log "" "s) Skip" 2
		while :; do
			printf "Choice > " >&2
			read -r choice || choice="s"
			case "$choice" in
				''|c|C|s|S) break ;;
				*[!0-9]*) ;;
				*) if [ "$choice" -gt 0 ] && [ -n "$(echo "$keys" | sed -n "${choice}p")" ]; then break; fi ;;
			esac
			log "error" "Enter a key number, c or s."
		done
	fi

	case "$choice" in
		c|C)
			key_fpr=$(create_signing_key) || key_fpr=""
			if [ -z "$key_fpr" ]; then
				log "error" "GPG key creation failed"
				return 0
			fi
			key_id=$(list_signing_keys | awk -F'|' -v f="$key_fpr" '$1 == f {print $2}')
			use_signing_key "$key_fpr"
			log "success" "Created new GPG key ${key_id:-$key_fpr} and set it as your Git signing key"
			;;
		''|s|S)
			log "info" "Skipped signing key setup. Run 'dotfiles gpg-key' any time to set it up."
			return 0
			;;
		*)
			selected=$(echo "$keys" | sed -n "${choice}p")
			key_fpr=$(echo "$selected" | cut -d'|' -f1)
			key_id=$(echo "$selected" | cut -d'|' -f2)
			use_signing_key "$key_fpr"
			log "success" "Linked existing GPG key $key_id as your Git signing key"
			;;
	esac

	offer_github_upload "$key_fpr" "$key_id"
}

# Print the default user folders that don't exist yet
missing_user_folders() {
	for folder in Screenshots Developer; do
		if [ ! -d "$HOME/$folder" ]; then
			echo "$folder"
		fi
	done
}

user_folders() {
	for folder in $(missing_user_folders); do
		mkdir "$HOME/$folder"
		log "success" "$HOME/$folder folder created"
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

	# Don't show suggested and recent apps in Dock
	defaults write com.apple.dock show-recents -bool false

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
