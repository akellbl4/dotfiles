#!/usr/bin/env sh
# A separate, hidden, non-admin macOS user that runs the T3 Code server and the
# agents it starts, so they can't reach your files, SSH and GPG keys, Keychain or
# gh login. GitHub access comes from fine-grained tokens stored in its home, one
# per repository owner (see 'dotfiles agent-token').

AGENT_USER="${AGENT_USER:-agent}"
AGENT_HOME="/Users/$AGENT_USER"
AGENT_T3_PORT="${AGENT_T3_PORT:-3780}"
AGENT_T3_LABEL="dotfiles.t3-agent"
AGENT_T3_PLIST="/Library/LaunchDaemons/$AGENT_T3_LABEL.plist"
AGENT_BIN="$AGENT_HOME/.local/bin"
AGENT_TOKENS="$AGENT_HOME/.config/github-tokens"

agent_user_exists() {
	dscl . -read "/Users/$AGENT_USER" >/dev/null 2>&1
}

# Run a command as the agent user, from / since it can't enter the current directory
as_agent() {
	(cd / && sudo -u "$AGENT_USER" -H "$@")
}

# Write stdin to a file owned by the agent user
agent_write() {
	as_agent sh -c 'umask 077; cat > "$1"' sh "$1"
}

# The T3 Code app bundle, e.g. "/Applications/T3 Code (Beta).app"
t3_app_dir() {
	for app_dir in "/Applications/T3 Code"*.app; do
		[ -d "$app_dir" ] && echo "$app_dir" && return 0
	done
	return 1
}

agent_requirements() {
	if [ "$(uname)" != "Darwin" ]; then
		log "error" "The agent user is only set up on macOS."
		return 1
	fi
	if ! t3_app_dir >/dev/null; then
		log "error" "T3 Code isn't in /Applications. Install it ('dotfiles ai-tools') and try again."
		return 1
	fi
}

create_agent_user() {
	if agent_user_exists; then
		log "info" "User $AGENT_USER already exists"
		return 0
	fi
	log "info" "Creating the $AGENT_USER user (standard, hidden from the login window)..."
	# Nobody logs in as this user, so the password is random and not kept
	password=$(openssl rand -base64 32)
	if ! sudo sysadminctl -addUser "$AGENT_USER" -fullName "Coding agents" -shell /bin/zsh \
		-home "$AGENT_HOME" -password "$password" || ! agent_user_exists; then
		log "error" "Could not create the $AGENT_USER user, see above"
		return 1
	fi
	[ -d "$AGENT_HOME" ] || sudo createhomedir -c -u "$AGENT_USER" >/dev/null
	sudo dscl . -create "/Users/$AGENT_USER" IsHidden 1
	log "success" "User $AGENT_USER created"
}

# New users are in the staff group, which can read a default (750) home folder
lock_own_home() {
	home_mode=$(stat -f %Lp "$HOME")
	if [ "$home_mode" = "700" ]; then
		log "info" "Your home folder is already private"
		return 0
	fi
	if [ "$(ask "Your home folder is readable by other users, including $AGENT_USER (mode $home_mode). Make it private (700)?")" = "y" ]; then
		chmod 700 "$HOME"
		log "success" "Your home folder is now private"
	else
		log "error" "Skipped: $AGENT_USER can still read your home folder"
	fi
}

install_agent_files() {
	app_dir=$(t3_app_dir)
	app_name=$(basename "$app_dir" .app)

	sudo chmod 700 "$AGENT_HOME"
	as_agent mkdir -p "$AGENT_BIN" "$AGENT_TOKENS" "$AGENT_HOME/Library/Logs"
	as_agent chmod 700 "$AGENT_TOKENS"

	# Root reads them from the dotfiles, since the agent user can't enter your home
	for script in github-token gh credential-helper; do
		sudo install -m 755 -o "$AGENT_USER" -g staff "$DOTFILES_ROOT/agent/$script" "$AGENT_BIN/$script"
	done

	# The agent's own t3 command, running the app's bundled server with its own data
	agent_write "$AGENT_BIN/t3" <<T3
#!/bin/sh
# Written by 'dotfiles agent-user': runs T3 Code's bundled server as $AGENT_USER.
export T3CODE_HOME="\$HOME/.t3"
export T3CODE_CLI_PATH="\$HOME/.local/bin/t3"
export ELECTRON_RUN_AS_NODE=1
exec "$app_dir/Contents/MacOS/$app_name" "$app_dir/Contents/Resources/app.asar/apps/server/dist/bin.mjs" "\$@"
T3
	as_agent chmod 755 "$AGENT_BIN/t3"

	agent_write "$AGENT_HOME/.zprofile" <<'ZPROFILE'
# Written by 'dotfiles agent-user'
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
ZPROFILE
}

