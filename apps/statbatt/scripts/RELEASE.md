# Release packaging

Local preview:

```sh
apps/statbatt/scripts/package-release.sh --local-preview
```

This creates a drag-to-Applications DMG in `apps/statbatt/dist`, clearly named
`LOCAL-PREVIEW`. It is ad-hoc signed, not approved for public distribution.

Public release requires Apple Developer Program membership, a valid Developer ID
Application signing identity in the build user's Keychain, and a `notarytool`
Keychain profile. Configure those interactively using Apple's documentation;
never commit certificate private keys or credentials. Then:

```sh
export STATBATT_SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)'
export STATBATT_NOTARY_PROFILE='YOUR_KEYCHAIN_PROFILE'
apps/statbatt/scripts/package-release.sh --public
```

The public path fails if configuration is missing, verifies both bundled
shortcut hashes, builds and signs the app with hardened runtime, submits the app
to Apple, staples and verifies it, then creates/signs/notarizes/staples the DMG.
A SHA-256 companion file identifies the finished image. It does not upload a
release to a hosting service. Public-path notarization remains untested until
valid credentials are available.

Both workflows are included inside the app before code signing. First-run
Charging setup opens these signed files in Apple's Shortcuts app under the
current user's account. The user approves Add Shortcut for each; returning to
StatBatt discovers the installed entries. This avoids Terminal instructions and
manual workflow creation. It deliberately uses no privileged postinstall hook:
Shortcuts' supported API does not provide silent per-user installation.

Before release, test a fresh supported-Mac user account: copy app, open it,
import both shortcuts, finish setup, apply both targets and verify Battery
settings. Also cancel an import and resume, relaunch midway through setup, and
check existing-shortcut reuse. Neither the import previews nor hash tests
substitute for this clean-account acceptance test.


Non-invasive package check:

```sh
apps/statbatt/scripts/verify-package.sh /absolute/path/to/StatBatt-image.dmg
```

This mounts the image read-only and checks contents/signatures, then detaches it.
It does not run the app, change trust, import shortcuts, or perform battery writes.
The package contains the native app and two signed shortcut exports; experimental
adapter-lab executables are not included. Package checksum files use the image's
basename so `shasum -a 256 -c <image>.sha256` works after download.

Public output is first built under an incomplete filename and renamed only after
verification/notarization completes. An incomplete build is not a public release.
The owner currently has no Apple Developer membership; preparing the pipeline
and local previews does not remove that public-distribution blocker.
