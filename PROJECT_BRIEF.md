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
- Free-first local development. The owner selected a proprietary Orca Solutions license. Developer Program entitlement, distribution budget, and a production signing identity have not been established.
- Owner approved implementation of the populated v1 spec and plan on October 2, 2026, then explicitly requested a team pursuant to project guidance. Proceed with local software implementation of the agreed flows; hardware writes, helper installation, spending, publication and release remain separate gates.

## Permissions and next decision

No purchases, publication, deployment, helper installation, or unrestricted hardware writes are authorized. On October 2 the owner explicitly authorized the bounded native80% test and restoration in LAB_PROTOCOL.md; that test is complete. Other hardware experiments remain gated. Local source, tests, app packaging, read-only diagnostics, and team review are authorized. After being told that supported Apple interfaces cannot detect every later shortcut edit, the owner explicitly approved trusting the configured shortcut: “yes statbatt may trust the shortcut.” This accepts the narrowly scoped mutable-workflow trust exception in [decision0002](docs/decisions/0002-trusted-user-native-shortcut.md); it does not authorize executing unrelated shortcuts or additional hardware experiments. The full v1 acceptance criteria remain in force. Git is locally initialized on implementation/v1; author email and remote must be established before commit/push/PR delivery.

## Monorepo and landing follow-up — 2026-10-02

The owner subsequently authorized organizing the native app and landing page into `apps/statbatt/` and `apps/landing/`, retaining shared `docs/`, coordinating with the app chat, verifying relocated builds/tests, and committing the landing work. This supersedes the prior local commit gate for the requested checkpoint, organization, and landing commits. The authenticated owner GitHub account is `jfricano` (ID44284799); repository-local commit attribution uses Jason Fricano and that account's private GitHub noreply address. The existing repository is preserved. No GitHub remote has been selected or configured. The owner plans a GitHub PR and deployment next; no push, PR, hosting operation, or native release is performed by the local organization work. Hardware and full v1 acceptance gates remain unchanged. Current commands and project entry points are in the root [README](README.md) and [monorepo notes](docs/MONOREPO.md).

## Organization repository and documentation follow-up — 2026-10-02

The owner explicitly authorized configuring the GitHub remote under Orca Solutions, selecting a proprietary license, pushing the setup/landing work, and opening a PR for landing rollout. The organization was verified as `Orca-Solutions`, named Orca Solutions. A new private [Orca-Solutions/stat-batt](https://github.com/Orca-Solutions/stat-batt) repository was created and configured as `origin`. The initial `main` base uses the existing pre-move app checkpoint; `codex/monorepo-landing` contains the monorepo, landing page, [proprietary license](LICENSE), [build/deployment guide](docs/BUILD_GUIDE.md), and [user guide](docs/USER_GUIDE.md). This authorization supersedes the earlier remote/source-publication gate for this private repository and PR. PR merge, hosting selection/production rollout, app release acceptance, spending, helper installation, and hardware experiments are not performed by repository setup.

## Full v1 completion team resumed — 2026-10-02

Owner requested a team to take the app through completion of the v1 spec. Implementation continues in an isolated worktree on `codex/app-v1-completion`, preserving the landing checkout. Product design, platform investigation, software hardening and fresh-context independent review participate. The original full acceptance criteria remain in force; no reduction has been accepted. The previous bounded native80% hardware test is complete; the owner separately authorized one app-path80% apply/visible verification/restart without replay/manual100% return. That owner-assisted build4 menu flow is now complete: visible80% confirmation, persisted request/confirmation across normal quit/reopen with no replay observed, and owner-verified permanent100% return recorded. Evidence and chronology limits are in docs/research/NATIVE_APP_FLOW_RESULT.md; no additional setting experiment is implied. After learning Apple has a built-in limiter, the owner reaffirmed finishing StatBatt for direct menu-icon → Apply80% convenience; build4 adds that button using the same guarded action. The reviewed read-only SMC probe ran without mutation and identified no verified custom backend. No helper installation, private entitlement, adapter write, spending or public app release follows from this completion request. See [candidate acceptance](docs/V1_ACCEPTANCE.md).

## Two-button native convenience — 2026-10-02

Owner explicitly requested one-click Set to80% / Set to100%, authorizing [decision0003](docs/decisions/0003-two-target-native-limit.md) and superseding mandatory manual100% return between ordinary successful requests. One-time trust remains separate for each fixed workflow; genuine unknown execution and exact-target qualification remain gated. The owner confirms the23:05UTC80% request was their deliberate click. Local implementation, packaging and review proceed; new100% hardware qualification is not yet authorized. Existing80% trust does not grant100% trust. Original full-v1 and release gates remain unchanged.
