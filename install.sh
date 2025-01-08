#!/usr/bin/env sh
dir="$HOME/.dotfiles"

if [[ -d $dir ]]; then
	echo "Update starts..."
	cd $dir
	git pull origin master
	echo "Pulling success"
else
	echo "Install starts..."
	git clone https://github.com/akellbl4/dotfiles.git $dir
	echo "Pulling success"
	echo "Adding source file..."

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
		echo "Brew not found."
		echo "Installing Homebrew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
		echo "Brew installed"
	fi

	echo "Installing brew bundle..."
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
