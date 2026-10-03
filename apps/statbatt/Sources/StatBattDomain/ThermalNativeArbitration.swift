import Foundation

/// Intent sequencing only. The actuator must verify ownership, journal effects,
/// and supply current-boot observations. This type confers no hardware capability.
public struct ThermalNativeArbitration: Equatable, Sendable {
    public enum NativeState: Equatable, Sendable {
        case idle, waitingForRestoration, running, outcomeUnknown
    }
    public enum Event: Sendable {
        case authorizeThermalSession
        /// Supply a fresh operation UUID for every deliberate request.
        case requestNative(UUID)
        case restorationObserved(RestoreObservation)
        case nativeCompleted(UUID)
        case nativeOutcomeUnknown(UUID)
        /// Explicit reconciliation of an unknown native outcome; does not reauthorize thermal control.
        case nativeReconciled(UUID)
        case sleep, quit, leaseExpired, recoveryFault
    }
    public enum Effect: Equatable, Sendable {
        case none, restoreOwnedAdapter, dispatchNative
    }
    public struct RestoreObservation: Sendable {
        public let keyIsZero: Bool
        public let adapterSupplyingPower: Bool
        public let observedAt: UInt64
        public let bootID: UUID
        public init(keyIsZero: Bool, adapterSupplyingPower: Bool, observedAt: UInt64, bootID: UUID) {
            self.keyIsZero = keyIsZero; self.adapterSupplyingPower = adapterSupplyingPower
            self.observedAt = observedAt; self.bootID = bootID
        }
    }
    public private(set) var nativeState: NativeState = .idle
    public private(set) var nativeRequestID: UUID?
    public private(set) var thermalAuthorized = false
    public private(set) var recoveryRequired = false
    private var restorationFloor: UInt64?
    private var bootID: UUID

    public init(bootID: UUID) { self.bootID = bootID }
    public var mayInhibitAdapter: Bool { thermalAuthorized && nativeState == .idle && !recoveryRequired }

    /// Timestamps are continuous nanoseconds from `bootID`; fresh readback means
    /// both key and power source observed together after the restore request.
    @discardableResult public mutating func handle(_ event: Event, now: UInt64) -> Effect {
        switch event {
        case .authorizeThermalSession:
            guard nativeState == .idle, !recoveryRequired else { return .none }
            thermalAuthorized = true
            return .none
        case .requestNative(let requestID):
            guard nativeState == .idle, !recoveryRequired else { return .none }
            thermalAuthorized = false
            nativeState = .waitingForRestoration
            nativeRequestID = requestID
            restorationFloor = now
            return .restoreOwnedAdapter
        case .restorationObserved(let observation):
            guard let floor = restorationFloor, observation.bootID == bootID,
                  observation.keyIsZero, observation.adapterSupplyingPower,
                  observation.observedAt >= floor, observation.observedAt <= now,
                  now - observation.observedAt <= 2_000_000_000 else { return .none }
            restorationFloor = nil
            recoveryRequired = false
            if nativeState == .waitingForRestoration {
                nativeState = .running
                return .dispatchNative
            }
            return .none
        case .nativeCompleted(let requestID):
            guard nativeState == .running, nativeRequestID == requestID else { return .none }
            nativeState = .idle
            nativeRequestID = nil
            return .none
        case .nativeOutcomeUnknown(let requestID):
            guard nativeState == .running, nativeRequestID == requestID else { return .none }
            thermalAuthorized = false
            nativeState = .outcomeUnknown
            return .none
        case .nativeReconciled(let requestID):
            guard nativeState == .outcomeUnknown, nativeRequestID == requestID else { return .none }
            nativeState = .idle
            nativeRequestID = nil
            return .none
        case .sleep, .quit, .leaseExpired, .recoveryFault:
            thermalAuthorized = false
            recoveryRequired = true
            restorationFloor = now
            // Cancel an undispatched request; a running shortcut may still finish.
            if nativeState == .waitingForRestoration { nativeState = .idle; nativeRequestID = nil }
            else if nativeState == .running { nativeState = .outcomeUnknown }
            return .restoreOwnedAdapter
        }
    }
}
