tap "homebrew/bundle"

# some packages don not have a sha256 checksum
# so those have overrides for `require_sha`
cask_args appdir: "/Applications", require_sha: true, noQuarantine: true

brew "tig"
brew "node"
brew "ssh-copy-id"
brew "gh"
brew "iperf"
brew "mkcert"
brew "fzf"

cask "qlmarkdown"
cask "qlstephen"
cask "qlvideo"
cask "quicklook-json", { args: { require_sha: false } }
cask "webpquicklook", { args: { require_sha: false } } # preview webp images in quicklook https://github.com/emin/WebPQuickLook

cask "raycast"
cask "google-chrome", { args: { require_sha: false } }
cask "firefox"
cask "ghostty"
cask "arc"
cask "visual-studio-code"
cask "spotify", { args: { require_sha: false } }
cask "figma"
cask "docker"
cask "protonvpn"
cask "font-jetbrains-mono"
cask "hiddenbar" # hide menu bar icons under folding section https://github.com/dwarvesf/hidden
cask "fluor" # enable fn keys per application https://github.com/Pyroh/Fluor
