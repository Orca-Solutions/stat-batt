# StatBatt

**Archived October 17, 2026.** Development and support have ended. The final saved
checkpoint is build 14; see [the archive record](../../ARCHIVE.md) and
[build-14 acceptance](../../docs/research/THERMAL_BUILD14_LOCAL_ACCEPTANCE.md).
The build instructions and earlier milestones below are retained as historical
development records. There is no signed/notarized public release.

V1 local candidate: native Apple 80%/100% charge-limit buttons, monitoring, history/CSV, diagnostics, preferences and opt-in alerts. The owner accepted native charging as the v1 scope; custom discharge, charge bands and temperature actuation are not required or claimed. See [scope decision](../../docs/decisions/0004-native-charging-v1.md).

## Build and run

Run these commands from the monorepo root.

Requires Xcode with Swift 6 and a macOS SDK; no downloaded dependencies or paid services.

```sh
apps/statbatt/scripts/swift-local.sh test
apps/statbatt/scripts/build-app.sh
open apps/statbatt/dist/StatBatt.app
```

On the first interactive launch, StatBatt presents Charging setup. Closing it keeps monitoring in the menu bar; later launches stay quiet. Click the menu bar battery to open the panel. **Details**, **History**, **Charging settings…**, and **Settings…** open the corresponding tab. Command-comma also opens Settings. A local ad-hoc signature permits development use; this is not a signed/notarized distribution candidate. Current target evidence is macOS 27.0.1 on arm64. The deployment minimum is macOS 15, but older OS versions and Intel have not been qualified.

Run the read-only diagnostic separately:

```sh
apps/statbatt/scripts/swift-local.sh run statbatt-diagnostics
```

The diagnostic exports allowlisted platform/metric fields, capability reasons, and versions. It excludes serials, usernames, home paths, raw registry dictionaries, and adapter identifiers. No shortcut, SMC control, helper installation, or hardware write occurs.

Local settings/history live in `~/Library/Application Support/StatBatt`. History can be paused, exported, or cleared. Gaps remain visible; missing measurements are never converted to zero. The qualified local target also shows reported physical capacities, estimated health, and estimated pack temperature through the newer macOS27 registry layout. Other advanced fields and unqualified target combinations remain unavailable. StatBatt does not replace a controller already installed on the Mac.

## Native Apple limit setup

The package includes signed **StatBatt — Apple Limit 80** and **StatBatt — Apple Limit 100** shortcut documents. On first launch, use each **Install … shortcut** button and approve Apple's **Add Shortcut** prompt. Then click **Enable charge buttons** after reviewing the trust/controller explanation. No manual action authoring is required. Already-installed workflows and trusted setup are preserved.

**Set to 80%** and **Set to 100%** were verified through the app on Mac16,13 / arm64 / macOS 27.0.1 / 26A434 / mBoot-20457.1.29. The app checks identity and known controller conflicts, persists intent before execution and never replays at startup. Unknown outcomes require review; ordinary completed requests need no repeated confirmation. Apple manages charging and retains the setting after StatBatt quits. The app cannot read the current selected limit or detect every later workflow edit.

Other fingerprints remain unqualified for charging. The older schema-1 app should not be reopened after migration to schema 2. For a rebuilt app, quit the older instance before launching this bundle. Build 8 is the 1.0.0 local candidate.

## Implementation and verification

- [Implementation status](../../docs/IMPLEMENTATION_STATUS.md): acceptance mapping, limitations, pending gates.
- [Lab protocol](../../docs/LAB_PROTOCOL.md): concrete next native-action experiment and recovery conditions.
- [Specification](../../docs/SPEC.md), [architecture](../../docs/ARCHITECTURE.md), [API](../../docs/API.md), and [document index](../../docs/README.md): agreed build contract.
- [Working record](../../WORKING_RECORD.md): current evidence, review, and remaining work.

SwiftPM modules separate domain policy, telemetry, local storage, control contracts, diagnostics, and native UI. Control contract tests use synthetic inputs and do not certify hardware or production XPC authentication. The normal app uses macOS frameworks and system SQLite. The standalone read-only probe’s permitted references and notices are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). StatBatt is [proprietary to Orca Solutions](../../LICENSE). Signing identity and release acceptance remain owner decisions before redistribution.

See the [build guide](../../docs/BUILD_GUIDE.md) and [user guide](../../docs/USER_GUIDE.md) for current instructions.

## Resumed completion candidate

Build3 adds expiry-aware monitoring display, readable history summaries and gap-safe power-state observations, charging/source and recovery-failure alerts, and explicit prerequisites for unavailable thermal/one-time controls. Build4 adds direct menu Apply80% and immediate release of acquired instance-lock ownership despite inherited descriptors; the integrated software suite passes131 tests. It remains a local candidate; [v1 acceptance](../../docs/V1_ACCEPTANCE.md) records open hardware, GUI, performance and distribution gates.

A separate `statbatt-hardware-probe` executable is read-only and accepts no arguments. Its [target metadata result](../../docs/research/SMC_READ_ONLY_QUALIFICATION.md) is not charging support. No privileged helper or hardware write was added.
