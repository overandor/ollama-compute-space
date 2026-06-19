#!/bin/bash

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="OllamaMacOSApp"
APP_PATH="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="OllamaComputeSpace"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"

echo "Building $APP_NAME for release..."

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build the app
xcodebuild -project "$PROJECT_DIR/OllamaMacOSApp.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive

# Export the app
xcodebuild -exportArchive \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    -exportPath "$BUILD_DIR" \
    -exportOptionsPlist "$PROJECT_DIR/scripts/ExportOptions.plist"

echo "Build complete. App located at: $APP_PATH"

# Create DMG
echo "Creating DMG..."
if [ -f "$DMG_PATH" ]; then
    rm "$DMG_PATH"
fi

# Create a temporary directory for DMG contents
DMG_TEMP_DIR="$BUILD_DIR/dmg_temp"
rm -rf "$DMG_TEMP_DIR"
mkdir -p "$DMG_TEMP_DIR"

# Copy app to DMG temp directory
cp -R "$APP_PATH" "$DMG_TEMP_DIR/"

# Create Applications symlink
ln -s /Applications "$DMG_TEMP_DIR/Applications"

# Create DMG
hdiutil create -volname "$DMG_NAME" \
    -srcfolder "$DMG_TEMP_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Clean up
rm -rf "$DMG_TEMP_DIR"

echo "DMG created at: $DMG_PATH"
