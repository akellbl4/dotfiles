. "$HOME/.dotfiles/variables.sh"

# Ensure Oh My Zsh is sourced correctly
if [ -f "$DOTFILES_ROOT/oh-my-zsh.sh" ]; then
    . "$DOTFILES_ROOT/oh-my-zsh.sh"
fi

# Source Homebrew configuration
if [ -f "$DOTFILES_ROOT/homebrew.sh" ]; then
    . "$DOTFILES_ROOT/homebrew.sh"
fi

if [ -f "$DOTFILES_ROOT/gpg-agent.sh" ]; then
		. "$DOTFILES_ROOT/gpg-agent.sh"
fi

# Add dotfiles bin directory to PATH
export PATH="$DOTFILES_ROOT/bin:$PATH"





