#!/bin/bash
set -euo pipefail

PLIST_NAME="com.user.wifi-disconnect"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
INSTALL_DIR="$HOME/.local/bin"

echo "==> Stopping service..."
launchctl bootout "gui/$(id -u)/$PLIST_NAME" 2>/dev/null || true

echo "==> Removing LaunchAgent plist..."
rm -f "$LAUNCH_AGENTS/$PLIST_NAME.plist"

echo "==> Removing binary..."
rm -f "$INSTALL_DIR/wifi-disconnect"

echo ""
echo "Done! Service stopped and files removed."
echo "Config left in place at ~/.config/wifi-disconnect/"
echo "To remove config too: rm -rf ~/.config/wifi-disconnect"
