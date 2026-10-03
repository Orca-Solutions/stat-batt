#!/bin/zsh
set -eu
cd "${0:A:h}/.."
stage=$(/usr/bin/mktemp -d /private/tmp/statbatt-installer-tests.XXXXXX)
trap '/bin/rm -rf "$stage"' EXIT
cat scripts/installer/UpdatePreflight.swift scripts/installer/PreflightFixtures.swift > "$stage/main.swift"
/usr/bin/swiftc -D PREFLIGHT_TESTING -module-cache-path "$stage/cache" "$stage/main.swift" -o "$stage/fixtures"
"$stage/fixtures"
