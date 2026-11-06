#!/usr/bin/env bash
# Builds TaskCoach.app (a windowed app that also lives in the menu bar) into ./build.
#
#   scripts/build-app.sh [--install] [--universal] [--zip]
#
#   --install    also copy it into ~/Applications
#   --universal  one app for Apple silicon and Intel (needs full Xcode, as on the release runner)
#   --zip        also write build/TaskCoach.zip and build/TaskCoach.zip.sha256 for a release
#
# SIGN_IDENTITY picks the signing identity: "Task Coach Self-Signed" for releases, ad-hoc ("-") otherwise.
set -euo pipefail
cd "$(dirname "$0")/.."

INSTALL=0 UNIVERSAL=0 ZIP=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    --universal) UNIVERSAL=1 ;;
    --zip) ZIP=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

VERSION="$(tr -d '[:space:]' < VERSION)"
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

if (( UNIVERSAL )); then
  ARCHS=(--arch arm64 --arch x86_64)
else
  ARCHS=()
fi
# The odd expansion keeps macOS's Bash 3.2 happy with an empty array under `set -u`.
swift build -c release ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/TaskCoach"

APP="build/TaskCoach.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TaskCoach"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp playbook.md "$APP/Contents/Resources/playbook.md"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>io.github.alvasi.taskcoach</string>
  <key>CFBundleName</key><string>Task Coach</string>
  <key>CFBundleDisplayName</key><string>Task Coach</string>
  <key>CFBundleExecutable</key><string>TaskCoach</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>NSHumanReadableCopyright</key><string>MIT licence</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# A fixed identity keeps macOS permissions across updates; ad-hoc is fine for your own builds.
codesign --force --timestamp=none --options runtime --sign "$SIGN_IDENTITY" "$APP"
codesign --verify --strict "$APP"
echo "Built $APP ($VERSION, $(lipo -archs "$APP/Contents/MacOS/TaskCoach"), signed: $SIGN_IDENTITY)"

if (( ZIP )); then
  rm -f build/TaskCoach.zip build/TaskCoach.zip.sha256
  # ditto keeps the signature and bundle metadata intact, unlike plain zip.
  ditto -c -k --keepParent "$APP" build/TaskCoach.zip
  (cd build && shasum -a 256 TaskCoach.zip > TaskCoach.zip.sha256)
  echo "Wrote build/TaskCoach.zip ($(du -h build/TaskCoach.zip | cut -f1)) and its checksum"
fi

if (( INSTALL )); then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/TaskCoach.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "Installed to ~/Applications/TaskCoach.app"
fi
