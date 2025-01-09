DOTFILES=(
	.zshrc
	.editorconfig
	.gitconfig
)

log() {
	level=$1
	message=$2
	if [[ $level == "info" ]]; then
		printf "\033[1;34m=>\033[0m %s\n" "$message"
	elif [[ $level == "success" ]]; then
		printf "\033[1;32m=>\033[0m \033[0;32m %s\033[0m\n" "$message"
	elif [[ $level == "error" ]]; then
		printf "\033[1;41;30m ERROR \033[0m \033[0;31m %s\033[0m\n" "$message" > /dev/stderr
	elif [[ $level == "final" ]]; then
		printf "\033[1;42;30m DONE \033[0m \033[0;33m %s\033[0m\n" "$message"
	else
		echo "$level"
	fi
}

dotfiles() {
	if [[ -d $DOTFILES_DIR ]]; then
		log "info" "Updating dotfiles..."
		cd "${DOTFILES_DIR}" || exit
		git pull origin master
		log "success" "Dotfiles updated"
	else
		log "info" "Installing dotfiles..."
		git clone https://github.com/akellbl4/dotfiles.git "$DOTFILES_DIR"
		log "success" "Dotfiles downloaded"
	fi


	for file in "${DOTFILES[@]}"; do
		rm -rf "${HOME:?}/${file:?}"
		ln -sv "$DOTFILES_DIR/$file" "$HOME/$file" 2>&1
	done

	log "success" "Dotfiles linked"
}



user_folders() {
	log "info" "Creating user folders..."
	if [[ ! -d ~/Screenshots ]]; then
		mkdir ~/Screenshots;
		log "success" "~/Screenshots folder created"
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
	defaults write -g PMPrintingExpandedStateForPrint -bool TRUE;

	# Simple window scale effect
	defaults write com.apple.dock mineffect -string scale;

	# Kill Dashboard permanently
	defaults write com.apple.dashboard mcx-disabled -boolean TRUE;

	# Zero timeout to show hidden Dock
	defaults write com.apple.dock autohide-delay -float 0;

	# Fast Dock showing animation (300ms)
	defaults write com.apple.dock autohide-time-modifier -float 0.3;

	# Set default folder for screenshots
	defaults write com.apple.screencapture location ~/Screenshots;

	# Disable Google Chrome auto-update
	defaults write com.google.Keystone.Agent checkInterval 0

	# Restart services
	killall Dock;
	killall SystemUIServer;

	log "success" "macOS defaults set"
}
