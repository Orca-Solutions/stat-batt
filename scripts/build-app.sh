#!/bin/zsh
set -eu
cd "${0:A:h}/.."
scripts/swift-local.sh build -c release
app_path="$PWD/dist/StatBatt.app"
mkdir -p "$app_path/Contents/MacOS"
cp .build/release/StatBatt "$app_path/Contents/MacOS/StatBatt"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
# Ad-hoc signing is for local execution only; it is not Developer ID distribution.
codesign --force --sign - "$app_path"
print "Built $app_path"
