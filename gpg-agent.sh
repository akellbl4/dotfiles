if command -v gpg >/dev/null 2>&1; then
	# Terminal for the passphrase prompt (pinentry). In a shell started with stdin
	# redirected from /dev/tty (like the one the installer opens), `tty` prints just
	# /dev/tty, which pinentry can't use, so ask ps for the real device instead.
	GPG_TTY=$(tty 2>/dev/null)
	if [ "$GPG_TTY" = "/dev/tty" ]; then
		GPG_TTY=/dev/$(ps -o tty= -p $$ | tr -d ' ')
	fi
	export GPG_TTY
fi
