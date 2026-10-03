# Local thermal integration — October 3, 2026

Public Developer ID signing and notarization are deferred at the owner's request. This does not mark automatic temperature control accepted. The working native 80% / 100% shortcuts remain the supported charging controls.

## Implemented integration

The local development application now includes temperature threshold preferences, authenticated background-service setup, estimated-temperature status, and restore-before-native/quit coordination. Enabling is never persisted. All application termination routes use the restoration check, including Command-Q. A separate uncertainty marker survives a lost reply; it is not authorization to resume a session.

The daemon accepts a bounded, versioned action protocol from Apple-signed, same-team, fixed-identifier clients belonging to the active console user. Client-supplied UIDs, executable paths, arbitrary keys and raw hardware values are not accepted. Connections are identified by server-created UUIDs; invalidation closes pending qualification admission. The legacy status endpoint cannot authorize uninstall of a write-enabled qualification candidate.

The daemon loads the durable ownership ledger, attempts owned recovery on startup and disconnection, and handles public sleep/wake notifications. OS sleep acknowledgement follows the recovery attempt; a failed attempt remains unresolved, and acknowledgement is not evidence that adapter power was restored. Forced power loss cannot be vetoed by this software.

The concrete backend resolves a fixed, same-team signed guardian executable from the protected installation. The guardian uses a separate process, fixed two-second maximum, ownership and writer locks, and a restricted root journal. It reaps its writer before restoration and responds to owner EOF and sleep. Inspection is read-only. Inhibition and recovery have separate source gates; repository defaults do not permit writes.

A separate one-shot qualification action is implemented, independently of temperature policy. It records intent before dispatch, seeks fresh battery-source evidence, and checks restoration. It cannot authorize recurring cycles or longer holds. The normal local package does not expose this test because its source gates remain disabled.

## Installation

The local unsigned Installer package contains Apple Development-signed code. It is intended for this Mac, not public distribution. Its first-install-only payload is `/Library/Application Support/StatBattLocal/StatBatt.app`, with a separate `StatBatt Local.app` launcher in Applications. The protected installation avoids trusting a user-writable privileged executable. Existing native app and Shortcuts are preserved. Installer requires the owner's macOS administrator authorization. Service registration is performed by the signed-in user from the app; it is not performed as root by a package script.

The package refuses an existing local-service target rather than overwriting a controller that might own an operation. A service update/removal workflow remains required before distributing updates. Apple shortcut imports still require Apple's own Add Shortcut approval when missing; bundled exports and missing-only setup remove manual shortcut construction.

## What is still unverified

The new Swift guardian and full app-to-daemon path have not performed a hardware cycle. Earlier Python-supervised two-second, owner-loss and sleep trials establish scoped evidence for the mechanism, not for this new executable implementation. No long pause or unattended recurring temperature session is qualified. The registry temperature remains estimated, and the policy reducer still refuses to treat it as a verified thermal protection sensor. Automatic `start` therefore returns unavailable, even if the one-shot qualification backend is enabled in an isolated candidate.

Completing temperature control requires reviewing and running a fixed one-shot candidate, lifecycle tests of that candidate, and an explicit estimated-sensor convenience-policy admission design. It must not be described as production thermal protection or silently unlocked by a successful two-second test.

## Candidate review findings

Review found and repaired a restoration hazard: writing status to a closed daemon output pipe could deliver SIGPIPE to the guardian. The guardian now ignores SIGPIPE before reporting anything; a disconnected output reader must not terminate restoration. Other repairs distinguish a completed inspection process from a hardware writer, reserve backend serialization before suspension points, and require post-call fresh key/source evidence instead of reusing the inhibit acknowledgement. A separate inherited writer lease prevents a replacement guardian from racing an orphaned writer.

These changes are software-reviewed safeguards, not executed hardware evidence. A crash of the guardian itself may still leave inhibition active after its writer exits until a later recovery process runs. The lease prevents overlapping writers; it is not an independent second restoration process. This limitation prevents claiming unattended lifecycle completion.

The proposed next hardware qualification is one explicit in-app action with a nonrenewable two-second guardian limit, normal thermal pressure, AC baseline, and at least 50% charge. It may observe a brief transition to battery power, then must verify zero key readback and AC supply before clearing ownership. It does not request sleep, repeat itself, modify Apple's charge limit, or enable temperature policy. Candidate identity and hashes must be recorded after local signing, before requesting that test.

## Build checkpoint

An isolated source-only one-shot candidate was prepared at `/private/tmp/statbatt-one-shot-candidate-4isugces/statbatt`. Its parent contains `GATE_DIFF.patch` and `CANDIDATE_MANIFEST.json`: exactly six write/recovery gates differ from the normal source. Automatic `start` remains refused. This is not a signed or installed artifact, and no candidate hardware action has run.

Local Apple Development signing stalled while the Mac was locked and a Keychain approval could not be handled. The pending default signing invocation is not a deliverable: it began before the guardian SIGPIPE repair and must be rebuilt from current source. No public signing/notarization was attempted. Unlocking and approving local private-key use is the next required owner action; it is separate from authorizing a hardware test.

Final software verification for this checkpoint: 200 tests passed (69 XCTest and 131 Swift Testing), zero failures. This includes closed request-schema validation, safe-no-ownership versus electrical-restoration semantics, closed default write gates, inherited writer-lease exclusion, fresh qualification evidence, and a separate C child process exercising the actual SIGPIPE-ignore function against a closed pipe. No hardware action is part of these tests. Full test log: `/private/tmp/statbatt-local-integration-tests.log`. The isolated source candidate was refreshed after the final SIGPIPE/C-fixture change; its manifest records the resulting source hashes.
