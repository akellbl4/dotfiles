#!/usr/bin/env bash

# Change default settings of printing
# If your printer support two sides print then it's off by default while you printing
defaults write -g PMPrintingExpandedStateForPrint -bool TRUE;

# Simple window scale effect
defaults write com.apple.dock mineffect -string scale;

# Kill Dashboard permanently
defaults write com.apple.dashboard mcx-disabled -boolean TRUE;

# Zero timeout to show hidden Dock
defaults write com.apple.dock autohide-delay -float 0;

# Fast Dock showing animation (300ms)
defaults write com.apple.dock autohide-time-modifier -float 0.3;

# Off shadows for a window screenshots
defaults write com.apple.screencapture disable-shadow -bool TRUE;

# Set default folder for screenshots
mkdir ~/Screenshots;
defaults write com.apple.screencapture location ~/Screenshots;

# Disable Google Chrome autoupdate
defaults write com.google.Keystone.Agent checkInterval 0

# Restart services
killall Dock;
killall SystemUIServer;
