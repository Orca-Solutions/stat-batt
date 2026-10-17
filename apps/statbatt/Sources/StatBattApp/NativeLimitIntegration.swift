import AppKit
import Foundation
import StatBattNativeLimit

@MainActor
extension AppStore {
    var nativeDiagnosticState: String {
        switch nativePresentation.phase {
        case .setup: "notConfigured"
        case .ready: "ready"
        case .applying: "requested"
        case .completed: "historicalRequestReceipt"
        case .recoveryRequired: "manualReconciliationRequired"
        case .unavailable: "unavailable"
        }
    }

    func initializeNativeLimit(storageDirectory: URL) {
        Task { [weak self] in
            guard let self else { return }
            do {
                nativeCoordinator = try NativeLimitCoordinator(platform: platform,
                    storageDirectory: storageDirectory, preflight: { [weak self] in
                        guard let self else { return .unavailable }
                        return await self.nativePreflight()
                    })
                refreshNativeLimit()
            } catch {
                nativePresentation = NativeLimitPresentation(phase: .unavailable,
                    message: "Native setup is unavailable. Another StatBatt instance may own it, or its recovery record cannot be read. Monitoring continues.")
                notifyNativeFailure(id: "nativeInitialization", message: "Charging setup is unavailable. Open StatBatt to review the recovery record or another running instance.")
            }
        }
    }

    private func nativePreflight() async -> NativePreflightResult {
        guard !sleeping else { return .unavailable }
        guard NSRunningApplication.runningApplications(withBundleIdentifier: "de.appgineers.energiza").isEmpty else {
            return .conflictingController
        }
        return await NativeKnownControllerProbe.check()
    }

    func refreshNativeLimit() {
        guard let coordinator = nativeCoordinator, !nativeTaskInProgress, nativeRefreshTask == nil else { return }
        nativeRefreshTask = Task {
            defer { nativeRefreshTask = nil }
            await refreshNativePresentation(coordinator, background: true)
        }
    }

    private func refreshNativePresentation(_ coordinator: NativeLimitCoordinator, background: Bool = false) async {
        var discovered: Set<NativeFixedLimit> = []
        var missing: Set<NativeFixedLimit> = []
        var discoveryFailed = false
        for limit in NativeFixedLimit.allCases {
            do {
                if try await coordinator.discoverConfiguredShortcut(for: limit) { discovered.insert(limit) }
                else { missing.insert(limit) }
            } catch { discoveryFailed = true }
        }
        let state = await coordinator.status()
        let preflight = await nativePreflight()
        // A click can arrive while discovery is suspended. Do not overwrite its progress.
        guard !background || !nativeTaskInProgress else { return }
        updateNativePresentation(state, discovered: discovered, missing: missing, preflight: preflight)
        if let imported = pendingNativeImport, discovered.contains(imported) || missing.contains(imported) {
            pendingNativeImport = nil
            nativeSetupMessage = missing.contains(imported)
                ? "The shortcut has not been added yet. You can retry installation."
                : Set(NativeFixedLimit.allCases).isSubset(of: discovered)
                ? "Both shortcuts are installed. Enable the charge buttons below."
                : "\(imported.rawValue)% shortcut installed. Add the remaining shortcut to finish."
        }
        if discoveryFailed && state.journalHealthy && nativePresentation.message == nil {
            nativePresentation.message = "Shortcut discovery is unavailable. Open Shortcuts, then refresh StatBatt. Refresh does not apply a limit."
        }
    }

    var nativeShortcutSetupPlan: NativeShortcutSetupPlan {
        NativeShortcutSetupPlan(discovered: nativePresentation.discoveredLimits,
            missing: nativePresentation.missingLimits,
            bundled: Set(NativeFixedLimit.allCases.filter { BundledNativeShortcuts.url(for: $0) != nil }),
            deviceQualified: nativePresentation.deviceQualified,
            controllerClear: nativePresentation.conflictingControllerResolved,
            recoveryRequired: nativePresentation.phase == .recoveryRequired || nativePresentation.phase == .unavailable,
            busy: nativeTaskInProgress || sleeping || pendingNativeImport != nil)
    }

