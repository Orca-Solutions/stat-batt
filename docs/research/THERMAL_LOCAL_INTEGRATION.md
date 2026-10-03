# Local thermal integration — October 3, 2026

Public Developer ID signing and notarization are deferred at the owner's request. This does not mark automatic temperature control accepted. The working native 80% / 100% shortcuts remain the supported charging controls.

## Implemented integration

The local development application now includes temperature threshold preferences, authenticated background-service setup, estimated-temperature status, and restore-before-native/quit coordination. Enabling is never persisted. All application termination routes use the restoration check, including Command-Q. A separate uncertainty marker survives a lost reply; it is not authorization to resume a session.

The daemon accepts a bounded, versioned action protocol from Apple-signed, same-team, fixed-identifier clients belonging to the active console user. Client-supplied UIDs, executable paths, arbitrary keys and raw hardware values are not accepted. Connections are identified by server-created UUIDs; invalidation closes pending qualification admission. The legacy status endpoint cannot authorize uninstall of a write-enabled qualification candidate.

The daemon loads the durable ownership ledger, attempts owned recovery on startup and disconnection, and handles public sleep/wake notifications. OS sleep acknowledgement follows the recovery attempt; a failed attempt remains unresolved, and acknowledgement is not evidence that adapter power was restored. Forced power loss cannot be vetoed by this software.

The concrete backend resolves a fixed, same-team signed guardian executable from the protected installation. The guardian uses a separate process, fixed two-second maximum, ownership and writer locks, and a restricted root journal. It reaps its writer before restoration and responds to owner EOF and sleep. Inspection is read-only. Inhibition and recovery have separate source gates; repository defaults do not permit writes.

A separate one-shot qualification action is implemented, independently of temperature policy. It records intent before dispatch, seeks fresh battery-source evidence, and checks restoration. It cannot authorize recurring cycles or longer holds. The normal local package does not expose this test because its source gates remain disabled.

## Installation

The local unsigned Installer package contains Apple Development-signed code. It is intended for this Mac, not public distribution. Its protected payload is `/Library/Application Support/StatBattLocal/StatBatt.app`, with a separate `StatBatt Local.app` launcher in Applications. The protected installation avoids trusting a user-writable privileged executable. Existing native app and Shortcuts are preserved. Installer requires the owner's macOS administrator authorization. Service registration is performed by the signed-in user from the app; it is not performed as root by a package script.

The first-install package refuses an existing local-service target. The separate `--update` package now requires a stopped app and unregistered launchd service, same-team Apple signatures, restrictive root ownership, a restored-or-missing ownership journal, and fresh zero-key/AC read-only inspection. The signed client's unregister action requests `prepareUninstall` and requires `safeToExit`; the package itself never unregisters or performs recovery. Do not reopen the app between update admission and payload replacement. A guided local removal command and signed, fixed-path privileged removal helper are implemented in source. The command requires signed-client safe unregistration; the helper repeats the full read-only preflight, atomically moves the verified app aside, then removes only that bundle and its exact launcher. User data, shortcuts and recovery records remain. This helper is not present in the already installed build 10 until a reviewed update deploys it; its removal behavior has not been exercised on the live installation. Apple shortcut imports still require Apple's own Add Shortcut approval when missing; bundled exports and missing-only setup remove manual shortcut construction.

## What is still unverified

Build12 completed the owner-operated app-to-daemon one-shot test: the service observed battery supply and verified restoration, with matching retained UI and authenticated status results. The separate user-level recorder stayed on AC; independent electrical corroboration is not claimed. Earlier build9/11 attempts remain inconclusive. Earlier Python-supervised two-second, owner-loss and sleep trials establish scoped evidence for the mechanism, not for this new executable implementation. No long pause or unattended recurring temperature session is qualified. The registry temperature remains estimated, and the policy reducer still refuses to treat it as a verified thermal protection sensor. Automatic `start` therefore returns unavailable, even if the one-shot qualification backend is enabled in an isolated candidate.

Completing temperature control requires reviewing and running a fixed one-shot candidate, lifecycle tests of that candidate, and qualification of the implemented estimated-sensor convenience-policy admission. The reducer keeps estimated quality and requires exact platform/source matching; it never manufactures verified sensor capability. It must not be described as production thermal protection or silently unlocked by a successful two-second test.

## Candidate review findings

