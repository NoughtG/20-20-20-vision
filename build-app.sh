#!/bin/bash
set -e

# Build the executable
swift build

# Create .app directory structure
APP_DIR="Farsight.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp .build/arm64-apple-macosx/debug/Farsight "$APP_DIR/Contents/MacOS/Farsight"

# Write Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Farsight</string>
    <key>CFBundleIdentifier</key>
    <string>com.farsight.app</string>
    <key>CFBundleName</key>
    <string>Farsight</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>Farsight uses the camera to detect if you are at your screen to avoid pausing breaks when reading or watching videos. No photos or videos are ever saved or transmitted.</string>
</dict>
</plist>
EOF

echo "✓ Farsight.app built successfully!"
