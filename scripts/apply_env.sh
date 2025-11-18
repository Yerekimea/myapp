#!/usr/bin/env bash
# Simple script to inject GOOGLE_MAPS_API_KEY from .env into native platform files
# Usage: ./scripts/apply_env.sh

set -e
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo ".env file not found. Copy .env.example to .env and add your API key."
  exit 1
fi

# Read key value
API_KEY_LINE=$(grep -E '^GOOGLE_MAPS_API_KEY=' "$ENV_FILE" || true)
if [ -z "$API_KEY_LINE" ]; then
  echo "GOOGLE_MAPS_API_KEY not found in .env"
  exit 1
fi
API_KEY=${API_KEY_LINE#GOOGLE_MAPS_API_KEY=}
API_KEY=${API_KEY//\"/}

echo "Injecting Google Maps API key into AndroidManifest.xml and AppDelegate.swift"

ANDROID_MANIFEST="$ROOT_DIR/android/app/src/main/AndroidManifest.xml"
IOS_APPDELEGATE="$ROOT_DIR/ios/Runner/AppDelegate.swift"

if [ -f "$ANDROID_MANIFEST" ]; then
  # Replace placeholder value YOUR_GOOGLE_MAPS_API_KEY or any existing value between quotes
  sed -i.bak -E "s|(android:name=\"com.google.android.geo.API_KEY\"\s+android:value=)\"[^"]*\"|\1\"$API_KEY\"|g" "$ANDROID_MANIFEST"
  echo "Updated $ANDROID_MANIFEST (backup saved as AndroidManifest.xml.bak)"
else
  echo "$ANDROID_MANIFEST not found; skipping Android update"
fi

if [ -f "$IOS_APPDELEGATE" ]; then
  # Replace GMSServices.provideAPIKey("...") argument
  sed -i.bak -E "s|GMSServices.provideAPIKey\(\"[^"]*\"\)|GMSServices.provideAPIKey(\"$API_KEY\")|g" "$IOS_APPDELEGATE"
  echo "Updated $IOS_APPDELEGATE (backup saved as AppDelegate.swift.bak)"
else
  echo "$IOS_APPDELEGATE not found; skipping iOS update"
fi

echo "Done. Please review the changes and rebuild the app."
