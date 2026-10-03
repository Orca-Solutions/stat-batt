#!/bin/zsh
set -eu
cd "${0:A:h}/.."
resource_dir="${1:-$PWD/Resources}/Shortcuts"
check_export() {
  local file="$resource_dir/StatBatt — Apple Limit $1.shortcut"
  [[ -f "$file" && ! -L "$file" ]] || { print -u2 "Missing bundled shortcut: $file"; exit 1; }
  local actual=$(/usr/bin/shasum -a 256 "$file")
  [[ "${actual%% *}" == "$2" ]] || { print -u2 "Unreviewed shortcut export: $file"; exit 1; }
}
check_export 80 5db7064b8e86d9df2e0c3c61759e57f23b7231956cbc141293f8f18463651665
check_export 100 81eb7e6acc7ff1225fc8822eba6bbe5f87447555363b580ba6086d11498b2225
print "Verified both inspected Apple-signed shortcut exports."
