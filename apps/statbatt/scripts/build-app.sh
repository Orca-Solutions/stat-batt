#!/bin/zsh
set -eu
cd "${0:A:h}/.."
scripts/verify-shortcuts.sh
scripts/swift-local.sh build -c release --product StatBatt
app_path="$PWD/dist/StatBatt.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources/Shortcuts"
cp .build/release/StatBatt "$app_path/Contents/MacOS/StatBatt"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
cp THIRD_PARTY_NOTICES.md Resources/INSTALL.txt "$app_path/Contents/Resources/"
cp Resources/Shortcuts/*.shortcut "$app_path/Contents/Resources/Shortcuts/"
# Ad-hoc signing is for local execution only; it is not Developer ID distribution.
codesign --force --sign - "$app_path"
codesign --verify --strict "$app_path"
scripts/verify-shortcuts.sh "$app_path/Contents/Resources"
print "Built $app_path (local preview; not notarized for public distribution)"
