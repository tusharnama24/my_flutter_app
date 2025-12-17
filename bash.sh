#!/bin/bash
set -e

# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable

# Add Flutter to PATH
export PATH="$PWD/flutter/bin:$PATH"

# Check Flutter
flutter doctor

# Get dependencies
flutter pub get

# Build web
flutter build web