    func installNextNativeShortcut() {
        guard let limit = nativeShortcutSetupPlan.nextImport,
              let coordinator = nativeCoordinator else { return }
        // Reserve synchronously so repeated clicks cannot open duplicate import sheets.
        pendingNativeImport = limit
        nativeTaskInProgress = true
        nativeSetupMessage = "Checking the shortcut library…"
        Task {
            defer { nativeTaskInProgress = false }
            await nativeRefreshTask?.value
            do {
                guard !sleeping else { throw NativeLimitFailure.preflightUnavailable }
                let state = await coordinator.status()
                guard !state.requiresManualRecovery else { throw NativeLimitFailure.manualRecoveryRequired }
                // Never import based only on a cached absence from a previous activation.
                if try await coordinator.discoverConfiguredShortcut(for: limit) {
                    pendingNativeImport = nil
                    nativeSetupMessage = "This shortcut is already installed."
                    await refreshNativePresentation(coordinator)
                    return
                }
                guard let url = BundledNativeShortcuts.url(for: limit) else {
                    pendingNativeImport = nil
                    nativeSetupMessage = "The included shortcut is unavailable. Reinstall StatBatt from a complete package."
                    return
                }
                // Opens Apple's import approval. Does not execute or edit the library.
                if NSWorkspace.shared.open(url) {
                    nativeSetupMessage = "Click Add Shortcut in Apple's window, then return here. If you cancel, use Check again to retry."
                } else {
                    pendingNativeImport = nil
                    nativeSetupMessage = "The shortcut could not be opened. Open Shortcuts, then try again."
                }
            } catch {
                pendingNativeImport = nil
                nativeSetupMessage = "The shortcut library could not be checked. Open Shortcuts, then use Check again."
                await refreshNativePresentation(coordinator)
            }
        }
    }

    func configureNativeLimits() {
        guard let coordinator = nativeCoordinator, !nativeTaskInProgress else { return }
        nativeTaskInProgress = true
        Task {
            defer { nativeTaskInProgress = false }
            // Finish read-only discovery before entering the coordinator; never discard a click.
            await nativeRefreshTask?.value
            do {
                for limit in NativeFixedLimit.allCases {
                    _ = try await coordinator.configureTrustedShortcut(for: limit,
                        acknowledgement: .approvedMutableUserWorkflow, confirmedOtherControllersStopped: true)
                }
                await refreshNativePresentation(coordinator)
            } catch { await displayNativeFailure(coordinator) }
        }
    }

    var canSetNativeLimit80: Bool { canSetNativeLimit(.eighty) }
    var canSetNativeLimit100: Bool { canSetNativeLimit(.hundred) }

    private func canSetNativeLimit(_ limit: NativeFixedLimit) -> Bool {
        nativeCoordinator != nil && !nativeTaskInProgress && !sleeping &&
            (nativePresentation.phase == .ready || nativePresentation.phase == .completed) &&
            nativePresentation.qualifiedLimits.contains(limit) && nativePresentation.trustedLimits.contains(limit) &&
            nativePresentation.discoveredLimits.contains(limit) && nativePresentation.conflictingControllerResolved
    }

    func setNativeLimit(_ limit: NativeFixedLimit) {
        guard canSetNativeLimit(limit), let coordinator = nativeCoordinator else { return }
        beginNativeRequest(limit)
        Task {
            defer { nativeTaskInProgress = false }
            // Finish read-only discovery before entering the coordinator; never discard a click.
            await nativeRefreshTask?.value
            do {
                guard !sleeping else { throw NativeLimitFailure.preflightUnavailable }
                guard await thermalControl.prepareNative() else {
                    message = thermalControl.errorMessage ?? "Adapter restoration is required before changing the Apple limit."
                    await refreshNativePresentation(coordinator)
                    return
                }
                guard !sleeping else { throw NativeLimitFailure.preflightUnavailable }
                _ = try await coordinator.request(limit)
                await refreshNativePresentation(coordinator)
            } catch { await displayNativeFailure(coordinator) }
        }
    }

