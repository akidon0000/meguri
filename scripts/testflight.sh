#!/bin/bash
# Archive, export, and upload to TestFlight with asc (App Store Connect CLI).
#
# Requires:
#   asc auth login (once, globally — the same key works for every app under
#   this Apple Developer team, no per-repo setup needed)
#   ASC_APP_ID   App Store Connect app ID (numeric), or pass as $1
#
# The Xcode project/scheme name is auto-detected from the .xcodeproj in the
# repo root (XprojGen names both after the product), so this script needs no
# per-app edits — just copy it into a new app's scripts/ as-is.
#
# Usage: scripts/testflight.sh APP_ID [--group "Internal"]
set -euo pipefail
cd "$(dirname "$0")/.."

APP_ID="${ASC_APP_ID:-}"
if [[ $# -gt 0 && "$1" != --* ]]; then
  APP_ID="$1"
  shift
fi
if [[ -z "$APP_ID" ]]; then
  echo "usage: scripts/testflight.sh APP_ID [--group NAME]" >&2
  exit 1
fi

PROJECT=$(ls *.xcodeproj 2>/dev/null | head -1)
if [[ -z "$PROJECT" ]]; then
  echo "error: no .xcodeproj found in $(pwd) — run 'xcodegen generate' first" >&2
  exit 1
fi
SCHEME="${PROJECT%.xcodeproj}"

command -v xcodegen >/dev/null 2>&1 && xcodegen generate --quiet

exec asc publish testflight \
  --app "$APP_ID" \
  --project "$PROJECT" \
  --scheme "$SCHEME" \
  --configuration Release \
  --export-options scripts/ExportOptions.plist \
  --archive-path "build/$SCHEME.xcarchive" \
  --ipa-path "build/$SCHEME.ipa" \
  --archive-xcodebuild-flag -allowProvisioningUpdates \
  --export-xcodebuild-flag -allowProvisioningUpdates \
  --wait \
  --pretty \
  "${@:---upload-only}"
