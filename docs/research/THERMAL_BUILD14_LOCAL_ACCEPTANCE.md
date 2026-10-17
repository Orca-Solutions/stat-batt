# Build 14 local acceptance

October 3, 2026. Public signing and notarization remain deferred by owner direction.

The build 13 120-second normal pause, guardian-loss recovery, and coordinated
sleep recovery passed. See the saved build 13 results and recovery sequence.
Sleep restoration used owner EOF following WILL_SLEEP; it does not independently
prove the worker's sleep callback. No fallback was needed. The owner confirmed
wake/unlock and fresh service inspection confirmed adapter restoration.

Build 14 admits optional automatic control only for the reviewed exact platform,
provider, guardian digest and enabled backend gates. Estimated temperature remains
explicitly estimated. Defaults are disconnect at 40°C, reconnect at 37°C, with a
50% reserve, maximum 120-second pause and one-hour session. Sleep, quit, lost
ownership and invalid observations end the session; sessions do not restart.
Installation and registration do not enable temperature control.

The initial source transition now permits bounded settling while fresh owned
08 readback persists. Subsequent holding observations remain strict. This does
not renew the worker lease or issue additional inhibition writes.

## Artifact provenance

Candidate source: `/private/tmp/statbatt-v14-candidate-efyjc7x9/statbatt`.
The accompanying source manifest describes the app and daemon candidate. Only its
three backend gates are enabled. Repository write gates remain closed.
The candidate build script copies the **already signed build 13 guardian and
removal helper**, verifies their identities, and signs only the new app and daemon.
The source manifest therefore does not describe a rebuilt guardian; its provenance
is the build 13 candidate and evidence. The exact qualified guardian is unchanged.

SHA-256:

- Update package: `2eb82774babc53af305f376b4b86af64a84f8fb22f19bf93110baa67d27c6d63`
- App executable: `93b2beaf913b15013db8fc302af63ef7ed85fa640cd6632810b07c66eb56c03e`
- Daemon: `af9d6542299f26909af36377d06e3c377314ea3c5d517c3fa44946c92c1ea269`
- Guardian: `747f18061e2c30f504b824b0d1c5730df2613930b16d080bdd5aef3ff5d32470`

The package contains Apple Development-signed code, with strict signature and
bundled-shortcut integrity checks passing. The Installer package itself is unsigned
and is for this local development installation, not public distribution.

## Validation and remaining checks

230 software tests passed (69 XCTest and 161 Swift Testing), including exact
admission, bounded initial source settling and cancellation. Hardware results
remain scoped to Mac16,13, arm64, macOS 27.0.1/26A434, mBoot-20457.1.29.

Installation passed: installed build number 14 and all three executable hashes
match the candidate. Registration succeeded without enabling control. Authenticated
status reports `controlAvailable: true`, `phase: off`, `adapterRestored: true`,
`safeToExit: true`, maximum pause 120 seconds and minimum reserve 50%. Installed
automatic-session start/stop verification is pending owner UI operation.
No live hot/cool threshold crossing has been observed. No synthetic heat is planned.
Clean-account setup, real notification delivery, broader hardware, long-duration
retention and public distribution acceptance remain unexecuted or deferred.
