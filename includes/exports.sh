export LANG=en_US.UTF-8
export TERM=xterm-256color
export PATH=$HOME/.dotfiles/bin/:$PATH
export EDITOR="code"

# Highlight section titles in manual pages
export LESS_TERMCAP_md="$COLOR_YELLOW"

# Larger bash history (allow 32³ entries; default is 500)
export HISTSIZE=32768
export HISTFILESIZE=$HISTSIZE
export HISTCONTROL=ignoreboth:erasedups

# Make some commands not show up in history
export HISTIGNORE="ls:cd:cd -:pwd:exit:date:* --help"

# Colors PS
USER="\[$COLOR_BRIGHT\]\[$COLOR_BRIGHT_MAGENTA\]\u"
HOST="\[$COLOR_RESET\]\[$COLOR_BRIGHT_BLUE@\h"
DIR="\[$COLOR_BRIGHT\]\[$COLOR_BRIGHT_WHITE\w"
THIS="\[$COLOR_BRIGHT_YELLOW\]\$\[$COLOR_RESET\]"
GIT_BRANCH="\[$COLOR_BRIGHT_GREEN\]\$(parse_git_branch)\[$COLOR_RESET\]"

export PS1="$USER$HOST $DIR\n$GIT_BRANCH$THIS "
export PS2="$COLOR_RESET→ "


# Colors grep
export GREP_OPTIONS="--color=auto"
export GREP_COLOR="1;37;45"

LS_COLORS="HxgxcxdxFxegedabagacad"

if ls --color > /dev/null 2>&1; then # GNU `ls`
	export LS_COLORS=$LS_COLORS
else # OS X `ls`
	export LSCOLORS=$LS_COLORS
fi