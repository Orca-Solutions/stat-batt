#!/bin/zsh
# Run as the signed-in user. Only the final, scoped removal requests administrator access.
set -eu
[[ $# == 0 && $EUID != 0 ]] || { print -u2 'Run without arguments as the signed-in user.'; exit 2; }
app='/Library/Application Support/StatBattLocal/StatBatt.app'
client="$app/Contents/MacOS/StatBatt"
[[ -d "$app" && ! -L "$app" ]] || exit 1
/usr/bin/codesign --verify --deep --strict -R='anchor apple generic and identifier "dev.statbatt.local"' "$app"
helper="$app/Contents/Resources/StatBattLocalRemoval"
[[ -f "$helper" && ! -L "$helper" ]] || { print -u2 'This app predates guided removal; install a reviewed update first.'; exit 1; }
# This signed entry point requests prepareUninstall and refuses to unregister
# unless the daemon returns safeToExit. Failure stops before privilege elevation.
"$client" --thermal-service-unregister
print 'The service is safely unregistered. Quit StatBatt before continuing.'
print 'This removes only the protected local app and its launcher; shortcuts, history, preferences and recovery records remain.'
read -r 'answer?Type REMOVE to request administrator approval: '
[[ "$answer" == REMOVE ]] || exit 0
# No user-supplied path or command is forwarded to the privileged helper.
/usr/bin/osascript -e 'do shell script "\"/Library/Application Support/StatBattLocal/StatBatt.app/Contents/Resources/StatBattLocalRemoval\"" with administrator privileges'
