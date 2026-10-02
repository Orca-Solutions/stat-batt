# Working record

Date: 2026-10-02. Stage: local implementation checkpoint, not completed v1/release candidate.

## Authority and state

The owner said “our plan set, and our project file populated … let her rip on the implementation of our v1 spec,” then explicitly requested a team pursuant to project folders and a product design expert consulting on UI/UX. This authorizes local software implementation, team work/review, builds and read-only checks. Discovery-only statements are superseded. Owner later explicitly authorized one native80% test and verified baseline restoration. Other hardware writes/helper installation, new spending, publication and release remain separately reserved gates under the brief/build plan.

Local Git initialized with approved metadata escalation, branch `implementation/v1`. No configured remote. Global author name is the owner; email is the literal placeholder `YOUR_GITHUB_EMAIL`. A concise asynchronous question requests the real commit email/remote. No commit/push/PR was fabricated or performed. Local source is intact and reviewable; no CI change or external message.

## Implemented snapshot

SwiftPM modules:

- `StatBattDomain`: typed quality/provenance metrics, independent capabilities, configuration validation, pure safety reducer, boot/continuous deadlines.
- `StatBattTelemetry`: IOPowerSources observations, coalesced change notifications,30s idle fallback, allowlisted read-only reported ExternalConnected/CycleCount, exact-target nested FCC/design/pack-temperature, thermal signal, platform fingerprint and diagnostics.
- `StatBattPersistence`: SQLite seven-day one-minute means, hard10,080-point bound, gaps, CSV/clear, validated atomic preferences.
- `StatBattControlProtocol`: strict64KiB Codable DTO codec, XPC interface declarations only, synthetic/in-memory connection/session/owner/CAS/replay and native-fence contracts.
- `StatBattApp`: SwiftUI menu bar and Battery/Charging/History/Settings tabs, per-metric unavailable explanations, opt-in notification/login flows, direct tab navigation, accessible labels and original native symbols.
- `statbatt-diagnostics`: read-only JSON command. `scripts/build-app.sh` packages an ad-hoc signed local `dist/StatBatt.app`.

No real control provider, listener/daemon, OS admin authorization, durable privileged recovery journal, full service reply DTOs/events, native setter/coordinator, or two-phase helper uninstall exists. These intentionally depend on control feasibility gates. Controls are visibly disabled and never silently fall back to adapter cycling. Software operation intents do not establish hardware behavior. See [implementation acceptance map](docs/IMPLEMENTATION_STATUS.md).

## Read-only device evidence

October2 diagnostic: model`Mac16,13`, arm64, macOS`27.0.1/build26A434`, firmware`mBoot-20457.1.29`, provider`public-telemetry-0.1.0`. Public/internal readings reported battery present, percentage, charging flag, reported adapter connection, supplying source, cycles and system thermal pressure. Initial advanced readings were absent or unqualified; subsequent exact-target registry enrichment reports physical FCC/design, derived health and estimated pack temperature. See research/MACOS27_TELEMETRY.md. No serials/raw dictionaries/auth data were exported. Battery settings read-only baseline100% was observed; Energiza helper running was confirmed via launchd. Subsequent authorized native action set80% with visible readback, followed by supported Battery settings restoration to100% and persisted verification; no helper/SMC write occurred. See research/NATIVE_LIMIT_LAB.md.

October1 retained evidence: Xcode27.0/build27A266a; Energiza helper0.5.1 reports both charge-control variants unsupported and adapter variant2 detected. This remains reported evidence, not our backend qualification. Earlier scope/doc-review FR-01–07 remains incorporated in the accepted contracts.

## Team and review

Three implementer subagents owned domain, protocol, and persistence in disjoint modules; lead owns telemetry/UI/integration. A separate fresh-context reviewer, same model family, inspected the source without editing and reproduced defects in temporary pure programs. A product design specialist consulted on the agreed monitor/unsupported-control UX. No alternate model credentials or external designer review are claimed.

Engineering dispositions:

- RV-01: quadratic full-retention chart segmentation replaced with chronological traversal per metric; missing-metric intervals/sleep gaps split series.
- RV-02: reconnect replay wrongly included session token. Admission now derives normalized intent from typed commands, excludes session token, retains expected lineage/revision and complete intent; new-session reconnect and restart regression coverage.
- RV-03: extreme ETA overflow could trap formatting. Decoder/formatter bound finite estimates; regression keeps malformed values unavailable.

