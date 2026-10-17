# StatBatt user guide

**Archived October 17, 2026.** These are historical usage instructions, not a
supported installation guide. See [the archive record](../ARCHIVE.md) for final
build-14 state and local-service recovery/removal references. Earlier claims
below about helper absence apply to the original native-only build.

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

## Apple charge-limit buttons

Use **Set to 80%** for everyday use and **Set to 100%** for a full charge, in either the menu or Charging. Both fixed Apple shortcuts have been observed changing the displayed setting on **Mac16,13 / arm64 / macOS 27.0.1 / build 26A434 / firmware mBoot-20457.1.29**. Existing trusted setup carries over automatically; there is no trial to unlock or confirmation loop after each click.

For a fresh setup, the first launch opens Charging. Click **Install 80% shortcut…**, approve **Add Shortcut** in Apple’s window, and return to StatBatt. Repeat for **Install 100% shortcut…**, then stop other charging apps/helpers and click **Enable charge buttons**. The inspected signed workflows are included in the app; you do not build or download them separately. Each contains one Apple **Set Battery Charge Limit** action at its named value, with **Set Until Tomorrow** off. Setup records trust without running either shortcut. Later edits can change what runs and cannot all be detected. If you cancel import, return and use **Check again** to retry. Existing installed shortcuts are not imported again.

Click either button and wait for its request to complete. StatBatt reports the requested value, not a live reading of Apple's setting. Opening Battery settings to check is optional during ordinary use. Monitoring needs no setup.

Uncertain execution disables both buttons. Check that the prior shortcut finished, or stop it in Shortcuts. Inspect the displayed80% or100% setting and record both facts in Charging to resume. A visible value or killing the CLI alone does not prove completion. Startup never repeats a request.

If the recovery record cannot be read/saved, inspect Battery settings, check or stop the shortcut, preserve the record and resolve storage before restarting. Forgetting setup does not change Apple's limit or bypass unresolved execution. Apple retains its setting after exit. No lower threshold, automatic expiry, precise electrical cutoff or active custom/discharge/temperature control is provided yet.

Build 7 removes the one-use qualification screen. The old trial marker is retained only as historical data and no longer disables the 100% button.

## Close, quit, and troubleshoot

Closing the dashboard keeps monitoring in the menu bar. **Quit** stops monitoring, but does not undo an Apple charge limit. If a rebuilt app still shows an old screen, quit the running instance and open the new `apps/statbatt/dist/StatBatt.app` bundle. Check **Settings → About StatBatt** for the version/build. See [implementation status](IMPLEMENTATION_STATUS.md) for the remaining acceptance checks.

## Landing page

The landing page introduces the app. **Explore StatBatt** leads to features, **See what’s available** leads to development status, and the Questions section expands answers. Its app panel and chart are labeled sample illustrations; they are not live readings. There is no download, account signup, or waitlist on the current page.

Choose **Compare** in the header for a side-by-side view of StatBatt, coconutBattery, and Energiza. On a small screen, scroll within the labeled comparison table to view all products. Official source links and a checked date identify the basis for the comparison. Development and qualification notes distinguish StatBatt's currently available capabilities from work still pending.


## Install and remove

Open the StatBatt disk image and drag StatBatt to Applications. The app includes the two shortcuts and presents Apple's import approval during setup. A package labeled LOCAL-PREVIEW is a development artifact, not a notarized public release. Native buttons are qualified only on the documented target; monitoring remains available elsewhere.

To update, quit StatBatt before replacing the application; keep its existing local data and shortcuts so trusted setup carries forward. To remove, choose Set to 100% first if you want to remove the Apple limit, wait for completion, then quit and move the app to Trash. A persisted Apple limit does not disappear when the app is deleted. The optional shortcuts remain in your Shortcuts library and can be removed there; local history/preferences are retained unless you choose to delete them separately. There is no privileged helper or scheduled custom-control service in v1.
