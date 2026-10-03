# Bundled charge-limit shortcuts

These two artifacts were exported from Apple's Shortcuts app on October 2, 2026
using **File → Export → For: Anyone**. Export signs the workflow through Apple's
validation service. They are actual exports, not hand-authored workflow files.

Before exporting, the editor showed exactly one native **Set Charge Limit**
action, set to 80% or 100% respectively. The 80% action's “Set Until Tomorrow”
option was off. Both source library workflows were previously exercised by the
owner through StatBatt's buttons and confirmed in Apple's Battery settings.
Exporting did not run the actions or change the library workflows.

The first 80% export encountered a transient Apple NSURLErrorDomain 500; the
retry succeeded. Both signed exports have an AEA1 container. Their SHA-256 hashes
are pinned in `BundledNativeShortcuts.swift` and `scripts/verify-shortcuts.sh`.
This pin checks the bundled artifact, not subsequent edits to an imported user
shortcut. Apple verifies the signed file when it is opened for import.

| Target | SHA-256 |
| --- | --- |
| 80% | `5db7064b8e86d9df2e0c3c61759e57f23b7231956cbc141293f8f18463651665` |
| 100% | `81eb7e6acc7ff1225fc8822eba6bbe5f87447555363b580ba6086d11498b2225` |

To update: inspect the one-action workflows in Apple's editor; export each for
Anyone into this folder; verify import previews and supported-Mac operation;
update both hash allowlists after review. Do not extract or mutate Shortcuts'
private library database, add shell actions, or silently import as root.

Apple references:
- [Sharing/export](https://support.apple.com/en-euro/guide/shortcuts-mac/apdf01f8c054/mac)
- [Importing shortcut files](https://support.apple.com/en-nz/guide/shortcuts-mac/apd02bffbaac/mac)
- [CLI operations/signing](https://support.apple.com/en-nz/guide/shortcuts-mac/apd455c82f02/mac)

Import-preview verification: both files were opened through Shortcuts' supported
File → Import command on the export Mac. Apple displayed Add Shortcut and each
More preview showed the correct single native action (80% / 100%). Both previews
were closed without importing duplicates or executing actions. A separate clean
user account / second-Mac installation has not yet been exercised.
