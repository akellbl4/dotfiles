export DOTFILES_DIR=${DOTFILES_DIR:-$HOME/.dotfiles}
export PATH=$PATH:$DOTFILES_DIR/bin

export HOMEBREW_NO_ENV_HINTS=1
eval "$(/opt/homebrew/bin/brew shellenv)" &> /dev/null

export ZSH="$HOME/.oh-my-zsh"
if [[ -d "${ZSH}" ]]; then
	# shellcheck disable=SC1091
	source "${ZSH}/oh-my-zsh.sh"

	export ZSH_THEME="robbyrussell"
	export plugins=(git)
fi

# Created by `pipx` on 2025-01-09 03:51:23
export PATH="$PATH:/Users/paul/.local/bin"
