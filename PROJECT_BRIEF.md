# Project brief — StatBatt

Status: v1 implementation authorized October 2, 2026; local implementation in progress. Original brief dated 2026-10-01.

## Intent and user

Build a native menu bar app for Apple silicon MacBooks that replaces Energiza's monitoring and charging-management experience on macOS 27. The owner wants close functional parity, especially battery statistics and charge/discharge cutoffs. Use familiar interaction patterns with original code, branding, artwork, and copy.

## Required outcome

- Battery percentage, power source, charging state/reason, health/capacity, cycles, temperature, electrical readings, adapter information, and time estimates where available; explicit unavailable/stale values elsewhere.
- An Energiza-like menu panel, battery details, lower/upper charge thresholds, immediate actions, temperature protection, notifications, and preferences.
- Separate modes for native Apple limits, holding charge with external power retained, and intentional discharge to a cutoff. Every control is gated by independently verified capability.
- A small authenticated helper only for operations that need privilege; policy survives closing the UI, and reversible hardware changes have recovery and uninstall paths.
- A reliable first-device macOS 27 compatibility result before describing any charging capability as working.

## Acceptance and non-goals

Detailed acceptance IDs live in [SPEC.md](docs/SPEC.md) and are verified under [TEST_PLAN.md](docs/TEST_PLAN.md). V1 is acceptable only if the named target has verified monitoring, supported native limiting, and explicit charge/discharge control or a clearly accepted capability limitation. A monitor-only build is a useful intermediate result, not completion of the requested replacement.

No Intel support in V1, private entitlement bypass, SIP changes, kernel extensions, cloud account, telemetry, payment system, remote control service, or automatic deep discharge/calibration. Optional extended parity is staged in the spec and must remain visible as deferred rather than implied complete.

## Constraints and assumptions

- User confirmed Apple silicon on 2026-10-01. October 2 read-only diagnostic identified Mac16,13 and firmware mBoot-20457.1.29.
- Read-only host checks found macOS 27.0.1 / 26A434, arm64, Xcode 27.0 / 27A266a. These are environment observations, not hardware control evidence.
- Existing Energiza helper reports both charge-control variants unsupported while detecting adapter disconnection variant 2. See [failure analysis](docs/research/ENERGIZA_FAILURE.md).
- Free-first local development. Developer Program entitlement, distribution budget, and final open-source license have not been established.
- Owner approved implementation of the populated v1 spec and plan on October 2, 2026, then explicitly requested a team pursuant to project guidance. Proceed with local software implementation of the agreed flows; hardware writes, helper installation, spending, publication and release remain separate gates.

## Permissions and next decision

No purchases, publication, deployment, helper installation, or unrestricted hardware writes are authorized. On October 2 the owner explicitly authorized the bounded native80% test and restoration in LAB_PROTOCOL.md; that test is complete. Other hardware experiments remain gated. Local source, tests, app packaging, read-only diagnostics, and team review are authorized. After being told that supported Apple interfaces cannot detect every later shortcut edit, the owner explicitly approved trusting the configured shortcut: “yes statbatt may trust the shortcut.” This accepts the narrowly scoped mutable-workflow trust exception in [decision0002](docs/decisions/0002-trusted-user-native-shortcut.md); it does not authorize executing unrelated shortcuts or additional hardware experiments. The full v1 acceptance criteria remain in force. Git is locally initialized on implementation/v1; author email and remote must be established before commit/push/PR delivery.
