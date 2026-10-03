#!/bin/zsh
# Prepare only; macOS Installer handles the eventual administrative authorization.
set -eu
cd "${0:A:h}/.."
mode=first-install
if [[ $# == 1 && "$1" == --update ]]; then mode=update
elif [[ $# != 0 ]]; then exit 2
fi
filename=StatBatt-LOCAL-DEVELOPMENT.pkg
[[ "$mode" != update ]] || filename=StatBatt-LOCAL-UPDATE.pkg
app="$PWD/dist/service-development/StatBatt.app"
[[ -d "$app" ]] || { print -u2 'Build the signed development service bundle first.'; exit 1; }
/usr/bin/codesign --verify --deep --strict -R='anchor apple generic and identifier "dev.statbatt.local"' "$app"
# Validate the exact privileged payload before constructing either package mode.
team=$(/usr/bin/codesign -dv --verbose=4 "$app" 2>&1 | /usr/bin/sed -n 's/^TeamIdentifier=//p')
[[ "$team" =~ '^[A-Z0-9]{10}$' ]] || exit 1
for pair in 'StatBattControlDaemon:dev.statbatt.control-daemon' 'StatBattAdapterGuardian:dev.statbatt.adapter-guardian'; do
  executable="${pair%%:*}"
  identifier="${pair#*:}"
  /usr/bin/codesign --verify --strict -R="anchor apple generic and identifier \"$identifier\" and certificate leaf[subject.OU] = \"$team\"" "$app/Contents/MacOS/$executable"
done
/usr/bin/codesign --verify --strict -R="anchor apple generic and identifier \"dev.statbatt.local-removal\" and certificate leaf[subject.OU] = \"$team\"" "$app/Contents/Resources/StatBattLocalRemoval"
scripts/verify-shortcuts.sh "$app/Contents/Resources"
stage=$(/usr/bin/mktemp -d "$PWD/dist/service-development/package.XXXXXX")
trap '/bin/rm -rf "$stage"' EXIT
mkdir -p "$stage/payload" "$stage/scripts"
/usr/bin/ditto --norsrc --noextattr --noacl "$app" "$stage/payload/StatBatt.app"
/bin/chmod -R go-w "$stage/payload"
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
if [[ "$mode" == update ]]; then
  team=$(/usr/bin/codesign -dv --verbose=4 "$app" 2>&1 | /usr/bin/sed -n 's/^TeamIdentifier=//p')
  [[ "$team" =~ '^[A-Z0-9]{10}$' ]] || exit 1
  /usr/bin/swiftc -module-cache-path "$stage/module-cache" scripts/installer/UpdatePreflight.swift -o "$stage/scripts/update-preflight"
  cat > "$stage/scripts/preinstall" <<SCRIPT
#!/bin/zsh
set -eu
[[ "\$3" == / ]] || exit 1
exec "\${0:A:h}/update-preflight" '$team'
SCRIPT
fi
cat > "$stage/scripts/postinstall" <<'SCRIPT'
#!/bin/zsh
set -eu
# Parent directories are never part of the payload or permission changes.
app='/Library/Application Support/StatBattLocal/StatBatt.app'
[[ "$3" == '/' && -d "$app" && ! -L "$app" ]] || exit 1
/usr/bin/codesign --verify --deep --strict -R='anchor apple generic and identifier "dev.statbatt.local"' "$app"
launcher='/Applications/StatBatt Local.app'
if [[ -L "$launcher" ]]; then
  [[ "$(/usr/bin/readlink "$launcher")" == "$app" ]] || exit 1
elif [[ -e "$launcher" ]]; then
  exit 1
else
  /bin/ln -s "$app" "$launcher"
fi
SCRIPT
chmod 755 "$stage/scripts/preinstall" "$stage/scripts/postinstall"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
/usr/bin/pkgbuild --analyze --root "$stage/payload" "$stage/components.plist"
/usr/libexec/PlistBuddy -c 'Add :0:BundleIsRelocatable bool false' "$stage/components.plist"
/usr/libexec/PlistBuddy -c 'Set :0:BundleHasStrictIdentifier true' "$stage/components.plist"
/usr/bin/pkgbuild --component-plist "$stage/components.plist" --root "$stage/payload" --scripts "$stage/scripts" --ownership recommended \
  --identifier "dev.statbatt.local.$mode" --version "$version" --install-location "/Library/Application Support/StatBattLocal" \
  "$stage/$filename"
/bin/mv "$stage/$filename" "dist/service-development/$filename"
print "Prepared $PWD/dist/service-development/$filename"
print 'Local, unsigned Installer package containing Apple Development-signed code; not notarized or suitable for public distribution.'
print 'Installer requires admin approval. Open StatBatt Local in Applications, then use its service setup button.'
if [[ "$mode" == update ]]; then
  print 'Update requires verified restoration, stopped app and unregistered service; the installer performs no recovery or registration.'
else
  print 'Existing StatBatt.app and Apple Shortcuts are preserved. This first-install package refuses to overwrite a local service installation.'
fi
