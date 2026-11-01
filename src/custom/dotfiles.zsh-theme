# Dotfiles prompt
#
#   14:02:07 ~/Developer/dotfiles ⌥ main +1 ~2 ?3 ↑1 · 1.4s · exit 1
#   $
#
# Line 1: time, user@host (SSH only), directory, git branch and status,
#         how long the last command took and its exit code (if it failed)
# Line 2: $ (# for root), green after success and red after failure
#
# Git status: +staged ~modified ?untracked !conflicts ↑ahead ↓behind
# Uses only plain zsh, terminal colors and glyphs available in JetBrains Mono.

zmodload zsh/datetime
autoload -Uz add-zsh-hook

typeset -g _dotfiles_cmd_start=""
typeset -g _dotfiles_first_prompt=1

# Format milliseconds as 85ms, 1.4s, 42s, 1m 5s or 2h 3m
_dotfiles_format_duration() {
	local ms=$1
	local total=$(( ms / 1000 ))
	local LC_NUMERIC=C  # always 1.4s, never 1,4s
	if (( ms < 1000 )); then
		print -n "${ms}ms"
	elif (( ms < 10000 )); then
		printf "%.1fs" $(( ms / 1000.0 ))
	elif (( total >= 3600 )); then
		print -n "$(( total / 3600 ))h $(( total % 3600 / 60 ))m"
	elif (( total >= 60 )); then
		print -n "$(( total / 60 ))m $(( total % 60 ))s"
	else
		print -n "${total}s"
	fi
}

# Branch and status of the current git repository, empty outside of one
_dotfiles_git_info() {
	local line branch="" oid="" staged=0 modified=0 untracked=0 conflicts=0 ahead=0 behind=0
	local output
	output=$(GIT_OPTIONAL_LOCKS=0 command git status --porcelain=v2 --branch 2>/dev/null) || return

	for line in "${(@f)output}"; do
		case $line in
			"# branch.oid "*) oid=${line#\# branch.oid } ;;
			"# branch.head "*) branch=${line#\# branch.head } ;;
			"# branch.ab "*)
				local ab=(${=line#\# branch.ab })
				ahead=${ab[1]#+}
				behind=${ab[2]#-}
				;;
			"1 "*|"2 "*)
				[[ ${line[3]} != "." ]] && (( staged++ ))
				[[ ${line[4]} != "." ]] && (( modified++ ))
				;;
			"u "*) (( conflicts++ )) ;;
			"? "*) (( untracked++ )) ;;
		esac
	done

	# Detached HEAD: show the short commit hash instead
	if [[ $branch == "(detached)" ]]; then
		branch="${oid[1,7]}"
		[[ $oid == "(initial)" ]] && branch="(initial)"
	fi

	local info="%F{8}⌥%f %F{magenta}${branch//\%/%%}%f"
	(( staged )) && info+=" %F{green}+${staged}%f"
	(( modified )) && info+=" %F{yellow}~${modified}%f"
	(( untracked )) && info+=" %F{8}?${untracked}%f"
	(( conflicts )) && info+=" %F{red}!${conflicts}%f"
	(( ahead )) && info+=" %F{cyan}↑${ahead}%f"
	(( behind )) && info+=" %F{cyan}↓${behind}%f"
	print -n "$info"
}

_dotfiles_preexec() {
	_dotfiles_cmd_start=$EPOCHREALTIME
}

_dotfiles_precmd() {
	local exit_code=$?
	local parts=()

	# Time the prompt was drawn, i.e. when the last command finished
	parts+=("%F{8}%D{%H:%M:%S}%f")

	# User and host only matter on remote machines
	if [[ -n $SSH_CONNECTION ]]; then
		parts+=("%F{yellow}%n@%m%f")
	fi

	# Directory: home shown as ~, long paths shortened to the last 3 folders
	parts+=("%B%F{blue}%(4~|…/%3~|%~)%f%b")

	local git_info
	git_info=$(_dotfiles_git_info)
	[[ -n $git_info ]] && parts+=("$git_info")

	local extras=()
	if [[ -n $_dotfiles_cmd_start ]]; then
		local -i elapsed_ms=$(( (EPOCHREALTIME - _dotfiles_cmd_start) * 1000 ))
		extras+=("%F{yellow}$(_dotfiles_format_duration $elapsed_ms)%f")
		(( exit_code != 0 )) && extras+=("%F{red}exit ${exit_code}%f")
	fi
	_dotfiles_cmd_start=""

	local first_line="${(j: :)parts}"
	local extra
	for extra in $extras; do
		first_line+=" %F{8}·%f ${extra}"
	done

	# A blank line between commands, except above the very first prompt
	local spacer=$'\n'
	if (( _dotfiles_first_prompt )); then
		spacer=""
		_dotfiles_first_prompt=0
	fi

	PROMPT="${spacer}${first_line}"$'\n'"%(?.%F{green}.%F{red})%(!.#.$)%f "
}

# Clear the screen without the blank line on top
_dotfiles_clear_screen() {
	_dotfiles_first_prompt=1
	_dotfiles_precmd
	zle .clear-screen
}
zle -N clear-screen _dotfiles_clear_screen

add-zsh-hook preexec _dotfiles_preexec
add-zsh-hook precmd _dotfiles_precmd

PROMPT2="%F{8}…%f "
RPROMPT=""
