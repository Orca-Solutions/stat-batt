# StatBatt — archived project

Development ended on **October 17, 2026**. StatBatt is preserved as an unfinished native Apple silicon macOS menu bar battery app. No further development, support, or public app release is planned. The landing page remains as a project archive.

Start with [the archive record](ARCHIVE.md) for the final app state, preserved work, known limitations, and hosting handoff. Older plans and acceptance gates are historical records, not active commitments.

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

App sources and scripts are self-contained in `apps/statbatt/`. Generated SwiftPM caches and the app bundle stay in that directory. These commands are retained for source inspection and local development; there is no supported installer. See the [app README](apps/statbatt/README.md) and [final build-14 evidence](docs/research/THERMAL_BUILD14_LOCAL_ACCEPTANCE.md).

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

## Delivery workflow

The [delivery workflow](docs/WORKFLOW.md) is retained with the other project records. It does not imply ongoing maintenance.

## Shared agent instructions

`AGENTS.md` and `CLAUDE.md` are shared project instructions and stay tracked in this repository so local and cloud agents can read them. Keep personal overrides in ignored `CLAUDE.local.md`; credentials and session state stay private. Existing project-specific instructions and permissions continue to apply.
