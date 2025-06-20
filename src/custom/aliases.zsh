alias d="cd ~/Desktop"
alias p="cd ~/Developer"
alias dl="cd ~/Downloads"

alias ip="curl -s http://checkip.dyndns.com/ | sed 's/[^0-9\.]//g'"
alias freewifi='sudo ifconfig en0 ether $(openssl rand -hex 6 | sed "s/\(..\)/\1:/g; s/.$//")'

# Show/hide hidden files in Finder
alias show="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias hide="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

# Recursively delete `.DS_Store` files
alias cleanup="find . -type f -name '*.DS_Store' -ls -delete"

alias o="open"
alias y="yarn"

# Flush Directory Service cache
alias flush="dscacheutil -flushcache && killall -HUP mDNSResponder"

# Lock the screen (when going AFK)
alias afk="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"

# Add colors to grep by alias because GREP_OPTIONS is deprecated
alias grep="grep --color=auto"
