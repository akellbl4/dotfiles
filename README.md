# ⚙️ Dotfiles

My development environment: Zsh with Oh My Zsh, Git and GPG configuration, Podman, AI coding tools, and on macOS also Homebrew packages and system defaults, managed by a single `dotfiles` command.

## Requirements

- macOS on Apple Silicon, with Git (`xcode-select --install` if it is missing), or
- Linux: Debian or Ubuntu, Fedora (including Asahi), or Bazzite/Silverblue. The installer adds zsh, git and curl if they're missing, using `sudo`.

## Install

```sh
curl -L https://github.com/akellbl4/dotfiles/raw/main/install.sh | bash
```

The script clones this repository into `~/.dotfiles` (or updates it if it is already there) and runs `dotfiles install`, so the same command also updates an existing setup. It asks a few questions up front, then:

1. On Linux, installs zsh, git, curl and unzip if missing and offers to make zsh your default shell. On Bazzite and Silverblue, missing packages are added with `rpm-ostree`, so reboot and run the installer again.
2. Saves your Git name and email to `src/.gitconfig.user`
3. Installs [Oh My Zsh](https://ohmyz.sh)
4. Symlinks the files in `src/` into `~`, `src/custom/` into `~/.oh-my-zsh/custom`, each `src/.config/<app>/` into `~/.config/<app>/`, and each [agent skill](#agent-skills) in `skills/` into `~/.agents/skills/` and `~/.claude/skills/`
5. On macOS, creates `~/Screenshots` and `~/Developer` if they're missing and gives Screenshots a camera icon, applies [macOS defaults](#macos-defaults), and installs Homebrew and everything in the [`Brewfile`](Brewfile)
6. Installs the latest [Node LTS, pnpm and Bun](#node-pnpm-and-bun), and moves to a newer LTS on later runs
7. Installs the [AI coding tools](#ai-coding-tools) on Linux (on macOS they come from the `Brewfile`)
8. Sets up [Podman](#podman) and makes the `docker` command use it
9. Links the GPG agent config and sets up a [commit signing key](#gpg)

Running it again is safe. It only asks about folders that are missing or lack their icon, macOS defaults that differ from your settings, and the default shell while it isn't zsh. It shows your current Git user and signing key and only changes them if you choose to. Press Enter to accept the default shown in capitals (`Y/n` or `y/N`), or to keep the current value shown in brackets.

When there is no terminal to prompt on, the script runs `dotfiles install -y`, which answers yes to everything except the Git user and GPG key questions, since those need your input.

Existing files are never deleted. Any file that would be replaced is renamed to `<name>.<timestamp>.bak` first.

## Commands

The `dotfiles` command is on your `PATH` after install.

| Command | Description |
| --- | --- |
| `dotfiles install [-y]` | Full setup, as described above |
| `dotfiles update [-y]` | Pulls the latest changes and runs the full setup again through the new `install.sh`, the same as the curl command |
| `dotfiles link` | Pulls the latest changes and re-creates the symlinks |
| `dotfiles bundle` | Installs everything in the `Brewfile` |
| `dotfiles config-user` | Edits your Git name and email |
| `dotfiles ai-tools` | Installs Claude Code and Codex, plus Cursor and T3 Code on machines with a desktop |
| `dotfiles t3-autostart` | Installs the T3 Code server as a background service so it starts at login (open T3 Code once first) |
| `dotfiles node` | Installs the latest Node LTS, pnpm and Bun |
| `dotfiles podman` | Installs Podman and makes the `docker` command use it |
| `dotfiles macos-vm [name]` | Installs Tart and creates a macOS virtual machine (Apple Silicon only) |
| `dotfiles gh` | Installs the GitHub CLI |
| `dotfiles gpg-key` | Picks an existing GPG key or creates a new one for signing commits |
| `dotfiles help` | Shows usage |

`dotfiles` is also a small zsh function ([`src/custom/functions.zsh`](src/custom/functions.zsh)): after `install`, `update` and `link` it reloads `~/.zshrc` in your current shell, so changes apply right away without opening a new one.

Updates only fast-forward. If `~/.dotfiles` has commits that aren't on `main`, the update stops so you can sort them out by hand.

## What's included

### Zsh

- `.zshrc` loads Homebrew, Oh My Zsh (`git` plugin), the GPG settings and your personal `~/.dotfiles/.zshrc.user.sh`
- A custom two-line prompt, [`src/custom/dotfiles.zsh-theme`](src/custom/dotfiles.zsh-theme):

```
14:02:07 ~/Developer/dotfiles ⌥ main +1 ~2 ?3 ↑1 · 1.4s · exit 1
$
```

  It shows the time, the directory, the Git branch, and counts of staged (`+`), modified (`~`), untracked (`?`) and conflicted (`!`) files and of commits ahead (`↑`) and behind (`↓`). After every command it shows how long it took (`85ms`, `1.4s`, `1m 5s`) and its exit code if it failed. `$` turns red after a failed command (`#` when running as root), and `user@host` appears over SSH. It uses only your terminal's colors and characters that JetBrains Mono has, so it needs no extra tools or Nerd Font.
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

### GitHub CLI

`dotfiles gh` installs [gh](https://cli.github.com). On macOS it comes from the Brewfile. On Linux, `install` and `update` offer it while it's missing: the latest [release](https://github.com/cli/cli/releases) is checked against its published checksum and installed into `~/.local/share/gh-cli`, with `gh` linked in `~/.local/bin`, so no `sudo` is needed. Logging in is left to you (`gh auth login`).

### GPG

- [`gpg-agent.conf`](gpg-agent.conf) caches your passphrase for 4 hours
- `dotfiles gpg-key` (also run by `install` and `update`) shows the key Git currently signs with and asks whether to change it. It then lists the signing keys in your keyring so you can:
  - **link an existing key** by its number, or
  - **create a new key** (ed25519, expires in 2 years) using your Git name and email

  The chosen key is saved to `.gitconfig.user` and commit signing is turned on. If you're logged in to `gh` and the key isn't on your GitHub account yet, it offers to upload it. Otherwise it prints the public key to add by hand.

### Node, pnpm and Bun

`dotfiles node` (also run by every `install` and `update`) sets up:

- **Node** with [fnm](https://github.com/Schniz/fnm): the latest LTS is installed and set as the default. When a newer LTS comes out, the next `dotfiles update` installs it and makes it the default. In a project with a `.nvmrc` or `.node-version` file, `cd` switches to that version.
- **pnpm** through Corepack. Node 25 and later no longer include Corepack, so it's installed from npm when missing, then enabled, and the latest pnpm is installed with it.
- **Bun**

fnm and Bun come from Homebrew on macOS and from their official installers on Linux. fnm goes into `~/.local/bin` and Bun into `~/.bun`. [`node.sh`](node.sh) puts them on your `PATH`, so neither installer edits `~/.zshrc`. If Node was installed with Homebrew before, `brew uninstall node` removes the old copy, since fnm's Node comes first on `PATH` anyway.

### AI coding tools

`dotfiles ai-tools` installs whichever of these are missing. `install` and `update` offer it on Linux, and on macOS the tools come from the `Brewfile`.

| Tool | macOS | Debian, Ubuntu | Fedora, Asahi | Bazzite, Silverblue |
| --- | --- | --- | --- | --- |
| Claude Code (`claude`) | `claude-code` cask | [Official installer](https://claude.ai/install.sh) | Official installer | Official installer |
| Codex (`codex`) | `codex` cask | [Official installer](https://chatgpt.com/codex/install.sh) | Official installer | Official installer |
| Cursor (`cursor`) | `cursor` cask | `.deb` | `.rpm` | AppImage |
| T3 Code (`t3code`) | `t3-code` cask | `.deb` | AppImage | AppImage |

- Cursor and T3 Code are desktop apps, so on Linux they're only installed when the machine has a desktop.
- The official installers and AppImages go into `~/.local/bin`, and AppImages also get an app menu entry.
- Both x64 and arm64 are supported.

### Agent skills

`skills/` holds the skills for every AI coding tool, adapted from [tstack](https://github.com/t3dotgg/tstack) (MIT, [`skills/LICENSE`](skills/LICENSE)). Each skill folder is symlinked into two places, so edits here apply right away:

| Folder | Read by |
| --- | --- |
| `~/.agents/skills/` | Codex, Cursor, Gemini CLI, GitHub Copilot, OpenCode (the shared location) |
| `~/.claude/skills/` | Claude Code (also read by Cursor and OpenCode) |

Tool-specific folders such as `~/.codex/skills/` or `~/.cursor/skills/` are left alone, because tools that read several of them would load each skill twice. A real folder with the same name as a skill is moved to `~/.agents/skills.bak/` or `~/.claude/skills.bak/` first.

| Skill | Say | What it does |
| --- | --- | --- |
| `full-send` | "full send" | Takes a change all the way to a merged PR unattended: proves it, reviews it, files it, babysits it, merges it |
| `full-push` | "full push" | Same as `full-send`, but stops when the PR is ready for you to merge |
| `council` | "council" | Gets review from three models from different providers and loops until they agree |
| `review-loop` | "review loop" | Reviews a change with GPT Sol in a loop until both agents agree |
| `file-pr` | "file a PR" | Files a short PR that leads with the problem, not an inventory of changes |
| `takeover` | "take over" | Finishes someone else's PR, branch or agent thread and keeps their credit |
| `babysit-pr` | "babysit" | Watches a PR through CI and review bots and fixes the real findings |
| `modernize` | "modernize" | Rebases an old PR and decides if it should still exist |
| `pr-comments` | (automatic) | Formats comments posted on your behalf: review comments (findings with a severity) and answers (fixed / won't fix / question) |

Changes from upstream: `full-stop` is renamed `full-push`, and `leaving-pr-comments` is renamed `pr-comments`, with separate templates for review comments and answers. `babysit-pr` needs `python3` and an authenticated `gh`.

### Podman

`dotfiles podman` (also offered by `install` and `update` until it's set up) works on macOS, Debian/Ubuntu and Fedora, including Asahi and Bazzite:

| System | How Podman is installed |
| --- | --- |
| macOS | Homebrew, then the Podman virtual machine is created and started |
| Debian, Ubuntu | `apt-get` |
| Fedora, Fedora Asahi Remix | `dnf` |
| Bazzite, Silverblue | Already included; if missing, added with `rpm-ostree` (reboot, then run `dotfiles podman` again) |

It then links `~/.local/bin/docker` to `podman`, so `docker` commands and scripts run Podman. If a real Docker is already installed, it is left alone and nothing is linked.

### macOS virtual machine

`dotfiles macos-vm [name]` is not part of `install`. It installs [Tart](https://tart.run) from its latest [GitHub release](https://github.com/openai/tart/releases) into `~/.local/share/tart`, with a `tart` launcher in `~/.local/bin`, after checking the download against its published checksum. Tart runs VMs on Apple's built-in Virtualization framework. The command then clones a prebuilt [Cirrus Labs image](https://github.com/cirruslabs/macos-image-templates) into a VM called `macos` (or the name you give). It picks the newest macOS the host can run, since a guest can't be newer than the host. The image is a download of about 25 GB. If the VM already exists, it is left alone.

```sh
tart run macos                  # add --no-graphics to run headless
ssh admin@$(tart ip macos)      # password: admin
```

macOS allows at most two macOS VMs running at once on one Mac.

### macOS defaults

Listed in `macos_defaults_list` in [`utils.sh`](utils.sh). `install` and `update` compare them with your current settings and only offer to apply them when something differs, naming the settings that would change. Only the changed settings are written, and only the affected apps (Dock, Finder, SystemUIServer) are restarted.

- Font smoothing turned off
- Print dialog expanded by default
- Scale effect when minimizing windows
- Dock appears instantly when hidden and animates faster
- No suggested and recent apps in the Dock
- Screenshots saved to `~/Screenshots`
- Folders listed first in Finder and on the desktop
- Wi-Fi and Spotlight hidden from the menu bar
- Spotlight's ⌘Space shortcut turned off, so it's free for Raycast. Raycast keeps its hotkey in its own settings, so set it once in Raycast → Settings → General → Raycast Hotkey (or during Raycast's onboarding on a new Mac).

### Ghostty

[`src/.config/ghostty/config.ghostty`](src/.config/ghostty/config.ghostty) is linked to `~/.config/ghostty/config.ghostty`, which Ghostty loads on startup. It sets JetBrains Mono as the font.

### Homebrew

The [`Brewfile`](Brewfile) covers command-line tools (gh, fzf, tig, gnupg, fnm, bun, podman and others), Quick Look extensions, apps, AI coding tools and fonts.

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
skills/<name>/      Agent skills linked into ~/.agents/skills/ and ~/.claude/skills/
*.sh                Snippets sourced by .zshrc (Homebrew, Oh My Zsh, Node, GPG)
Brewfile            Homebrew packages
gpg-agent.conf      Linked to ~/.gnupg/gpg-agent.conf
```

CI runs shellcheck on the scripts and tests `dotfiles link` on macOS for every push and pull request.

## License

This project is licensed under the MIT License.