    private func beginNativeRequest(_ limit: NativeFixedLimit) {
        nativeTaskInProgress = true
        nativePresentation.phase = .applying
        nativePresentation.lastRequestedLimit = limit
        nativePresentation.canForgetSetup = false
        nativePresentation.message = nil
    }

    func confirmNativeVisibleLimit(_ limit: NativeFixedLimit) {
        updateNativeConfirmation { try await $0.confirmVisibleLimit(limit) }
    }

    func reconcileNativeLimit(_ limit: NativeFixedLimit, priorShortcutCompletedOrStopped: Bool) {
        guard priorShortcutCompletedOrStopped else { return }
        updateNativeConfirmation {
            try await $0.reconcileVisibleLimit(limit, priorShortcutCompletedOrStopped: true)
        }
    }

    func forgetNativeSetup() {
        updateNativeConfirmation { try await $0.forgetSetup() }
    }

    private func updateNativeConfirmation(
        _ action: @escaping @Sendable (NativeLimitCoordinator) async throws -> NativeLimitStatus
    ) {
        guard let coordinator = nativeCoordinator, !nativeTaskInProgress else { return }
        nativeTaskInProgress = true
        Task {
            defer { nativeTaskInProgress = false }
            // Finish read-only discovery before entering the coordinator; never discard a click.
            await nativeRefreshTask?.value
            do {
                _ = try await action(coordinator)
                await refreshNativePresentation(coordinator)
            } catch { await displayNativeFailure(coordinator) }
        }
    }

    private func displayNativeFailure(_ coordinator: NativeLimitCoordinator) async {
        await refreshNativePresentation(coordinator)
        guard nativePresentation.phase != .unavailable else { return }
        if nativePresentation.phase == .recoveryRequired {
            nativePresentation.message = "The shortcut may still be running. Check or stop it in Shortcuts, then inspect the displayed limit in Battery settings before resuming the buttons."
        } else if nativePresentation.message == nil {
            nativePresentation.message = "Native setup or request could not proceed. Check the configured shortcut and other charging controllers, then refresh."
        }
    }

    private func updateNativePresentation(_ state: NativeLimitStatus, discovered: Set<NativeFixedLimit>,
                                          missing: Set<NativeFixedLimit>, preflight: NativePreflightResult) {
        let phase: NativeLimitPhase
        if !state.journalHealthy { phase = .unavailable }
        else if state.requiresManualRecovery { phase = .recoveryRequired }
        else {
            switch state.phase {
            case .notConfigured: phase = .setup
            case .ready: phase = .ready
            case .requested, .outcomeUnknown: phase = .recoveryRequired
            case .acknowledgedUnverified: phase = .completed
            case .ownerReconciled: phase = .ready
            }
        }
        nativePresentation = NativeLimitPresentation(phase: phase,
            discoveredLimits: discovered, missingLimits: missing, trustedLimits: state.trustedLimits,
            qualifiedLimits: state.qualifiedLimits, deviceQualified: state.qualifiedTarget,
            conflictingControllerResolved: preflight == .clear,
            lastRequestedLimit: state.lastRequestedLimit, lastObservedLimit: state.lastObservedLimit,
            canForgetSetup: state.journalHealthy && !state.requiresManualRecovery,
            message: preflight == .conflictingController
                ? "Stop other charge-management apps and helpers before changing the limit. StatBatt does not stop them for you."
                : preflight == .unavailable ? "The controller check is unavailable. Setting a limit is disabled." : nil)
        if !state.journalHealthy {
            nativePresentation.message = "The recovery record could not be saved. Check or stop the shortcut and inspect Battery settings. Resolve local storage and restart StatBatt before recording recovery."
        }
        if let failure = state.lastError {
            notifyNativeFailure(id: "native:\(failure.rawValue)", message: state.requiresManualRecovery || !state.journalHealthy
                ? "Charging recovery needs your attention. Check or stop the shortcut, then inspect the limit in Battery settings."
                : "Charging setup or request could not proceed. Open StatBatt for details.")
        } else { clearNativeFailureNotification() }
    }
}