Source re-review found no open material defect in the delivered scope. Final independent test rerun passed62 tests (zero failures); durable notes are saved in `docs/handoffs/2026-10-02-engineering-review.md` and `2026-10-02-product-design-review.md`. Final plain-language copy/compact menu refinements were lead-self-reviewed. A subsequent independent registry-telemetry review resolved TR-01 (clear owned old readings on missing/malformed data, profile downgrade, and stale presence), and independently passed24 telemetry tests (16 registry +8 public). The exact-target profile does not confer thermal/charge capability. Product design recommendations integrated: accurate reason-unavailable state copy, inactive defaults, direct menu navigation/Command-comma, menu ETA, charge-proportional symbols, consistent temperature units, compact missing menu metrics, explicit icon labels. Visual consultation remains bounded by the desktop inspection failure below.

## Verification

- `scripts/swift-local.sh build`: passes Swift6 compilation/concurrency checks.
- `scripts/swift-local.sh test`: initial integrated run34 XCTest +28 Swift Testing =62 tests passed; expanded suite includes16 additional registry regressions, with final integrated result recorded below, zero failures. Covers boundaries, thermal, freshness/wake, reserve/expiry/reboot, unsafe configuration, replay/session/CAS/fence, malformed/bounded DTOs, retention/aggregation/export/corruption, numeric/sentinel/unit handling and failed acquisition.
- `scripts/build-app.sh`: release build and local ad-hoc app bundle pass.
- `codesign --verify --deep --strict dist/StatBatt.app`: passes local signature verification; not Developer ID/notarization.
- `.build/debug/statbatt-diagnostics`: runs against live read-only target; output in ignored `.build/diagnostics.json`. No control capability verified.
- Markdown relative-link/fence audit: zero errors.

The compiler native build mode is currently used explicitly; Swift6.4 warns this mode is deprecated. Package caches remain inside `.build` for sandbox compatibility; user-level SwiftPM config/security cache warnings are expected. No external dependency was downloaded.

Unrun: StatBatt launch/visual/interactive keyboard/VoiceOver checks, both appearances, notification delivery/login approval, full-retention rendered chart timing, CPU/RSS/network resource measurements, charger hot-plug and actual sleep/reboot/logout/crash/restoration, native cutoff and other targets (80% setter/readback and100% restoration now verified), SMC probes/writes, helper auth/install/update/uninstall, signing/notarization and clean-machine packaging. Desktop CUA `getApp` on the custom bundle timed out after300s; inventory was reachable but the custom build was not discoverable, and a native launcher method was unavailable. No live UI screenshot or successful launch is claimed.

## Next bounded work

The owner confirmed the Energiza helper stopped and said to proceed. The authorized native80% setter/readback and manual100% baseline restoration passed (see [lab evidence](docs/research/NATIVE_LIMIT_LAB.md)). Initial sandboxed transport failed; unsandboxed read-only listing isolated helper communication, then the fixed inspected action succeeded. The lab action was removed and its empty shortcut renamed completed; no automatic control remains in that artifact. Native integration still needs a trusted bounded coordinator, edited/missing-shortcut handling, observed-versus-acknowledged outcomes, conflict checks, and recovery. Do not mistake this lab result for cutoff or lifecycle acceptance. No additional hardware mutation is authorized by the completed test.

Complete visual/accessibility and resource measurements on a working desktop execution path. Later provider experiments require a named allowlist/reversible protocol before helper installation. Establish owner author email/remote, commit/push a draft PR, and keep full requested scope visible until hardware acceptance or an explicit scope reduction.

No release acceptance or publication. Final open-source license/signing identity remain owner decisions before distribution. Stop is a permission/verification checkpoint, not a declaration that the v1 replacement is finished.

## Final software checkpoint

Expanded integrated suite: **78 tests passed (50 XCTest +28 Swift Testing), zero failures**. Final release build and `codesign --verify --deep --strict dist/StatBatt.app` pass. Markdown audit remains zero errors. Sorted source/test/script/resource manifest SHA256: `f239f7c47111c557a808213ed20f47efab026a343aed8e60ccce995a41332d13` (manifest saved in ignored `.build/source-manifest.sha256`).

