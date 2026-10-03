# 0004 — Native Apple charging is the v1 control scope

Accepted by the owner on October 2, 2026.

The owner requested completing v1 and shipping the required shortcuts in the install package. After reviewing the unavailable independent charge gate, the owner said the separate custom controls were unnecessary because charging is handled automatically. A subsequent idea to tie temperature control to the native setting was withdrawn ("ohhhh nm").

V1 therefore consists of local battery monitoring, menu presentation, history/CSV, diagnostics, preferences, opt-in battery/temperature/failure alerts, and deliberate native Apple 80%/100% limit buttons. macOS manages its charging behavior. Custom lower/upper bands, forced discharge, app-controlled temperature pause/resume, temporary overrides and their privileged daemon are not required for this release. They are not implemented capabilities and must not be marketed as automatic features of StatBatt.

Ship the two inspected signed .shortcut documents in the app package. First-time setup opens each through Apple's supported import UI; the user approves Add Shortcut and then explicitly enables the controls. No manual action authoring, external workflow download, private library modification or automatic execution during installation is required. Preserve existing shortcut trust on upgrade, avoid duplicate imports and fail clearly on missing/ambiguous/replaced identities.

Native execution continues to journal intent before dispatch, serialize requests, reject known controller conflicts, preserve interrupted outcomes and never replay at startup. A completed request is not a live setting reading. Shortcuts remain editable by the user; approval does not guarantee immutable library contents. Apple retains a selected limit after the app quits.

The exact hardware qualification remains Mac16,13 / arm64 / macOS 27.0.1 / 26A434 / mBoot-20457.1.29. Other Macs can monitor; charging is not advertised as qualified until checked. Public distribution requires Developer ID signing, notarization and clean-machine validation. The owner has no Apple Developer membership yet; local packages are previews, not public releases.

This decision supersedes full-v1 custom-control requirements in earlier specification, brief, build-plan and acceptance documents. It does not waive truthfulness, remaining native lifecycle/accessibility checks, signing, publication approval or broader compatibility validation.
