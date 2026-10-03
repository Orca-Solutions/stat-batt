# Private native charge-limit feasibility

Read-only investigation, October 2, 2026. No setter, preference write, notification,
SMC mutation, helper installation, or third-party executable was run.

## Finding

Ampere's native fallback is a useful research lead, but it is **not** a supported
private-client setter accepting arbitrary targets. Its implementation writes
PowerUIAgent's preferences as root to bypass the client’s slider-range checks.
It then uses the private client when releasing the override. This introduces a
privileged, persistent system-setting path and a restoration obligation, even
though firmware enforces the limit. It is not an immediate substitute for a
qualified thermal stop mechanism.

## Pinned primary source and license

Inspected repository commit `7e944650db120623b5bfb4cd831b696779a4b4f4`:

- [MIT license, copyright 2026 AZ Code Lab](https://github.com/az-code-lab/ampere/blob/7e944650db120623b5bfb4cd831b696779a4b4f4/LICENSE)
- [NativeChargeLimit.swift](https://github.com/az-code-lab/ampere/blob/7e944650db120623b5bfb4cd831b696779a4b4f4/Sources/Shared/NativeChargeLimit.swift)
- [SMCWriter implementation](https://github.com/az-code-lab/ampere/blob/7e944650db120623b5bfb4cd831b696779a4b4f4/Sources/SMCWriter/main.swift#L376)
- [Author's technical explanation](https://amperebattery.app/tech.html#native-limit)

MIT permits reuse with the copyright and permission notice included in copies
or substantial portions. No Ampere implementation was copied into StatBatt.
The temporary read-only runtime probes were independently written.

## Mechanism found in source

`/System/Library/PrivateFrameworks/PowerUI.framework/Versions/A/PowerUI` exposes
`PowerUISmartChargeClient`, initialized with `initWithClientName:`. Ampere checks
for `isMCLCurrentlyEnabled:`, `enableMCL:`, and `disableMCL:` before selecting the
fallback. The app also expects `pmset -g battlimit` to answer.

Its root helper uses CFPreferences in domain
`com.apple.smartcharging.topoffprotection`, current user (root), any host. It
sets `MCLFeatureState=1` and `mclLimitValue=<target>`, synchronizes, and posts the
Darwin notification `com.apple.smartcharging.defaultschanged`. The helper accepts
integers 1–100; that is upstream's allowed range, not validation performed here.

Before mutation it persists the original feature state and target. Release
uses `isMCLCurrentlyEnabled:`, conditionally `enableMCL:`, then `disableMCL:` to
clear the registration; simply writing feature state off can leave a powerd
registration behind according to upstream's comments. It then restores saved
preferences and retains its recovery marker on failure. This means restore must
be independently qualified, including errors and absent/corrupt original state.

The author reports about one-minute evaluation latency, firmware enforcement
through sleep/reboot, and firmware discharge above a lowered target. A hold at
current SOC therefore has settling drift and can cause discharge if the target
falls behind the observed SOC. These behavioral claims were not tested here.

## Local read-only evidence

On the current host, framework load and Objective-C class/method inspection
succeeded. Relevant instance selectors and runtime ABI shapes:

| Selector | Return / argument |
| --- | --- |
| `isMCLSupported` | BOOL |
| `availableChargeLimitsWithError:` | object; NSError ** |
| `isMCLCurrentlyEnabled:` | UInt64; NSError ** |
| `currentChargeLimit:` | UInt64; NSError ** |
| `getMCLLimitWithError:` | UInt8; NSError ** |
| `enableMCL:` / `disableMCL:` | BOOL; NSError ** |
| `setMCLLimit:error:` | BOOL; UInt8, NSError ** |
| `temporarilyOverrideMCLTargetSoC:error:` | BOOL; UInt8, NSError ** |

Method presence is not permission or behavioral qualification. The two setter
selectors were inspected only, never invoked. The temporary probe did not load
Ampere's executable or run its code.

`pmset -g battlimit` returned `No battery level limits set`. This is useful
readback of registered limits, but an empty list should not be conflated with a
successful write to a specific target or a read failure. Upstream's parser maps
unknown output to empty; StatBatt should distinguish those cases if adopted.

A bounded getter probe initially returned Cocoa error 4099 because the execution
sandbox could not look up `com.apple.powerui.smartChargeManager`. Thus its false
support value / zero targets are not evidence that the Mac lacks the feature.

## Practical assessment

This may offer a less disruptive *holding* approach than `CHIE`, because firmware
can enforce a target without disconnecting AC. It is also more complex than the
existing 80/100 Shortcuts flow, depends on private implementation details, and
needs root to achieve arbitrary targets through the mechanism actually used by
Ampere. It does not establish immediate stop latency suitable for a temperature
threshold. Firmware-initiated discharge may be undesirable while the battery
is hot. The user's simplified native 80/100 v1 should remain the default while
any optional thermal feature is separately qualified.

Before adoption: verify non-root getter outcomes and available targets; authorize
and qualify one bounded target/restore lab; observe enforcement, latency, drain,
sleep, reboot and failure behavior; implement durable recovery and external-
controller conflict handling; qualify each OS/firmware fingerprint. Never infer
all of those guarantees from class existence or an acknowledged setter.

### Non-sandboxed getter result

The same bounded read-only probe was approved outside the execution sandbox and
completed normally as the current user, without root:

- `isMCLSupported`: true.
- `availableChargeLimitsWithError:`: 80, 85, 90, 95, 100; no error.
- `isMCLCurrentlyEnabled:`: 0; no error.
- `currentChargeLimit:`: 100; no error.
- `getMCLLimitWithError:`: 100; no error.

This confirms a usable read-only client on this exact host and provides a
potential readback improvement for existing native controls. It does not prove
setter authorization, below-80 targets, or thermal-stop semantics. Runtime ABI
checks, bounded execution, errors as unknown, and fallback to visible Settings
remain necessary if a getter is integrated.
