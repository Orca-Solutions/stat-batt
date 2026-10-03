#!/bin/zsh
# Read-only image inspection: never launches StatBatt or opens/imports shortcuts.
set -eu
cd "${0:A:h}/.."
[[ $# == 1 && -f "$1" ]] || { print -u2 'Usage: verify-package.sh /absolute/path/to/StatBatt.dmg'; exit 2; }
image_path="${1:A}"
/usr/bin/hdiutil verify "$image_path"
mount_path=$(/usr/bin/mktemp -d "$PWD/dist/inspect.XXXXXX")
mounted=0
cleanup() {
  if (( mounted )); then /usr/bin/hdiutil detach "$mount_path" >/dev/null; fi
  /bin/rmdir "$mount_path"
}
trap cleanup EXIT
/usr/bin/hdiutil attach -readonly -nobrowse -noautoopen -mountpoint "$mount_path" "$image_path" >/dev/null
mounted=1
app_path="$mount_path/StatBatt.app"
[[ -x "$app_path/Contents/MacOS/StatBatt" && -f "$mount_path/INSTALL.txt" ]]
[[ -L "$mount_path/Applications" && "$(/usr/bin/readlink "$mount_path/Applications")" == /Applications ]]
[[ -f "$app_path/Contents/Resources/THIRD_PARTY_NOTICES.md" ]]
/usr/bin/codesign --verify --strict "$app_path"
scripts/verify-shortcuts.sh "$app_path/Contents/Resources"
/usr/bin/plutil -lint "$app_path/Contents/Info.plist"
# The experimental permission lab must never ship in the normal app image.
[[ ! -e "$app_path/Contents/MacOS/statbatt-adapter-lab" ]]
print "Package inspection passed. No app launched, shortcuts imported, or user settings changed."
