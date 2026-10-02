# StatBatt

A native Apple silicon macOS menu bar battery app. The first local implementation provides live monitoring, details, seven-day history, CSV exports, settings, opt-in notifications, and redacted capability diagnostics.

**Apple80% limiting now has a trusted-shortcut setup and app flow on the qualified local target.** Custom charge bands, discharge cutoffs, thermal control and a privileged helper remain unavailable. The native setter/readback lab passed; end-to-end app interaction, cutoff and lifecycle checks are still pending. This is not the completed v1 Energiza replacement.

## Build and run

Requires Xcode with Swift 6 and a macOS SDK; no downloaded dependencies or paid services.

```sh
scripts/swift-local.sh test
scripts/build-app.sh
open dist/StatBatt.app
```

On the first interactive launch, StatBatt presents its Battery dashboard. Closing it keeps monitoring in the menu bar; later launches stay quiet. Click the menu bar battery to open the panel. **Details**, **History**, **Charging settings…**, and **Settings…** open the corresponding tab. Command-comma also opens Settings. A local ad-hoc signature permits development use; this is not a signed/notarized distribution candidate. Current target evidence is macOS 27.0.1 on arm64. The deployment minimum is macOS 15, but older OS versions and Intel have not been qualified.

Run the read-only diagnostic separately:

```sh
scripts/swift-local.sh run statbatt-diagnostics
```

The diagnostic exports allowlisted platform/metric fields, capability reasons, and versions. It excludes serials, usernames, home paths, raw registry dictionaries, and adapter identifiers. No shortcut, SMC control, helper installation, or hardware write occurs.

Local settings/history live in `~/Library/Application Support/StatBatt`. History can be paused, exported, or cleared. Gaps remain visible; missing measurements are never converted to zero. The qualified local target also shows reported physical capacities, estimated health, and estimated pack temperature through the newer macOS27 registry layout. Other advanced fields and unqualified target combinations remain unavailable. StatBatt does not replace a controller already installed on the Mac.

## Native Apple limit setup

After rebuilding, quit StatBatt from its menu-bar menu and reopen `dist/StatBatt.app`; closing the Details window does not quit the old process. Settings → About StatBatt identifies this candidate as **0.1.0 (2)**.

Open **Charging settings…**. A shortcut named **StatBatt — Apple Limit 80** must contain exactly one Apple **Set Battery Charge Limit** action set to80%. On the owner's development machine this is already prepared under the exact app name **StatBatt — Apple Limit 80**; inspect it before recording setup. Other user shortcuts were not edited.

Record the three setup declarations: inspected/trusted shortcut, Battery settings visibly showing the100% return baseline, and other charge-management apps stopped. StatBatt binds the shortcut's UUID, rejects missing/ambiguous/replaced identities and checks the known Energiza controller. It cannot detect every later action/parameter edit or exclude every external controller; the owner approved this trust model.

**Apply 80% limit** invokes the trusted shortcut from the app; manual shortcut execution is not the ordinary flow. Completion remains unverified until you check Battery settings and explicitly confirm80%. To return, first verify the shortcut finished or stop it in Shortcuts, then manually restore100% in Battery settings and record both declarations. A timeout/crash can leave an unknown result, which blocks another request. Killing the CLI does not prove that the underlying Shortcuts action stopped.

The setting is delegated to macOS and persists after app exit. There is no lower threshold, expiry, automatic restoration or guarantee of a precise electrical cutoff. Only80% on Mac16,13 / arm64 / macOS27.0.1 build26A434 / mBoot-20457.1.29 is qualified by the bounded setter lab. A different fingerprint disables Apply. New runtime hardware experiments are not performed by startup or tests.

## Implementation and verification

- [Implementation status](docs/IMPLEMENTATION_STATUS.md): acceptance mapping, limitations, pending gates.
- [Lab protocol](docs/LAB_PROTOCOL.md): concrete next native-action experiment and recovery conditions.
- [Specification](docs/SPEC.md), [architecture](docs/ARCHITECTURE.md), [API](docs/API.md), and [document index](docs/README.md): agreed build contract.
- [Working record](WORKING_RECORD.md): current evidence, review, and remaining work.

SwiftPM modules separate domain policy, telemetry, local storage, control contracts, diagnostics, and native UI. Control contract tests use synthetic inputs and do not certify hardware or production XPC authentication. No third-party package code was copied; SQLite is supplied by macOS. Product license, signing identity, remote, and release acceptance remain owner decisions before redistribution.
