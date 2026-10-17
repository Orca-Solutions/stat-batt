# Proposed local API and data contracts

Status: v1 contract, 2026-10-01; domain models, strict request DTOs and non-actuating contract harnesses implemented 2026-10-02. Production XPC service, full reply DTOs, durable privileged journal/events and uninstall remain unimplemented. The normal-user native80% coordinator and local intent journal are implemented under owner-approved decision0002. See IMPLEMENTATION_STATUS.md. Units, state distinctions, replay behavior, and failure semantics are normative for implementation; Swift below is pseudocode. Hardware capabilities are empty/unsupported until verified. See [ARCHITECTURE.md](ARCHITECTURE.md) for ownership, authentication, and lifecycle rationale.

## Boundaries and transport

`TelemetryProvider` runs in the normal app without requiring the daemon. `NativeLimitCoordinator` is an optional normal-user integration with Apple's Shortcuts action. `PowerControlService` is the narrowly scoped privileged Mach-service XPC interface. It does not run shortcuts or subprocesses and is not an HTTP server. Product automation/Shortcuts integration, if added later, calls the normal app's validated use cases; it cannot directly invoke hardware operations.

Use Objective-C-compatible `NSXPCInterface` methods carrying bounded `NSData` containing versioned Codable JSON DTOs; method names fix their semantics. Configure allowed classes precisely, limit request/reply size, and reject malformed fields before policy evaluation. Proposed limits: request/reply 64 KiB, 1 MiB bounded export handled only in the app, 32 outstanding commands per authenticated connection, 1 event subscription per connection, 256 retained events. Reject NaN/infinity and out-of-range numeric values. Never expose SMC key strings, raw writes, command strings, executable/shortcut paths, arbitrary launchd labels, or root filesystem paths.

