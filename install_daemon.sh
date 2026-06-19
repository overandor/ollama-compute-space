#!/bin/bash

# Install Ollama daemon as launchd service
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PLIST_FILE="$SCRIPT_DIR/OllamaMacOSApp/com.ollamamacos.daemon.plist"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"

echo "Installing Ollama daemon service..."

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$LAUNCH_AGENTS_DIR"

# Copy plist file
cp "$PLIST_FILE" "$LAUNCH_AGENTS_DIR/"

# Load the service
launchctl unload "$LAUNCH_AGENTS_DIR/com.ollamamacos.daemon.plist" 2>/dev/null || true
launchctl load "$LAUNCH_AGENTS_DIR/com.ollamamacos.daemon.plist"

# Start the service
launchctl start com.ollamamacos.daemon

echo "✓ Ollama daemon installed and started"
echo "  Plist location: $LAUNCH_AGENTS_DIR/com.ollamamacos.daemon.plist"
echo "  Logs: /tmp/ollama-daemon.log"
echo ""
echo "To stop the daemon:"
echo "  launchctl stop com.ollamamacos.daemon"
echo ""
echo "To uninstall:"
echo "  launchctl unload $LAUNCH_AGENTS_DIR/com.ollamamacos.daemon.plist"
echo "  rm $LAUNCH_AGENTS_DIR/com.ollamamacos.daemon.plist"
