# StatBatt archive record

Development ended October 17, 2026 at the owner's request. The app is preserved
as-is; the landing page remains a static archive. No maintenance, support,
compatibility updates, or public app release is planned. Proprietary ownership
and the [existing license](LICENSE) remain unchanged.

## Final app state

The latest saved local checkpoint is **build 14**, documented on October 3 in
[local acceptance and artifact provenance](docs/research/THERMAL_BUILD14_LOCAL_ACCEPTANCE.md).
It includes monitoring, seven-day local history, CSV export, preferences, opt-in
alerts, and Apple 80% / 100% shortcut controls verified on one exact Mac/OS target.

The thermal-control investigation includes a local signed service, bounded
adapter pauses, and saved normal-pause, guardian-loss, and coordinated-sleep
recovery evidence. Build 14 was recorded as installed locally, with automatic
control available but off. Owner-operated session start/stop and live hot/cool
threshold crossings remained unverified. Repository backend write gates remain
disabled; rebuilding this source does not reproduce the separately qualified,
hash-pinned guardian automatically.

The archive operation does not install, run, update, stop, or remove the app or
its helper, change charging settings, or alter local history and shortcuts.
Existing installations retain their prior state. Recovery/removal instructions
remain in [the local service guide](apps/statbatt/Resources/LOCAL_SERVICE_INSTALL.txt)
and [security operations](docs/SECURITY_OPERATIONS.md).

Public signing/notarization, clean-account installation, wider hardware coverage,
notification delivery, and long-duration acceptance were unfinished or deferred.
See [V1 acceptance](docs/V1_ACCEPTANCE.md). These gaps are preserved, not an active
roadmap. This archive is not a qualified public distribution.

## Work preserved

- The original `codex/simple-charge-controls` history through `6b3891a`, including
  app development beyond `main` and beyond the earlier app-completion PR.
- Previously uncommitted build-14 code, tests, installation notes, and build-13
  result files, checkpointed in signed commit `045995e`.
- The comparison page from `codex/battery-comparison` (`fedef75`), including its
  dated source notes. Its October 2 table is a historical snapshot.
- The outstanding workflow documentation through `16c6e8a`.

All are consolidated on `codex/archive-statbatt` without rewriting their history.
Generated caches, app bundles, local operating documents already ignored by Git,
and personal runtime data stay outside the source archive. Old branches remain
available; cleanup does not delete them.

## Landing page and repository handoff

GitHub Pages already publishes **only `apps/landing/dist/`** using
[the existing workflow](.github/workflows/static.yml) on pushes to `main`.
The configured custom domain is `statbatt.orcasolutions.dev`. Keep that hosting
configuration and its DNS so the landing page remains available. The site has no
build dependencies, analytics, forms, or app downloads.

The archive candidate adds a discontinued-project notice and final status to the
home page. The separate comparison page keeps its original dated claims and
explicitly identifies them as historical. Existing artwork and layout remain.

The consolidation PR supersedes the content of open PRs #2, #3, and #4. Merge
the archive PR first, allow its existing Pages deployment to finish, and verify
the home page, archive notice, comparison route, and artwork at the custom domain.
Then close any superseded PRs still open and, if desired, set the GitHub repository
to read-only archive status. Do not archive it before the final Pages deployment.
The archive preparation itself does not change GitHub settings or deploy the site.

## Verification on October 17, 2026

- 230 Swift tests passed: 69 XCTest and 161 Swift Testing.
- 37 mocked Python recovery/evidence tests passed across six scripts.
- Installer preflight and native-request fixtures passed.

These are software checks. No new hardware qualification, native app release,
or runtime installation is implied. Landing-page verification and final Git
handoff are recorded in [the working record](WORKING_RECORD.md).
