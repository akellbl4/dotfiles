export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(git)

if [[ -s "$ZSH/oh-my-zsh.sh" ]]; then
	source "$ZSH/oh-my-zsh.sh"
else
	echo "Oh My Zsh not found at $ZSH/oh-my-zsh.sh"
fi
