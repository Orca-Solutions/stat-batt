# Build and deployment guide

StatBatt has two independent projects. The app uses SwiftPM and the macOS SDK; the landing page is static HTML/CSS with local assets. The repository is private and [proprietary](../LICENSE).

## Checkout

With organization repository access and the GitHub CLI:

```sh
gh repo clone Orca-Solutions/stat-batt
cd stat-batt
```

The monorepo and landing foundation is merged. Use the default branch:

```sh
git switch main
```

All commands below run from the monorepo root.

## Native app

Use an Apple silicon Mac, Xcode with Swift 6 and its macOS SDK, and the configured Xcode command-line toolchain. There are no downloaded Swift package dependencies; SQLite is supplied by macOS. The minimum deployment target is macOS 15, but current device qualification covers one Apple silicon target on macOS 27.0.1.

The bounded native 80% setter/readback qualification applies only to **Mac16,13 / arm64 / macOS 27.0.1 / build 26A434 / firmware mBoot-20457.1.29**. Other targets, effective cutoff, and the integrated app's Apply/recovery lifecycle remain unqualified. Building on a supported deployment target does not unlock charging controls.

```sh
apps/statbatt/scripts/swift-local.sh test
apps/statbatt/scripts/build-app.sh
codesign --verify --deep --strict apps/statbatt/dist/StatBatt.app
open apps/statbatt/dist/StatBatt.app
```

The scripts resolve their app directory automatically. Caches are generated in `apps/statbatt/.build/`; the app bundle is generated in `apps/statbatt/dist/`. Both are ignored by Git. The current software suite has 102 tests. Test success establishes software contracts, not charging behavior on hardware.

The bundle is locally ad-hoc signed, not a notarized public release. Quit an older running StatBatt instance from its menu before opening a rebuilt bundle; closing its window leaves monitoring running. Settings → About StatBatt identifies version `0.1.0 (2)`. Do not run charging actions as a build verification step.

For a standalone read-only platform/telemetry probe:

```sh
apps/statbatt/scripts/swift-local.sh run statbatt-diagnostics
```

This command does not read the app's native setup/recovery journal or execute the shortcut. For the running app's native-workflow state, use its **Export diagnostics…** action. The [user guide](USER_GUIDE.md) explains the deliberate setup, visible confirmation, and manual return to 100%; tests and startup do not apply a limit.

If building fails, check `xcode-select -p` and `swift --version`, and confirm the selected Xcode includes a macOS SDK. Do not move the retained root `.build/` evidence into the new SwiftPM cache. Build or license changes do not authorize privileged helpers, hardware experiments, or app distribution.

## Landing preview

Python 3 is enough; there is no package installation, build command, environment variable, or backend.

```sh
python3 -m http.server 4187 --bind 127.0.0.1 --directory apps/landing/dist
```

Open `http://127.0.0.1:4187/`. If that port already hosts this preview, reuse it. Reload after HTML/CSS changes. Check the hero image, internal navigation, FAQs, and narrow-screen layout. See the [landing README](../apps/landing/README.md) for files and artwork provenance.

For the comparison change, check out `codex/battery-comparison` and open `http://127.0.0.1:4187/compare.html`. Verify the home/Compare header links, all three product columns, source links, mobile table scrolling, and keyboard focus. Its separate PR targets `main`; after it merges, the comparison is available from the default branch.

## Landing deployment

Merge the reviewed PR before production rollout. Configure a static host to publish **only `apps/landing/dist/`**. No install or build command is required. If a host asks for a project directory, use `apps/landing/` and its `dist/` output directory.

Never publish the monorepo root, native app bundles, `.build/`, repository guidance, or local user data. The website does not require runtime secrets or a database. GitHub Pages is configured at [the project site](https://orca-solutions.github.io/stat-batt/). The existing `.github/workflows/static.yml` workflow uploads only `apps/landing/dist/` and deploys on pushes to `main` or a manual workflow dispatch. The foundation deployment workflow succeeded on October 2, 2026. Comparison previews remain local until their PR is merged and that deployment succeeds. Recheck product-status copy before rollout. Publishing the landing page does not publish or release the native app.

For everyday app use, see the [user guide](USER_GUIDE.md). For layout and preserved paths, see [monorepo notes](MONOREPO.md).
