#!/usr/bin/env bash
# Builds Task Coach from source and installs it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

major="$(sw_vers -productVersion | cut -d. -f1)"
if (( major < 14 )); then
  echo "Task Coach needs macOS 14 or later (you have $(sw_vers -productVersion))." >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1 || ! command -v swift >/dev/null 2>&1; then
  echo "Swift isn't installed. Install the Xcode Command Line Tools, then run this again:" >&2
  echo "  xcode-select --install" >&2
  exit 1
fi

./scripts/build-app.sh --install

if ! ls "$HOME/Library/Application Support/Claude/claude-code/"*/*/claude.app/Contents/MacOS/claude >/dev/null 2>&1 \
   && ! command -v claude >/dev/null 2>&1; then
  echo
  echo "Note: the claude CLI wasn't found. Install Claude Code and log in, or set its path in"
  echo "Task Coach under Settings > Advanced."
fi

open "$HOME/Applications/TaskCoach.app"
echo "Installed. Task Coach is in your menu bar and in ~/Applications."
