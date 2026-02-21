#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="OpenCodeCanvas"
APP_BUNDLE="$APP_NAME.app"
DEST_DIR="$HOME/Applications"
OPEN_AFTER_INSTALL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --open)
            OPEN_AFTER_INSTALL=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--open]"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "  OpenCode Canvas Installer"
echo "=========================================="
echo ""

cd "$SCRIPT_DIR"

echo "[1/4] Building with Swift Package Manager..."
swift build -c release 2>&1 | while read -r line; do
    echo "  $line"
done

if [ ! -f ".build/release/$APP_NAME" ]; then
    echo "Error: Build failed - executable not found"
    exit 1
fi

echo ""
echo "[2/4] Creating application bundle..."

# Remove old bundle if exists
rm -rf "$APP_BUNDLE"

# Create bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp ".build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>OpenCodeCanvas</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.opencodecanvas.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OpenCode Canvas</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 OpenCode Canvas. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "[3/4] Installing to $DEST_DIR..."

# Create ~/Applications if it doesn't exist
mkdir -p "$DEST_DIR"

# Remove old version if exists
rm -rf "$DEST_DIR/$APP_BUNDLE"

# Copy to Applications
cp -R "$APP_BUNDLE" "$DEST_DIR/"

echo "[4/4] Cleaning up..."
rm -rf "$APP_BUNDLE"

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "OpenCode Canvas has been installed to:"
echo "  $DEST_DIR/$APP_BUNDLE"
echo ""

if [ "$OPEN_AFTER_INSTALL" = true ]; then
    echo "Launching OpenCode Canvas..."
    open "$DEST_DIR/$APP_BUNDLE"
else
    echo "To launch:"
    echo "  open $DEST_DIR/$APP_BUNDLE"
    echo ""
    echo "Tip: Use --open flag to launch after installation"
fi
