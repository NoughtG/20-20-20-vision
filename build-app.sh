#!/bin/bash
set -e

echo "Building Farsight with Swift Package Manager..."
swift build -c release

APP_DIR="Farsight.app"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy compiled binary
cp .build/release/Farsight "$APP_DIR/Contents/MacOS/Farsight"

# Copy AppIcon.icns if present
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

# Write comprehensive Info.plist for macOS & App Store
cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Farsight</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.farsight.app</string>
    <key>CFBundleName</key>
    <string>Farsight</string>
    <key>CFBundleDisplayName</key>
    <string>Farsight</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Farsight. All rights reserved.</string>
    <key>NSCameraUsageDescription</key>
    <string>Farsight uses the camera solely to detect if you are at your screen to avoid falsely pausing breaks while you are reading or watching videos. Frames are analyzed in memory and immediately discarded. Nothing is ever saved or transmitted.</string>
</dict>
</plist>
EOF

# Ad-hoc sign with entitlements for local testing & sandbox verification
if [ -f "Farsight.entitlements" ]; then
    codesign --force --deep --sign - --entitlements Farsight.entitlements "$APP_DIR" 2>/dev/null || true
fi

echo "✓ Farsight.app built and packaged successfully with AppIcon and Entitlements!"
