#!/bin/zsh
set -eu
cd "${0:A:h}/.."
scripts/verify-shortcuts.sh
scripts/swift-local.sh build -c release --product StatBatt
mkdir -p "$PWD/dist"
build_stage=$(/usr/bin/mktemp -d "$PWD/dist/build.XXXXXX")
trap '/bin/rm -rf "$build_stage"' EXIT
app_path="$build_stage/StatBatt.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources/Shortcuts"
cp .build/release/StatBatt "$app_path/Contents/MacOS/StatBatt"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
cp THIRD_PARTY_NOTICES.md Resources/INSTALL.txt "$app_path/Contents/Resources/"
cp Resources/Shortcuts/*.shortcut "$app_path/Contents/Resources/Shortcuts/"
# Ad-hoc signing is for local execution only; it is not Developer ID distribution.
codesign --force --sign - "$app_path"
codesign --verify --strict "$app_path"
scripts/verify-shortcuts.sh "$app_path/Contents/Resources"
# A fresh bundle excludes obsolete resources/executables from previous builds.
# Do not truncate the executable inside a potentially running app bundle.
if [[ -e "$PWD/dist/StatBatt.app" ]]; then
  /bin/mv "$PWD/dist/StatBatt.app" "$build_stage/previous.app"
fi
if ! /bin/mv "$app_path" "$PWD/dist/StatBatt.app"; then
  [[ ! -e "$build_stage/previous.app" ]] || /bin/mv "$build_stage/previous.app" "$PWD/dist/StatBatt.app"
  exit 1
fi
print "Built $PWD/dist/StatBatt.app (local preview; not notarized for public distribution)"
