# Node via fnm (default: latest LTS). On shell start and every cd, switches to the version from the
# nearest .nvmrc/.node-version/package.json engines in this or a parent folder, installing it when
# missing, and back to the default outside a project
if command -v fnm >/dev/null 2>&1; then
	eval "$(fnm env --version-file-strategy recursive --shell zsh)"

	# fnm's own --use-on-cd hook only runs where the version file is, so it misses subfolders and
	# keeps the project's version after leaving it. `fnm use` falls back to the default by itself.
	_fnm_auto_use() {
		fnm use --silent-if-unchanged --install-if-missing
	}
	autoload -U add-zsh-hook
	add-zsh-hook chpwd _fnm_auto_use
	_fnm_auto_use
fi

# Bun
if [ -d "$HOME/.bun/bin" ]; then
	export BUN_INSTALL="$HOME/.bun"
	export PATH="$BUN_INSTALL/bin:$PATH"
fi
