if [ -n "$PS1" ]; then

	for file in $HOME/.dotfiles/includes/*.sh; do
		[ -r $file ] && source "$file"
	done
	unset file

	# Setup git completion for its alias
	__git_complete g __git_main

	# Case-insensitive globbing (used in pathname expansion)
	shopt -s nocaseglob

	# Append to the Bash history file, rather than overwriting it
	shopt -s histappend

	# Autocorrect typos in path names when using `cd`
	shopt -s cdspell

	# Save all lines of a multiple-line command in the same history entry (allows easy re-editing of multi-line commands)
	shopt -s cmdhist

	# Don't autocomplete when accidentally pressing Tab on an empty line. (It takes forever and yields "Display all 15 gazillion possibilites?")
	shopt -s no_empty_cmd_completion

	# Add tab completion for SSH hostnames based on ~/.ssh/config, ignoring wildcards
	[ -e "$HOME/.ssh/config" ] && complete -o "default" -o "nospace" -W "$(grep "^Host" ~/.ssh/config | grep -v "[?*]" | awk '{print $2}')" scp sftp ssh
fi