#!/bin/bash

# Build Docker container and package as DMG
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BUILD_DIR="$SCRIPT_DIR/build-docker"
APP_NAME="OllamaDocker"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DMG_NAME="$APP_NAME-1.0.0"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"

echo "Building Docker container and packaging as DMG..."

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build Docker image
echo "Building Docker image..."
cd "$SCRIPT_DIR"
docker build -f docker-dmg/Dockerfile -t ollama-docker:latest .

# Save Docker image
echo "Saving Docker image..."
docker save ollama-docker:latest -o "$BUILD_DIR/ollama-docker.tar"

# Create app bundle structure
echo "Creating app bundle..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy Docker image
cp "$BUILD_DIR/ollama-docker.tar" "$RESOURCES_DIR/"

# Create launcher script
cat > "$MACOS_DIR/$APP_NAME" <<'EOF'
#!/bin/bash

APP_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RESOURCES_DIR="$APP_PATH/../Resources"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    osascript -e 'display dialog "Docker Desktop is not installed. Please install Docker Desktop first." buttons {"OK"} default button "OK"'
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    osascript -e 'display dialog "Docker Desktop is not running. Please start Docker Desktop first." buttons {"OK"} default button "OK"'
    exit 1
fi

# Load Docker image if not already loaded
if ! docker images | grep -q "ollama-docker"; then
    echo "Loading Docker image..."
    docker load -i "$RESOURCES_DIR/ollama-docker.tar"
fi

# Stop existing container if running
docker stop ollama-docker-container 2>/dev/null || true
docker rm ollama-docker-container 2>/dev/null || true

# Run container
echo "Starting Ollama Docker container..."
docker run -d \
    --name ollama-docker-container \
    -p 11434:11434 \
    -p 7860:7860 \
    -v ollama-models:/models \
    ollama-docker:latest

# Wait for container to start
sleep 5

# Open web interface
open http://localhost:7860

osascript -e 'display notification "Ollama Docker container started" with title "OllamaDocker"'
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
    <string>com.ollamadocker.app</string>
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
hdiutil create -volname "Ollama Docker" \
    -srcfolder "$BUILD_DIR" \
    -ov \
    -format UDRW \
    -size 2g \
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