Review found and repaired a restoration hazard: writing status to a closed daemon output pipe could deliver SIGPIPE to the guardian. The guardian now ignores SIGPIPE before reporting anything; a disconnected output reader must not terminate restoration. Other repairs distinguish a completed inspection process from a hardware writer, reserve backend serialization before suspension points, and require post-call fresh key/source evidence instead of reusing the inhibit acknowledgement. A separate inherited writer lease prevents a replacement guardian from racing an orphaned writer.

These changes are software-reviewed safeguards, not executed hardware evidence. Build 11 adds worker self-restoration on guardian EOF, sleep, deadline or hardware failure, with an independent two-second lease and sleep assertion. A READY/G handshake excludes signature/startup time from that lease. The guardian requests cooperative restoration before forced termination and its own fallback. Both processes use nonblocking output and ignore SIGPIPE. These paths have software tests but no exact-build hardware qualification yet. A shared kernel/firmware failure or guardian failure during forced-kill escalation remains outside a universal recovery guarantee.

The proposed next hardware qualification is one explicit in-app action with a nonrenewable two-second guardian limit, normal thermal pressure, AC baseline, and at least 50% charge. It may observe a brief transition to battery power, then must verify zero key readback and AC supply before clearing ownership. It does not request sleep, repeat itself, modify Apple's charge limit, or enable temperature policy. Candidate identity and hashes must be recorded after local signing, before requesting that test.

## Installed build 10 checkpoint

Build 10 is installed at the protected path, with exact installed executable hashes verified against its reviewed package by the coordinating agent. The service is registered. A read-only status query reported `adapterRestored: true`, `safeToExit: true`, `controlAvailable: false`, and `qualificationAvailable: true`. This is a restored baseline and available one-shot button, not evidence of a successful test or automatic temperature support.

Build 9's owner-triggered app-path test was inconclusive: the independent power-source trace stayed on AC, and its UI lost the specific result. Build 10 deploys persistent test feedback, visible status-check results, coalesced reads and sanitized diagnostics. No additional build 10 hardware test is claimed. Public signing/notarization remain deferred; local signing and installation are no longer blocked by the earlier locked-Keychain checkpoint.

The normal repository retains disabled write gates. Qualification packages use isolated gate changes; automatic start remains refused. The earlier 200-test checkpoint and later 204-test feedback checkpoint are recorded in the one-shot evidence document. Installer-specific fixture tests now exercise the actual preflight's restored journal validation and fresh zero/AC observation admission without calling hardware or service APIs.

Remaining owner validation: verify both native buttons still change Apple's limit in the installed build, confirm persisted test feedback and Check status are visible, and validate missing-shortcut import on a clean user profile. Apple Add Shortcut and any Background Items/admin approvals are OS-operated. A new one-shot hardware test requires separate authorization; guardian-death recovery and unattended recurring temperature control remain unqualified.

## Build 11 software completion checkpoint

The source now connects a five-second policy loop to the tested orchestrator, with an independent one-second lease watchdog, 15-second heartbeat expiry, one-hour absolute session limit, active-user checks, and restoration on stop, owner loss and sleep. Consent is never persisted. The automatic qualification record remains nil; no source or app action can infer automatic permission from a successful one-shot result. The current guardian's two-second limit is not sufficient for an operational long temperature pause.

Native shortcut admission is fenced durably before restoration/dispatch. A lost connection or restart requires explicit owner confirmation that the previous shortcut finished or stopped. Pending native requests block removal; installer preflight independently verifies the persisted marker. Ordinary completed requests clear their own fence. Idle UI service polling is 30 seconds, active/recovery polling five seconds.

Full software suite passed 218 tests (69 XCTest +149 Swift Testing), with zero failures, at `/private/tmp/statbatt-v1-completion-tests.log`. Installer preflight fixtures separately pass for restored ownership, fresh zero/AC observations and cleared native requests. The build 11 signed package is prepared; installation and hardware execution remain pending. This is implementation progress, not v1 temperature acceptance.

## Current installed checkpoint: build12

Build12 is installed and its single approved test succeeded in the service/guardian observations. Automatic policy remains off. Worker/guardian-loss and sleep recovery of this exact executable remain unqualified. New source-only backend fixes serialize read-only inspection with mutation admission; they are not deployed and do not alter the pinned installed guardian used for the next lab. Public Developer ID membership/signing remain optional for continued local development and are deferred.