configure_agent_git() {
	git_name=$(git config --global user.name || true)
	git_email=$(git config --global user.email || true)
	[ -n "$git_name" ] && as_agent git config --global user.name "$git_name"
	[ -n "$git_email" ] && as_agent git config --global user.email "$git_email"
	# The agent has no GPG key
	as_agent git config --global commit.gpgsign false
	as_agent git config --global init.defaultBranch main
	# Only the per-owner tokens: an empty helper drops any inherited ones (like osxkeychain)
	as_agent git config --global --unset-all credential.https://github.com.helper || true
	as_agent git config --global --add credential.https://github.com.helper ""
	as_agent git config --global --add credential.https://github.com.helper "$AGENT_BIN/credential-helper"
	as_agent git config --global credential.https://github.com.useHttpPath true
	# The agent has no SSH key, so fetch and push GitHub over HTTPS
	as_agent git config --global --unset-all url.https://github.com/.insteadOf || true
	as_agent git config --global --add url.https://github.com/.insteadOf git@github.com:
	as_agent git config --global --add url.https://github.com/.insteadOf ssh://git@github.com/
}

# A LaunchDaemon so the server runs as the agent user from boot, without logging in
install_agent_t3_service() {
	sudo tee "$AGENT_T3_PLIST" >/dev/null <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$AGENT_T3_LABEL</string>
	<key>UserName</key>
	<string>$AGENT_USER</string>
	<key>GroupName</key>
	<string>staff</string>
	<key>ProgramArguments</key>
	<array>
		<string>$AGENT_BIN/t3</string>
		<string>serve</string>
		<string>--lan</string>
		<string>--port</string>
		<string>$AGENT_T3_PORT</string>
	</array>
	<key>WorkingDirectory</key>
	<string>$AGENT_HOME</string>
	<key>EnvironmentVariables</key>
	<dict>
		<key>HOME</key>
		<string>$AGENT_HOME</string>
		<key>USER</key>
		<string>$AGENT_USER</string>
		<key>LOGNAME</key>
		<string>$AGENT_USER</string>
		<key>SHELL</key>
		<string>/bin/zsh</string>
		<key>PATH</key>
		<string>$AGENT_BIN:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
	</dict>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>StandardOutPath</key>
	<string>$AGENT_HOME/Library/Logs/t3-server.log</string>
	<key>StandardErrorPath</key>
	<string>$AGENT_HOME/Library/Logs/t3-server.log</string>
</dict>
</plist>
PLIST
	sudo chown root:wheel "$AGENT_T3_PLIST"
	sudo chmod 644 "$AGENT_T3_PLIST"
	# Reload so a changed plist or app path takes effect
	sudo launchctl bootout "system/$AGENT_T3_LABEL" 2>/dev/null || true
	if sudo launchctl bootstrap system "$AGENT_T3_PLIST"; then
		log "success" "T3 Code server runs as $AGENT_USER on port $AGENT_T3_PORT, reachable from your local network and tailnet"
	else
		log "error" "Could not start the T3 Code service, see $AGENT_HOME/Library/Logs/t3-server.log"
		return 1
	fi
}

setup_agent_user() {
	agent_requirements || return 1
	sudo -v || return 1
	create_agent_user || return 1
	lock_own_home
	install_agent_files || return 1
	configure_agent_git
	install_agent_t3_service || return 1

	log "success" "Agent user ready. Next:"
	log "" "1. Add GitHub tokens: dotfiles agent-token <owner>, and dotfiles agent-token default for the rest" 2
	log "" "2. Log the agents in: sudo -u $AGENT_USER -i claude, then sudo -u $AGENT_USER -i codex login" 2
	log "" "3. Connect T3 Code to the server: dotfiles agent-pair" 2
}

# Store a fine-grained token for one repository owner (or "default") in the agent's home
add_agent_token() {
	owner=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')
	case "$owner" in
		"" | -* | *[!a-z0-9-]*)
			log "error" "Usage: dotfiles agent-token <owner|default>, where owner is a GitHub user or org"
			return 1
			;;
	esac
	if ! agent_user_exists; then
		log "error" "Set up the agent user first: dotfiles agent-user"
		return 1
	fi
	printf "Paste the GitHub token for %s (hidden): " "$owner" >&2
	stty -echo 2>/dev/null || true
	read -r token || token=""
	stty echo 2>/dev/null || true
	printf "\n" >&2
	if [ -z "$token" ]; then
		log "error" "No token entered"
		return 1
	fi
	if has_command gh; then
		if login=$(GH_TOKEN=$token gh api user --jq .login 2>/dev/null); then
			log "info" "Token works (belongs to $login)"
		else
			log "error" "GitHub rejected this token. Saving it anyway; check it hasn't expired."
		fi
	fi
	sudo -v || return 1
	as_agent mkdir -p "$AGENT_TOKENS"
	printf '%s\n' "$token" | agent_write "$AGENT_TOKENS/$owner"
	log "success" "Saved the token for $owner"
}

# Mint a pairing code for the agent's T3 Code server, to connect the desktop app to it
pair_agent_t3() {
	if ! agent_user_exists; then
		log "error" "Set up the agent user first: dotfiles agent-user"
		return 1
	fi
	log "info" "Pairing code for the T3 Code server on port $AGENT_T3_PORT:"
	as_agent "$AGENT_BIN/t3" pair
}
