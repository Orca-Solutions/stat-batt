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


## App v1 completion resumed — October 2, 2026

Owner requested a team to take the app through full v1 completion. Work is isolated from the landing checkout in the managed statbatt-v1-completion worktree, branch codex/app-v1-completion, starting at origin/main 01178b9. Product design, notification hardening, platform investigation, and a fresh-context final reviewer have separate ownership. Existing one-time native80% hardware authorization was already consumed; this request authorizes implementation, not undeclared privileged experiments. Full acceptance remains conditional on real backend and lifecycle evidence.

Implemented a monitor presentation validity boundary (60 seconds, separate from active-control15 seconds), localized numeric formatting and sanitized UI readings; explicit historical native labels; readable history chart summaries and source/charging observations; disabled custom one-time/thermal surfaces with prerequisites. Notification reducer coalesces bounded pending categories, preserves crossings through the cooldown, reports source transitions and native failures, resets baselines for sleep/mute/settings, and fences delayed permission replies.

Added a standalone nonactuating exact-target SMC metadata diagnostic with a closed8-key catalog, command9 metadata and conditional command5 reads only. No arbitrary key/value/command API, mutation command, capability promotion, root helper, private entitlement or GPL code adoption. BSD/MIT reference notices are preserved; the APSL header is not copied. No live probe or hardware action has yet been performed in this increment.

Integrated software suite passes121 tests (60 XCTest+61 Swift Testing), release packaging passes before build-number-only follow-up. Build3 identifies the resumed candidate. Source and GUI review, compiled probe inspection/runtime read-only results and final signature verification follow; no completion or release claim is made. Native app binding failed with 'native pipe closed before response'; keyboard/VoiceOver/live Apply/recovery remain unverified. Read-only signing check found0 valid code-signing identities, so Developer ID/notarized distribution remains unavailable.


Completion-team final regression run passes130 tests (69 XCTest+61 Swift Testing), zero failures. Build3 release packaging and `codesign --verify --deep --strict` pass. Binary SHA256 is9ec6d842954bf1d7ea17d3238c4caf56273bf5ebe383a5143cde5633c8062448. Logs remain /private/tmp/statbatt-v1-completion-final-tests.log and -final-build.log.

Fresh-context independent review of b664fbe found V1R-01 denial continued to subsequent keys, V1R-02 sleep lost queued failure with retained dedup, V1R-03 exact timestamps incorrectly handled minute-bucket sleep gaps. All were repaired; reviewer source-rechecked denial cleanup, reset/preserved-failure semantics and new HistoryTimeline with SQLite/boundary/missing-value regressions. Final commit review disposition follows. Exact pinned MIT header/license was fetched into ignored .build/provenance and ABI independently confirmed.

Reviewed release probe ran once normal-user: service/client open/close0; CHTE/CH0C metadata SMC result132; CHIE size1/hex_/D4 baseline00 read-success; CH0J permission-denied0xe00002c1, then catalog stopped. Remaining keys unattempted. Compiled symbol inspection matches read-only IO calls; C source has no write command or arbitrary input. No helper/shortcut/battery write. Evidence and remaining recovery gap are in docs/research/SMC_READ_ONLY_QUALIFICATION.md.

Native GUI binding still fails. Finder and Activity Monitor are accessible, but Activity Monitor identifies97086 at the old app path while shell read-only pgrep reports9095 at that same path. No ambiguous process was killed or live/native acceptance claimed. A proposed app-path80%/100% test is concrete in LAB_PROTOCOL but not yet authorized/executed. New hardware experiments were not inferred from broad completion authorization. No valid Developer ID identity exists locally. Full v1 acceptance remains open; no release or accepted feature reduction is claimed.


Final fresh-context review rechecked c4596ddd4046005f2147fd24df4298ea7f4214bd versus01178b9 and resolved V1R-01/02/03 with no remaining blocking/material finding within this increment. Reviewer inspected root130-test/build evidence and live read-only report, independently computed exact pinned ABI layout, and ran no hardware/build/edit. Review disposition is docs/handoffs/2026-10-02-v1-completion-review.md. Tracked Markdown audit passes125 local links across38 files before this final handoff addition; final link/whitespace/scope checks follow. Owner has pending questions for the separately authorized native app80%/100% flow with manual assistance and whether to keep original v1 acceptance open or explicitly accept a reduced scope. No response or reduced acceptance is assumed.