The bounded [telemetry review](docs/handoffs/2026-10-02-telemetry-review.md) independently passed24 tests and found no remaining material defect after TR-01. Product design estimate/help/accessibility and capacity-width recommendations are integrated; live StatBatt visual QA remains unrun. Latest package includes health/temperature enrichment. Authorized native80% lab test is complete and the100% baseline restored; the app coordinator remains unimplemented. Commit/push still await real author email and agreed remote. Full v1 remains in progress.


## Native lab and UI clarification

Native lab single Apple action execution passed outside the execution sandbox (exit0,0.340s); Battery settings showed80%, then100% after supported restoration and reopening. No battery observation while80 was active was collected; initialSOC100/already-not-charging cannot prove cutoff. The lab shortcut now has zero actions and the name “StatBatt Lab — Completed (no actions).” Full evidence and limitations live in docs/research/NATIVE_LIMIT_LAB.md.

Product design reconsulted after the lab: Charging UI now says “Native integration not verified,” explains that the current app cannot apply the limit, and offers Battery settings. The primary Open Shortcuts action was removed to avoid suggesting manual execution as the product flow. This is reversible UI clarification, not a scope reduction or native-control activation.


## Trust decision and launch follow-up

Protocol specialist completed bounded read-only supported-interface research, saved in [NATIVE_SHORTCUT_TRUST.md](docs/research/NATIVE_SHORTCUT_TRUST.md). UUID/action count plus approved transport do not establish current action content. Automatic native execution therefore remains disabled under SECURITY_OPERATIONS.md. The owner has a concise asynchronous material-exception question pending: preserve content verification or explicitly trust a configured mutable user workflow with disclosed edit limitations. No approval or scope reduction is inferred from silence.

Product design recommended a one-time first-interactive-launch Battery dashboard with later/login launches quiet. Implemented via SwiftUI defaultLaunchBehavior and a UI-only initialDashboardShown flag recorded after onAppear; footer explains close-versus-quit. This API requires macOS15, so Package.swift and Info.plist now set15, while actual device qualification remains27. The initial availability-wrapper attempt did not compile because SceneBuilder lacks that control-flow path; the final direct supported API builds and tests pass. No test was added for a simple reversible UI presentation rule.

Finder launched the local build. A named-process read-only check confirmed it alive, and a one-second stack sample showed normal AppKit event-loop wait, not startup deadlock. The initial-dashboard flag was recorded. CUA's native pipe then closed before inspection; visual/keyboard/VoiceOver and menu interaction remain unverified. Activity Monitor Quit/Force Quit was used only on the earlier monitor build, which owned no hardware control, to restart the rebuilt candidate; its old process exit was verified. No current-app GUI pass is claimed.

Final follow-up: scripts/build-app.sh passed, all78 tests passed again, codesign/Markdown checks are recorded after final documentation update. Source content changed from the preceding manifest; current digest below supersedes the earlier checkpoint digest.

Current source/test/script/resource/Package.swift manifest SHA256: `ac77981acd1d44d783fc23d836a651ad565fb2d3ba8f8436bc66eef95a502681`. Final signature and Markdown audit passed.

Fresh-session launch review read the supplied sample and source graph, found no established startup deadlock, and recommended no speculative initialization fix. Idle process state does not pass visual acceptance.


## Native shortcut trust approved

The owner explicitly replied “yes statbatt may trust the shortcut” after the two choices and undetectable-edit limitation were explained. Decision0002 and SECURITY_OPERATIONS now record that material exception. Root owns integration/docs; protocol specialist owns the new native module/tests; product design owns NativeLimitView and consults on setup, acknowledged/unverified outcomes and manual recovery. No further hardware test is authorized or executed by this approval; subsequent setting changes occur only on deliberate user Apply actions in the product. Custom/helper gates remain.

## Native integration increment — review-ready software

The trusted80% path is now integrated as StatBattNativeLimit plus the app's product-designed setup/apply/confirmation/recovery flow. It is normal-user code with fixed CLI jobs, exact-target qualification, bound shortcut UUID, owner-only atomic intent journal and cooperating same-account lock. Known Energiza app/helper checks and the other-controller declaration gate setup/dispatch. Requested work is never replayed on restart; an unresolved outcome blocks another Apply. Exit0 is acknowledged/unverified, and historical user confirmation is explicitly labeled. Returning100% is manual, after confirming the shortcut finished or was stopped. No custom helper/control provider was added, and full v1 remains in progress.

