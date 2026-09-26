#!/bin/bash
# Build an unsigned IPA suitable for TrollStore (run on macOS with Xcode).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="TripleGeminiBrowser"
BUNDLE_ID="com.local.triplegeminibrowser"
APP_NAME="TripleGeminiBrowser"
BUILD_DIR="$ROOT/build"
DERIVED="$BUILD_DIR/DerivedData"
PAYLOAD="$BUILD_DIR/Payload"
IPA_OUT="$BUILD_DIR/${APP_NAME}-trollstore.ipa"

rm -rf "$BUILD_DIR"
mkdir -p "$DERIVED" "$PAYLOAD"

echo "==> xcodebuild (iphoneos, Release, no signing)"
xcodebuild \
  -project "$ROOT/TripleGeminiBrowser.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  build

APP_PATH="$(find "$DERIVED/Build/Products" -name "${APP_NAME}.app" -print -quit)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "ERROR: ${APP_NAME}.app not found under $DERIVED"
  exit 1
fi

echo "==> Packaging IPA from: $APP_PATH"
cp -R "$APP_PATH" "$PAYLOAD/"

# Optional fake-sign with ldid when available (TrollStore will resign anyway).
if command -v ldid >/dev/null 2>&1; then
  echo "==> ldid fake-sign"
  ENTITLEMENTS="$ROOT/TripleGeminiBrowser/TripleGeminiBrowser.entitlements"
  # Strip team placeholders for ldid
  TMP_ENT="$(mktemp)"
  /usr/bin/plutil -convert xml1 -o "$TMP_ENT" "$ENTITLEMENTS" 2>/dev/null || cp "$ENTITLEMENTS" "$TMP_ENT"
  ldid -S"$TMP_ENT" "$PAYLOAD/${APP_NAME}.app/${APP_NAME}" || ldid -S "$PAYLOAD/${APP_NAME}.app/${APP_NAME}"
  rm -f "$TMP_ENT"
else
  echo "==> ldid not found; packaging unsigned (TrollStore OK)"
fi

(
  cd "$BUILD_DIR"
  rm -f "$IPA_OUT"
  zip -qr "$IPA_OUT" Payload
)

echo ""
echo "Done."
echo "IPA: $IPA_OUT"
echo "Bundle ID: $BUNDLE_ID"
echo "Install with TrollStore on device."
