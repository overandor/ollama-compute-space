#!/bin/bash

# Build DMG installer for OllamaMacOSApp
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="OllamaMacOSApp"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-1.0.0"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
VOLUME_NAME="Ollama MacOS App"

echo "Building DMG installer..."

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    echo "Please run ./build_app.sh first"
    exit 1
fi

# Create temporary DMG
echo "Creating temporary DMG..."
TEMP_DMG="$BUILD_DIR/temp.dmg"
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$BUILD_DIR" \
    -ov \
    -format UDRW \
    -size 500m \
    "$TEMP_DMG"

# Mount the DMG
echo "Mounting DMG..."
MOUNT_DIR="/tmp/$APP_NAME-mount"
mkdir -p "$MOUNT_DIR"
hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_DIR" -readonly

# Create symbolic link to Applications
echo "Creating Applications link..."
ln -s /Applications "$MOUNT_DIR/Applications"

# Copy app bundle to DMG
echo "Copying app bundle..."
cp -R "$APP_BUNDLE" "$MOUNT_DIR/"

# Unmount
echo "Unmounting..."
hdiutil detach "$MOUNT_DIR"

# Compress to final DMG
echo "Compressing to final DMG..."
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

# Clean up
rm -f "$TEMP_DMG"
rm -rf "$MOUNT_DIR"

echo "✓ DMG created at $DMG_PATH"
echo ""
echo "To test:"
echo "  open $DMG_PATH"
echo ""
echo "DMG size:"
du -h "$DMG_PATH"