Prepared the previously emptied owned lab shortcut as `StatBatt — Apple Limit 80`, inspected its single Apple80% action in Shortcuts, and saved it without running. Read-only UUID listing found exactly one matching item; ignored `.build/native-shortcut-prepared.json` records preparation and executed=false. The app's setup declarations were not fabricated or recorded on the owner's behalf. The latest actual hardware-setting evidence remains the preceding authorized lab80%/100% test; no additional setting change occurred in this increment.

Fresh-context independent review found NLR-01 (returning before the owned CLI exited) and NLR-02 (false no-change assurance during unresolved discovery). Both were repaired and rechecked. The runner now waits for observed termination/reaping, and the recovery UI requires a finished/stopped declaration before recording100%. The Shortcuts library action may still outlive its CLI, including app death; manual reconciliation remains required. The independent native suite passed24 tests, including SIGTERM-ignoring child-disappearance assertions. See [review](docs/handoffs/2026-10-02-native-limit-review.md).

Final verification: `scripts/swift-local.sh test` passed102 tests (50 XCTest+52 Swift Testing), zero failures; `scripts/build-app.sh` passed; `codesign --verify --deep --strict dist/StatBatt.app` passed. Logs are ignored `.build/native-final-tests.log` and `.build/native-final-build.log`. No hardware shortcut execution occurred in these tests.

A final UI attempt reached Finder and Activity Monitor. Activity Monitor retained old PID97086 after Quit/Force Quit attempts; the live read-only process check instead reported PID6141, started07:27:30 before the final08:05:29 bundle build. Thus those UI attempts did not establish an exit/relaunch of the current instance. Direct bundle-ID selection then failed with “native pipe closed before response.” No final live setup, Apply, visual/keyboard/VoiceOver pass, or new-process launch is claimed. Avoid further blind GUI actions while this mismatch persists.

Next: verify the rebuilt candidate's actual setup/app transport, then obtain a concrete authorized protocol for any further hardware/cutoff/lifecycle experiment. The private/custom backend feasibility and helper gates remain; do not install speculative privileged code. Commit/push still await the real owner email and agreed remote. No publication or release acceptance requested or inferred.

Final source/test/script/resource/Package.swift manifest SHA256: `51a2be127cf3168b9042ad2458fdd8d3103d609d11d7c3d91f1897521ab5fe94`. Final local StatBatt executable SHA256: `e80a124b776f82418e09feead358d79d5dcf74c3b855f67ed3da25362c0b4f02`.

## Desktop inspection recovery attempt

Owner asked whether the UI-tool failure could be worked through without assistance. Reset the CUA JavaScript session and reinitialized with a fresh desktop inventory: generic inventory, Activity Monitor and Finder were reachable. A fresh Activity Monitor filter still displayed StatBatt PID97086, while read-only `pgrep`/`ps` found PID6141 and no97086. This mismatch persists; its cause is unestablished. Finder reopening the exact app did not establish a visible StatBatt window, and exact-path `cua.getApp` again returned “native pipe closed before response.” The app is an LSUIElement menu-bar utility, with subsequent dashboard launches intentionally suppressed; no live app UI failure is established. No source change, hardware setting change, new permission grant or process kill was performed during this recovery attempt.

A bounded official OpenAI documentation search/read through OpenAI Docs yielded general plugin troubleshooting, without a documented remedy for this specific native-pipe error. No unrelated API transport guidance was substituted. The smallest next assistance is opening StatBatt's Details window from its menu-bar item, leaving it open so native binding can be retried. Do not press Apply or alter the charge limit for this inspection.

The owner opened Details as requested. Reinitialized CUA successfully with fresh inventory, then attempted `cua.getApp("StatBatt")` against the visibly owner-opened app. The bridge immediately returned “native pipe closed before response” again. Opening a window did not resolve app selection. No UI screen/interaction was captured, no setting changed and no software source changed. Automated native inspection remains blocked by the tool; a user-supplied Charging-tab screenshot is the next available evidence for static visual review. It cannot establish interactive Apply behavior or accessibility acceptance.

## Owner screenshot and build2 restart handoff

The owner supplied a Charging screenshot dated08:26:29. It shows the prior static “Native integration not verified” card and “StatBatt can’t apply an Apple charge limit yet.” Product design inspected the supplied pixels read-only and confirmed it matches the earlier build, not current NativeLimitView. The visible custom-band card is readable, explicitly inactive and disabled; no material clipping defect was established at that supplied size. Screenshot review does not establish current trusted setup, Apply, keyboard or VoiceOver acceptance.

