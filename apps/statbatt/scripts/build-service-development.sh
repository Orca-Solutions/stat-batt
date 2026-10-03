#!/bin/zsh
# Signed local application with authenticated background service. Building never registers or runs it.
set -eu
cd "${0:A:h}/.."
[[ $# == 0 ]] || { print -u2 'No arguments accepted; set STATBATT_DEVELOPMENT_IDENTITY.'; exit 2; }
: "${STATBATT_DEVELOPMENT_IDENTITY:?Set an installed Apple Development or Developer ID Application identity}"
[[ "$STATBATT_DEVELOPMENT_IDENTITY" == 'Apple Development: '* || "$STATBATT_DEVELOPMENT_IDENTITY" == 'Developer ID Application: '* ]] || {
  print -u2 'An Apple-issued signing identity is required; ad-hoc signing is rejected.'; exit 1
}
identities=$(/usr/bin/security find-identity -v -p codesigning)
[[ "$identities" == *\""$STATBATT_DEVELOPMENT_IDENTITY"\"* ]] || { print -u2 'Requested identity is not valid in the keychain.'; exit 1; }
scripts/verify-shortcuts.sh
scripts/swift-local.sh build -c release --product StatBatt
scripts/swift-local.sh build -c release --product StatBattControlDaemon
scripts/swift-local.sh build -c release --product StatBattAdapterGuardian
mkdir -p dist/service-development
stage=$(/usr/bin/mktemp -d "$PWD/dist/service-development/build.XXXXXX")
cleanup() {
  if [[ -e "$stage/previous.app" && ! -e "$PWD/dist/service-development/StatBatt.app" ]]; then
    print -u2 "Prior development app preserved at $stage/previous.app"
    return
  fi
  /bin/rm -rf "$stage"
}
trap cleanup EXIT
app="$stage/StatBatt.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/Shortcuts"
cp .build/release/StatBatt "$app/Contents/MacOS/"
cp Resources/Info.plist "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 11' "$app/Contents/Info.plist"
cp THIRD_PARTY_NOTICES.md Resources/INSTALL.txt Resources/LOCAL_SERVICE_INSTALL.txt "$app/Contents/Resources/"
cp Resources/Shortcuts/*.shortcut "$app/Contents/Resources/Shortcuts/"
mkdir -p "$app/Contents/Library/LaunchDaemons"
cp .build/release/StatBattControlDaemon .build/release/StatBattAdapterGuardian "$app/Contents/MacOS/"
cp Resources/LaunchDaemons/dev.statbatt.control-daemon.plist "$app/Contents/Library/LaunchDaemons/"
/usr/bin/swiftc -D LOCAL_REMOVAL -module-cache-path "$stage/removal-cache" scripts/installer/UpdatePreflight.swift -o "$app/Contents/Resources/StatBattLocalRemoval"
cp scripts/remove-service-local.sh "$app/Contents/Resources/Remove StatBatt Local.command"
/usr/bin/codesign --force --options runtime --sign "$STATBATT_DEVELOPMENT_IDENTITY" --identifier dev.statbatt.local-removal "$app/Contents/Resources/StatBattLocalRemoval"
/usr/bin/codesign --force --options runtime --sign "$STATBATT_DEVELOPMENT_IDENTITY" --identifier dev.statbatt.adapter-guardian "$app/Contents/MacOS/StatBattAdapterGuardian"
/usr/bin/codesign --force --options runtime --sign "$STATBATT_DEVELOPMENT_IDENTITY" --identifier dev.statbatt.control-daemon "$app/Contents/MacOS/StatBattControlDaemon"
/usr/bin/codesign --force --options runtime --sign "$STATBATT_DEVELOPMENT_IDENTITY" "$app"
/usr/bin/codesign --verify --strict -R='anchor apple generic and identifier "dev.statbatt.adapter-guardian"' "$app/Contents/MacOS/StatBattAdapterGuardian"
/usr/bin/codesign --verify --strict -R='anchor apple generic and identifier "dev.statbatt.control-daemon"' "$app/Contents/MacOS/StatBattControlDaemon"
/usr/bin/codesign --verify --strict -R='anchor apple generic and identifier "dev.statbatt.local"' "$app"
[[ ! -e dist/service-development/StatBatt.app ]] || /bin/mv dist/service-development/StatBatt.app "$stage/previous.app"
if ! /bin/mv "$app" dist/service-development/StatBatt.app; then
  [[ ! -e "$stage/previous.app" ]] || /bin/mv "$stage/previous.app" dist/service-development/StatBatt.app
  exit 1
fi
print "Prepared $PWD/dist/service-development/StatBatt.app"
print 'No service registered or installed. Use the in-app background-service setup button.'
print 'Temperature controls remain gated by the daemon’s qualification and verified recovery state.'
