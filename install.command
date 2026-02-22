#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="OpenCanvas"
APP_BUNDLE="$APP_NAME.app"
DEST_DIR="$HOME/Applications"
OPEN_AFTER_INSTALL=false
ICON_SOURCE="$SCRIPT_DIR/assets/icon.png"
ICONSET_DIR="$SCRIPT_DIR/AppIcon.iconset"
ICNS_FILE="$APP_BUNDLE/Contents/Resources/AppIcon.icns"

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
echo "  OpenCanvas Installer"
echo "=========================================="
echo ""

cd "$SCRIPT_DIR"

echo "[1/6] Cleaning previous build artifacts..."
swift package clean 2>&1 | while read -r line; do
    echo "  $line"
done

echo "[2/6] Building with Swift Package Manager..."
swift build -c release 2>&1 | while read -r line; do
    echo "  $line"
done

if [ ! -f ".build/release/$APP_NAME" ]; then
    echo "Error: Build failed - executable not found"
    exit 1
fi

echo ""
echo "[3/6] Creating application bundle..."

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
    <string>OpenCanvas</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.opencanvas.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OpenCanvas</string>
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
    <string>Copyright © 2026 OpenCanvas. All rights reserved.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "[4/6] Generating application icon..."

if [ ! -f "$ICON_SOURCE" ]; then
    echo "Error: Icon source not found at $ICON_SOURCE"
    exit 1
fi

if ! command -v iconutil >/dev/null 2>&1; then
    echo "Error: iconutil is required to convert the icon; please install Xcode command line tools."
    exit 1
fi

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

ICON_SPECS=(
    "16 icon_16x16.png 1"
    "16 icon_16x16@2x.png 2"
    "32 icon_32x32.png 1"
    "32 icon_32x32@2x.png 2"
    "64 icon_64x64.png 1"
    "64 icon_64x64@2x.png 2"
    "128 icon_128x128.png 1"
    "128 icon_128x128@2x.png 2"
    "256 icon_256x256.png 1"
    "256 icon_256x256@2x.png 2"
    "512 icon_512x512.png 1"
    "512 icon_512x512@2x.png 2"
    "1024 icon_1024x1024.png 1"
)

for spec in "${ICON_SPECS[@]}"; do
    read -r size filename scale <<< "$spec"
    scale=${scale:-1}
    pixel_size=$((size * scale))
    sips -z "$pixel_size" "$pixel_size" "$ICON_SOURCE" --out "$ICONSET_DIR/$filename" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$ICNS_FILE"
rm -rf "$ICONSET_DIR"

echo "[5/6] Installing to $DEST_DIR..."


# Create ~/Applications if it doesn't exist
mkdir -p "$DEST_DIR"

# Remove old version if exists
rm -rf "$DEST_DIR/$APP_BUNDLE"

# Copy to Applications
cp -R "$APP_BUNDLE" "$DEST_DIR/"

echo "[6/6] Cleaning up..."
rm -rf "$APP_BUNDLE"

echo ""
echo "=========================================="
echo "  Installation Complete!"
echo "=========================================="
echo ""
echo "OpenCanvas has been installed to:"
echo "  $DEST_DIR/$APP_BUNDLE"
echo ""

if [ "$OPEN_AFTER_INSTALL" = true ]; then
    echo "Launching OpenCanvas..."
    open "$DEST_DIR/$APP_BUNDLE"
else
    echo "To launch:"
    echo "  open $DEST_DIR/$APP_BUNDLE"
    echo ""
    echo "Tip: Use --open flag to launch after installation"
fi