Read-only packaged binary inspection found current “One-time trusted shortcut setup” / “Record trusted setup” strings, and matched the previous final executable hash. The current instance still started07:27:30, before the08:05:29 rebuild. Owner suggested restart; confirmed that Quit from StatBatt’s menu then reopening the rebuilt bundle is necessary. Closing Details alone leaves the earlier process running.

Corrected a newly found stale Settings recovery statement to disclose persistence of the Apple limit after quit, manual100% recovery after checking/stopping the shortcut, and absence of custom/helper controls. Added a read-only Settings About StatBatt version label from Bundle metadata and raised local CFBundleVersion to2. The local candidate reports0.1.0(2). Release rebuild and codesign verification passed; the previously executed102-test suite remains the software contract evidence, without claiming it reran after this copy/metadata-only correction. No new test was needed for displayed metadata/text. No shortcut was run or charging setting changed.

Build2 source manifest SHA256: `4a2b15e3454a12d2a7c291fae1ecf807bb883f9c4a244e453e03c1a4211325d6`; executable SHA256: `adf87578cbb0eb2b1ec712fdedf274463807a54724e230873184265b7022e65c`. These supersede build1 hashes. The owner must reopen the rebuilt candidate before a current UI screenshot can validate it.

## Build2 restart verified

Owner requested confirmation that StatBatt completely quit, then continuation. Read-only `pgrep -x StatBatt` returned exit1 with no matches: no StatBatt process remained. Rechecked the build2 bundle signature and CFBundleVersion=2. Reconnected CUA, navigated Finder to the exact dist directory and opened StatBatt. Read-only process verification found new PID9095 started08:29:54 executing the exact rebuilt dist bundle. This establishes exit of the old instance and launch of the new candidate, not GUI acceptance. The following CUA bundle-ID selection returned `timeoutReached` (-10005), so automated screen inspection remains unavailable. No hardware request or setup declaration was made.

Product design independently source-reviewed the final Settings quit/recovery guidance and metadata version row, finding no material issue, and saved its bounded screenshot/source review in the design handoff. Current native setup screen still requires a fresh owner screenshot or working desktop binding. The obsolete screenshot cannot validate the newly restarted build.

## StatBatt landing page — local review

Owner requested a simple, attractive landing site and an art designer collaborating with the team. Added the isolated dependency-free static site in `landing/dist/`, with a forest-green editorial theme, original generated glass-battery artwork, visibly labeled synthetic app/chart previews, feature overview, development status, and native keyboard-operable FAQ disclosures. Asset-only art design and fresh-context product/content review collaborated with the root implementation. No human contractor was hired and no spending occurred. Artwork provenance and its single built-in imagegen prompt are recorded in `landing/ART_DIRECTION.md`.

The page accurately presents local monitoring/history/CSV/settings/opt-in alerts, target-specific Apple 80% workflow qualification, pending app/cutoff/lifecycle checks, unavailable custom/discharge/thermal control, and absence of a public download. Independent source review caught and corrected the History versus Settings clear-history location, small-label contrast, and enlarged-text reflow risks. Website work changes no native Swift code, battery setting, shortcut, app packaging, or device capability.

Verification: local HTTP response 200; all 9 links and 9 unique IDs checked, local stylesheet and hero image resolved, one main heading and image alt checked, no external links/asset requests or temporary test override remain. Browser inspection confirmed the hero loaded, no console warnings/errors, no horizontal overflow at desktop 1280px and mobile 390px/320px, and status-anchor navigation plus mouse/Enter FAQ disclosure behavior. Temporary 200% root text enlargement initially exposed a narrow highlight-grid overflow; flexible columns and word wrapping fixed it. Rechecked at 320px and 1280px with 32px root text and matching document width, then restored 16px text and normal browser sizing. `landing/preview.jpg` is local review evidence, not a requested social card or deployment thumbnail. Native Swift tests were not rerun because this change is isolated static website content.

Local preview runs at `http://127.0.0.1:4187/`; README records how to restart it without dependencies. The preview browser is retained for the owner. Publication remains a separate gate in PROJECT_BRIEF.md: no Site registration, source upload, cloud deployment, public sharing, app distribution, commit, push, or PR occurred. Existing in-progress untracked native-app files remain untouched. Git remote and human author identity are still unset, so no fabricated commit/PR metadata was supplied.

## Monorepo follow-up — coordinated and verified

