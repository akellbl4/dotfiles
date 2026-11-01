#!/usr/bin/env sh
# shellcheck disable=SC2034 # color variables are used by scripts that source this file

# Define styling variables
BOLD='\033[1m'
WHITE='\033[37m'
# Define color variables
BLUE='\033[34m'
GREEN='\033[32m'
BLACK='\033[30m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
# Define background color variables
BG_YELLOW='\033[43m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_CYAN='\033[46m'
# Reset formatting
RESET='\033[0m'

log() {
	log_type="$1"
	log_message="$2"
	log_indent=${3:-0}

	# Define styling based on log type
	case "$log_type" in
		"info") log_style=${BLUE} ;;
		"success") log_style=${GREEN} ;;
		"error") log_style=${RED} ;;
		*) log_style=${RESET} ;;
	esac

	# Apply indent and styling
	log_prefix=""
	if [ "$log_indent" -gt 0 ]; then
		log_prefix=$(printf "%${log_indent}s" "")
	fi

	printf "%b\n" "${log_prefix}${log_style}${log_message}${RESET}"
}

# Prompt a yes/no question (default yes) and print "y" or "n"
ask() {
	printf "%s (Y/n) > " "$1" >&2
	read -r answer || answer=""
	case "$answer" in
		[nN]*) echo "n" ;;
		*) echo "y" ;;
	esac
}

# Put Homebrew on PATH for this shell
load_brew() {
	if [ -x /opt/homebrew/bin/brew ]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
		return 0
	fi
	command -v brew >/dev/null 2>&1
}

# Clone or update the dotfiles repo
pull_repo() {
	if [ -d "$DOTFILES_ROOT/.git" ]; then
		log "info" "Updating dotfiles..."
		if ! git -C "$DOTFILES_ROOT" pull --ff-only origin main; then
			log "error" "Could not update $DOTFILES_ROOT, see the git error above. If you have local changes, commit or stash them and retry."
			return 1
		fi
		log "success" "Pulled the latest dotfiles"
	else
		log "info" "Installing dotfiles..."
		git clone https://github.com/akellbl4/dotfiles.git "$DOTFILES_ROOT"
		log "success" "Dotfiles downloaded"
	fi
}

