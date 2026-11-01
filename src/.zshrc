export DOTFILES_ROOT="$HOME/.dotfiles"

. "$DOTFILES_ROOT/variables.sh"

# Source Homebrew first so Oh My Zsh picks up Homebrew completions
if [ -f "$DOTFILES_ROOT/homebrew.sh" ]; then
    . "$DOTFILES_ROOT/homebrew.sh"
fi

# Add dotfiles bin directory and ~/.local/bin (fnm, docker -> podman link, CLIs) to PATH
export PATH="$DOTFILES_ROOT/bin:$HOME/.local/bin:$PATH"

if [ -f "$DOTFILES_ROOT/node.sh" ]; then
    . "$DOTFILES_ROOT/node.sh"
fi

if [ -f "$DOTFILES_ROOT/oh-my-zsh.sh" ]; then
    . "$DOTFILES_ROOT/oh-my-zsh.sh"
fi

if [ -f "$DOTFILES_ROOT/gpg-agent.sh" ]; then
    . "$DOTFILES_ROOT/gpg-agent.sh"
fi

if [ -f "$DOTFILES_ROOT/.zshrc.user.sh" ]; then
    . "$DOTFILES_ROOT/.zshrc.user.sh"
fi
