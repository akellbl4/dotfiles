#!/usr/bin/env bash
DOTFILES_DIR="$HOME/.dotfiles"
MAC=$(if [[ $OSTYPE == darwin* ]]; then echo true; else echo false; fi )
DOTFILES=(
	.zshrc
	.editorconfig
	.gitconfig
)

if [[ -d $DOTFILES_DIR ]]; then
	echo "Updating dotfiles..."
	cd $DOTFILES_DIR
	git pull origin master
	echo "Pulling success"
else
	echo "Installing dotfiles..."
	git clone https://github.com/akellbl4/dotfiles.git $DOTFILES_DIR
	echo "Dotfiles downloaded"

	if [[ $MAC == true && "$2" == "--change-defaults" ]]; then
 		echo "Applying mac defaults"
		source macos_custom_settings.sh
	fi
fi

if [[ $MAC == false ]]; then
	exit 1;
fi

echo "Checking for Homebrew..."
if [[ -n $(brew -v | grep -iE "^homebrew") ]]; then
	echo "Updating homebrew..."
	brew doctor  --quiet
	brew update  --quiet
	brew upgrade  --quiet
	echo "Homebrew updated"
else
	echo "Installing Homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	eval "$(/opt/homebrew/bin/brew shellenv)"
	echo "Homebrew installed"
fi

echo "Installing packages from Homebrew..."
brew bundle --quiet --file=$DOTFILES_DIR/Brewfile



echo "Linking dotfiles..."
for file in ${DOTFILES[@]}; do
	# create symbolic link if not exists
	if [[ -L $HOME/$file ]]; then 
		rm -rf $HOME/$file
	fi

	ln -sv $DOTFILES_DIR/$file $HOME/$file
done
echo
echo "Done."
