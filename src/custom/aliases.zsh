alias d="cd ~/Desktop"
alias p="cd ~/Developer"
alias dl="cd ~/Downloads"

alias ip="curl -s https://icanhazip.com"

# Show/hide hidden files in Finder
alias show="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias hide="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

# Recursively delete `.DS_Store` files
alias cleanup="find . -type f -name '*.DS_Store' -ls -delete"

alias o="open"

# Flush Directory Service cache
alias flush="dscacheutil -flushcache && killall -HUP mDNSResponder"

# Lock the screen (when going AFK)
alias afk="pmset displaysleepnow"

# Add colors to grep by alias because GREP_OPTIONS is deprecated
alias grep="grep --color=auto"

alias reload="source $HOME/.zshrc && echo \"File .zshrc reloaded correctly\" || echo \"Syntax error, could not import the .zshrc file\"";