### Authorized native app-path follow-up — preparation only

- Owner explicitly authorized one build3 app-path Apple80% apply, visible verification, restart without replay, and manual permanent100% restoration/verification. This is separate from the completed first lab test; no adapter write or helper installation is authorized.
- Candidate source4455ae3eb8779e3e4f7c16967eacfdb92b2d0ff5, build0.1.0(3), binarySHA2569ec6d842954bf1d7ea17d3238c4caf56273bf5ebe383a5143cde5633c8062448 identified before execution.
- Read-only native UI inspection currently shows Battery settings charge-limit slider100%, optimized charging on, and shortcut editor UUID167E2AAB-4EDC-4195-8B33-271EBEE9619E with exactly one visible Set charge limit action at80%. No shortcut was run and no setting changed during preparation.
- Read-only process check shows the older checkout app still running. StatBatt desktop binding again failed with native pipe closed; owner assistance requested to quit it before verifying exit and launching the identified candidate. No ambiguous process was killed.
- Draft app PR3 created and attached: https://github.com/Orca-Solutions/stat-batt/pull/3. Software acceptance remains open. Recommendation is to retain full-v1 criteria and use the monitoring/native80% increment as a preview milestone; owner has not approved a scope reduction.
- Final documentation audit:39 tracked Markdown files,128 local links,zero missing targets; whitespace check passed. Live test remains unexecuted pending owner UI assistance.

### Correction: shortcut inspection may have executed the native action

The earlier preparation assertion that no shortcut ran was not justified. A library accessibility button click returned no immediate selection change, but the later selected card exposed Play semantics. Subsequent native Battery settings showed80%, compared with the earlier100% observation. This may have executed the Apple80% action during inspection. The agent acknowledged the mistake to the owner; no successful StatBatt app-flow test is claimed.

Owner reported100% all morning while plugged in, then85%. Read-only local history contains347 minute summaries:100% with source adapter, then99% at11:15PDT and gradual decline to90% at11:39, all reporting adapter/not charging. These summaries are not a physical circuit trace. Native80% limiting may explain the decline, but exact cause and execution timing remain unproven. StatBatt has no enabled private adapter cutoff backend and no CHIE write was dispatched.

The old StatBatt process is now absent in the process check. Shortcuts editor showed Run, not Stop. Under the owner's baseline-restoration authorization, Battery settings was set permanently100% using Set Limit to100% (not Allow Until Tomorrow), Done, then Charging detail reopened and verified100%, optimized charging on. Settings reported Charging89%; pmset still reported AC attached/not charging89%. Requested owner-visible100% confirmation because tool observations disagree. No further limit action, candidate launch or fabricated in-app confirmation occurred. Prior app-path authorization remains pending actual app execution; do not automatically replay a shortcut.

### Direct menu action — owner clarification and build4 preparation

Owner affirmed the value of menu-icon → Apply80% convenience and instructed us to finish. Product design audit MENU-01 found the current panel only opened Charging; build4 now exposes Apply80% directly after trusted setup. Menu and Charging share AppStore.canApplyNativeLimit80 and the existing guarded request80 operation. Pending/confirmed/recovery states show status/review rather than reapply; messages surface inline. Manual100% return and mutable-shortcut trust remain disclosed. This clarification does not approve a scope reduction or new private hardware backend.

Build4 initial packaging/signature passed. Integrated test rerun passed69 XCTest cases and60/61 Swift Testing cases; sameAccountInstanceLockExcludesCooperatingInstances failed on owner release. A teammate is investigating inherited file-description lifetime and a deterministic regression; this candidate is not yet fully verified. No charging dispatch occurred. The build3 process launched despite UI binding timeout; owner was asked to quit it and verify the permanent100% return baseline before candidate replacement. The one bounded app-path operation remains pending.

### Instance-lock lifetime repair and final menu software checks

