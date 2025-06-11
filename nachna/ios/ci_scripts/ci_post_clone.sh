#!/bin/sh

set -e

# Go to repo root
cd $CI_PRIMARY_REPOSITORY_PATH

# Install Flutter using git.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for iOS
flutter precache --ios

# Navigate to your project subdirectory
cd nachna/

# Install Flutter dependencies
flutter pub get

# Install CocoaPods using Homebrew
HOMEBREW_NO_AUTO_UPDATE=1
brew install cocoapods

# Install CocoaPods dependencies
cd ios && pod install

exit 0