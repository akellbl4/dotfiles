if command -v gpg >/dev/null 2>&1; then
	GPG_TTY=$(tty)
	export GPG_TTY
fi
