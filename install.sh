#!/usr/bin/env sh
dir="$HOME/.dotfiles"

if [[ -d $dir ]]; then
	echo "Updating dotfiles..."
	cd $dir
	git pull origin master
	echo "Pulling success"
else
	echo "Installing dotfiles..."
	git clone https://github.com/akellbl4/dotfiles.git $dir
	echo "Dotfiles downloaded"

	if [[ "$1" == "--macos" && "$2" == "--change-defaults" ]]; then
 		echo "Applying mac defaults"
		source macos_custom_settings.sh
	fi
fi

if [[ "$1" == "--macos" ]]; then
	if [[ -n $(brew -v | grep -iE "^homebrew") ]]; then
		echo "Run brew updates"
		brew doctor
		brew update
		brew upgrade
	else
		echo "Installing Homebrew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		echo "Homebrew installed"
	fi

	echo "Installing packages from brew"
	brew bundle
fi

declare -a files=(
	.editorconfig
	.gitconfig
)

echo "Linking dotfiles..."
for i in ${files[@]}; do
	# create symbolic link if not exists
	[[ -L $HOME/$i ]] || ln -sv $dir/$i $HOME/$i
done
echo
echo "Done."
