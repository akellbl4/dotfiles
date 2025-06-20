# ⚙️ Dotfiles

A collection of configuration files and scripts to set up and manage your development environment efficiently.

## Install

```sh
curl -L https://github.com/akellbl4/dotfiles/raw/main/install.sh | bash
```

## Features

- 🛠️ **Zsh Configuration**: Includes a pre-configured `.zshrc` file with support for Oh My Zsh, custom plugins, and themes.
- 🍺 **Homebrew Integration**: Automatically installs and updates Homebrew packages using a `Brewfile`.
- 💻 **macOS Defaults**: Applies macOS system preferences for a better developer experience.
- ⚡ **Custom Commands**: Provides the `dotfiles` command to manage installation, updates, and linking of dotfiles.
- 🧩 **Modular Setup**: Keeps configurations lightweight and modular for easy customization.

## Usage

After installation, the `dotfiles` command will be available globally. Use it to manage your environment.
Run `dotfiles [command]` to execute a specific command.

### Commands

- **install**: Installs the dotfiles, sets up Oh My Zsh, Homebrew, and applies macOS defaults.
- **update**: Updates the dotfiles and re-applies configurations, ensuring everything is up-to-date.
- **link**: Links the dotfiles to your home directory, ensuring all configurations are properly applied.
- **bundle**: Installs all Homebrew packages listed in the Brewfile.
- **config-user**: Prompts for Git user settings (full name, email, signing key) and saves them to `src/.gitconfig.user`.
- **help**: Displays usage information for the dotfiles command.

## Customization

Feel free to modify the dotfiles to suit your needs. All configurations are stored in the `$HOME/.dotfiles` directory.

## License

This project is licensed under the MIT License.
