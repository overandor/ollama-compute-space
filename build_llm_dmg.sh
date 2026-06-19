#!/bin/bash

# Build LLM DMG app with browser interface
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$SCRIPT_DIR/build-llm"
APP_NAME="OllamaLLM"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_NAME="$APP_NAME-1.0.0"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"

echo "Building LLM DMG app with browser interface..."

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create app bundle structure
echo "Creating app bundle..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy Ollama binary
echo "Copying Ollama binary..."
cp "$SCRIPT_DIR/OllamaMacOSApp/Resources/ollama" "$RESOURCES_DIR/"

# Copy Flask app
echo "Copying Flask app..."
cp "$SCRIPT_DIR/llm-dmg/app.py" "$RESOURCES_DIR/"

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install flask flask-cors --target "$RESOURCES_DIR/" --system 2>/dev/null || true

# Create launcher script
cat > "$MACOS_DIR/$APP_NAME" <<'EOF'
#!/bin/bash

APP_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RESOURCES_DIR="$APP_PATH/../Resources"

# Set Python path
export PYTHONPATH="$RESOURCES_DIR:$PYTHONPATH"

# Start Flask app in background
cd "$RESOURCES_DIR"
python3 app.py &

# Wait for server to start
sleep 3

# Open browser
open http://localhost:7860

# Keep script running
wait
EOF

chmod +x "$MACOS_DIR/$APP_NAME"

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
    <string>com.ollamallm.app</string>
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

# Create DMG
echo "Creating DMG..."
TEMP_DMG="$BUILD_DIR/temp.dmg"
hdiutil create -volname "Ollama LLM" \
    -srcfolder "$BUILD_DIR" \
    -ov \
    -format UDRW \
    -size 500m \
    "$TEMP_DMG"

MOUNT_DIR="/tmp/$APP_NAME-mount"
mkdir -p "$MOUNT_DIR"
hdiutil attach "$TEMP_DMG" -mountpoint "$MOUNT_DIR" -readonly

ln -s /Applications "$MOUNT_DIR/Applications"
cp -R "$APP_BUNDLE" "$MOUNT_DIR/"

hdiutil detach "$MOUNT_DIR"

hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

rm -f "$TEMP_DMG"
rm -rf "$MOUNT_DIR"

echo "✓ DMG created at $DMG_PATH"
echo ""
echo "To test:"
echo "  open $DMG_PATH"
echo ""
echo "DMG size:"
du -h "$DMG_PATH"