Owner approved `apps/statbatt/`, `apps/landing/`, shared root `docs/`, preservation of app identity/state, coordinated relocation with the **Implement the v1 spec** chat, and local landing commits. The app chat paused edits and reported no workers or in-flight modifications before the move. A pre-move app checkpoint was committed as `7d8d28d` on `implementation/v1`, then the coordinated changes proceeded on `codex/monorepo-landing`. GitHub authenticated account identity was read without exposing credentials: owner Jason Fricano / `jfricano` / ID44284799. Repository-local author attribution uses the corresponding private GitHub noreply address; global Git settings are unchanged. These facts supersede historical no-commit/placeholder-email entries above. No remote is configured.

Moved the Swift package, Sources, Tests, Resources, scripts, app README and app changelog together into `apps/statbatt/`; moved the complete landing directory into `apps/landing/`. Shared specs/research/handoffs and the root brief/working record remain root. Added a root overview and `docs/MONOREPO.md`, updated current guidance commands, relocated app README links to `../../docs/`, and added current-path context to implementation status. Historical logs/manifests remain historical. Root ignored `.build/` evidence and the old root `dist/StatBatt.app` remain untouched so the currently running app's executable is not removed. No app restart or battery setting change occurred.

Hash verification: all42 moved package/source/test/resource/script files initially byte-identical. The only later native-input edit corrects the optional hook's installation-path comment; package, runtime sources, tests, resources, and both executable build scripts remain byte-identical. Bundle ID `dev.statbatt.local`, version0.1.0(2), and Application Support data-path code remain unchanged. Landing output remains tracked through its local ignore rules; native caches/distribution remain ignored.

Relocated verification passed102 tests (50 XCTest+52 Swift Testing), zero failures, release packaging, strict local signature, and bundle identifier/build2 checks. Logs are `/private/tmp/statbatt-monorepo-tests.log` and `/private/tmp/statbatt-monorepo-build.log`. A Markdown link/fence audit passed83 local targets across33 files before final progress documentation. The relocated landing preview responds200 at the same address. Native GUI/Apply/hardware qualification is not expanded by this work. The app chat independently reviewed the completed relocation read-only, found no material issue, verified executable permissions/paths/identity/preserved evidence, and independently passed strict signature verification. Its review relied on the root test/build logs rather than duplicating compilation. Reorganization and landing are staged/committed separately, with the prior app checkpoint retained for a reviewable comparison. No push, GitHub PR, deployment or app release is performed in this local step.

## Current native setup visually observed from owner screenshots

Owner supplied08:35:21 current Charging setup and08:35:27 compatibility screenshots. The current NativeLimitView is visibly present, expected shortcut found, all three setup declarations unchecked, and Record trusted setup visibly disabled. This is the expected unconfigured state. Native target fingerprint matches Mac16,13/arm64/macOS27.0.1/26A434/mBoot-20457.1.29; custom and discharge controls remain inactive, helper absent. The prior old-instance screen mismatch is resolved by the verified restart plus new screenshot. Native automation app binding remains unavailable; this is owner-supplied static visual evidence.

Preserved exact screenshot copies in ignored .build/ui-native-setup-083521.png and .build/ui-native-target-083527.png for local review. Product design is reviewing the current original pixels. No setup declaration was checked on the owner's behalf, no Apply was invoked, and the current100% baseline was not independently re-observed in these images. No build/source change or extra test run is warranted absent a material visual finding. Remaining live interaction, verification/recovery, keyboard/VoiceOver and hardware acceptance are still distinct gates.

Product design completed static visual QA of both current08:35 screenshots at original resolution: no material UI/UX defect at the supplied size/light appearance. Current native setup rendering and disabled admission affordance are now visually reviewed. Other states, appearances, keyboard/VoiceOver and real execution remain unexercised.

Owner supplied StatBatt-diagnostics.json generated08:36:12 local. Read-only inspection confirms the exact target, public monitoring verified, expected native limit80 allowed but temporarily unavailable because nativeState=notConfigured, manual user-confirmed restoration/no current-limit getter, helper notInstalled, and custom hold/inhibition unsupported. Temperature is estimated27.09°C; health derived96.94%; SOC100%, adapter supplying power, charging=false, nominal system thermal pressure. Current/power/voltage and OS condition remain unavailable as declared. No present native setup/request failure is established; the user has not recorded setup. SOC100% is not proof of the Battery settings charge-limit baseline. No action/setting change followed from the diagnostic.

