#!/bin/zsh
# Prepare only; macOS Installer handles the eventual administrative authorization.
set -eu
cd "${0:A:h}/.."
[[ $# == 0 ]] || exit 2
app="$PWD/dist/service-development/StatBatt.app"
[[ -d "$app" ]] || { print -u2 'Build the signed development service bundle first.'; exit 1; }
/usr/bin/codesign --verify --deep --strict -R='anchor apple generic and identifier "dev.statbatt.local"' "$app"
stage=$(/usr/bin/mktemp -d "$PWD/dist/service-development/package.XXXXXX")
trap '/bin/rm -rf "$stage"' EXIT
mkdir -p "$stage/payload/Library/Application Support/StatBattLocal" "$stage/payload/Applications" "$stage/scripts"
/usr/bin/ditto "$app" "$stage/payload/Library/Application Support/StatBattLocal/StatBatt.app"
/bin/ln -s '/Library/Application Support/StatBattLocal/StatBatt.app' "$stage/payload/Applications/StatBatt Local.app"
/bin/chmod -R go-w "$stage/payload/Library"
cat > "$stage/scripts/preinstall" <<'SCRIPT'
#!/bin/zsh
set -eu
# First-install-only package. Updating a registered controller needs a verified
# restoration/unregistration flow; never replace an existing control bundle.
[[ "$3" == '/' ]] || { print -u2 'Install only on the startup volume.'; exit 1; }
for path in '/Library/Application Support/StatBattLocal' '/Applications/StatBatt Local.app'; do
  [[ ! -e "$path" && ! -L "$path" ]] || { print -u2 "Existing local installation: $path. Stop and restore, then use the supported update flow."; exit 1; }
done
for path in / /Library '/Library/Application Support'; do
  [[ ! -L "$path" && -d "$path" && "$(/usr/bin/stat -f %u "$path")" == 0 ]] || exit 1
  mode=$(/usr/bin/stat -f %Lp "$path")
  (( (8#$mode & 8#22) == 0 )) || { print -u2 "Unsafe writable ancestor: $path"; exit 1; }
done
SCRIPT
chmod 755 "$stage/scripts/preinstall"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
/usr/bin/pkgbuild --analyze --root "$stage/payload" "$stage/components.plist"
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$stage/components.plist"
/usr/libexec/PlistBuddy -c 'Set :0:BundleHasStrictIdentifier true' "$stage/components.plist"
/usr/bin/pkgbuild --component-plist "$stage/components.plist" --root "$stage/payload" --scripts "$stage/scripts" --ownership recommended \
  --identifier dev.statbatt.local.first-install --version "$version" --install-location / \
  "$stage/StatBatt-LOCAL-DEVELOPMENT.pkg"
/bin/mv "$stage/StatBatt-LOCAL-DEVELOPMENT.pkg" dist/service-development/StatBatt-LOCAL-DEVELOPMENT.pkg
print "Prepared $PWD/dist/service-development/StatBatt-LOCAL-DEVELOPMENT.pkg"
print 'Local, unsigned Installer package containing Apple Development-signed code; not notarized or suitable for public distribution.'
print 'Installer requires admin approval. Open StatBatt Local in Applications, then use its service setup button.'
print 'Existing StatBatt.app and Apple Shortcuts are preserved. This first-install package refuses to overwrite a local service installation.'
