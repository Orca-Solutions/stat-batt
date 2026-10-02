# StatBatt monorepo

StatBatt is a native Apple silicon macOS menu bar battery app, with a separate static landing page. The app is in local development; this organization does not change its feature availability or qualify a public release.

Owned by Orca Solutions. This project is [proprietary, all rights reserved](LICENSE). The organization repository is [Orca-Solutions/stat-batt](https://github.com/Orca-Solutions/stat-batt).

```text
apps/
  statbatt/    Swift package, Sources, Tests, Resources, scripts, app README and changelog
  landing/    Static landing page, original artwork, and preview instructions
docs/         Shared specifications, architecture, research, and review records
```

## Native app

Run from the repository root:

```sh
apps/statbatt/scripts/swift-local.sh test
apps/statbatt/scripts/build-app.sh
open apps/statbatt/dist/StatBatt.app
```

App sources and scripts are self-contained in `apps/statbatt/`. Generated SwiftPM caches and the app bundle stay in that directory. See the [app README](apps/statbatt/README.md) for native 80% workflow requirements, current qualification, and recovery limitations.

## Landing page

```sh
python3 -m http.server 4187 --bind 127.0.0.1 --directory apps/landing/dist
```

Open `http://127.0.0.1:4187/`. No install or build step is required. Only `apps/landing/dist/` should be deployed as the website; it contains no app binaries or local user data. See the [landing README](apps/landing/README.md) and [art direction](apps/landing/ART_DIRECTION.md).

## Shared project records

- [Project brief](PROJECT_BRIEF.md): scope and permissions.
- [Documentation index](docs/README.md): specifications, evidence, and acceptance gates.
- [Monorepo notes](docs/MONOREPO.md): path migration and independent build surfaces.
- [Build and deployment guide](docs/BUILD_GUIDE.md): checkout, app verification, local preview, and static hosting boundaries.
- [User guide](docs/USER_GUIDE.md): monitoring, history, settings, native 80% setup/recovery, and landing navigation.
- [Working record](WORKING_RECORD.md): dated progress, verification, and handoffs.

The Git repository remains at this root. App bundle identity and the existing `~/Library/Application Support/StatBatt` data location are preserved. Historical ignored root `.build/` evidence and the previously running root `dist/StatBatt.app` are retained; new builds use `apps/statbatt/`. Commit the source folders, not generated native artifacts or personal data.
