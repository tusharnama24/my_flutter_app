#!/bin/bash
set -e

# Clone Flutter only if not already present
if [ ! -d "flutter" ]; then
  echo "Cloning Flutter SDK..."
  git clone https://github.com/flutter/flutter.git -b stable
else
  echo "Flutter SDK already exists, skipping clone."
fi

# Add Flutter to PATH
export PATH="$PWD/flutter/bin:$PATH"

# Verify Flutter
flutter doctor

# Get dependencies
flutter pub get

# Build web
flutter build web
