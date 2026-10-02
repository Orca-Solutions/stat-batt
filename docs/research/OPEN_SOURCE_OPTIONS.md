# Open-source reuse options

Research date: October 1, 2026. This assesses source availability and candidate reuse; no implementation code has been copied into this workspace. License choice remains a product decision before code adoption or distribution.

Evidence labels follow [macOS platform research](MACOS_PLATFORM.md): verified source, upstream claim, inference, and hardware-unverified. Repository availability and an explicit license are separate checks. A public repository without a license is not an open-source reuse grant.

## Candidate assessment

| Project | Verified license/status | Useful material | Recommendation |
| --- | --- | --- | --- |
| [mhaeuser/Battery-Toolkit](https://github.com/mhaeuser/Battery-Toolkit) | BSD-3-Clause; upstream archived March 21, 2026 | Native Swift app/helper structure, SMC transport, event-driven hysteresis, power-state lifecycle | Best native Swift reference or selectively audited source base; do not inherit its hardware support claims |
| [charlie0129/batt](https://github.com/charlie0129/batt) | LICENSE contains GPL version 2; current upstream development | Backend detection, firmware limits, recent macOS 27 adapter fallback, private native fallback, control semantics | Strongest recent compatibility research reference; fork if GPL distribution is desired, otherwise implement independently without copying GPL code |
| [charlie0129/gosmc](https://github.com/charlie0129/gosmc) | Repository identifies GPL-2.0; underlying LICENSE text was not separately fetched successfully | Go/CGO SMC transport and codecs | Treat as GPL until source notices and pinned license audit complete; not a permissive dependency |
| [diegonoceli/Battery-Toolkit-MacOs-27](https://github.com/diegonoceli/Battery-Toolkit-MacOs-27) | README/repository identify BSD-3-Clause; inherited license requires audit at pinned commit | Claimed Xcode/SMAppService fixes, XPC timeouts, CHIE handling | Watch-list candidate; do not adopt before actual diff and hardware validation |
| [caseymrm/go-smc](https://github.com/caseymrm/go-smc) | MIT license text inspected | Another low-level transport reference | Secondary option if a Go component is chosen; modern Apple silicon/macOS 27 support not established here |
| [Apple IOKitUser](https://github.com/apple-oss-distributions/IOKitUser) | `IOPSKeys.h` has APSL-2.0 notice | Primary definitions for monitoring keys and units | Prefer using installed SDK APIs/constants; copying Apple source requires its own license assessment |

Direct license sources: [Battery Toolkit license](https://github.com/mhaeuser/Battery-Toolkit/blob/main/LICENSE.txt), [batt license](https://github.com/charlie0129/batt/blob/master/LICENSE), [go-smc license](https://github.com/caseymrm/go-smc/blob/master/LICENSE). GPL version-2 text in a repository is not by itself a verified answer to “only” versus “or later”; inspect actual source grant notices before recording an SPDX variant. The standard license appendix's example language is not a project-specific grant.

## Battery Toolkit: useful Swift foundation, older control assumptions

The actual `SMCComm+Power.swift` requires a valid charge-control key **and** adapter-control key for `supported()`. It tries `CHTE`/`CH0C` for charging and `CHIE`/`CH0J` for adapter control, then writes separate on/off encodings. This explains how a platform with an available adapter switch but blocked charge switch can be rejected by the upstream app. Preserve separate capability checks in the new design. [Inspected source](https://github.com/mhaeuser/Battery-Toolkit/blob/main/Libraries/SMCComm%2BPower.swift)

Its `BTPowerEvents.swift` reads charge state, coordinates event handlers, applies lower/upper hysteresis, refreshes state on wake, and restores platform defaults outside debug builds. It also uses an `IOPSPrivate` wrapper; adopting the project does not automatically keep our app on public telemetry APIs. Rewrite or replace private monitoring dependencies with supported IOPS APIs where feasible. [Inspected source](https://github.com/mhaeuser/Battery-Toolkit/blob/main/me.mhaeuser.batterytoolkitd/BTPowerEvents.swift)

The upstream README limits support to Apple silicon and notes lifecycle limitations. Its archived status means we would own OS update support, helper packaging, signing/notarization, and recovery work. BSD-3-Clause permits modified source/binary redistribution when required notices and disclaimer are retained; names cannot be used as endorsement. Audit each copied file and dependency, retain attributions in a third-party notices file, and use our own app identity. [Repository/status](https://github.com/mhaeuser/Battery-Toolkit), [license text](https://github.com/mhaeuser/Battery-Toolkit/blob/main/LICENSE.txt)

## batt: current macOS 27 evidence and source boundary

The inspected `pkg/smc/charging.go` differentiates legacy switching from firmware enforcement. `pkg/daemon/managedlimit.go` distinguishes Apple-managed limits from active app switching and restores adapter power when exiting adapter mode. `pkg/powerui/powerui.m` loads a private framework and dynamically invokes charge-limit methods. These are three different control semantics, and the capability model must expose them honestly. [Charging implementation](https://github.com/charlie0129/batt/blob/master/pkg/smc/charging.go), [managed control](https://github.com/charlie0129/batt/blob/master/pkg/daemon/managedlimit.go), [private PowerUI implementation](https://github.com/charlie0129/batt/blob/master/pkg/powerui/powerui.m)

[Issue 152](https://github.com/charlie0129/batt/issues/152) provides a dated, build/firmware-specific report of blocked charge keys. [PR 154](https://github.com/charlie0129/batt/pull/154), merged September 24, supplies the adapter fallback and author testing. The frozen reference for that change is [aa9b6ffc3e8f8f465333387a3a3664037db31f8e](https://github.com/charlie0129/batt/commit/aa9b6ffc3e8f8f465333387a3a3664037db31f8e). This makes a plausible feasibility path, not a universal compatibility guarantee.

Do not freeze production reuse at that merge without examining follow-up fixes: [issue 158](https://github.com/charlie0129/batt/issues/158) reports concurrent runtime-mode/sleep-callback state access and a targeted race reproduction; the observed hardware consequence is explicitly unverified. Retrieved pages showed inconsistent open/closed state across caches, so recheck resolution and fixing commits before dependency selection. Our policy transitions and power callbacks should share one serialized owner.

GPL source reuse and derived binary distribution bring source/license obligations. A closed-source Swift app cannot assume that translating GPL Go code or embedding its library avoids those obligations. Wrapping the tool as a separate process is not an automatic exemption: packaging, protocol, derivation, and integration need assessment. An entirely GPL-compatible product is a reasonable option; an independent implementation using publicly described behavior is another. Do not copy code first and defer the license decision.

## macOS 27 Battery Toolkit fork: investigate before adoption

The fork README claims broader SMC support through `CHIE`, helper registration fixes, XPC timeouts, and macOS 27 verification. It also says that disabling charging via `CHIE` cuts AC power, then describes separating adapter isolation and keeping AC active. Those claims are insufficient to prove true charge-pause behavior with the adapter active. [Fork README](https://github.com/diegonoceli/Battery-Toolkit-MacOs-27)

The actual fork control source and comparison diff could not be retrieved by the web tool during this investigation. No exact tested build/firmware matrix or independent reproduction was established. Its marketing language must not be used as a compatibility claim for this project. Audit the diff at a pinned commit and test charge-pause versus adapter-cut semantics before any reuse.

## Decision before implementation

Recommended initial path: original SwiftUI/AppKit product; public IOPS monitoring; an inspectable native Shortcuts integration; a small isolated charge-control adapter if the feasibility gate proves it. Selectively reuse BSD Battery Toolkit transport/lifecycle material only after pinned source/license review. Keep recent GPL `batt` findings as cited research unless the owner chooses a GPL-compatible derivative.

Before adding a dependency or copied file:

1. Pin repository URL, full commit SHA, source file paths, licenses/notices, and transitive dependencies.
2. Confirm source authorship and file-level licenses; inspect build files and embedded binary assets.
3. Choose reuse/fork/independent implementation deliberately and record an ADR with distribution implications.
4. Preserve required notices, modification records, and source delivery obligations for the selected path.
5. Verify current maintenance status, critical bug resolutions, toolchain compatibility, and the exact target hardware matrix.
6. Keep our product name, icons, artwork, and copy original. Functional inspiration does not grant rights to Energiza branding or proprietary assets.

No project license, external fork, dependency, Git commit, or public repository was created by this assessment. A full dependency bill of materials becomes meaningful when actual implementation dependencies are selected.