Teammate proved the lifecycle defect deterministically: Darwin dup/fork descriptors share flock ownership, and close-only deinit can leave ownership held by a retained copy. A unique-inode fixture duplicated the lock descriptor with CLOEXEC, held it alive, and required reacquisition after the original owner released. It failed with anotherInstance before repair; acquired-owner explicit LOCK_UN before close fixes it while third-instance exclusion remains enforced. The exact transient child behind the earlier integrated failure is unproven.

Eight native boundary tests passed after repair. One subsequent integrated suite passed131 tests (69 XCTest+62 Swift Testing), zero failures; /private/tmp/statbatt-menu4-final-tests.log. Before/after deterministic evidence remains in /private/tmp/statbatt-lock-regression-before.log and /private/tmp/statbatt-lock-regression-after.log. Menu commit ce68c962fd501eee5c7c7137ef74776fa4eb7855 was independently reviewed in fresh context with no material/blocking finding; the lock repair and final packaging still await independent recheck. No hardware control is promoted by these software checks.

### Build4 review-ready software candidate

Fresh-context same-family reviewer cleared menu ce68c96 and lock repair782c021 with no remaining material/blocking finding within this increment. Reviewer read the before/after and integrated logs and independently verified strict local signature, bundle version4, and binarySHA256f6ccb0354d699c72d711532310467daa49f80254142a80e4406da8577424cae3. Final release build passed2.60sec. Reviewer did not independently run tests/build/UI/hardware. Full disposition: docs/handoffs/2026-10-02-menu-convenience-review.md.

The next authorized lab candidate is0.1.0(4), reviewed source782c021fcbadc6af25d89ac1b77e5e5227130f71, binaryhash above. No limit request has been made from StatBatt. The running build3 must be quit, owner-visible permanent100% baseline confirmed, and build4 identity verified before one menu80% request. Owner assistance remains pending because StatBatt UI automation times out. Original full-v1 gaps and release acceptance remain open; no merge, new backend, signing purchase or publication is authorized.

### Completed owner-assisted native menu test — October2

Owner confirmed the app closed and permanent Charge Limit100%, then used the verified build4 candidate. Trusted setup was recorded and journal phase ready corroborated Apply enabled. Owner clicked menu Apply80% once, reported Battery settings80% and confirmed in StatBatt; journal manuallyConfirmed80 requested2026-10-02T22:28:02.270Z/confirmed22:28:13.811Z. Normal quit/reopen changed the app process while preserving operation digest and request/confirmation timestamps; owner still saw the saved historical80% confirmation, with no replay observed. Owner subsequently followed finished/stopped check → permanent Set Limitto100% → Done/reopen100% → app restoration declaration and reported done. Journal restoredUserConfirmed100 records both finished/stopped and restoration at22:32:23.080Z, original operation unchanged.

The actual UI was owner-operated because native StatBatt binding remains unreliable. Fresh evidence audit confirmed this bounded qualification, preserving two limits: the finished/stopped declaration was recorded during restoration, not independently before restart; the local packet's earlier timestamp is preparation time, not completed-flow capture. Exact cutoff/current, abnormal crash/sleep/reboot, custom/thermal control, unattended return and broader targets remain unproved. No additional setting request or private key write is authorized from this result. Authoritative result: docs/research/NATIVE_APP_FLOW_RESULT.md. Original inspection incident is excluded and baseline was independently owner-confirmed before this flow.

A10-minute ordinary-session resource observation is running read-only. UI idle/closed state is not instrumented; a separate3-second stack sample occurred during the observation, so it must not be represented as a controlled-idle budget pass. Source/stack triage found no runaway loop or attributed hot path and made no source change. Concrete redundant bounded history reads exist but their materiality was not established. Final resource values and disposition follow when the observation ends.

### Resource observation result and next verification

Build4 ordinary-session observation completed600.048sec: meanCPU0.7933% of one logicalcore, peakRSS104.0469MiB/final102.1719MiB, no Internet sockets observed in roughly5sec snapshots. These values exceed proposed targets in this session, but UI closed/idle condition was not confirmed and3sec stack sampling can perturb CPU. This does not certify an idle budget pass/failure or absence of brief network activity. Triage found ordinary event waits/no attributed hotpath; repeated bounded history reads exist but no justified optimization was established. No source change. Authoritative result: docs/research/RESOURCE_OBSERVATION.md.

