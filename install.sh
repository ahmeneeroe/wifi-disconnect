#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_NAME="wifi-disconnect"
INSTALL_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/wifi-disconnect"
PLIST_NAME="com.user.wifi-disconnect"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

echo "==> Compiling $BINARY_NAME..."
swiftc -swift-version 5 -O \
    -o "$SCRIPT_DIR/$BINARY_NAME" \
    "$SCRIPT_DIR/$BINARY_NAME.swift" \
    -framework CoreWLAN -framework AppKit

echo "==> Installing binary to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/$BINARY_NAME" "$INSTALL_DIR/$BINARY_NAME"
chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo "==> Setting up config in $CONFIG_DIR..."
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config.txt" ]; then
    cp "$SCRIPT_DIR/config.txt" "$CONFIG_DIR/config.txt"
    echo "    Created config (matches SSIDs containing 'DAAAVID')."
    echo "    Edit $CONFIG_DIR/config.txt to customize."
else
    echo "    Config already exists, keeping it."
fi

echo "==> Installing LaunchAgent..."
mkdir -p "$LAUNCH_AGENTS"

# Stop existing service if running
launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true

# Generate plist with absolute path
sed "s|__BINARY_PATH__|$INSTALL_DIR/$BINARY_NAME|g" \
    "$SCRIPT_DIR/$PLIST_NAME.plist" \
    > "$LAUNCH_AGENTS/$PLIST_NAME.plist"

launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENTS/$PLIST_NAME.plist"

echo ""
echo "Done! wifi-disconnect is now running."
echo "  Config:  $CONFIG_DIR/config.txt"
echo "  Log:     $CONFIG_DIR/disconnect.log"
echo "  Service: launchctl print gui/$(id -u)/$PLIST_NAME"
