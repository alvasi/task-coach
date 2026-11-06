#!/usr/bin/env bash
# Installs the latest Task Coach release into ~/Applications.
#
#   curl -fsSL https://alvasi.github.io/task-coach/install.sh | bash
#
# It checks the download's checksum and that the app is signed with Task Coach's own certificate
# (pinned below by fingerprint) before installing anything.
set -euo pipefail

REPO="alvasi/task-coach"
RELEASE_URL="${TASKCOACH_RELEASE_URL:-https://github.com/$REPO/releases/latest/download}"
DEST="${TASKCOACH_DEST:-$HOME/Applications}"
# SHA-256 of the "Task Coach Self-Signed" certificate every release is signed with.
CERT_SHA256="${TASKCOACH_CERT_SHA256:-9099fec881b68bc7650eca59df2866234fc6aecddada6810783a9c84afcf1ea6}"

say() { printf '%s\n' "$*"; }
fail() { printf 'Task Coach install failed: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "Task Coach only runs on macOS."
major="$(sw_vers -productVersion | cut -d. -f1)"
(( major >= 14 )) || fail "it needs macOS 14 or later (you have $(sw_vers -productVersion))."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

say "Downloading Task Coach…"
curl -fsSL "$RELEASE_URL/TaskCoach.zip" -o "$tmp/TaskCoach.zip" || fail "couldn't download the release."
curl -fsSL "$RELEASE_URL/TaskCoach.zip.sha256" -o "$tmp/TaskCoach.zip.sha256" || fail "couldn't download the checksum."

expected="$(awk '{print $1}' "$tmp/TaskCoach.zip.sha256")"
actual="$(shasum -a 256 "$tmp/TaskCoach.zip" | awk '{print $1}')"
[[ -n "$expected" && "$expected" == "$actual" ]] || fail "the download doesn't match its checksum."

ditto -x -k "$tmp/TaskCoach.zip" "$tmp/unpacked"
app="$tmp/unpacked/TaskCoach.app"
[[ -d "$app" ]] || fail "the download doesn't contain TaskCoach.app."

say "Checking the signature…"
codesign --verify --strict "$app" 2>/dev/null || fail "the app's signature is broken or it was modified."
codesign -d --extract-certificates="$tmp/cert" "$app" 2>/dev/null || true
[[ -f "$tmp/cert0" ]] || fail "the app isn't signed with Task Coach's certificate."
signer="$(shasum -a 256 "$tmp/cert0" | awk '{print $1}')"
[[ "$signer" == "$CERT_SHA256" ]] || fail "the app isn't signed with Task Coach's certificate."

# Replace any running or older copy.
if pgrep -x TaskCoach >/dev/null; then
  osascript -e 'quit app id "io.github.alvasi.taskcoach"' >/dev/null 2>&1 || pkill -x TaskCoach || true
  sleep 1
fi
mkdir -p "$DEST"
rm -rf "$DEST/TaskCoach.app"
ditto "$app" "$DEST/TaskCoach.app"
# curl downloads aren't quarantined, but clear it in case the zip was fetched another way.
xattr -dr com.apple.quarantine "$DEST/TaskCoach.app" 2>/dev/null || true

version="$(defaults read "$DEST/TaskCoach.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "")"
say "Installed Task Coach $version in $DEST."

if ! command -v claude >/dev/null 2>&1 \
   && ! ls "$HOME/Library/Application Support/Claude/claude-code/"*/*/claude.app/Contents/MacOS/claude >/dev/null 2>&1; then
  say ""
  say "Task Coach needs Claude Code to write quizzes: https://claude.com/claude-code"
  say "Once it's installed, run claude in Terminal and type /login."
fi

[[ -n "${TASKCOACH_NO_OPEN:-}" ]] || open "$DEST/TaskCoach.app"
