#!/bin/bash
set -e

# Build script for GitHub Tray using Xcode

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building GitHub Tray with Xcode ==="

# Generate Xcode project if needed
if [ ! -d "SwiftApp/GitHubTray.xcodeproj" ]; then
    echo "Generating Xcode project..."
    cd SwiftApp
    xcodegen generate
    cd ..
fi

# Build the app
echo "Building..."
cd SwiftApp
xcodebuild -project GitHubTray.xcodeproj \
    -scheme GitHubTray \
    -configuration Release \
    -derivedDataPath build \
    build

echo ""
echo "=== Build Complete ==="
echo ""
echo "The app is at: SwiftApp/build/Build/Products/Release/GitHubTray.app"
echo ""
echo "To run:"
echo "  open SwiftApp/build/Build/Products/Release/GitHubTray.app"