# Link everything into place
link_all() {
	link_files "$DOTFILES_ROOT/src" "$HOME" "Dotfiles"
	link_files "$DOTFILES_ROOT/src/custom" "$HOME/.oh-my-zsh/custom" "ZSH files"

	# Each folder in src/.config/ is linked into ~/.config/ (e.g. ghostty)
	for config_dir in "$DOTFILES_ROOT"/src/.config/*/; do
		[ -d "$config_dir" ] || continue
		app_name=$(basename "$config_dir")
		link_files "$config_dir" "$HOME/.config/$app_name" "$app_name config"
	done
}

sync_repo() {
	pull_repo
	link_all
}

link_files() {
	src_dir=$1
	target_dir=$2
	name=$3

	if [ ! -d "$src_dir" ]; then
		log "error" "$name directory not found"
		return 1
	fi
	mkdir -p "$target_dir"

	log "info" "Linking $name..."
	# read files from source directory avoiding subdirectories
	find "$src_dir" -maxdepth 1 -type f | while read -r source_file; do
		target_file="$target_dir/$(basename "$source_file")"

		# if target is a real file, back it up
		if [ -f "$target_file" ] && [ ! -L "$target_file" ]; then
			mv "$target_file" "$target_file.$(date "+%Y%m%d%H%M%S").bak"
		fi

		log "info" "$(ln -sfv "$source_file" "$target_file")" 1
	done
	log "success" "$name linked"
}

# Path to the personal Git config (name, email, signing key)
git_user_config() {
	echo "$DOTFILES_ROOT/src/.gitconfig.user"
}

# Read a value from the personal Git config, empty if unset
git_user_get() {
	git config -f "$(git_user_config)" "$1" 2>/dev/null || true
}

# Prompt for a value, showing the current one; Enter keeps it
prompt_value() {
	if [ -n "$2" ]; then
		printf "%s [%s]: " "$1" "$2" >&2
	else
		printf "%s: " "$1" >&2
	fi
	read -r value || value=""
	echo "${value:-$2}"
}

# Prompt a yes/no question that defaults to no and print "y" or "n"
ask_no() {
	printf "%s (y/N) > " "$1" >&2
	read -r answer || answer=""
	case "$answer" in
		[yY]*) echo "y" ;;
		*) echo "n" ;;
	esac
}

# Print "Name <email>" from the personal Git config, empty if not configured
git_user_summary() {
	summary_name=$(git_user_get user.name)
	summary_email=$(git_user_get user.email)
	if [ -n "$summary_name" ] || [ -n "$summary_email" ]; then
		echo "${summary_name:-?} <${summary_email:-?}>"
	fi
}

# Ask for Git name and email, keeping current values on Enter.
# The signing key is managed separately by setup_gpg_key.
configure_git_user() {
	log "info" "Configuring Git user settings (press Enter to keep the current value)..."
	user_config=$(git_user_config)
	new_name=$(prompt_value "Full name" "$(git_user_get user.name)")
	new_email=$(prompt_value "Email" "$(git_user_get user.email)")

	touch "$user_config"
	if [ -n "$new_name" ]; then git config -f "$user_config" user.name "$new_name"; fi
	if [ -n "$new_email" ]; then git config -f "$user_config" user.email "$new_email"; fi
	ln -sf "$user_config" "$HOME/.gitconfig.user"

	log "success" "Git user: $(git_user_summary)"
}

# List usable secret signing keys, one per line: fingerprint|key id|user id|expiry (epoch, empty if none)
list_signing_keys() {
	gpg --list-secret-keys --with-colons --fixed-list-mode 2>/dev/null | awk -F: '
		$1 == "sec" { usable = ($2 != "r" && $2 != "e" && $2 != "d" && $12 ~ /S/); keyid = $5; expiry = $7; fpr = ""; printed = 0; next }
		$1 == "fpr" && fpr == "" { fpr = $10; next }
		$1 == "uid" && $2 != "r" && usable && !printed && fpr != "" { printf "%s|%s|%s|%s\n", fpr, keyid, $10, expiry; printed = 1 }
	'
}

# Human-readable expiry for an epoch timestamp
format_expiry() {
	if [ -n "$1" ]; then
		# BSD date (macOS) uses -r, GNU date (Linux) uses -d @
		echo "expires $(date -r "$1" "+%Y-%m-%d" 2>/dev/null || date -d "@$1" "+%Y-%m-%d")"
	else
		echo "never expires"
	fi
}

# Describe a key by fingerprint or id: "KEYID  Name <email>, expires ..."
describe_key() {
	list_signing_keys | awk -F'|' -v k="$1" 'toupper($1) == toupper(k) || toupper($2) == toupper(k) || toupper(substr($1, length($1) - length(k) + 1)) == toupper(k)' | head -n 1 \
		| while IFS='|' read -r d_fpr d_id d_uid d_exp; do
			echo "$d_id  $d_uid, $(format_expiry "$d_exp")"
		done
}

# Configure Git to sign commits with the given key
use_signing_key() {
	user_config=$(git_user_config)
	touch "$user_config"
	git config -f "$user_config" user.signingkey "$1"
	git config -f "$user_config" commit.gpgsign true
	ln -sf "$user_config" "$HOME/.gitconfig.user"
}

# Device of the terminal this script runs in, e.g. /dev/ttys003 or /dev/pts/0.
# `tty` prints just /dev/tty when stdin is redirected from it (as install.sh does),
# and gpg-agent can't open that for the passphrase prompt, so ask ps for the real device.
terminal_device() {
	terminal_name=$(ps -o tty= -p $$ 2>/dev/null | tr -d ' ')
	case "$terminal_name" in
		''|'?'|'??') terminal_name=$(tty 2>/dev/null) && echo "$terminal_name" ;;
		/dev/*) echo "$terminal_name" ;;
		*) echo "/dev/$terminal_name" ;;
	esac
}

# Create a new ed25519 signing key and print its fingerprint
create_signing_key() {
	key_name=$(git_user_get user.name)
	key_email=$(git_user_get user.email)
	if [ -z "$key_name" ] || [ -z "$key_email" ]; then
		log "info" "The key needs a name and email (these are also saved as your Git user)." >&2
		key_name=$(prompt_value "Full name" "$key_name")
		key_email=$(prompt_value "Email (should match your GitHub email)" "$key_email")
	fi
	if [ -z "$key_name" ] || [ -z "$key_email" ]; then
		log "error" "Name and email are required to create a key." >&2
		return 1
	fi
	git config -f "$(git_user_config)" user.name "$key_name"
	git config -f "$(git_user_config)" user.email "$key_email"

	# pinentry needs to know which terminal to ask for the passphrase on
	GPG_TTY=$(terminal_device)
	export GPG_TTY

	log "info" "Creating a new GPG key for $key_name <$key_email> (you will be asked for a passphrase)..." >&2
	gpg --status-fd 1 --quick-generate-key "$key_name <$key_email>" ed25519 sign 2y \
		| awk '/KEY_CREATED/ {print $NF}'
}

# Offer to upload a public key to GitHub unless it is already there
offer_github_upload() {
	upload_fpr=$1
	upload_id=$2
	if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
		log "info" "Add the public key at https://github.com/settings/gpg/new:"
		gpg --armor --export "$upload_fpr"
		return 0
	fi
	if gh gpg-key list 2>/dev/null | grep -qi "$upload_id"; then
		log "info" "Key $upload_id is already on your GitHub account."
		return 0
	fi
	if [ "$(ask "Add key $upload_id to your GitHub account?")" != "y" ]; then
		return 0
	fi
	if gpg --armor --export "$upload_fpr" | gh gpg-key add -; then
		log "success" "Key $upload_id added to GitHub"
	else
		log "error" "Upload failed. You may need: gh auth refresh -s write:gpg_key"
	fi
}

# Choose an existing GPG key or create a new one, and configure Git to sign commits with it
# Pass --change to skip the "Change the signing key?" confirmation (already asked)
setup_gpg_key() {
	load_brew || true
	if ! command -v gpg >/dev/null 2>&1; then
		log "error" "gpg not found, skipping signing key setup. Run 'dotfiles bundle' to install gnupg."
		return 0
	fi

	current_key=$(git_user_get user.signingkey)
	if [ -n "$current_key" ]; then
		current_desc=$(describe_key "$current_key")
		log "info" "Git signs commits with: ${current_desc:-$current_key (not found in your GPG keyring!)}"
		if [ "$1" != "--change" ] && [ "$(ask_no "Change the signing key?")" != "y" ]; then
			return 0
		fi
	fi

	keys=$(list_signing_keys)
	choice=""
	if [ -z "$keys" ]; then
		log "info" "No GPG signing keys found in your keyring."
		if [ "$(ask "Create a new GPG signing key?")" = "y" ]; then
			choice="c"
		fi
	else
		log "info" "Choose a GPG key for signing commits:"
		index=0
		echo "$keys" | while IFS='|' read -r k_fpr k_id k_uid k_exp; do
			index=$((index + 1))
			log "" "$index) Use existing key $k_id  $k_uid, $(format_expiry "$k_exp")" 2
		done
		log "" "c) Create a new key" 2
		log "" "s) Skip" 2
		while :; do
			printf "Choice > " >&2
			read -r choice || choice="s"
			case "$choice" in
				''|c|C|s|S) break ;;
				*[!0-9]*) ;;
				*) if [ "$choice" -gt 0 ] && [ -n "$(echo "$keys" | sed -n "${choice}p")" ]; then break; fi ;;
			esac
			log "error" "Enter a key number, c or s."
		done
	fi

	case "$choice" in
		c|C)
			key_fpr=$(create_signing_key) || key_fpr=""
			if [ -z "$key_fpr" ]; then
				log "error" "GPG key creation failed"
				return 0
			fi
			key_id=$(list_signing_keys | awk -F'|' -v f="$key_fpr" '$1 == f {print $2}')
			use_signing_key "$key_fpr"
			log "success" "Created new GPG key ${key_id:-$key_fpr} and set it as your Git signing key"
			;;
		''|s|S)
			log "info" "Skipped signing key setup. Run 'dotfiles gpg-key' any time to set it up."
			return 0
			;;
		*)
			selected=$(echo "$keys" | sed -n "${choice}p")
			key_fpr=$(echo "$selected" | cut -d'|' -f1)
			key_id=$(echo "$selected" | cut -d'|' -f2)
			use_signing_key "$key_fpr"
			log "success" "Linked existing GPG key $key_id as your Git signing key"
			;;
	esac

	offer_github_upload "$key_fpr" "$key_id"
}

# Describe the signing key when GPG is fully set up (agent config linked, Git signing
# with a key that's in the keyring); prints nothing otherwise
gpg_setup_summary() {
	[ -L "$HOME/.gnupg/gpg-agent.conf" ] || return 0
	[ "$(readlink "$HOME/.gnupg/gpg-agent.conf")" = "$DOTFILES_ROOT/gpg-agent.conf" ] || return 0
	load_brew >/dev/null 2>&1 || true
	command -v gpg >/dev/null 2>&1 || return 0
	summary_key=$(git_user_get user.signingkey)
	[ -n "$summary_key" ] || return 0
	describe_key "$summary_key"
}

# Print the default user folders that don't exist yet
missing_user_folders() {
	for folder in Screenshots Developer; do
		if [ ! -d "$HOME/$folder" ]; then
			echo "$folder"
		fi
	done
}

user_folders() {
	for folder in $(missing_user_folders); do
		mkdir "$HOME/$folder"
		log "success" "$HOME/$folder folder created"
	done
}

# Print the Linux package family: debian, fedora, fedora-atomic (Bazzite, Silverblue) or unknown
linux_family() {
	os_release=${1:-/etc/os-release}
	ostree_marker=${2:-/run/ostree-booted}
	if [ ! -r "$os_release" ]; then
		echo "unknown"
		return 0
	fi
	os_ids=$(unset ID ID_LIKE; . "$os_release"; echo "$ID $ID_LIKE")
	case " $os_ids " in
		*" fedora "*)
			if [ -e "$ostree_marker" ]; then echo "fedora-atomic"; else echo "fedora"; fi
			;;
		*" debian "*|*" ubuntu "*) echo "debian" ;;
		*) echo "unknown" ;;
	esac
}

DOCKER_LINK="$HOME/.local/bin/docker"

# True when Podman is installed, its VM exists (macOS) and the docker command is set up
podman_ready() {
	command -v podman >/dev/null 2>&1 || return 1
	if [ "$(uname)" = "Darwin" ] && [ -z "$(podman machine list --format '{{.Name}}' 2>/dev/null)" ]; then
		return 1
	fi
	[ -L "$DOCKER_LINK" ] || [ -n "$(other_docker)" ]
}

# Path of a docker command that isn't our Podman link, empty if there is none
other_docker() {
	(
		PATH=$(printf "%s" "$PATH" | tr ':' '\n' | grep -vx "$HOME/.local/bin" | paste -sd: -)
		command -v docker 2>/dev/null || true
	)
}

install_podman() {
	if command -v podman >/dev/null 2>&1; then
		log "info" "Podman already installed ($(podman --version))"
		return 0
	fi

	log "info" "Installing Podman..."
	if [ "$(uname)" = "Darwin" ]; then
		if ! load_brew; then
			log "error" "Homebrew is required to install Podman on macOS."
			return 1
		fi
		brew install podman
		return
	fi

	case "$(linux_family)" in
		debian)
			sudo apt-get update && sudo apt-get install -y podman
			;;
		fedora)
			sudo dnf install -y podman
			;;
		fedora-atomic)
			# Image-based Fedora (Bazzite, Silverblue) normally ships Podman; layer it if it's missing
			sudo rpm-ostree install podman
			log "info" "Podman is layered and will be available after a reboot. Then run 'dotfiles podman' to finish."
			return 1
			;;
		*)
			log "error" "Unsupported system. Install Podman yourself, then run 'dotfiles podman'."
			return 1
			;;
	esac
}

# On macOS containers run in a Linux VM: create it once and make sure it's running
start_podman_machine() {
	[ "$(uname)" = "Darwin" ] || return 0
	if [ -z "$(podman machine list --format '{{.Name}}' 2>/dev/null)" ]; then
		log "info" "Creating the Podman virtual machine (downloads a Linux image)..."
		podman machine init
	fi
	if [ "$(podman machine inspect --format '{{.State}}' 2>/dev/null)" != "running" ]; then
		log "info" "Starting the Podman virtual machine..."
		podman machine start
	fi
}

# Make `docker` run Podman, unless a real Docker is installed
link_docker_to_podman() {
	existing_docker=$(other_docker)
	if [ -n "$existing_docker" ]; then
		log "info" "Docker is already installed at $existing_docker, so docker is not linked to Podman."
		return 0
	fi
	mkdir -p "$(dirname "$DOCKER_LINK")"
	ln -sf "$(command -v podman)" "$DOCKER_LINK"
	log "success" "docker now runs Podman ($DOCKER_LINK -> $(command -v podman))"
}

setup_podman() {
	install_podman || return 1
	start_podman_machine || return 1
	link_docker_to_podman
}

# True when a command exists, also looking in ~/.local/bin where many tools install
has_command() {
	(
		PATH="$HOME/.local/bin:$PATH"
		command -v "$1" >/dev/null 2>&1
	)
}

# True when this machine has a desktop (always on macOS)
has_gui() {
	[ "$(uname)" = "Darwin" ] && return 0
	[ -n "$DISPLAY$WAYLAND_DISPLAY" ] && return 0
	[ "$(systemctl get-default 2>/dev/null)" = "graphical.target" ]
}

# CPU architecture as x64 or arm64
cpu_arch() {
	case "$(uname -m)" in
		x86_64|amd64) echo "x64" ;;
		aarch64|arm64) echo "arm64" ;;
		*) echo "unsupported" ;;
	esac
}

# Download a URL to a file, following redirects
download() {
	curl -fL --progress-bar "$1" -o "$2"
}

# Run a vendor install script with the given shell and arguments (downloaded first, so a failed download isn't run)
run_install_script() {
	script_url=$1
	script_shell=$2
	shift 2
	script_file=$(mktemp)
	if download "$script_url" "$script_file"; then
		"$script_shell" "$script_file" "$@"
		script_status=$?
	else
		script_status=1
	fi
	rm -f "$script_file"
	return $script_status
}

# Install an AppImage as ~/.local/bin/<name> with an app menu entry
install_appimage() {
	appimage_name=$1
	appimage_url=$2
	appimage_title=$3
	mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
	appimage_tmp=$(mktemp)
	if ! download "$appimage_url" "$appimage_tmp"; then
		rm -f "$appimage_tmp"
		return 1
	fi
	chmod +x "$appimage_tmp"
	mv "$appimage_tmp" "$HOME/.local/bin/$appimage_name"
	cat > "$HOME/.local/share/applications/$appimage_name.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$appimage_title
Exec=$HOME/.local/bin/$appimage_name %U
Terminal=false
Categories=Development;
DESKTOP
}

# URL of the latest GitHub release asset whose name matches a pattern
github_release_asset() {
	curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
		| grep -o '"browser_download_url": *"[^"]*"' \
		| sed 's/.*"\(https[^"]*\)"/\1/' \
		| grep -E -e "$2" | head -n 1
}

# AI coding tools for this machine: CLIs everywhere, desktop apps only where there's a GUI
ai_tools() {
	echo "claude codex"
	if has_gui; then
		echo "cursor t3code"
	fi
}

# Homebrew cask for each tool on macOS
ai_tool_cask() {
	case "$1" in
		claude) echo "claude-code" ;;
		t3code) echo "t3-code" ;;
		*) echo "$1" ;;
	esac
}

ai_tool_installed() {
	if [ "$(uname)" = "Darwin" ]; then
		load_brew >/dev/null 2>&1 && brew list --cask "$(ai_tool_cask "$1")" >/dev/null 2>&1
	else
		has_command "$1"
	fi
}

# Print the AI tools that aren't installed yet, space separated
missing_ai_tools() {
	for tool in $(ai_tools); do
		ai_tool_installed "$tool" || printf "%s " "$tool"
	done
}

install_cursor_linux() {
	cursor_base="https://api2.cursor.sh/updates/download/golden/linux-$(cpu_arch)"
	case "$(linux_family)" in
		debian)
			package_file="$(mktemp -d)/cursor.deb"
			download "$cursor_base-deb/cursor/latest" "$package_file" && sudo apt-get install -y "$package_file"
			;;
		fedora)
			package_file="$(mktemp -d)/cursor.rpm"
			download "$cursor_base-rpm/cursor/latest" "$package_file" && sudo dnf install -y "$package_file"
			;;
		*)
			install_appimage cursor "$cursor_base/cursor/latest" "Cursor"
			;;
	esac
}

install_t3code_linux() {
	if [ "$(linux_family)" = "debian" ]; then
		deb_arch=amd64
		[ "$(cpu_arch)" = "arm64" ] && deb_arch=arm64
		t3_url=$(github_release_asset pingdotgg/t3code "-${deb_arch}\.deb$")
		[ -n "$t3_url" ] || return 1
		package_file="$(mktemp -d)/t3code.deb"
		download "$t3_url" "$package_file" && sudo apt-get install -y "$package_file"
	else
		appimage_arch=x86_64
		[ "$(cpu_arch)" = "arm64" ] && appimage_arch=arm64
		t3_url=$(github_release_asset pingdotgg/t3code "-${appimage_arch}\.AppImage$")
		[ -n "$t3_url" ] || return 1
		install_appimage t3code "$t3_url" "T3 Code"
	fi
}

install_ai_tool() {
	if [ "$(uname)" = "Darwin" ]; then
		if ! load_brew; then
			log "error" "Homebrew is required to install $1 on macOS."
			return 1
		fi
		brew install --cask "$(ai_tool_cask "$1")"
		return
	fi
	if [ "$(cpu_arch)" = "unsupported" ]; then
		log "error" "Unsupported CPU architecture $(uname -m) for $1."
		return 1
	fi
	# The vendor installers put binaries in ~/.local/bin and only prompt when it isn't on PATH
	PATH="$HOME/.local/bin:$PATH"
	export PATH
	case "$1" in
		claude) run_install_script https://claude.ai/install.sh bash ;;
		codex) run_install_script https://chatgpt.com/codex/install.sh sh ;;
		cursor) install_cursor_linux ;;
		t3code) install_t3code_linux ;;
	esac
}

# Install Claude Code and Codex everywhere, plus Cursor and T3 Code where there's a desktop
setup_ai_tools() {
	missing=$(missing_ai_tools)
	if [ -z "$missing" ]; then
		log "info" "AI tools already installed: $(ai_tools | tr '\n' ' ')"
		return 0
	fi
	failed=""
	for tool in $missing; do
		log "info" "Installing $tool..."
		if install_ai_tool "$tool" && ai_tool_installed "$tool"; then
			log "success" "$tool installed"
		else
			log "error" "$tool installation failed, see above"
			failed="$failed $tool"
		fi
	done
	if [ -n "$failed" ]; then
		log "error" "Not installed:$failed. Run 'dotfiles ai-tools' to retry."
		return 1
	fi
}

# Install zsh, git, curl and unzip on Linux if they're missing (macOS ships them)
ensure_base_packages() {
	[ "$(uname)" = "Darwin" ] && return 0
	missing_packages=""
	for package in zsh git curl unzip; do
		command -v "$package" >/dev/null 2>&1 || missing_packages="$missing_packages $package"
	done
	[ -z "$missing_packages" ] && return 0

	log "info" "Installing$missing_packages..."
	case "$(linux_family)" in
		debian)
			# shellcheck disable=SC2086 # package list is meant to split
			sudo apt-get update && sudo apt-get install -y $missing_packages
			;;
		fedora)
			# shellcheck disable=SC2086
			sudo dnf install -y $missing_packages
			;;
		fedora-atomic)
			# shellcheck disable=SC2086
			sudo rpm-ostree install $missing_packages
			log "error" "Reboot to finish installing$missing_packages, then run the installer again."
			return 1
			;;
		*)
			log "error" "Install$missing_packages with your package manager, then run the installer again."
			return 1
			;;
	esac
}

# Login shell of the current user
login_shell() {
	if [ "$(uname)" = "Darwin" ]; then
		dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}'
	else
		getent passwd "$USER" | cut -d: -f7
	fi
}

zsh_is_default_shell() {
	[ "$(basename "$(login_shell)")" = "zsh" ]
}

# Make zsh the login shell (Linux usually defaults to bash)
set_zsh_default_shell() {
	zsh_path=$(command -v zsh) || return 1
	if sudo usermod --shell "$zsh_path" "$USER"; then
		log "success" "zsh is now your default shell (applies to new logins)"
	else
		log "error" "Could not change the default shell. Run: chsh -s $zsh_path"
	fi
}

# fnm (Node version manager): Homebrew on macOS, official installer into ~/.local/bin on Linux
install_fnm() {
	has_command fnm && return 0
	log "info" "Installing fnm..."
	if [ "$(uname)" = "Darwin" ]; then
		load_brew && brew install fnm
		return
	fi
	# --skip-shell: node.sh sets up the shell, so the installer mustn't edit ~/.zshrc
	mkdir -p "$HOME/.local/bin"
	run_install_script https://fnm.vercel.app/install bash --skip-shell --install-dir "$HOME/.local/bin"
}

bun_installed() {
	has_command bun || [ -x "$HOME/.bun/bin/bun" ]
}

install_bun() {
	bun_installed && return 0
	log "info" "Installing Bun..."
	if [ "$(uname)" = "Darwin" ]; then
		load_brew && brew install bun
		return
	fi
	# The installer appends to ~/.zshrc (part of this repo) for zsh users; with
	# another SHELL it only prints instructions, and node.sh adds Bun to PATH
	(
		SHELL=/bin/sh
		export SHELL
		run_install_script https://bun.sh/install bash
	)
}

# Latest Node LTS as the default via fnm, Corepack with pnpm, and Bun
setup_node() {
	if ! install_fnm; then
		log "error" "Could not install fnm."
		return 1
	fi
	PATH="$HOME/.local/bin:$PATH"
	export PATH

	log "info" "Installing the latest Node LTS..."
	fnm install --lts || return 1
	fnm default lts-latest || return 1
	eval "$(fnm env --shell bash)"
	log "success" "Node $(node --version) is the default"

	# Node 25+ no longer bundles Corepack, so install it from npm when missing
	COREPACK_ENABLE_DOWNLOAD_PROMPT=0
	export COREPACK_ENABLE_DOWNLOAD_PROMPT
	if ! command -v corepack >/dev/null 2>&1; then
		npm install --global corepack || return 1
	fi
	corepack enable || return 1
	corepack install --global pnpm@latest || return 1
	log "success" "pnpm $(pnpm --version) enabled through Corepack"

	if ! install_bun; then
		log "error" "Could not install Bun."
		return 1
	fi
	log "success" "Bun $(PATH="$HOME/.bun/bin:$PATH" bun --version) installed"
}

# Desired macOS defaults, one per line: currentHost (y/n)|domain|key|type|value|description
macos_defaults_list() {
	cat <<DEFAULTS
y|-g|AppleFontSmoothing|int|0|Font smoothing off
n|-g|PMPrintingExpandedStateForPrint|bool|true|Expanded print dialog
n|com.apple.dock|mineffect|string|scale|Scale effect when minimizing
n|com.apple.dock|autohide-delay|float|0|Hidden Dock appears instantly
n|com.apple.dock|autohide-time-modifier|float|0.3|Faster Dock animation
n|com.apple.dock|show-recents|bool|false|No suggested and recent apps in Dock
n|com.apple.screencapture|location|string|$HOME/Screenshots|Screenshots saved to ~/Screenshots
n|com.apple.finder|_FXSortFoldersFirst|bool|true|Folders first in Finder
n|com.apple.finder|_FXSortFoldersFirstOnDesktop|bool|true|Folders first on the desktop
DEFAULTS
}

# True when a default already has the desired value
macos_default_matches() {
	if [ "$1" = "y" ]; then
		current=$(defaults -currentHost read "$2" "$3" 2>/dev/null) || return 1
	else
		current=$(defaults read "$2" "$3" 2>/dev/null) || return 1
	fi
	case "$4" in
		# defaults read prints booleans as 1 or 0
		bool)
			[ "$5" = "true" ] && wanted=1 || wanted=0
			[ "$current" = "$wanted" ]
			;;
		int|float)
			awk -v a="$current" -v b="$5" 'BEGIN { exit !(a + 0 == b + 0) }'
			;;
		*)
			[ "$current" = "$5" ]
			;;
	esac
}

# Print the descriptions of defaults that differ from the desired values, one per line
changed_macos_defaults() {
	macos_defaults_list | while IFS='|' read -r host domain key type value description; do
		macos_default_matches "$host" "$domain" "$key" "$type" "$value" || echo "$description"
	done
}

# Apply only the defaults that differ, then restart just the affected apps
macos_defaults() {
	restart_apps=""
	changes=$(macos_defaults_list | while IFS='|' read -r host domain key type value description; do
		macos_default_matches "$host" "$domain" "$key" "$type" "$value" && continue
		if [ "$host" = "y" ]; then
			defaults -currentHost write "$domain" "$key" "-$type" "$value"
		else
			defaults write "$domain" "$key" "-$type" "$value"
		fi
		echo "$domain|$description"
	done)

	if [ -z "$changes" ]; then
		log "info" "macOS defaults already up to date"
		return 0
	fi

	echo "$changes" | while IFS='|' read -r domain description; do
		log "success" "$description" 1
	done
	case "$changes" in *com.apple.dock*) restart_apps="$restart_apps Dock" ;; esac
	case "$changes" in *com.apple.finder*) restart_apps="$restart_apps Finder" ;; esac
	case "$changes" in *com.apple.screencapture*) restart_apps="$restart_apps SystemUIServer" ;; esac
	for app in $restart_apps; do
		killall "$app" >/dev/null 2>&1 || true
	done
	log "success" "macOS defaults updated"
}
