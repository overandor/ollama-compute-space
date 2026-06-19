#!/bin/bash

# Build and package OllamaMacOSApp
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="OllamaMacOSApp"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building $APP_NAME..."

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create app bundle structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR/models"

# Build the Swift app
echo "Building Xcode project..."
cd "$SCRIPT_DIR"
xcodebuild -project OllamaMacOSApp.xcodeproj \
    -scheme OllamaMacOSApp \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build

# Copy the built executable
echo "Copying executable..."
cp "$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app/Contents/MacOS/$APP_NAME" "$MACOS_DIR/"

# Copy Ollama binary
echo "Copying Ollama binary..."
cp "$SCRIPT_DIR/OllamaMacOSApp/Resources/ollama" "$RESOURCES_DIR/"

# Copy daemon plist
echo "Copying daemon plist..."
mkdir -p "$RESOURCES_DIR"
cp "$SCRIPT_DIR/OllamaMacOSApp/com.ollamamacos.daemon.plist" "$RESOURCES_DIR/"

# Compile daemon
echo "Compiling daemon..."
swiftc -o "$MACOS_DIR/ollama-daemon" "$SCRIPT_DIR/ollama-daemon.swift"

# Make binaries executable
chmod +x "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/ollama-daemon"
chmod +x "$RESOURCES_DIR/ollama"

# Create Info.plist
echo "Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.ollamamacos.app</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✓ App bundle created at $APP_BUNDLE"
echo ""
echo "To install:"
echo "  cp -R $APP_BUNDLE /Applications/"
echo ""
echo "To test:"
echo "  open $APP_BUNDLE"
