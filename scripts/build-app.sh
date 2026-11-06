#!/usr/bin/env bash
# Builds TaskCoach.app (a windowed app that also lives in the menu bar) into ./build.
# Pass --install to also copy it into ~/Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN="$(swift build -c release --show-bin-path)/TaskCoach"

APP="build/TaskCoach.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TaskCoach"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp playbook.md "$APP/Contents/Resources/playbook.md"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>local.taskcoach</string>
  <key>CFBundleName</key><string>Task Coach</string>
  <key>CFBundleDisplayName</key><string>Task Coach</string>
  <key>CFBundleExecutable</key><string>TaskCoach</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>NSHumanReadableCopyright</key><string>Your personal task coach</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough for notifications and Keychain on your own Mac.
codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/TaskCoach.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "Installed to ~/Applications/TaskCoach.app"
fi
