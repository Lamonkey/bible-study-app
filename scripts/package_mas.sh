#!/bin/bash
# Build a Mac App Store package. UNTESTED end to end: it needs a paid Apple Developer
# Program membership, which supplies the two certificates and the provisioning profile.
#
#   APP_CERT="Apple Distribution: Your Name (TEAMID)" \
#   PKG_CERT="3rd Party Mac Developer Installer: Your Name (TEAMID)" \
#   PROFILE=path/to/ChaJing_MAS.provisionprofile \
#   scripts/package_mas.sh
#
# Output: dist/mas/好查经.pkg, ready for Transporter or `xcrun altool --upload-app`.
set -euo pipefail
: "${APP_CERT:?set APP_CERT to the Apple Distribution identity}"
: "${PKG_CERT:?set PKG_CERT to the Mac Installer Distribution identity}"
: "${PROFILE:?set PROFILE to the Mac App Store provisioning profile}"

cd "$(dirname "$0")/.."
NAME=好查经
OUT=dist/mas; APP=$OUT/$NAME.app
rm -rf "$OUT"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Universal binary: the deployment target (macOS 13) still includes Intel Macs.
swift build -c release --arch arm64 --arch x86_64
BIN=.build/apple/Products/Release
cp "$BIN/ChaJing" "$APP/Contents/MacOS/ChaJing"
cp -R "$BIN/ChaJing_ChaJing.bundle" "$APP/Contents/Resources/"
cp packaging/Info.plist "$APP/Contents/Info.plist"
cp packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# The App Store entitlements must carry the team and app identifiers from the profile.
security cms -D -i "$PROFILE" > "$OUT/profile.plist"
TEAM=$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$OUT/profile.plist")
APPID=$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$OUT/profile.plist")
cp packaging/ChaJing.entitlements "$OUT/mas.entitlements"
/usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $APPID" "$OUT/mas.entitlements"
/usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $TEAM" "$OUT/mas.entitlements"

codesign --force --options runtime --sign "$APP_CERT" "$APP/Contents/Resources/ChaJing_ChaJing.bundle"
codesign --force --options runtime --entitlements "$OUT/mas.entitlements" --sign "$APP_CERT" "$APP"
codesign --verify --strict --verbose=2 "$APP"
productbuild --component "$APP" /Applications --sign "$PKG_CERT" "$OUT/$NAME.pkg"
echo "built $OUT/$NAME.pkg"
