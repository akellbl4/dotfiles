# ⚙️ Dotfiles

My macOS development environment: Zsh with Oh My Zsh, Homebrew packages, Git and GPG configuration, and a set of macOS defaults, managed by a single `dotfiles` command.

## Requirements

- macOS on Apple Silicon
- Git (`xcode-select --install` if it is missing)

## Install

```sh
curl -L https://github.com/akellbl4/dotfiles/raw/main/install.sh | bash
```

The script clones this repository into `~/.dotfiles` and runs `dotfiles install`. It asks a few yes/no questions (Enter means yes), then:

1. Saves your Git name, email and signing key to `src/.gitconfig.user`
2. Installs [Oh My Zsh](https://ohmyz.sh)
3. Symlinks the files in `src/` into `~`, `src/custom/` into `~/.oh-my-zsh/custom` and each `src/.config/<app>/` into `~/.config/<app>/`
4. Creates `~/Screenshots` and `~/Developer`
5. Applies [macOS defaults](#macos-defaults)
6. Installs Homebrew and everything in the [`Brewfile`](Brewfile)
7. Links the GPG agent config and offers to create a signing key

When there is no terminal to prompt on, the script runs `dotfiles install -y`, which answers yes to everything except the Git user and GPG key questions, since those need your input.

Existing files are never deleted. Any file that would be replaced is renamed to `<name>.<timestamp>.bak` first.

## Commands

The `dotfiles` command is on your `PATH` after install.

| Command | Description |
| --- | --- |
| `dotfiles install [-y]` | Full setup, as described above |
| `dotfiles update [-y]` | Pulls the latest changes and runs the full setup again |
| `dotfiles link` | Pulls the latest changes and re-creates the symlinks |
| `dotfiles bundle` | Installs everything in the `Brewfile` |
| `dotfiles config-user` | Asks for your Git name, email and signing key |
| `dotfiles gpg-key` | Creates a GPG signing key and sets Git up to use it |
| `dotfiles help` | Shows usage |

Updates only fast-forward. If `~/.dotfiles` has commits that aren't on `main`, the update stops so you can sort them out by hand.

## What's included

### Zsh

- `.zshrc` loads Homebrew, Oh My Zsh (`robbyrussell` theme, `git` plugin), the GPG settings and your personal `~/.dotfiles/.zshrc.user.sh`
- [`src/custom/aliases.zsh`](src/custom/aliases.zsh):

| Alias | Action |
| --- | --- |
| `d`, `p`, `dl` | `cd` to Desktop, `~/Developer`, Downloads |
| `o` | `open` |
| `ip` | Print your public IP address |
| `show` / `hide` | Show or hide hidden files in Finder |
| `cleanup` | Delete `.DS_Store` files under the current directory |
| `flush` | Flush the DNS cache |
| `afk` | Turn the display off |
| `reload` | Reload `~/.zshrc` |

### Git

[`src/.gitconfig`](src/.gitconfig) sets patience diffs, highlighting for moved lines, upstream branches set automatically on push, and a global ignore file ([`src/.gitignore_global`](src/.gitignore_global)). Commits are signed only once a signing key is configured.

Some of the aliases:

| Alias | Command |
| --- | --- |
| `st` | `status -s` |
| `c` / `co` | `checkout` / `checkout -b` |
| `cc` | Pick a branch to check out with fzf |
| `dc` / `wd` | Staged diff / word diff |
| `ca` / `rename` | Amend the last commit / amend it without editing the message |
| `undo` | Undo the last commit and keep its changes staged |
| `pf` | `push --force-with-lease` |
| `sync` | Rebase onto the remote's default branch |
| `lg` / `ss` | Browse the log / stashes in tig |
| `cleanup` | Delete local branches that are already merged |
| `snapshot` | Stash the working tree without removing your changes |
| `la` | List all aliases |

### GPG

- [`gpg-agent.conf`](gpg-agent.conf) caches your passphrase for 4 hours
- `dotfiles gpg-key` creates an ed25519 signing key that expires in 2 years, adds it to `.gitconfig.user`, turns on commit signing and, if you're logged in to `gh`, offers to upload the public key to GitHub

### macOS defaults

Set by `macos_defaults` in [`utils.sh`](utils.sh):

- Font smoothing turned off
- Print dialog expanded by default
- Scale effect when minimizing windows
- Dock appears instantly when hidden and animates faster
- Screenshots saved to `~/Screenshots`
- Folders listed first in Finder and on the desktop

### Ghostty

[`src/.config/ghostty/config.ghostty`](src/.config/ghostty/config.ghostty) is linked to `~/.config/ghostty/config.ghostty`, which Ghostty loads on startup. It sets JetBrains Mono as the font.

### Homebrew

The [`Brewfile`](Brewfile) covers command-line tools (gh, fzf, tig, gnupg, node and others), Quick Look extensions, apps and fonts.

## Personal settings

These files are ignored by Git, so personal settings and secrets stay out of the repo:

| File | Purpose |
| --- | --- |
| `~/.dotfiles/.zshrc.user.sh` | Your own shell config, loaded by `.zshrc` |
| `~/.dotfiles/src/.gitconfig.user` | Git name, email and signing key, linked to `~/.gitconfig.user` |

To add a dotfile, put it in `src/`, `src/custom/` for Zsh files or `src/.config/<app>/` for apps that read `~/.config`, then run `dotfiles link`.

## Repository layout

```
bin/dotfiles        The dotfiles command
install.sh          Bootstrap script used by the curl one-liner
utils.sh            Shared helpers: linking, prompts, macOS defaults, GPG setup
src/                Files linked into ~
src/custom/         Files linked into ~/.oh-my-zsh/custom
src/.config/<app>/  Files linked into ~/.config/<app>/ (Ghostty)
*.sh                Snippets sourced by .zshrc (Homebrew, Oh My Zsh, GPG)
Brewfile            Homebrew packages
gpg-agent.conf      Linked to ~/.gnupg/gpg-agent.conf
```

CI runs shellcheck on the scripts and tests `dotfiles link` on macOS for every push and pull request.

## License

This project is licensed under the MIT License.
