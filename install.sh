#!/usr/bin/env bash
dir="$HOME/.dotfiles"

source $dir/includes/colors.sh

if [[ -d $dir ]]; then
	echo "Update starts..."
	cd $dir
	git pull origin master
	echo "${COLOR_GREEN}Pulling success${COLOR_RESET}"
else
	echo "Install starts..."
	git clone https://github.com/akellbl4/dotfiles.git $dir
	echo "${COLOR_GREEN}Pulling success${COLOR_RESET}"
	echo "Adding source file..."
	grep -q "\.dotfiles/\.bashrc" $HOME/.bashrc || echo "source ~/.dotfiles/.bashrc" >> $HOME/.bashrc

	if [[ "$1" == "--macos" && "$2" == "--change-defaults" ]]; then
		source macos_custom_settings.sh
	fi
fi

if [[ "$1" == "--macos" ]]; then
	echo "Check Homebrew installation..."
	if [[ -n $(brew -v | grep -iE "^homebrew") ]]; then
		brew doctor
		brew update
		brew upgrade
	else
		echo "${COLOR_YELLOW}Brew not found.${COLOR_RESET}"
		echo "Installing Homebrew..."
		/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
		echo "${COLOR_GREEN}Brew installed${COLOR_RESET}"
	fi

	echo "Installing brew bundle..."
	brew bundle

	vscodeSettingsFile="$HOME/Library/Application Support/Code/User/settings.json"

	if [[ -f $vscodeSettingsFile && ! -L $vscodeSettingsFile ]]; then
		echo "${COLOR_YELLOW}You already have user settings for Visual Studio Code${COLOR_RESET}"
		echo "If you need install or reinstall settings run:"
		echo
		echo "    ${COLOR_BRIGHT}ln -svf $dir/vscode/settings.json $HOME/Library/Application\ Support/Code/User/settings.json${COLOR_RESET}"
	else
		if [[ -L $vscodeSettingsFile ]]; then
			echo
			echo "Visual Studio Code settings already linked"
			echo
		else
			echo "Linking Visual Studio Code settings..."
			ln -sv "$dir/vscode/settings.json" "$vscodeSettingsFile"
			echo "${COLOR_GREEN}Linked${COLOR_RESET}"
		fi
	fi
fi

declare -a files=(
	.bash_profile
	.editorconfig
	.gitconfig
	.gitignore
	.inputrc
	.huslogin
)

echo "Linking dotfiles..."
for i in ${files[@]}; do
	# create symbolic link if not exists
	[[ -L $HOME/$i ]] || ln -sv $dir/$i $HOME/$i
done
echo
echo "${COLOR_BRIGHT}${COLOR_GREEN}Done.${COLOR_RESET}"
