#!/bin/bash
set -e

# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable

# Add Flutter to PATH (important)
export PATH="$PATH:$PWD/flutter/bin"

# Verify Flutter
flutter doctor

# Get packages
flutter pub get

# Build web
flutter build web