Requested owner close Details/menu but leave the app running before a controlled-idle rerun, without concurrent stack sampling. No battery setting change or additional native request is involved. Original full-v1/backend, accessibility/notification/retention and distribution gates remain open; the native bounded workflow is now separately qualified.

### Native evidence recheck clarification

Evidence auditor cleared the native and resource claim boundaries with one phrase requiring clarification: a pre-restart process check after manuallyConfirmed80 did observe the original candidate process and no shortcuts-run CLI, but this was CLI absence, not independent observation of library completion. NATIVE_APP_FLOW_RESULT now says exactly that; the later finished/stopped declaration remains correctly scoped to restoration. Private filtered packet stores pre-restart CLI-absence evidence and before/after candidate PIDs. No source/test/build/hardware change followed.

### Owner-confirmed closed-window resource result

Owner replied closed/still running. Same identified build4 process remained running through600.043sec observation, with no agent UI interaction, stack sampling, build or charging action. CPU1.4716% onecore exceeds0.5% target; peakRSS60.9375MiB/63.8976MB meets100MB; final37.9375MiB. Approximately5sec socket snapshots observed0 with0errors; brief connections are not excluded. Ordinary Mac use was allowed, and host sleep/system workload were not independently instrumented. Artifact is /private/tmp/statbatt-build4-idle-resource-check.json; raw rows remain temporary/private.

Source/cadence teammate found two samples/minute, no autonomous animation/feedback loop or periodic native subprocess launch. No cost was attributed by the earlier3sec stack. After completion, one longer stack diagnostic is authorized read-only to distinguish telemetry/history/framework costs; it is excluded from budget evidence. No speculative source optimization or performance acceptance is claimed. Full-v1 gates remain open and native baseline remains owner-verified100%.

### Bounded menu-label comparison prepared

The separate70sec/1ms attribution diagnostic observed telemetry/history, retained dashboard body and menu/framework/status-replication work, with no Charts/HistoryTimeline path. Inclusive stack residency is not CPU share and no dominant defect was established. Instrumented CPU1.89sec/70.0033sec is excluded from budget evidence. Raw stacks remain temporary/private. Architecture consultation recommended only a small Equatable label experiment, acknowledging the appearance-driven framework path can bypass app-driven label evaluation.

Extracted StatusItemLabel with immutable text/symbol/accessibilityDescription and .equatable(), preserving the same Label and accessibility content. No menu action, telemetry, history or native implementation changed. Build5 uniquely identifies the experiment; release compilation passed4.01sec, strict local ad-hoc signature passed, binarySHA256f92357afeaa2f3f0c52477903b1672502b560235f66a4dbde712a5117c54be02. Separate ignored bundle apps/statbatt/dist/label-experiment/StatBatt.app leaves the running qualified build4 unchanged. Source independent review, owner-visible parity and a clean600sec comparison are pending; no CPU repair, regression-suite rerun or hardware qualification is claimed.

Fresh-context same-family reviewer cleared the exact15insertions/3deletions runtime/plist diff againstf5fd180 with no blocking/material finding. Synthesized equality includes all threeStrings, so changes to text, icon or accessibility-only description remain observable. Reviewer read the4.01sec compile log and independently checked whitespace, without running build/tests/UI/hardware. Reviewed sourceSHA256bd2e209240e17c214c4a177ca4051ba84b6745fd1a4b83940247a616d3f687df/plist4b2c8b730be9057e65f20e1436b264384e73a95cf89cfb1f5dd768a6cb68ec8f. Runtime parity and CPU benefit remain unverified. Finder is opened to the experimental folder for owner-assisted normalQuit/relaunch; reliable native StatBatt binding remains unavailable. No setting action is requested.

### Build5 resource check completed

