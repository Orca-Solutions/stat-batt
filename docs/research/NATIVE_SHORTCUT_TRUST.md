# Native Shortcuts execution and content trust

Date: 2026-10-02. Status: bounded read-only investigation; owner subsequently accepted mutable-workflow trust under decision0002. The examined interfaces still do not establish full current-content integrity. This finding does not invalidate the successful native80% lab setter or supported manual restoration to100% recorded in [NATIVE_LIMIT_LAB.md](NATIVE_LIMIT_LAB.md).

## Question and current result

Can StatBatt use an Apple-supported interface to execute its inspected native battery-limit action while detecting changes to that action before execution?

Supported library-shortcut execution is documented and the lab demonstrated transport on this exact target. This investigation found no documented current-content inspection, content hash/revision, or immutable exported-file execution interface sufficient to meet the selected trust contract. That is a bounded finding about the examined interfaces, not proof that no possible integration exists.

[SECURITY_OPERATIONS.md](../SECURITY_OPERATIONS.md) treats user shortcut content as untrusted, requires detecting edits, states that a name alone is not a security boundary, and requires setup to fail closed when it cannot establish what will execute. Automatic native control remains disabled until this requirement is met or the owner explicitly accepts a material security/UX exception. The80% setter lab result alone does not satisfy this requirement.

## Examined supported interfaces

| Interface | Supported behavior and evidence | Limitation for this contract |
| --- | --- | --- |
| `/usr/bin/shortcuts` | Installed help/man expose `run`, `list`, `view`, `sign`. `run` takes a shortcut name or identifier; `list --show-identifiers` exposes library identities. Apple's guide documents running, listing, viewing and signing. | No content-inspection/export command is exposed in this surface. Help/man do not document running an immutable workflow file; `--input-path` supplies input to a library shortcut. |
| ScriptingBridge / Shortcuts Events | Apple recommends this interface for apps to list and run library shortcuts. Installed scripting dictionaries expose identity, display metadata, input acceptance and action count. | Examined dictionaries expose no action identifiers/parameters, content bytes, export, content hash or modification revision. |
| URL schemes | Apple's run URL targets a shortcut in the user's collection by name. | No documented immutable-content binding; it does not solve the library trust issue. |
| Signed exported `.shortcut` | Apple supports exporting/signing shortcuts for distribution and importing files through Shortcuts. | This investigation found no documented binding from the verified exported artifact to the current editable library object subsequently executed. Checking a bundled file alone would not establish that binding. |

Local read-only evidence: `/usr/bin/shortcuts --help`, `shortcuts help run`, `shortcuts help list`, `shortcuts help view`, `shortcuts help sign`, and `man shortcuts`; installed Shortcuts app version10.0; `/System/Applications/Shortcuts.app/Contents/Resources/Shortcuts.sdef` and `/System/Library/CoreServices/Shortcuts Events.app/Contents/Resources/Shortcuts.sdef`. No library database or private workflow framework was inspected.

The installed shortcut properties are `name`, `subtitle`, `id`, `folder`, `color`, `icon`, `accepts input`, and `action count`, plus the `run` command. A UUID is useful for identity and missing/replaced-entry checks; action count can detect additions/removals. Neither establishes which action or parameter is present. Replacing one action with another or editing its target can preserve identity and count. Subtitle is presentation metadata with no documented content-integrity guarantee. These limitations are engineering inferences from the exposed surface; mutation experiments were not performed.

## Integration consequences

The normal-user transport can use fixed executable/argument handling or Apple's documented ScriptingBridge interface. Execution identity, bounded inputs, serialized requests, timeout handling, local journaling, and separate acknowledged/observed outcomes remain useful implementation requirements. They do not resolve the content-integrity requirement by themselves. No private API or Shortcuts library database access has been adopted, and execution by file path is not assumed supported.

One possible owner-approved exception would explicitly treat an inspected, approved **mutable user workflow** as trusted within the user's account. A resulting setup could bind its UUID and check existence/action count, while warning that those checks do not detect every action/parameter edit, that edits can change what StatBatt executes, and that native setting/restoration outcomes still need observation or visible user confirmation. This is a candidate material change to the current trust/UX contract, not accepted behavior or a claim that UUID/count constitute content verification. It requires an explicit owner decision and corresponding specification updates before coordinator activation.

The current implementation remains unchanged: no automatic native setter, no expiring native override, and no claim of automatic restoration. The exact target Mac16,13 / macOS27.0.1 build26A434 / firmware mBoot-20457.1.29 has only the lab80% setting/readback and manual100% restoration evidence described in the lab record; cutoff and lifecycle behavior remain unverified.

## Primary sources

- [Apple: Run shortcuts from the command line](https://support.apple.com/en-nz/guide/shortcuts-mac/apd455c82f02/mac) — library execution, CLI operations, input/output, signing and exit status.
- [Apple WWDC21: Meet Shortcuts for macOS](https://developer.apple.com/videos/play/wwdc2021/10232/) — app integration through Shortcuts Events/ScriptingBridge, around25:39–25:49 and the accompanying code.
- [Apple: Run a shortcut using a URL scheme](https://support.apple.com/en-euro/guide/shortcuts-mac/apd624386f42/mac) — execution of a named shortcut in the user's collection.
- [Apple: Share shortcuts on Mac](https://support.apple.com/en-euro/guide/shortcuts-mac/apdf01f8c054/mac) — export/signing for sharing.
- [Apple: Import shortcuts and Automator workflows](https://support.apple.com/en-nz/guide/shortcuts-mac/apd02bffbaac/mac) — opening a `.shortcut` file imports it.

## Investigation bounds

Repository reading, CLI help/man, installed Apple scripting definitions, and primary Apple documentation only. No source/UI changes, shortcut execution, signing/upload, live library enumeration, database access, helper installation, SMC access or hardware write occurred during this investigation. A future supported content-integrity mechanism would need its own concrete verification; this note does not prescribe an unsupported workaround.


## Owner disposition

After disclosure of the edit limitation, the owner explicitly approved trusting the shortcut on October2: “yes statbatt may trust the shortcut.” The resulting accepted exception and retained restrictions are recorded in [decision0002](../decisions/0002-trusted-user-native-shortcut.md) and SECURITY_OPERATIONS.md. Earlier statements requiring an owner decision describe the investigation checkpoint; that trust decision is now resolved.
