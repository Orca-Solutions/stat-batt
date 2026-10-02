# Monorepo organization

The owner authorized this layout on October 2, 2026, coordinated with the **Implement the v1 spec** chat. App edits were paused before the move; the landing page remains a separate product surface.

| Previous path | Current path |
|---|---|
| `Package.swift` | `apps/statbatt/Package.swift` |
| `Sources/`, `Tests/`, `Resources/` | The same directories under `apps/statbatt/` |
| `scripts/` | `apps/statbatt/scripts/` |
| App `README.md` and `CHANGELOG.md` | `apps/statbatt/README.md` and `apps/statbatt/CHANGELOG.md` |
| `landing/` | `apps/landing/` |
| `docs/`, `PROJECT_BRIEF.md`, `WORKING_RECORD.md` | Retained at the repository root |

The root README now provides entry points for both projects. The Swift package, native sources, tests, resources, and executable build scripts move together without behavioral changes. Each script resolves the app root from its own location, so it works from the monorepo root or any current directory. SwiftPM caches are regenerated under `apps/statbatt/.build/`.

## Independent commands

From the monorepo root:

```sh
apps/statbatt/scripts/swift-local.sh test
apps/statbatt/scripts/build-app.sh
codesign --verify --deep --strict apps/statbatt/dist/StatBatt.app
python3 -m http.server 4187 --bind 127.0.0.1 --directory apps/landing/dist
```

The optional commit-message hook can be installed from the root with:

```sh
cp apps/statbatt/scripts/commit-msg-hook.sh .git/hooks/commit-msg
chmod +x .git/hooks/commit-msg
```

## Preserved state and boundaries

- The existing `.git/` repository remains at the root. Each app is a directory, not a submodule or nested repository.
- Bundle identifier remains `dev.statbatt.local`, app version remains `0.1.0 (2)`, and user data remains in `~/Library/Application Support/StatBatt`.
- Root `.build/` lab journals, logs, screenshots, and manifests are retained as ignored historical evidence. Old verification paths in dated records refer to the pre-move layout.
- The old ignored root `dist/StatBatt.app` is retained so relocation does not remove a running app's executable. New builds produce `apps/statbatt/dist/StatBatt.app`. Quit the old app before deliberately launching the new bundle; closing its window does not quit it. No app restart or battery setting change is performed by relocation.
- Native `.build/` and `dist/` stay ignored. The static `apps/landing/dist/` is intentionally tracked through its local `.gitignore`.
- Website deployment must serve only `apps/landing/dist/`. No CI, cloud repository, hosting resource, charging control, or app release is created by this reorganization.

There is no shared package manager or root dependency installation. Landing-page edits cannot enter the Swift package build. Native builds cannot overwrite website assets.

## Relocation verification

- Before relocation, hashes captured 42 package/source/test/resource/script files. All matched immediately after the move. Subsequent native input changes are limited to the optional commit-hook installation comment; runtime code and both build scripts are byte-identical.
- `apps/statbatt/scripts/swift-local.sh test` passed 102 tests (50 XCTest +52 Swift Testing), zero failures, using freshly generated app-local caches.
- `apps/statbatt/scripts/build-app.sh` succeeded. The new bundle retains `dev.statbatt.local` and `0.1.0 (2)`; local strict code-signature verification passed.
- The Markdown link/fence audit passed 83 local link targets across 33 files before this final verification note. The relocated landing server responded HTTP200 at the retained preview address.
- No live app window, native Apply behavior, charging cutoff, OS notification delivery, or accessibility acceptance for the native app is newly claimed. Relocation checks verify packaging and software contracts, not hardware qualification.

The app chat independently reviewed relocation read-only and found no material issues. It confirmed paths, source preservation, executable permissions, identity/data location, preserved evidence, artifact exclusions, and the relocated bundle signature.