Apple exposes public `NSXPCListener.setConnectionCodeSigningRequirement` and `NSXPCConnection.setCodeSigningRequirement`. Set them before activation and require expected identifiers, Team ID, and production signature trust in both directions. EUID and audit session come from the connection, not request bodies; no PID-only authentication. [Apple listener requirement API](https://developer.apple.com/documentation/foundation/nsxpclistener/setconnectioncodesigningrequirement(_:)), [Apple connection requirement API](https://developer.apple.com/documentation/foundation/nsxpcconnection/setcodesigningrequirement(_:))

## Common envelopes

```swift
struct ProtocolVersion: Codable { let major: UInt16; let minor: UInt16 }
struct StateVersion: Codable, Equatable {
    let generation: UUID       // durable state lineage; changes on reset/corruption recovery
    let revision: UInt64       // increases on accepted config/override/owner/session changes
}
struct CommandContext: Codable {
    let protocolVersion: ProtocolVersion
    let commandID: UUID        // idempotency key
    let expected: StateVersion
    let controlSessionID: UUID // daemon-issued, bound to authenticated connection/user
}
struct AdminRecoveryContext: Codable {
    let protocolVersion: ProtocolVersion
    let commandID: UUID
    let externalAuthorizationForm: Data // exact kAuthorizationExternalFormLength bytes
    // No owner session required; helper authenticates the peer and checks its fixed admin right.
}
struct Receipt: Codable {
    let commandID: UUID
    let operationID: UUID?
    let version: StateVersion
    let outcome: Outcome       // acceptedPending, appliedVerified, noChange, rejected,
                               // partialFailure, outcomeUnknown
    let snapshot: ControlSnapshot
    let error: APIError?
}
struct APIError: Codable {
    let code: ErrorCode
    let retryable: Bool
    let retryAfterSeconds: Double?
    let details: [String: String] // fixed allowlist; no raw system dictionaries/secrets
}
```

An accepted command changes durable desired state before effect execution and increments the revision once. All mutations run through one daemon coordinator. `expected` is compare-and-swap: stale generation/revision returns `revisionConflict` plus current version, without changing hardware. Safety events may independently terminate an override and increment revision; ordinary telemetry does not increment config revision. Explicit Stop is allowed with a stale expected revision for an authenticated current owner because stopping must remain available; it reports the actual resulting version. It cannot enable, take ownership, or modify somebody else's settings.

Deduplicate before revision checking. Scope a command ID to the authenticated UID + command kind; persist an intent hash and result before effect execution. Same ID/same normalized payload returns the original receipt/current operation status; different payload returns `idempotencyConflict`. Include `expected` in that hash and do not “fix” a conflicting replay. Retain records for seven days; after expiry a retry is a new request subject to current revision and must not be silently replayed against fresh state. An interrupted write is resolved from the journal/readback on restart; never rerun ambiguous actuation merely because a reply was lost. Client request timeout does not cancel an accepted command.

Time fields use UTC RFC 3339 with fractional seconds for display/export and `UInt64` continuous nanoseconds plus boot UUID for ordering/durations. In-process safety timers use a continuous clock that includes sleep. Do not compare monotonic values across boots. Ephemeral overrides cancel on boot. Persisted expiry is conservatively checked at startup, and a wall-clock jump never extends a live override. Percentages are `Double` in 0…100 and threshold differences are percentage points. All numeric units are explicit in field names.

## Telemetry contract

```swift
enum ValueQuality: String, Codable {
    case observed, derived, estimated, unavailable, stale, invalid
}
struct Metric<Value: Codable>: Codable {
    let value: Value?           // required nil for unavailable/invalid
    let quality: ValueQuality
    let sampledAtUTC: String
    let sampledAtContinuousNanoseconds: UInt64
    let source: String         // stable provider ID, not a guessed sensor name
    let unavailableReason: String?
}
struct BatterySnapshot: Codable {
    let bootID: UUID
    let sequence: UInt64
    let batteryPresent: Metric<Bool>
    let stateOfChargePercent: Metric<Double>
    let rawStateOfChargePercent: Metric<Double>
    let isCharging: Metric<Bool>
    let adapterAttached: Metric<Bool>
    let supplyingSource: Metric<PowerSource> // battery, adapter, UPS, unknown
    let batteryCurrentMilliamps: Metric<Double> // + into battery, - out; normalized
    let batteryVoltageMillivolts: Metric<Double>
    let batteryPowerWatts: Metric<Double>   // + charging, - discharging
    let adapterRatedWatts: Metric<Double>   // rating, distinct from observed draw
    let adapterObservedInputWatts: Metric<Double>
    let batteryTemperatureCelsius: Metric<Double>
    let cycleCount: Metric<UInt64>
    let fullChargeCapacityMilliampHours: Metric<Double>
    let designCapacityMilliampHours: Metric<Double>
    let healthPercent: Metric<Double>       // derived FCC/design; separate OS condition
    let operatingSystemCondition: Metric<String>
    let timeToEmpty: TimeEstimate
    let timeToFull: TimeEstimate
    let thermalPressure: Metric<ThermalPressure> // nominal/fair/serious/critical/unknown
}
enum TimeEstimate: Codable {
    case seconds(Double, provenance: String)
    case unlimited, calculating, unavailable(reason: String)
}
protocol TelemetryProvider {
    func snapshot() async -> BatterySnapshot
    func updates() -> AsyncStream<BatterySnapshot>
}
```

Never convert missing values/sentinels to zero, calculate watts from a stale or mismatched current/voltage pair, or call adapter rating real-time power. Validate sensor encoding and current sign in the hardware matrix. Health may exceed 100% if observed capacities warrant it; don't silently cap the exported value. UI can explain rather than fabricate precision. Battery identity is an ephemeral local token, not its serial number.

Public IOPowerSources change notifications trigger refreshed snapshots. Filter UPS/external batteries from internal-Mac charging policy; missing internal battery yields monitor-only. `IOPSGetTimeRemainingEstimate` has special unknown/unlimited sentinels; despite its summary mentioning minutes, Apple's return-value section specifies positive values in **seconds**, matching `CFTimeInterval`. Description-dictionary estimate keys may use other units and require separate documented conversion. [Apple IOPowerSources](https://developer.apple.com/documentation/iokit/iopowersources_h), [Apple estimate return value](https://developer.apple.com/documentation/iokit/1523835-iopsgettimeremainingestimate)

## Capabilities and platform provenance

```swift
enum SupportStatus: String, Codable {
    case unsupported, unknown, restricted, verified, temporarilyUnavailable
}
enum EnforcementScope: String, Codable {
    case none, appleDelegated, awakeOnly, hardwarePersistentVerified
}
struct Capability: Codable {
    let status: SupportStatus
    let scope: EnforcementScope
    let reasonCode: String?
    let evidence: [EvidenceReference]
    let verifiedAtUTC: String?
    let maximumObservedActuationLatencySeconds: Double?
    let restorationVerified: Bool
    let crashRecoveryBoundSeconds: Double?
}
struct CapabilitySnapshot: Codable {
    let capabilityRevision: UInt64
    let platform: PlatformFingerprint // model, arch, OS/build, firmware, provider version
    let canMonitorInternalBattery: Capability
    let canHoldChargePreservingAC: Capability
    let canInhibitAdapter: Capability
    let canReadControlState: Capability
    let canRestoreOwnedControl: Capability
    let canSetNativeChargeLimit: Capability
    let allowedNativeLimitsPercent: [Double] // verified discrete values; empty if unknown
    let nativeCurrentLimitReadable: Bool
    let nativeRestorationMode: String        // observedBaseline/userAgreedReturnLimit/none
    let canObserveBatteryTemperature: Capability
    let verifiedBatteryTemperatureBoundsCelsius: ClosedBounds?
    let restrictions: [Restriction] // operation, observed/reported provenance, URL/lab case
}
```

`verified` is exact-combination test evidence, not “OS version >= 27” or “root available.” A report of entitlement-gated access is `reported` restriction evidence until confirmed locally; the UI distinguishes it from an observed permission error. A probe is read-only; never test support by toggling hardware. Presence of a key or successful API return does not prove a working cutoff. Capability downgrade invalidates affected operations and emits a safety event; it never activates another mode. Sleep support is an independent scope, not inferred from launchd persistence.

## Policy and control state

```swift
struct RangePolicy: Codable {
    let enabled: Bool
    let resumeAtPercent: Double     // proposed default 70
    let holdAtPercent: Double       // proposed default 80
    let reserveFloorPercent: Double // proposed minimum/default 20
    let backend: CustomBackend     // trueChargeHold / adapterCycling
    let adapterCyclingConsent: ConsentRecord? // separate opt-in, never inferred
    let temperatureGuardEnabled: Bool
    let maximumBatteryTemperatureCelsius: Double? // within verified provider bounds
    let resumeBatteryTemperatureCelsius: Double?  // < maximum; hysteresis
}
enum OverrideGoal: Codable {
    case allowCharging(untilPercent: Double)
    case holdCharging
    case discharge(untilPercent: Double)
}
struct OverrideRequest: Codable {
    let goal: OverrideGoal
    let expiresAfterSeconds: Double // >0 and <=86_400; daemon computes deadline
}
struct ControlSnapshot: Codable {
    let version: StateVersion
    let daemonInstanceID: UUID
    let owner: OwnerSummary         // controlledByThisUser/otherUser/unclaimed
    let serviceState: ServiceState  // notRegistered/requiresApproval/enabled/unavailable
    let mode: Mode                 // monitor/nativeDelegated/custom
    let phase: Phase               // disabled/recovering/armed/applying/holding/
                                   // chargingPermitted/discharging/suspended/recoveryRequired/
                                   // nativeTransitioning/nativeDelegated/nativeOutcomeUnknown
    let nativeFence: NativeFenceSummary? // ID, generation, owner relation, phase, evidence
    let policy: RangePolicy?
    let override: ActiveOverride?
    let desiredEffect: ControlEffect
    let observedEffect: ObservedControlEffect // each field observed/unknown/conflict
    let appliedAtUTC: String?
    let suspensionReasons: [String]
    let capabilities: CapabilitySnapshot
    let latestSafetyTelemetry: BatterySnapshot?
    let cleanup: CleanupStatus      // restoredVerified/pending/partial/unknown/notOwned
}
```

Service registration state is an app-side SMAppService observation and carries provenance; the daemon cannot truthfully claim its own unavailable/not-running condition. Combined application status explicitly distinguishes last known daemon state from fresh status. `chargingPermitted` means our restriction is released, never “battery must be charging.” `holding` requires verified readback; a receipt pending verification is `applying`. `adapterAttached`, `supplyingSource`, `desiredEffect`, and `observedEffect` remain distinct.

Validation: finite thresholds with 10 <= resume < hold <=100, gap >=2pp for true hold or >=5pp for adapter cycling, reserve >=20, adapter-cycling resume >=reserve, temperature guard only with validated sensor/bounds, supported restoration/readback, and explicit fallback consent. When the temperature guard is enabled both temperatures must be finite, within verified sensor/provider bounds, and resume < maximum. Proposed product defaults are pause40°C/resume37°C, subject to the provider gate; they are not universal chemical safety limits. Reaching maximum latches the guard; resume requires a fresh sample <=resume and cleared system thermal pressure. Override discharge target >=reserve and below current fresh SOC; charge target >current SOC unless already satisfied. Manual hold requires the true-hold capability; it cannot secretly select adapter inhibition. Safety overrides manual requests. Clamp nothing silently: return `invalidConfiguration` with the offending fixed field name.

## Privileged XPC surface

```swift
@objc protocol PowerControlService {
    // JSON Data payloads; per-method typed DTO specified below.
    func negotiate(_ request: Data, reply: @escaping (Data) -> Void)
    func getCapabilities(_ request: Data, reply: @escaping (Data) -> Void)
    func getState(_ request: Data, reply: @escaping (Data) -> Void)
    func enrollOwner(_ request: Data, reply: @escaping (Data) -> Void)
    func openControlSession(_ request: Data, reply: @escaping (Data) -> Void)
    func beginNativeDelegation(_ request: Data, reply: @escaping (Data) -> Void)
    func resolveNativeDelegation(_ request: Data, reply: @escaping (Data) -> Void)
    func setPolicy(_ request: Data, reply: @escaping (Data) -> Void)
    func startOverride(_ request: Data, reply: @escaping (Data) -> Void)
    func cancelOverride(_ request: Data, reply: @escaping (Data) -> Void)
    func stopAndRestore(_ request: Data, reply: @escaping (Data) -> Void)
    func getOperation(_ request: Data, reply: @escaping (Data) -> Void)
    func subscribe(_ request: Data, reply: @escaping (Data) -> Void)
    func acknowledgeEvents(_ request: Data, reply: @escaping (Data) -> Void)
    func unsubscribe(_ request: Data, reply: @escaping (Data) -> Void)
    func prepareUninstall(_ request: Data, reply: @escaping (Data) -> Void)
    func finalizeUninstall(_ request: Data, reply: @escaping (Data) -> Void)
}
@objc protocol PowerControlEvents {
    func receive(_ event: Data)
}
```

| Method | Request payload | Reply and semantics |
| --- | --- | --- |
| negotiate | Supported major/minor ranges, app version | Chosen version, instance ID, max bytes, capabilities; no control token |
| getCapabilities / getState | Protocol version | Fresh snapshot or `recovering`; no owner acquisition |
| enrollOwner | AdminRecoveryContext + expected version + enrollment/transfer intent | Fixed admin right checked in helper; derive UID from connection; refuses active ownership transfer until restored; authorization bytes never persisted |
| openControlSession | Protocol version, requested read/control role | Authenticated owner only gets connection-bound token; expires on disconnect; one machine owner |
| beginNativeDelegation | CommandContext + fixed native intent | Durably disables custom automation/overrides and persists native fence; returns fence readiness only after custom owned restoration is verified; never runs a shortcut |
| resolveNativeDelegation | Tagged owner CommandContext **or** AdminRecoveryContext + native fence UUID + disposition/evidence | Owner may record native applied/unknown outcome; owner or fresh-admin recovery may clear fence only after native restoration/reconciliation; admin branch cannot apply native intent, enable custom policy, or change original owner/fence attribution |
| setPolicy | CommandContext + complete RangePolicy | Atomic replace validated desired config, receipt; enable only exact verified custom backend |
| startOverride | CommandContext + OverrideRequest | Replaces prior override atomically after safely reconciling existing effect; target/deadline returned |
| cancelOverride | CommandContext | Removes override, re-evaluates configured policy; does not disable range management |
| stopAndRestore | Tagged owner CommandContext **or** AdminRecoveryContext + fixed reason enum | Cancels all custom automation, restores owned fields, returns verified/partial/unknown cleanup; allowed despite stale revision; admin context works without owner's session |
| getOperation | Protocol version + command/operation UUID | Latest receipt; `operationNotFound` if unavailable; no re-execution |
| subscribe | Protocol version + optional cursor | Subscription ID, atomic initial full snapshot and watermark, subsequent callbacks |
| acknowledgeEvents | Subscription ID + delivered cursor | Releases bounded buffer; no mutation of power state |
| unsubscribe | Subscription ID | Idempotent; no change to approved policy |
| prepareUninstall | Tagged owner CommandContext **or** AdminRecoveryContext | Restore, freeze mutations, return readiness receipt only if verified; fails safely otherwise; no owner session required in admin branch |
| finalizeUninstall | Readiness receipt + command ID | Deletes only fixed project state after restoration; no hardware write/path argument; final receipt before app unregisters service |

The readiness receipt is daemon-issued, requester-UID/instance/version-bound, expires after five minutes, and is invalidated by any policy/hardware state change. Its requester may be the owner or an authenticated fresh-admin recovery peer; the admin branch does not acquire the owner's normal session or policy ownership. `prepareUninstall` first rejects an unresolved native fence with `uninstallNotReady`; the normal app must complete native restoration/reconciliation before calling it. It blocks new control sessions/mutations until finalized or explicitly aborted via owner session re-open after rechecking state. Receipt expiry does not re-enable any policy. Call `finalizeUninstall` while the daemon remains reachable, receive its final receipt, then unregister using SMAppService and verify service status. Unregistration is not a daemon endpoint running a shell. Apple documents register/unregister and service status as the supported lifecycle APIs. [Apple SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)

## Native delegated interface

```swift
protocol NativeLimitCoordinator {
    func inspect() async -> NativeLimitStatus
    func setLimit(_ request: NativeLimitRequest) async -> NativeLimitReceipt
    func restoreAgreedLimit(_ request: NativeRestoreRequest) async -> NativeLimitReceipt
}
struct NativeLimitRequest: Codable {
    let commandID: UUID
    let expected: StateVersion
    let nativeFenceID: UUID?  // required when a helper is installed
    let limitPercent: Double
    let agreedReturnLimitPercent: Double?
    let baselineProvenance: String // observed or explicitUserConfirmation
}
```

When the helper is installed, the daemon serializes native/custom arbitration. `beginNativeDelegation` persists `{fenceID, ownerUID, generation, phase: restoringCustom, commandID}` before changing controls, disables custom policy and overrides, restores owned controls, then persists `readyForNative`. The readiness receipt and normal-app native request bind the fence and current state version. No shortcut runs until readiness is verified. `resolveNativeDelegation(nativeApplied)` records the native outcome; an unknown result retains `nativeOutcomeUnknown`. While any fence exists, `setPolicy(enabled: true)` and custom overrides return `nativeModeFenced`. Stop can restore custom remnants but cannot clear the fence or claim native restoration.

The fence survives app/daemon crash, disconnect, reboot, and control-session replacement; fetch it from `getState` after reconnect and query command outcome before replay. It is UID/state-generation-bound, not a reusable bearer token. The owner normally resolves it; a fixed fresh-admin recovery branch can resolve only restoration/reconciliation without an owner session and cannot apply a new native intent or claim policy ownership. Cross-user transfer requires fresh admin approval and explicit native reconciliation before new control. No TTL automatically releases it. To leave native mode, the normal app restores/reconciles the native setting and calls `resolveNativeDelegation(nativeRestored)` with an observed current-limit result or an explicit visible user confirmation carrying the agreed setting and provenance. Shortcut exit success alone is insufficient. If observability or confirmation is absent, retain the fence. Clearing it leaves custom disabled; a separate revisioned enable is required. The daemon cannot independently validate the native setting through a privileged setter that does not exist; manually reconciled status remains labeled as such.

Native-only installations without a helper use a normal-user singleton coordinator and local intent journal. They cannot claim machine-wide exclusion of external controllers/other users; the app has no persistent privileged custom policy in this configuration. Before a helper is subsequently enabled, reconcile any local native intent and initialize the daemon fence/owner state rather than silently activating custom control.

Exact allowed values come from successful lab tests, not a guessed continuous 0…100 range. Native receipt distinguishes `shortcutCompleted`, `limitSettingObserved`, and `chargingBehaviorObserved`. No lower resume threshold is offered in delegated mode. A visible user-agreed return limit is not an automatically observed previous setting. Native expiry is unsupported until a tested mechanism can restore the setting after app exit, logout, and sleep. Apple documents executing a named shortcut and its exit status; this is evidence for transport, not hardware confirmation. [Apple Shortcuts CLI](https://support.apple.com/en-nz/guide/shortcuts-mac/apd455c82f02/mac)

## Streaming and reconnect

Each event has `{daemonInstanceID, sequence, producedAtUTC, type, payload}`. Types include `stateChanged`, `capabilitiesChanged`, `telemetryChanged`, `operationCompleted`, `safetyAction`, `recoveryRequired`, and `resyncRequired`. Sequence numbers are strictly increasing within an instance. Subscription atomically takes a snapshot at sequence N then streams N+1 onward; no gap between initial fetch and subscription. Telemetry events may coalesce; control/safety events remain ordered. If a subscriber exceeds the bounded buffer or resumes beyond retained history, issue `resyncRequired` and provide a full snapshot. Never let a stalled GUI block safety evaluation.

On interruption/invalidation, mark control observation stale immediately, reconnect with bounded exponential backoff (1/2/4/8/16/30 seconds plus jitter), negotiate again, establish a new session, obtain fresh state/capabilities, then resubscribe using the old cursor only if the instance matches. Query in-flight operation IDs before considering a replay. Show “helper disconnected; control status unknown” instead of “stopped.” A connection loss does not silently disable a previously approved persistent custom policy. UI can continue independent telemetry.

## Error codes

| Code | Meaning and client response |
| --- | --- |
| unauthenticatedPeer / authorizationDenied | Reject connection or operation; no automatic downgrade to insecure transport |
| ownerConflict / controlSessionExpired | No takeover; refresh status or explicitly authorize transfer |
| protocolMismatch / malformedRequest / payloadTooLarge | Do not retry unchanged; show update/configuration issue |
| revisionConflict / idempotencyConflict | Refresh state; preserve user intent; never auto-change replay payload |
| unsupportedPlatform / capabilityRestricted / capabilityChanged | Disable affected controls; continue monitoring; show operation-specific reason |
| helperRequiresApproval / helperUnavailable | App-side registration/connectivity error; offer documented system approval route |
| invalidConfiguration / unsafeReserve / temperatureUnavailable | Explain rejected field/guard; no silent clamping |
| noInternalBattery / adapterUnavailable / telemetryStale / thermalGuardActive | Suspend/end relevant control; emit safety reason |
| ownershipConflict / providerReadFailed / providerWriteFailed / verificationFailed | Attempt only owned restoration; show exact observed/unknown status |
| recoveryRequired / restoreFailed / outcomeUnknown | Retain journal/helper, block new actuation, use status/recovery flow |
| rateLimited / operationNotFound / resyncRequired | Respect retry delay or obtain full state; do not duplicate hardware writes |
| uninstallNotReady / nativeLimitUnobservable / nativeShortcutUnavailable | Preserve components/settings; explain missing verification or setup |
| nativeModeFenced | Persisted native setting/fence prevents custom control; reconcile explicitly without automatic expiry |

Errors contain a stable code, safe localized message key, retry hint, current version when authorized, and fixed diagnostic keys. Authorization forms, battery serials, raw registry dictionaries, local usernames, full file paths, and opaque hardware buffers are not logged or returned. Diagnostics export is local and user initiated.

## Provider seam and acceptance

```swift
protocol HardwareControlProvider {
    func probeReadOnly() async -> CapabilitySnapshot
    func readControlState() async throws -> ProviderObservedState
    func captureBaseline() async throws -> OwnedBaseline
    func apply(_ effect: AllowlistedEffect, ownership: OwnershipToken)
        async throws -> VerifiedProviderResult
    func restoreOwned(_ baseline: OwnedBaseline, lastApplied: ProviderObservedState)
        async -> RestorationResult
}
// AllowlistedEffect: releaseOwnedControls, holdChargingPreservingAC, inhibitAdapter.
// Compound safety plans are orchestrated and journaled; no arbitrary register/key API.
```

`UnsupportedProvider` performs no writes and returns explicit unsupported reasons. Test-only mock providers simulate readback failure, stale telemetry, sleep, and crashes with a prominent synthetic-data label. Daemon production builds cannot select a mock provider through environment variables or client DTOs. Provider output never bypasses exact capability verification or policy validation.

Implementation acceptance requires serialization, unit/sentinel handling, authenticated connection rejection, owner transfer, compare-and-swap race, replay after lost reply/restart, expiry across sleep/clock changes, stream overflow/reconnect, partial write, owned restoration, capability downgrade, and two-phase uninstall tests. Mode-fence tests cover persistent custom policy surviving GUI loss, interrupted native transition, helper reboot/reconnect, second-user attempts, missing native observation, and TTL expiry without custom reactivation. Hardware and native action tests remain separate mandatory release gates; passing DTO/reducer tests establishes no real charging capability.


## Implemented native-only boundary

`NativeLimitCoordinator` accepts only `NativeFixedLimit.eighty` or `.hundred`. Per-target setup binds the expected named UUID and its own trust. Dispatch uses fixed normal-user `/usr/bin/shortcuts` arguments, repeated preflight, durable intent and same-account advisory lock. No privileged service runs. Production qualification currently includes only80% on the exact tuple. The separate compile-flag, durable one-use100% trial never adds100% to allowed production limits.

Schema2 preserves per-target trust, requested target/time, historical observation, unknown execution and qualification-attempt time. Atomic schema1 migration preserves80% trust without100% trust. Pending/unknown and legacy manuallyConfirmed80 stay fenced. A normal acknowledged request permits another deliberate qualified request. Startup never retries or replays. Unknown execution requires explicit finished/stopped plus visible80/100 reconciliation; observation or CLI termination alone is insufficient.

Storage faults and missing/ambiguous/replaced identities block dispatch. Later workflow edits cannot all be detected. No automatic expiry/restoration or machine-wide exclusion is offered. Later helper enrollment must reconcile this journal before enabling custom control. See [decision0003](decisions/0003-two-target-native-limit.md).
