export DOTFILES_DIR=${DOTFILES_DIR:-$HOME/.dotfiles}
export PATH=$PATH:$DOTFILES_DIR/bin

export HOMEBREW_NO_ENV_HINTS=1
eval "$(/opt/homebrew/bin/brew shellenv)" &> /dev/null

export ZSH="$HOME/.oh-my-zsh"
[ -d $ZSH ] && source $ZSH/oh-my-zsh.sh

ZSH_THEME="robbyrussell"
plugins=(git)
