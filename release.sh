#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

WORK="$(mktemp -d)"
DIST="dist"
PROFILE="${HEATGLANCE_NOTARY_PROFILE:-heatglance-notary}"

cleanup() {
  rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p "$DIST"

xcodegen generate

xcodebuild \
  -project HeatGlance.xcodeproj \
  -scheme HeatGlance \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$WORK/derived" \
  -archivePath "$WORK/HeatGlance.xcarchive" \
  -allowProvisioningUpdates \
  archive

cat > "$WORK/export.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$WORK/HeatGlance.xcarchive" \
  -exportOptionsPlist "$WORK/export.plist" \
  -exportPath "$WORK/export" \
  -allowProvisioningUpdates

APP="$WORK/export/HeatGlance.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$DIST/HeatGlance-$VERSION.dmg"
IDENTITY="$(codesign -dvv "$APP" 2>&1 | awk -F= '/^Authority=Developer ID Application/ && !seen { print $2; seen = 1 }')"

if [ -z "$IDENTITY" ]; then
  echo "The exported app is not signed with a Developer ID certificate."
  exit 1
fi

echo "Notarizing the app"
ditto -c -k --keepParent "$APP" "$WORK/HeatGlance.zip"
xcrun notarytool submit "$WORK/HeatGlance.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"

echo "Building $DMG"
STAGE="$WORK/dmg"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/HeatGlance.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "HeatGlance" -srcfolder "$STAGE" -fs APFS -format ULFO "$DMG"
codesign --sign "$IDENTITY" --timestamp "$DMG"

echo "Notarizing the disk image"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

echo "Done: $DMG"
