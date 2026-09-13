#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP_DIR="$PROJECT_DIR/PrintQuote 3D.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/PrintQuote3D" "$APP_DIR/Contents/MacOS/PrintQuote3D"
cp -R "$BIN_DIR/PrintQuote3D_QuoteData.bundle" "$APP_DIR/Contents/Resources/"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>PrintQuote3D</string>
<key>CFBundleIdentifier</key><string>local.printquote.desktop</string>
<key>CFBundleName</key><string>PrintQuote 3D</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.2.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
cp "$PROJECT_DIR/LICENSE" "$APP_DIR/Contents/Resources/LICENSE"
cp "$PROJECT_DIR/ATTRIBUTION.md" "$APP_DIR/Contents/Resources/ATTRIBUTION.md"
cp -R "$PROJECT_DIR/ThirdParty" "$APP_DIR/Contents/Resources/"
codesign --force --deep --sign - "$APP_DIR"
printf '%s\n' "$APP_DIR"
