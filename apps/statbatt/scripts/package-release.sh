#!/bin/zsh
# Builds a drag-to-Applications DMG. Imports happen in the signed app under the
# receiving user's account with Apple's Add Shortcut approval, never as root.
set -eu
cd "${0:A:h}/.."
[[ $# -le 1 ]] || { print -u2 'Usage: package-release.sh [--public|--local-preview]'; exit 2; }
mode="${1:---public}"
[[ "$mode" == --public || "$mode" == --local-preview ]] || {
  print -u2 'Usage: package-release.sh [--public|--local-preview]'; exit 2
}
if [[ "$mode" == --public ]]; then
  : "${STATBATT_SIGNING_IDENTITY:?Set STATBATT_SIGNING_IDENTITY to a Developer ID Application identity}"
  : "${STATBATT_NOTARY_PROFILE:?Set STATBATT_NOTARY_PROFILE to a notarytool Keychain profile}"
  [[ "$STATBATT_SIGNING_IDENTITY" == 'Developer ID Application: '* ]] || {
    print -u2 'Public releases require a Developer ID Application identity.'; exit 1
  }
fi
scripts/build-app.sh
app_path="$PWD/dist/StatBatt.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app_path/Contents/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app_path/Contents/Info.plist")
if [[ "$mode" == --public ]]; then
  /usr/bin/codesign --force --options runtime --timestamp --sign "$STATBATT_SIGNING_IDENTITY" "$app_path"
  /usr/bin/codesign --verify --strict --verbose=2 "$app_path"
  archive="$PWD/dist/StatBatt-notarization.zip"
  /usr/bin/ditto -c -k --keepParent "$app_path" "$archive"
  /usr/bin/xcrun notarytool submit "$archive" --keychain-profile "$STATBATT_NOTARY_PROFILE" --wait
  /usr/bin/xcrun stapler staple "$app_path"
  /usr/bin/xcrun stapler validate "$app_path"
  /usr/sbin/spctl --assess --type execute --verbose=2 "$app_path"
  suffix=""
else
  suffix="-LOCAL-PREVIEW"
fi
stage=$(/usr/bin/mktemp -d "$PWD/dist/package.XXXXXX")
trap '/bin/rm -rf "$stage"' EXIT
/usr/bin/ditto "$app_path" "$stage/StatBatt.app"
/bin/ln -s /Applications "$stage/Applications"
/bin/cp Resources/INSTALL.txt "$stage/INSTALL.txt"
final_dmg="$PWD/dist/StatBatt-$version-$build$suffix.dmg"
# Do not leave an unnotarized image with a public release filename on failure.
dmg="$PWD/dist/.StatBatt-$version-$build$suffix-incomplete.dmg"
trap '/bin/rm -rf "$stage"; /bin/rm -f "$dmg"' EXIT
/usr/bin/hdiutil create -volname "StatBatt$suffix" -srcfolder "$stage" -ov -format UDZO "$dmg"
if [[ "$mode" == --public ]]; then
  /usr/bin/codesign --timestamp --sign "$STATBATT_SIGNING_IDENTITY" "$dmg"
  /usr/bin/xcrun notarytool submit "$dmg" --keychain-profile "$STATBATT_NOTARY_PROFILE" --wait
  /usr/bin/xcrun stapler staple "$dmg"
  /usr/bin/xcrun stapler validate "$dmg"
  /usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
fi
/usr/bin/hdiutil verify "$dmg"
/bin/mv -f "$dmg" "$final_dmg"
(cd "${final_dmg:h}" && /usr/bin/shasum -a 256 "${final_dmg:t}") > "$final_dmg.sha256"
print "Packaged $final_dmg"
