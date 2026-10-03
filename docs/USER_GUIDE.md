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

## Apple charge-limit buttons

The new flow offers **Set to 80%** and **Set to 100%** in the menu and Charging. Each needs separate one-time trust and qualification. Currently80% is qualified only on **Mac16,13 / arm64 / macOS27.0.1 / build26A434 / firmwaremBoot-20457.1.29**;100% remains unavailable until its supervised app test. Monitoring needs no setup.

1. In Charging, inspect **StatBatt — Apple Limit 80** or **StatBatt — Apple Limit 100**. Each must contain exactly one Apple **Set Battery Charge Limit** action at its named value, with **Set Until Tomorrow** off. Do not run it during setup.
2. Record trust for that target only after inspection and stopping other charging apps/helpers. Setup saves declarations without execution. Reinspect if you later change the workflow; StatBatt cannot detect every edit. Existing80% trust does not cover100%.
3. Use either enabled menu button. A completed request allows the next deliberate click, without mandatory review or manual return. StatBatt cannot read the current limit. Optional Battery settings observations remain historical.

Uncertain execution disables both buttons. Check that the prior shortcut finished, or stop it in Shortcuts. Inspect the displayed80% or100% setting and record both facts in Charging to resume. A visible value or killing the CLI alone does not prove completion. Startup never repeats a request.

If the recovery record cannot be read/saved, inspect Battery settings, check or stop the shortcut, preserve the record and resolve storage before restarting. Forgetting setup does not change Apple's limit or bypass unresolved execution. Apple retains its setting after exit. No lower threshold, automatic expiry, precise electrical cutoff or active custom/discharge/temperature control is provided yet.

The separate qualification build may expose a clearly labeled one-use supervised100% test, used only after explicit authorization and100% trust. It does not enable the normal100% button by itself.

## Close, quit, and troubleshoot

Closing the dashboard keeps monitoring in the menu bar. **Quit** stops monitoring, but does not undo an Apple charge limit. If a rebuilt app still shows an old screen, quit the running instance and open the new `apps/statbatt/dist/StatBatt.app` bundle. Check **Settings → About StatBatt** for the version/build. See [implementation status](IMPLEMENTATION_STATUS.md) for the remaining acceptance checks.

## Landing page

The landing page introduces the app. **Explore StatBatt** leads to features, **See what’s available** leads to development status, and the Questions section expands answers. Its app panel and chart are labeled sample illustrations; they are not live readings. There is no download, account signup, or waitlist on the current page.