Owner reported the app running without open windows. Exact experimental build5 process/path, bundle version and binaryhash were verified; the build4 process was absent. Source reviewer subsequently cleared named commitf72adff, matching both previously reviewed file hashes. One600.010sec read-only closed-window observation completed with no agent UI/build/stack-sample/charging action: meanCPU0.1583% onecore, peakRSS75.5625MiB/79.233024MB, final25.65625MiB/26.902528MB,0observed Internet sockets and0observation errors. App CPU/RSS targets are met in this run. Restart/retained-view/host-activity differences prevent attributing the improvement solely to the Equatable label. No helper/policy budget, continuousnetworktrace or broader runtime accessibility pass is claimed. Artifact /private/tmp/statbatt-build5-idle-resource-check.json remains temporary/private. After completion, read-only history found20validpercentage readings across8completedminutes, counts2–3/minute; monitoring continued.

### Newer native intent discovered; current limit requires owner reconciliation

Read-only journal inspection during measurement found a newer intent2026-10-02T23:05:07.957Z, phase outcomeUnknown, distinct from the qualified22:28 request/22:32 restoration. The newer timestamp predates build5 preparation. Startup journalmtime23:38 is consistent with converting pending/unknown to outcomeUnknown while preserving timestamps, with no replay. Source audit of f72 found the sole production request caller is the owner Apply path; only request80Percent writes nonnil requestedAtUTC, before durable intent/execution. This proves no automatic source route, not who invoked the later intent or whether execution succeeded.

After the resource observation ended, CUA opened the Apple Charging detail sheet read-only; slider80/text charge-to80 were visible. No slider, setter, Done or shortcut action occurred. Apple UI currently shows80%, while StatBatt's newer request is unconfirmed/recovery-required. Earlier100% return is historical qualification, not a current guarantee. Owner was asked whether they applied80% again around16:05PDT; response remains pending. No owner confirmation, agent80% execution or further100% restoration is invented. Current-state claims were corrected; full-v1 and release gates remain open.

Evidence auditor rechecked the build5 resource packet and current working documentation with no material chronology/claim/scope issue: measured targets met only in this run, no causal/network overclaim, newer80% tool observation separated from owner confirmation and original build4 qualification. Source remained unchanged; no UI/build/profiling/hardware/write by the auditor. Whitespace check passed;42trackedMarkdown files/147local targets/0missing. Commit/push follows on the existing draft PR; no software test rerun is claimed for documentation.

### Owner-requested two-button native flow

Owner confirms the23:05UTC80% intent was their deliberate Apply click, not unexplained automatic replay. Its execution outcome still needs finished/stopped and visible-setting reconciliation. Owner requests one-click Set to80% / Set to100%. Product design and architecture consultation informs decision0003, superseding mandatory normal manual100% return while retaining genuine unknown fencing. Core/schema/tests and UI have separate team owners; lead owns integration/docs. A separate100% shortcut was prepared and visually inspected with one Apple setter at100%, Set Until Tomorrow off; it was not run.100% trust and new hardware authorization remain pending. No user journal was edited manually or private hardware control used.

### Two-target software checks

Default integrated suite passes137 tests (69 XCTest +68 Swift Testing), zero failures; qualification-flag suite passes138 (69+69), zero failures. Initial compile caught throwing load calls inside test macros; the test author repaired them before the passing runs. Production release build passes6.49sec and strict ad-hoc signature verification; binarySHA256dc13523b9519ccdb213e4df56ba96a596148b195013e54673de05e646c2a6bd5.100% remains absent from production qualification. Separate qualification packaging/review and actual owner-assisted flow are next; software success is not hardware proof. Neither new candidate has been launched; active build5 is untouched.

### Two-target candidate prepared and reviewed

Fresh-context same-family reviewer cleared named source commitdc5c8993c39986fee0c14ce564de476e74575eee againsta0729e2 with no blocking/material finding across core/schema/safety/tests/app/UI/packaging/docs. Reviewer read test/build logs and independently checked whitespace; did not rerun tests or touch UI/hardware/live journal. Separate qualification build passes9.40sec release compilation and strict local signature; About0.1.0-qualification(6), binarySHA25675c7b0d9e2fe1086337db946666d3c608dd625908c4f8404486e7fae1ee1ffcb. Package path apps/statbatt/dist/native-100-qualification/StatBatt.app. Neither candidate launched; old5PID53738 remains.43trackedMarkdown files/157localtargets/0missing and zsh syntax check pass. New runtime UI and actual100% flow remain unvalidated. Owner authorization/trust and initial genuine-unknown reconciliation are next; no new hardware action occurred.
