# StatBatt user guide

StatBatt is a native Apple silicon MacBook battery utility in local development. There is no public download yet. Obtain and run the development build only through an authorized checkout; [build instructions](BUILD_GUIDE.md) cover that process. Advanced readings and charging capabilities depend on your exact Mac and macOS version.

## Open and read the app

On the first interactive launch, the Battery dashboard opens. Later launches may stay in the menu bar. Click the StatBatt battery item to open its panel, then choose **Details**, **History**, **Charging settings…**, or **Settings…**. Command-comma also opens Settings.

The panel shows charge, power source, and charging state. Details groups battery condition, capacity, temperature, and power readings when available. A tilde (`~`) marks an estimate; health is an estimated capacity ratio, not a diagnosis. **Unavailable** means there is no supported reading, not zero. A paused charge can have several causes; StatBatt may not know which one applies.

## History and exports

**History** shows seven days of one-minute summaries. Sleep and missing-reading gaps remain visible.

- Choose **Export CSV…** in History, or **Export history…** in Settings, to save readings.
- In Settings, turn **Record battery history** off to pause recording. Saved history remains available.
- In History, choose **Clear…** and confirm **Clear history** to remove saved readings and gap records. Export first if you need to keep them.

History and settings stay in `~/Library/Application Support/StatBatt`. The current build needs no cloud account or analytics service.

## Settings and alerts

In Settings, choose what the menu bar shows and your temperature unit. **Allow battery notifications** opts into alerts and macOS notification permission. Charging transitions and temperature alerts are optional. Temperature alerts require an available reading and do not control charging. Notification delivery and launch-at-login behavior remain subject to device qualification.

**Export diagnostics…** saves an allowlisted compatibility report for troubleshooting. It does not execute a charging action.

To include the running app's native-workflow state, export from StatBatt. The standalone diagnostic command is a read-only probe and does not load the app's saved native setup or recovery journal.

## Apple 80% workflow

This is a target-specific development workflow. Its bounded setter/readback lab passed; end-to-end app, cutoff, and lifecycle acceptance remain pending. Monitoring does not require this setup, and setup alone does not change charging.

The current 80% setter qualification is **Mac16,13 / arm64 / macOS 27.0.1 / build 26A434 / firmware mBoot-20457.1.29**. A different fingerprint disables native setup and Apply; a successful build does not qualify another Mac.

1. Open **Charging settings…**. If the device is unqualified or another controller is unresolved, applying the limit is unavailable.
2. Choose **Open Shortcuts for setup** and inspect the shortcut named **StatBatt — Apple Limit 80**. If it is missing, create it with exactly one Apple **Set Battery Charge Limit** action set to **80%**, then return to StatBatt and refresh if needed. Later content edits cannot all be detected; trust only the workflow you inspected. StatBatt checks its identity and can reject missing, duplicate, or replaced shortcuts.
3. Verify the visible **100%** return baseline in macOS Battery settings and stop other charge-management controllers, including Energiza and its helper when installed. Check the three declarations only when they are true, then choose **Record trusted setup**. This saves setup without applying the limit. The button stays disabled while a declaration or admission check is unresolved; StatBatt does not stop controllers for you.
4. After setup, click StatBatt's menu-bar battery item and choose **Apply 80% limit** directly in its panel. The same button is available in Charging. It stays unavailable during sleep, unresolved recovery or another request. You do not need to run the shortcut manually for the normal app flow.
5. Check the displayed setting in macOS Battery settings. If it shows 80%, choose **I see an 80% limit in Battery settings** in StatBatt. A completed request or battery percentage alone is not proof of the setting. StatBatt records your last confirmation; it cannot read the current limit.

To return to **100%**, first verify that the prior shortcut finished, or stop it in Shortcuts. Check **The shortcut has finished, or I stopped it in Shortcuts.** Restore 100% manually in macOS Battery settings, verify it is displayed, then choose **I restored 100% in Battery settings** in StatBatt. These declarations only record what you checked; they do not change the setting. An interrupted or timed-out request can remain unresolved and blocks another request until recovery is recorded. Startup does not retry a pending request. Killing a command-line process does not prove the underlying shortcut stopped.

If StatBatt cannot read or save its recovery record, new requests remain disabled. Check or stop the shortcut and restore 100% manually; preserve the recovery record, export diagnostics, and resolve local storage before restarting and recording recovery. **Forget shortcut setup**, when available, removes StatBatt's configuration without changing Apple's limit and cannot bypass unresolved recovery.

The Apple setting persists after StatBatt quits. There is no lower threshold, automatic expiry, automatic restoration, or guarantee of a precise electrical cutoff. Custom charge bands, intentional discharge cutoffs, and temperature-based charging controls are unavailable; no privileged helper is installed.

## Close, quit, and troubleshoot

Closing the dashboard keeps monitoring in the menu bar. **Quit** stops monitoring, but does not undo an Apple charge limit. If a rebuilt app still shows an old screen, quit the running instance and open the new `apps/statbatt/dist/StatBatt.app` bundle. Check **Settings → About StatBatt** for the version/build. See [implementation status](IMPLEMENTATION_STATUS.md) for the remaining acceptance checks.

## Landing page

The landing page introduces the app. **Explore StatBatt** leads to features, **See what’s available** leads to development status, and the Questions section expands answers. Its app panel and chart are labeled sample illustrations; they are not live readings. There is no download, account signup, or waitlist on the current page.
