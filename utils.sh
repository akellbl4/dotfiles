#!/usr/bin/env sh

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
    local type="$1"
    local message="$2"
    local indent=${3:-0}

    # Define styling based on log type
    case "$type" in
        "info")
            local style=${BLUE} ;; # Bold blue
        "success")
            local style=${GREEN} ;; # Bold green
        "error")
            local style=${RED} ;; # Bold red
        *)
            local style=${RESET} ;;
    esac

    # Apply indent and styling
    local prefix=""
    if [ "$indent" -gt 0 ]; then
        prefix="$(printf ' %.0s' $(seq 1 $indent))"
    fi

    printf "${prefix}${style}${message}${RESET}\n"
}

dotfiles() {
	if [[ -d $DOTFILES_ROOT ]]; then
		log "info" "Updating dotfiles..."
		cd "$DOTFILES_ROOT" || exit
		git pull origin main
		log "success" "Dotfiles updated"
	else
		log "info" "Installing dotfiles..."
		git clone https://github.com/akellbl4/dotfiles.git "$DOTFILES_ROOT"
		log "success" "Dotfiles downloaded"
	fi

	link_files "$DOTFILES_ROOT/src" "$HOME" "Dotfiles"
	link_files "$DOTFILES_ROOT/src/custom" "$HOME/.oh-my-zsh/custom" "ZSH files"
}

link_files() {
	src_dir=$1
	target_dir=$2
	name=$3

	if [[ ! -d $src_dir ]]; then
		log "error" "$name directory not found"
	fi

	log "info" "Linking $name..."
	# read files from source directory avoiding subdirectories
	find "$src_dir" -maxdepth 1 -type f | while read -r source_file; do
		target_file="$target_dir/$(basename "$source_file")"

		# if target file exists, backup it
		if [[ -f $target_file ]]; then
			mv "$target_file" "$target_file.$(date "+%Y%m%d%H%M%S").bak" > /dev/null 2>&1
		fi

		# if target file is a symbolic link, remove it
		if [[ -L $target_file ]]; then
			rm -rf "$target_file" > /dev/null 2>&1
		fi

		log "info" "$(ln -sv "$source_file" "$target_file")" 1
	done
	log "success" "$name linked"
}

configure_git_user() {
    log "info" "Configuring Git user settings..."
    read -p "Enter your full name (or press Enter to skip): " full_name
    read -p "Enter your email (or press Enter to skip): " email
    read -p "Enter your GPG signing key (or press Enter to skip): " signing_key

    # Create or update src/.gitconfig.user
    echo "[user]" > "$DOTFILES_ROOT/src/.gitconfig.user"
    [ -n "$full_name" ] && echo "\tname = $full_name" >> "$DOTFILES_ROOT/src/.gitconfig.user"
    [ -n "$email" ] && echo "\temail = $email" >> "$DOTFILES_ROOT/src/.gitconfig.user"
    [ -n "$signing_key" ] && echo "\tsigningkey = $signing_key" >> "$DOTFILES_ROOT/src/.gitconfig.user"

    log "info" "Git user settings configured."
}

user_folders() {
	log "info" "Creating user folders..."
	if [[ ! -d ~/Screenshots ]]; then
		mkdir ~/Screenshots;
		log "success" "$HOME/Screenshots folder created"
	else
		log "info" "Screenshots folder already exists"
	fi

	if [[ ! -d ~/Developer ]]; then
		mkdir ~/Developer;
		log "success" "$HOME/Developer folder created"
	else
		log "info" "Developer folder already exists"
	fi
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

	# Kill Dashboard permanently
	defaults write com.apple.dashboard mcx-disabled -boolean TRUE

	# Zero timeout to show hidden Dock
	defaults write com.apple.dock autohide-delay -float 0

	# Fast Dock showing animation (300ms)
	defaults write com.apple.dock autohide-time-modifier -float 0.3

	# Set default folder for screenshots
	defaults write com.apple.screencapture location ~/Screenshots

	# Disable Google Chrome auto-update
	defaults write com.google.Keystone.Agent checkInterval 0

	# Sort folders on top in Finder
	defaults write com.apple.finder _FXSortFoldersFirst -boolean TRUE
	defaults write com.apple.finder _FXSortFoldersFirstOnDesktop -boolean TRUE

	# Restart services
	killall Dock;
	killall SystemUIServer;
	killall Finder;

	log "success" "macOS defaults set"
}
