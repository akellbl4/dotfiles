init_zsh() {
	export ZSH="$HOME/.oh-my-zsh"
	# shellcheck disable=SC2034
	ZSH_THEME="robbyrussell"
	# shellcheck disable=SC2034
	plugins=(git)
	# shellcheck disable=SC1091
	[[ -s "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"
}

init_zsh

export DOTFILES_DIR=${DOTFILES_DIR:-$HOME/.dotfiles}
export PATH=$PATH:$DOTFILES_DIR/bin

export HOMEBREW_NO_ENV_HINTS=1
eval "$(/opt/homebrew/bin/brew shellenv)" &>/dev/null


# Created by `pipx` on 2025-01-09 03:51:23
export PATH="$PATH:/Users/paul/.local/bin"
