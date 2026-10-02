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
        case .awaitingConfirmation: "acknowledgedUnverified"
        case .confirmed: "manuallyConfirmed80"
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
        guard let coordinator = nativeCoordinator, !nativeTaskInProgress else { return }
        nativeTaskInProgress = true
        Task {
            defer { nativeTaskInProgress = false }
            let state = await coordinator.status()
            let preflight = await nativePreflight()
            do {
                let found = try await coordinator.discoverConfiguredShortcut()
                updateNativePresentation(state, discovered: found, preflight: preflight)
            } catch {
                updateNativePresentation(state, discovered: false, preflight: preflight)
                guard state.journalHealthy else { return }
                nativePresentation.message = state.requiresManualRecovery
                    ? "Shortcut discovery is unavailable. The prior request still needs review in Shortcuts and Battery settings."
                    : "Shortcut discovery is unavailable. Open Shortcuts, then refresh StatBatt. This refresh does not apply a limit."
            }
        }
    }

    func configureNativeLimit(inspected: Bool, baselineConfirmed: Bool, controllersStopped: Bool) {
        guard inspected, baselineConfirmed, controllersStopped,
              let coordinator = nativeCoordinator, !nativeTaskInProgress else { return }
        nativeTaskInProgress = true
        Task {
            defer { nativeTaskInProgress = false }
            do {
                let state = try await coordinator.configureTrusted80Shortcut(
                    acknowledgement: .approvedMutableUserWorkflow, confirmedBaselinePercent: 100,
                    confirmedOtherControllersStopped: true)
                updateNativePresentation(state, discovered: true, preflight: await nativePreflight())
            } catch {
                await displayNativeFailure(coordinator)
            }
        }
    }

    func applyNativeLimit80() {
        guard let coordinator = nativeCoordinator, !nativeTaskInProgress, !sleeping,
              nativePresentation.phase == .ready,
              nativePresentation.deviceQualified && nativePresentation.shortcutDiscovered &&
              nativePresentation.conflictingControllerResolved else { return }
        nativeTaskInProgress = true
        nativePresentation.phase = .applying
        nativePresentation.canForgetSetup = false
        nativePresentation.message = nil
        Task {
            defer { nativeTaskInProgress = false }
            do {
                let state = try await coordinator.request80Percent()
                updateNativePresentation(state, discovered: true, preflight: await nativePreflight())
            } catch {
                await displayNativeFailure(coordinator)
            }
        }
    }

    func confirmNativeLimit80() {
        updateNativeConfirmation { try await $0.confirmVisibleLimit80() }
    }

    func confirmNativeRestored100(priorShortcutCompletedOrStopped: Bool) {
        guard priorShortcutCompletedOrStopped else { return }
        updateNativeConfirmation { try await $0.confirmRestored100(priorShortcutCompletedOrStopped: true) }
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
            do {
                let state = try await action(coordinator)
                let found = (try? await coordinator.discoverConfiguredShortcut()) ?? false
                updateNativePresentation(state, discovered: found, preflight: await nativePreflight())
            } catch {
                await displayNativeFailure(coordinator)
            }
        }
    }

    private func displayNativeFailure(_ coordinator: NativeLimitCoordinator) async {
        let state = await coordinator.status()
        let found = (try? await coordinator.discoverConfiguredShortcut()) ?? false
        updateNativePresentation(state, discovered: found, preflight: await nativePreflight())
        guard state.journalHealthy else { return }
        nativePresentation.message = state.requiresManualRecovery
            ? "The result needs manual review. Check or stop the shortcut, then verify the limit in Battery settings and restore 100% before another request."
            : "Native setup or request could not proceed. Check the configured shortcut and other charging controllers, then refresh."
    }

    private func updateNativePresentation(_ state: NativeLimitStatus, discovered: Bool,
                                          preflight: NativePreflightResult) {
        let phase: NativeLimitPhase
        switch state.phase {
        case .notConfigured: phase = .setup
        case .ready, .restoredUserConfirmed100: phase = state.canRequest80 ? .ready : .unavailable
        case .requested: phase = .recoveryRequired
        case .acknowledgedUnverified: phase = .awaitingConfirmation
        case .outcomeUnknown: phase = .recoveryRequired
        case .manuallyConfirmed80: phase = .confirmed
        }
        nativePresentation = NativeLimitPresentation(phase: phase,
            shortcutDiscovered: discovered, deviceQualified: state.qualifiedTarget,
            conflictingControllerResolved: preflight == .clear,
            message: preflight == .conflictingController
                ? "Stop Energiza and its helper before applying a native limit. StatBatt does not stop them for you."
                : preflight == .unavailable ? "The controller check is unavailable. Applying a limit is disabled." : nil,
            canForgetSetup: state.lastError != .journalUnavailable &&
                (state.phase == .ready || state.phase == .restoredUserConfirmed100))
        if !state.journalHealthy {
            nativePresentation.message = "The recovery record could not be saved. Check or stop the shortcut and restore 100% in Battery settings. Resolve local storage and restart StatBatt before recording recovery."
        }
    }
}
