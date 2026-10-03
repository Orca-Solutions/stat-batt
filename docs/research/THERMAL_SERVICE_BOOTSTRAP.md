# Signed thermal-service bootstrap

This development-only bundle tests mutually authenticated XPC through SMAppService. It has no charging command, SMC dependency, or automatic temperature policy. Normal release packaging excludes its executable and launch-daemon plist.

Build from the repository root with an installed Apple-issued identity:

```sh
STATBATT_DEVELOPMENT_IDENTITY='Apple Development: YOUR IDENTITY' apps/statbatt/scripts/build-service-development.sh
```

The result is `apps/statbatt/dist/service-development/StatBatt.app`. The script verifies Apple-anchored signatures on both executables and does not register a service. Keychain access may require a user prompt. A sandboxed identity listing may report zero identities even when the normal login keychain contains one.

Run the bundle's `Contents/MacOS/StatBatt` executable as the ordinary logged-in user with exactly one of:

- `--thermal-service-register`: requests registration; macOS background approval may be required. On this macOS build the initial request returned “Operation not permitted” while successfully creating a pending approval entry, so that error alone does not prove nothing was registered.
- `--thermal-service-status`: authenticates the daemon and requires a bounded response with `actuationDisabled: true`.
- `--thermal-service-unregister`: first authenticates the non-actuating endpoint, then unregisters it. An unreachable pending service cannot be removed with this command; resolve approval before this test cleanup path.

The client and daemon require an Apple-anchored signature, their fixed peer identifier, and the same signing team. Ad-hoc builds reject before registration or connection. The daemon accepts non-root clients only and exposes a single bounded status method.

## Evidence and remaining work

On October 2, 2026, Xcode created a valid Apple Development identity using the owner's Personal Team. The isolated release build and both strict signature checks passed. Registration created a pending background approval entry. After the owner approved it, authenticated live status returned `{"actuationDisabled":true,"version":1}`. Launchd confirmed the fixed daemon identity, signing team requirement and system-domain service. Authenticated unregister succeeded and launchd reported the service absent; re-registration returned enabled and a fresh authenticated status call succeeded without another approval prompt.

The initial unapproved connection exposed a Swift actor-isolation crash in the client error callback. Making the status routine explicitly nonisolated prevents XPC callbacks from inheriting MainActor; the rebuilt denied-connection path returned an ordinary error, and the approved path passed. A normal-user attempt to signal the system daemon was denied; no crash-recovery result is inferred from that attempt.

Software validation passed 165 Swift tests (69 XCTest and 96 Swift Testing), plus five separate mocked guardian tests. The unsigned client check rejected with `untrustedCode` as intended.

This does not qualify persistent adapter control. Temperature-source qualification, durable restoration ownership, lifecycle recovery, and the live temperature UI remain separate work. Public Developer ID signing and notarization also remain pending.
