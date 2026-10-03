# 0002 — Trust a configured user native shortcut

Status: accepted by the Product Owner, October 2, 2026. The normal baseline/return loop is superseded by [decision0003](0003-two-target-native-limit.md); the decision below records its historical contract.

## Context

The supervised native lab demonstrated the Apple80% setter and visible settings readback on Mac16,13 / arm64 / macOS27.0.1 build26A434 / mBoot-20457.1.29, followed by supported manual restoration to100%. Supported Apple interfaces run library shortcuts but the bounded investigation found no complete current-content inspection or immutable-execution binding. UUID and action-count checks cannot detect all action/parameter edits. See [trust research](../research/NATIVE_SHORTCUT_TRUST.md).

The original security contract required failing closed without current-content verification. The coordinator explained the choices: preserve that requirement and leave automatic native control disabled, or trust an explicitly configured workflow accepting undetectable later edits. The owner replied: “yes statbatt may trust the shortcut.”

## Decision

The normal app may trust the explicitly configured mutable user workflow after setup records approval and inspection. The setup warning must explain that later edits can change what StatBatt executes and cannot all be detected. Bind the installed shortcut UUID, use a fixed executable and argument array, reject missing/ambiguous/replaced identities, and restrict setup to the expected one-action80% native workflow. No root execution, downloaded opaque workflow, arbitrary user-selected command/path, shell or private workflow database/framework is introduced.

Limit the current qualified operation to80% on the exact lab fingerprint. Record a visibly user-confirmed baseline/return setting100%; do not infer it from the old lab or a generic battery snapshot. Persist intent before execution, serialize app requests, use a bounded timeout, preserve unknown outcomes across crashes, and require visible manual reconciliation before another operation. Command completion means acknowledged, not observed. The native setting persists independently of app lifetime; no expiry or automatic restore is promised.

Setup records trust only. Applying a setting remains a deliberate user action in the app. This exception does not authorize additional unattended lab mutations, private controls/helper installation, other targets, or a reduction in full v1 acceptance scope.

## Consequences

A later edit to the trusted shortcut can change its behavior without being detected. UUID/existence checks reduce accidental identity mistakes but are not content integrity. The shortcut runs only with normal user privileges. Native readback is visible user confirmation until a verified getter exists. Custom controllers remain disabled, and the app cannot claim machine-wide exclusion of external controllers or other users.

The owner may revoke setup trust; unresolved native intent must be reconciled before its recovery record can be cleared. Production signing, cutoff and lifecycle acceptance remain separate work.