## GitHub organization setup, proprietary license, and guides

Owner authorized the Orca Solutions organization remote, proprietary licensing, and a PR for landing rollout; additionally requested current build documentation and a short user guide. Verified GitHub membership/organization name and existing repositories, then created new private `Orca-Solutions/stat-batt` and configured `origin` to its HTTPS URL. No existing organization repository was modified. Prepared local `main` at the preserved original app checkpoint `7d8d28d` for initial repository setup; the work remains on `codex/monorepo-landing`, retaining separate migration/landing commits `1d0440d` and `a1235d8`.

Added root LICENSE with proprietary/all-rights-reserved terms for Orca Solutions and a third-party-terms carveout. Updated the overview, app/landing READMEs, project brief and build plan to reflect the selected license/remote. Landing footer now names Orca Solutions. Added `docs/BUILD_GUIDE.md` for checkout, PR branch, native test/build/signature commands, local preview, troubleshooting and static-only deployment boundaries. Added `docs/USER_GUIDE.md` for the app's actual menu/tab workflows, history export/pause/clear locations, optional notifications, diagnostics, target-specific trusted80% setup/manual confirmation/restoration, close-versus-quit, and illustrative landing content. Both guides are linked from the root, product READMEs, and documentation index.

The setup PR targets the initial app-checkpoint base and includes monorepo/landing/license/docs changes. There is no new native runtime change or CI configuration. App software evidence remains the prior verified102 tests, release build, strict signature and independent relocation review; no redundant Swift test run is claimed for licensing/documentation/footer changes. Source privacy and local-asset/link/fence checks are performed before pushing. GitHub PR creation/attachment and terminal state are verified after creation. No merge, deployment, app release, hardware request, or paid service is performed by this repository/PR step.

The owner explicitly permitted handing documentation to **Implement the v1 spec**. That chat independently source-reviewed and updated only the two guides' native portions: exact target qualification, current buttons, missing-shortcut setup, manual recovery and failed restoration-record handling, and app-versus-standalone diagnostic behavior. It verified links/fences/whitespace and reported completion; checkout/landing/deployment content and runtime sources remain untouched. Root restaged the final reviewed guides for the setup PR. Publication scope audit found86 tracked files at the check, no native build artifacts, internal operating documents or detected credential tokens; native inputs were re-compared with the original checkpoint and remain unchanged apart from the optional hook comment. The current local landing response remains200.


## Separate landing comparison and completed foundation rollout

Owner requested a development agent for one comparison page linked next to Questions, followed by committing/pushing all outstanding landing work. Delegated only comparison HTML/CSS and shared navigation to the comparison developer; root verified official publisher material, reviewed the final copy, updated landing/build/user documentation and the source ledger, and owns Git/PR operations. Added `apps/landing/dist/compare.html` with a semantic seven-row StatBatt/coconutBattery/Energiza table, StatBatt focus cards, competitor strengths, official links, checked date, and visible development/qualification boundaries. Unconfirmed published capabilities are not characterized as absent; the comparison does not claim measured superiority, benchmark results, or battery-life improvements. Project evidence links disclose private repository access.

The new page is isolated on `codex/battery-comparison` at the completed foundation commit `bc1022f`. Foundation branch local and origin heads match; no outstanding foundation changes remain. During final verification, GitHub reported foundation PR #1 merged at17:13:29UTC on October2. Fetched main and confirmed it includes the foundation; the comparison PR therefore targets main directly. Main also has an existing GitHub Pages workflow publishing only `apps/landing/dist/`; the workflow completed successfully for `01178b9`. This task did not create/change that workflow or merge a PR. Build/landing docs now reflect the configured Pages URL, main checkout, and comparison review/deployment sequence.

Browser checks passed at320px,390px,1068px and1280px: navigation stays visible, Compare and Questions route correctly, sources navigation resolves, and the table alone scrolls horizontally with keyboard arrows. Enlarged text at200% passed at320px and1280px after correcting a clipped long word in the fit cards; the temporary override was removed. Mobile headline spacing was corrected after visual inspection. HTML/asset/fragment checks passed25 local targets across both pages; Markdown checks passed113 local targets across36 files at the audit. No new native app changes occurred; prior102-test/build/signature evidence remains applicable without a redundant Swift run for static-page/docs edits. A comparison screenshot records the reviewed normal-text layout.
