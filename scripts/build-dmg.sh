#!/usr/bin/env bash
set -euo pipefail

# Build a polished Dispatch.dmg installer
#
# Prerequisites:
#   brew install create-dmg
#   cd packages/dispatch_app && flutter build macos

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_SOURCE="$PROJECT_ROOT/packages/dispatch_app/build/macos/Build/Products/Release/dispatch_app.app"
BACKGROUND="$PROJECT_ROOT/assets/dmg/background.png"
DMG_OUTPUT="$PROJECT_ROOT/Dispatch.dmg"
STAGING_DIR="$PROJECT_ROOT/build/dmg-staging"

# Validate prerequisites
if ! command -v create-dmg &>/dev/null; then
    echo "Error: create-dmg not found. Install with: brew install create-dmg"
    exit 1
fi

if [ ! -d "$APP_SOURCE" ]; then
    echo "Error: App not found at $APP_SOURCE"
    echo "Build it first: cd packages/dispatch_app && flutter build macos"
    exit 1
fi

if [ ! -f "$BACKGROUND" ]; then
    echo "Error: Background image not found at $BACKGROUND"
    echo "Generate it: python3 scripts/generate-dmg-background.py"
    exit 1
fi

# Prepare staging directory with renamed app
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_SOURCE" "$STAGING_DIR/Dispatch.app"

# Remove old DMG if it exists (create-dmg won't overwrite)
rm -f "$DMG_OUTPUT"

# Build the DMG
create-dmg \
    --volname "Dispatch" \
    --background "$BACKGROUND" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 128 \
    --text-size 14 \
    --icon "Dispatch.app" 150 190 \
    --app-drop-link 450 190 \
    --no-internet-enable \
    "$DMG_OUTPUT" \
    "$STAGING_DIR"

# Clean up staging
rm -rf "$STAGING_DIR"

echo ""
echo "DMG created: $DMG_OUTPUT"
