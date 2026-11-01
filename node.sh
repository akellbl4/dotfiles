# Node via fnm (default: latest LTS, switches per project on cd from .nvmrc/.node-version)
if command -v fnm >/dev/null 2>&1; then
	eval "$(fnm env --use-on-cd --shell zsh)"
fi

# Bun
if [ -d "$HOME/.bun/bin" ]; then
	export BUN_INSTALL="$HOME/.bun"
	export PATH="$BUN_INSTALL/bin:$PATH"
fi
