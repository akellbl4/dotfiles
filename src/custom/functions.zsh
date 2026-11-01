# Run dotfiles, then reload ~/.zshrc in this shell after commands that change the
# setup, so changes apply right away without opening a new shell.
# (A script can't change the shell that started it, so the reload happens here.)
dotfiles() {
	case "$1" in
		install|update|link)
			command dotfiles "$@" --source
			local dotfiles_status=$?
			source ~/.zshrc
			return $dotfiles_status
			;;
		*)
			command dotfiles "$@"
			;;
	esac
}
