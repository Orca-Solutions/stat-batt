#!/bin/zsh
# Separate local candidate; this script builds/signs only and never launches a shortcut.
set -eu
cd "${0:A:h}/.."
scripts/swift-local.sh build -c release -Xswiftc -DSTATBATT_NATIVE_100_QUALIFICATION
app_path="$PWD/dist/native-100-qualification/StatBatt.app"
mkdir -p "$app_path/Contents/MacOS"
cp .build/release/StatBatt "$app_path/Contents/MacOS/StatBatt"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
# Distinguish this candidate from ordinary builds in the owner's About view.
/usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 0.1.0-qualification' "$app_path/Contents/Info.plist"
codesign --force --sign - "$app_path"
codesign --verify --deep --strict "$app_path"
print "Built supervised candidate $app_path"
