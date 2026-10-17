# Security, privacy, installation and recovery

Proposed, 2026-10-01. Security design is normative; hardware recovery behavior must still be demonstrated. See API.md for exact client/daemon boundaries.

## Trust and threats

Trusted: signed production application/helper and fixed allowlisted hardware provider; the explicitly configured normal-user native shortcut under the owner-approved exception in decision0002. Untrusted: any other local client, edited preferences, unapproved shortcut content, metrics returned by undocumented services, exported/imported files, and remote update metadata. The daemon must not trust UI validation as its only validation.

Protect against arbitrary root command execution, unauthorized cutoff, indefinite adapter inhibition, replay/stale mutation, two simultaneous policy owners, malformed XPC objects, symlink/permissions attacks on helper state, tampered updater/helper, and private information in logs. Failures may leave hardware state changed after process death; a journal and launchd restart reduce that risk but do not prove automatic cleanup in every circumstance.

Authenticate both ends with production designated signing requirements including trusted signing anchor, Team ID and approved bundle identifiers. Verify before exporting privileged interfaces; helper approval alone is not client authentication. Enforce one authorized policy owner, root-owned state paths, bounded typed messages and validation. Development signing is a separate explicit configuration and must not weaken production checks.

## Helper lifecycle

Use bundled SMAppService daemon registration and macOS approval rather than password collection or shell-based installation. States: absent, registration requested, approval pending, available, incompatible, denied, recovery required. Launch daemon before user mutation; version/protocol mismatch disables control. GUI exit leaves enabled persisted policy only as described in UX; removing the helper is a separate operation with restore-first semantics.

Before each private write, record owner, baseline, intended effect and pending state in a durable journal. Confirm state after write. On recovery, compare current state with app-owned state; restore only owned changes with verified semantics. Serialize sleep handling and mutation. No success banner before restoration confirmation. If restoration fails, preserve the service/recovery record and provide precise diagnostics rather than uninstalling the only recovery path.

## Native shortcut boundary

Execute in the logged-in user's context with a fixed executable and fixed argument array; never send arbitrary shell text through XPC. Inspect/setup a user-approved trusted shortcut, restrict target inputs, set timeout, and revalidate identity/content when possible. A named shortcut alone is not a security boundary. The owner-approved exception permits trusting a configured mutable user workflow after a clear setup acknowledgement that later action/parameter edits may not be detectable. Bind its library UUID and reject missing, ambiguous or replaced identities; do not describe these checks as complete content verification. Use only the expected native80% setup workflow for the currently qualified target. Arbitrary caller-selected workflows, shell strings and privileged shortcut execution remain forbidden. See [decision0002](decisions/0002-trusted-user-native-shortcut.md).

Persist owner-only intent before native dispatch, retain an advisory same-account lock, and never retry an unresolved request at startup. Bound process output and return timeout/cancellation receipts only after the owned CLI terminates. The Shortcuts action may outlive its CLI; require the user to check or stop it and record the visible80% or100% setting before another request. The owner-approved two-target flow in decision0003 replaces the ordinary mandatory manual100% return; normal acknowledged receipts permit another deliberate qualified request.

The native action's exit status does not prove effective limit or original value. If no reliable getter is available, require a visible user-confirmed baseline/return target and disclose manual verification. Disable automatic native expiry/restore features that cannot meet the product's recovery contract. Do not copy a private PowerUI integration and call it public API.

## Local data

Keep UI preferences/history in user-owned app storage; root helper holds only validated control configuration and recovery journal. No serial numbers, unique hardware identifiers, username/home path, license keys, or full raw I/O registry dumps in logs/export. Diagnostics include versions, nonidentifying model family where permitted, capability reasons, normalized metrics and bounded errors. Export is explicit and previewable. History is optional, bounded and deletable. No telemetry or account required.

## Release and updates

Use Developer ID signing, hardened runtime, notarization and stapling for external distribution; test downloaded artifact on a clean Mac. Apple describes the distribution and signing path. [macOS distribution](https://developer.apple.com/macos/distribution/), [Developer ID](https://developer.apple.com/developer-id/).

For V1, manual update is adequate. If an updater is adopted, verify license and signed-update scheme, pin compatible helper protocol, restore active controls before helper replacement and record a rollback path. Never download/execute unsigned helper binaries. No update service or new spending is assumed in discovery.

## Operator runbook

1. Diagnose: read app/helper version, capability report, latest state/telemetry age and operation journal status.
2. Disable control through authenticated API; wait for restoration confirmation.
3. If failed, preserve journal, stop new operations and follow backend-specific recovery established in lab. Avoid blindly toggling unknown keys.
4. Uninstall only after recovery succeeds; unregister daemon and remove bundled app. Explain any user-confirmed native setting/shortcut that requires manual restoration/removal.
5. After macOS/firmware updates, invalidate prior scoped verification and recheck before private actuation. Monitoring continues.

Network behavior is limited to explicitly enabled update checks/downloads in a future release. Publishing, buying signing memberships, and sending diagnostics externally require the owner's established authorization.
