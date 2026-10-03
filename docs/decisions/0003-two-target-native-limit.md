# 0003 — Two deliberate native limit buttons

Status: UX direction accepted by the Product Owner, October 2, 2026; two-button local implementation in build 7.

## Context

The owner asked for one-click **Set to 80%** and **Set to 100%**, replacing the repeated review/manual100% return. Product design consultation recommends this flow. This explicitly supersedes the normal-operation baseline/return loop in decision0002; its mutable-workflow warning, identity admission and genuine unknown-execution fence remain.

## Decision

Expose both buttons in the menu and Charging. Each target has a separate fixed one-action Apple shortcut, owner inspection/trust record and exact-target qualification. Existing80% trust migrates without granting100% trust. Setup never executes. A successful transport acknowledgement is a historical completed request, not a current-limit reading, and permits the next deliberate qualified request without mandatory observation or manual restoration. Startup never dispatches, queues, retries or replays.

Busy state blocks both buttons. Pending or genuinely unknown execution blocks both until the owner explicitly reports the prior shortcut finished or was stopped and the currently visible80% or100% setting. Observing a setting alone does not prove execution completion. Legacy manuallyConfirmed80 records retain this fence because schema1 permitted that confirmation after unknown execution. Owner observations stay historical.

Dispatch accepts only the closed80/100 enum, with fixed executable/arguments, fresh controller and identity checks, same-account lock and durable intent before execution. Storage failures disable dispatch. Both fixed setters are enabled on the exact observed target after a visible 100→80→100 round trip using the trusted identities through `/usr/bin/shortcuts run`. The owner renewed the request for simple two-state switching on October 2. Build 7 removes the one-use trial UI and execution path. Fresh setup records the two distinct identities with one explicit Enable charge buttons action; existing trust records are preserved. Read-only activation refresh does not disable an otherwise eligible button: an accepted click displays progress immediately and waits for refresh before fresh dispatch checks.

## Consequences

Ordinary use becomes two buttons after one-time setup. The app cannot independently read the selected limit or detect every future shortcut edit. Apple retains the setting after app exit. No automatic expiry, private controller, helper installation, electrical cutoff or machine-wide exclusion is established. Original full-v1 and release acceptance remain open.

## Evidence and next gate

The previous build4 app80%/visible confirmation/normal-reopen/manual100% result remains historical. The owner confirms the later23:05UTC80% request was their deliberate Apply click; its execution outcome still needs reconciliation. The separate100% shortcut was prepared and visually inspected as one Apple setter at100%, Set Until Tomorrow off, without execution. Software review and separately authorized actual100% qualification remain pending.


## Build 7 verification update

The earlier build 6 observation does not establish the 100% action: the owner clarified that they manually changed System Settings. In this follow-up, both workflows were visually inspected in Shortcuts, with one setter at the correct percentage and Set Until Tomorrow off. Their identities matched the saved trust. System Settings showed 100 initially, 80 after the 80 shortcut completed, and 100 after the 100 shortcut completed; no manual slider change was used. This qualifies the fixed setter mechanism on this target, not physical cutoff or the rest of v1. App-button/restart verification is recorded in WORKING_RECORD.md.

The owner subsequently tested both normal build 7 buttons against Apple's Battery settings and reported “Both buttons work.” The actual app-path qualification is therefore established for these two fixed setters on this target.
