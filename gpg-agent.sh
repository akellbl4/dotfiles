export GPG_TTY=$(tty)
export GPG_AGENT_INFO="$(gpgconf --list-dirs agent-socket)"
