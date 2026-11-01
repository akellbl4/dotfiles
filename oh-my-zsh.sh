export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="dotfiles"

# Fall back to the default theme until `dotfiles link` has linked the custom one
if [[ ! -f "${ZSH_CUSTOM:-$ZSH/custom}/$ZSH_THEME.zsh-theme" ]]; then
	ZSH_THEME="robbyrussell"
fi

plugins=(git)

if [[ -s "$ZSH/oh-my-zsh.sh" ]]; then
	source "$ZSH/oh-my-zsh.sh"
else
	echo "Oh My Zsh not found at $ZSH/oh-my-zsh.sh"
fi
