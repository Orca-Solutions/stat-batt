# Energiza replacement: research and feasibility report

October 1, 2026. Outcome: a concrete foundation for a native Apple silicon battery app; full macOS27 charge-control parity remains dependent on hardware qualification.

## Recommendation

Build an original SwiftUI/AppKit menu-bar app, public monitoring first, with separate capability-based control providers. Prove the supported Apple native limit route before building around SMC writes. Where independently verified, add custom lower/upper thresholds, deliberate discharge to a cutoff, thermal holds and reliable recovery. Do not label adapter cutoff as pausing charge while remaining on AC.

The proposal is sufficiently defined to start a bounded feasibility spike. It is not evidence that a newly written helper will regain interfaces that the OS denies. Unsupported custom charge holding may be an enduring product limitation requiring explicit scope acceptance.

## What the Energiza investigation established

The publisher is appgineers / Dr. Jan Linxweiler. No public reusable Energiza application source was found in the bounded repository search; the vendor EULA is proprietary. The Homebrew repository contains installation metadata. A same-name GitHub profile was inspected but not verified as the vendor's account. This finding is “no source located,” not proof that no private/unindexed repository exists. [Vendor EULA](https://appgineers.de/energiza/eula.html), [source-search ledger](research/ENERGIZA_SOURCES.md).

The free product is primarily a menu-bar battery monitor; Pro adds explicit charge thresholds and control. The sourced inventory covers telemetry, menu customization, immediate charge/stop/full actions, active discharge, thermal protection, sleep behavior, alerts, helper maintenance and updates. Historical vendor screenshots show the familiar two-handle battery slider and state-specific menu text. [App Store monitor](https://apps.apple.com/us/app/energiza-battery-monitor/id1643751440?mt=12), [parity inventory](research/ENERGIZA_PARITY.md).

The published Pro changelog's latest listed version is1.3.5 from November2025; it adds M5 MacBook Pro recognition, while1.3.4 explicitly adds macOS26. No macOS27-specific support evidence was found. [Vendor changelog](https://appgineers.de/energiza/files/Energiza.html).

## What your log establishes

The helper starts, identifies arm64 and reports both charge-control variants unsupported. Adapter disconnection variant2 and MagSafe LED support are detected separately. Repeated unsupported messages originate from Helper.swift:164. That places the observed failure in capability detection/use rather than a helper that never starts. Exact meanings of private variant numbers and SMCKit error4 remain unknown. [Local failure analysis](research/ENERGIZA_FAILURE.md).

The local environment reports macOS27.0.1/build26A434 and Xcode27.0/build27A266a. Exact device model and firmware were not obtained. No control writes or restoration tests ran.

## macOS27 feasibility

| Feature | Current evidence | Build consequence |
|---|---|---|
| Basic monitoring | Public IOKit power-source functions | Proceed with original monitor; advanced fields individually optional |
| Apple native upper limit | Apple documents limit setting and Shortcuts action | First integration spike; supported targets/observation/restore still need target testing |
| Hold charge while keeping AC | Older open-source backends; new access-denial reports | Conditional; root does not guarantee access |
| Intentional discharge cutoff | Existing adapter-control implementations and local detection | Separately promising; prove actual writes, reserve and restoration |
| Adapter cycling band | Recent upstream fallback with author test | Opt-in experimental behavior; more battery use, awake limitation |
| Temperature charge hold | Depends on verified temperature and independent charge gate | Disabled if either prerequisite fails; no adapter-cut substitution |
| MagSafe LED / sleep variants | Vendor and source references | Secondary parity, qualified independently |

Public IOPowerSources supplies source information and notifications; it is not a general documented charge-control API. [Apple IOPowerSources](https://developer.apple.com/documentation/iokit/iopowersources_h).

Apple's built-in limit operates in the80–100% range and can periodically charge fully. Apple's supported Shortcuts action is a credible user-level integration path; direct public Swift setting/readback was not established. [Apple charge limit](https://support.apple.com/en-us/102338), [Apple Shortcuts action](https://support.apple.com/en-gb/125148).

A recent upstream issue reports blocked charge interfaces even for root on specific macOS27 firmware. A merged fallback uses adapter inhibition instead, with author-reported testing on an M5 Air. Neither establishes behavior on this Mac. The interface restriction is a plausible explanation for Energiza's failure. [batt issue152](https://github.com/charlie0129/batt/issues/152), [adapter fallback PR154](https://github.com/charlie0129/batt/pull/154).

## Reuse and licensing

Battery Toolkit is the closest native Swift reference: BSD-3-Clause, but archived and carrying older hardware/private-API assumptions. Recent batt code has valuable compatibility findings but GPL obligations; source translation/wrapping is not automatically a license workaround. A macOS27 Toolkit fork claims support, but its actual control diff could not be verified in this investigation. Recommended path: original implementation, selectively audited BSD components if useful, and cited compatibility research until a license/reuse decision is made. [Reuse assessment and exact sources](research/OPEN_SOURCE_OPTIONS.md).

No dependency, copied implementation, project license, purchase or public fork was created. Before source reuse, pin revision, check each file and transitive license, preserve notices and choose distribution terms.

## Proposed foundation

The product spec defines modes, defaults, requirements and acceptance IDs. The architecture isolates monitoring, policy, native shortcut execution and authenticated privileged control. The API defines capability/telemetry DTOs, revisions, idempotency, policy/actions, errors, event reconnect, restoration and uninstall. Security/operations covers signing, local privacy, ownership and recovery; UX documents reviewable flows; the test plan maps each acceptance ID to evidence.

Stage0 must answer the hardest questions: native action targets/readback/restore, independently writable charge gate, independently writable adapter inhibit, and sleep/crash behavior. Stage1 builds monitoring and a mock policy UI. Later stages add only proven controls. [Build plan](BUILD_PLAN.md), [test plan](TEST_PLAN.md).

## Verification and limitations

Performed: primary-source research, published screenshot inspection, selected open-source code/license inspection, supplied local helper-log examination, environment/toolchain version checks, cross-document consistency and link checks, and a separate fresh-session review of the documentation. Findings and dispositions live in WORKING_RECORD.md.

Unperformed: app implementation/compilation, helper registration, native-action invocation, SMC capability probing or writes, discharge experiment, sleep/reboot/crash recovery, signing/notarization and release testing. Documentation provides a testable plan, not certification of these behaviors.

The directory has no Git repository or remote; all deliverables are local files. Product scope/UX are proposed, and no release is authorized. The next useful increment is the read-only target diagnostic followed by a separately approved reversible control experiment.
