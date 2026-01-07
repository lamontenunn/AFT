#!/bin/sh
set -e

cd $CI_PRIMARY_REPOSITORY_PATH

# Install Flutter using git.
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Install Flutter artifacts for iOS.
flutter precache --ios

# Install Flutter dependencies (this is what generates ios/Flutter/Generated.xcconfig).
flutter pub get

# Install CocoaPods.
HOMEBREW_NO_AUTO_UPDATE=1
brew install cocoapods

# Install Pods (this generates the Pods-Runner xcfilelist files).
cd ios && pod install

exit 0