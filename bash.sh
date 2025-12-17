#!/bin/bash
set -e

echo "Removing old Flutter SDK if exists..."
rm -rf flutter

echo "Cloning Flutter SDK..."
git clone https://github.com/flutter/flutter.git -b stable

export PATH="$PWD/flutter/bin:$PATH"
