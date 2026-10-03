import Foundation
import Testing
import StatBattDomain
@testable import StatBattControlProtocol

@Test func thermalControlWireRejectsPrivilegeFieldsAndInvalidPolicy() throws {
    let codec = BoundedCodec()
    for text in [
        "{\"version\":2,\"action\":\"status\"}",
        "{\"version\":1,\"action\":\"status\",\"uid\":501}",
        "{\"version\":1,\"action\":\"start\"}",
        "{\"version\":1,\"action\":\"writeKey\"}",
        "{\"version\":1,\"action\":\"start\",\"policy\":{\"key\":\"CHIE\"}}"
    ] {
        #expect(throws: (any Error).self) { try codec.decode(ThermalControlRequest.self, from: Data(text.utf8)) }
    }
    #expect(throws: (any Error).self) { try codec.encode(ThermalControlRequest(action: .start, policy: .init())) }
    #expect(throws: (any Error).self) { try codec.encode(ThermalControlRequest(action: .stop, policy: .init(enabled: true))) }
    let policy = ThermalAdapterPolicy(enabled: true)
    let request = try codec.decode(ThermalControlRequest.self, from: codec.encode(ThermalControlRequest(action: .start, policy: policy)))
    #expect(request.policy == policy)
}

@Test func thermalControlWireDistinguishesSafeNoOwnershipFromElectricalRestoration() throws {
    let codec = BoundedCodec()
    let safe = ThermalControlStatus(phase: .unavailable, controlAvailable: false, nativeMayProceed: true,
                                    adapterRestored: false, safeToExit: true, message: "No owned operation")
    let decoded = try codec.decode(ThermalControlStatus.self, from: codec.encode(safe))
    #expect(decoded.safeToExit && decoded.nativeMayProceed && !decoded.adapterRestored)
    #expect(throws: (any Error).self) {
        try codec.encode(ThermalControlStatus(phase: .recoveryRequired, controlAvailable: false,
                                              nativeMayProceed: true, message: "Unknown"))
    }
    #expect(throws: (any Error).self) {
        try codec.encode(ThermalControlStatus(phase: .watching, controlAvailable: false, message: "Invalid"))
    }
}

@Test func thermalStatusKeepsQualificationOutcomeAndAcceptsOlderReplies() throws {
    let codec = BoundedCodec()
    let result = "No fresh battery-source transition was observed; restoration verified."
    let reply = ThermalControlStatus(phase: .unavailable, controlAvailable: false,
        adapterRestored: true, safeToExit: true, message: "Automatic control unavailable.", qualificationResult: result)
    let data = try codec.encode(reply)
    let decoded = try codec.decode(ThermalControlStatus.self, from: data)
    #expect(decoded.qualificationResult == result)
    var older = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    older.removeValue(forKey: "qualificationResult")
    #expect(try codec.decode(ThermalControlStatus.self, from: JSONSerialization.data(withJSONObject: older)).qualificationResult == nil)
    #expect(throws: (any Error).self) {
        try codec.encode(ThermalControlStatus(phase: .unavailable, controlAvailable: false,
            message: "Unavailable", qualificationResult: String(repeating: "x", count: 1025)))
    }
}

@Test func nativeReconciliationIsExplicitAndBackwardCompatible() throws {
    let codec = BoundedCodec()
    let request = try codec.decode(ThermalControlRequest.self, from: codec.encode(ThermalControlRequest(action: .reconcileNative)))
    #expect(request.action == .reconcileNative && request.policy == nil)
    #expect(throws: (any Error).self) {
        try codec.encode(ThermalControlRequest(action: .reconcileNative, policy: .init(enabled: true)))
    }
    let reply = ThermalControlStatus(phase: .unavailable, controlAvailable: false, message: "Prior request needs confirmation", nativeReconciliationRequired: true)
    let data = try codec.encode(reply)
    #expect(try codec.decode(ThermalControlStatus.self, from: data).nativeReconciliationRequired == true)
    var old = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    old.removeValue(forKey: "nativeReconciliationRequired")
    #expect(try codec.decode(ThermalControlStatus.self, from: JSONSerialization.data(withJSONObject: old)).nativeReconciliationRequired == nil)
}

@Test func pendingNativeMayProceedWithoutPermittingQuitOrRemoval() throws {
    let codec = BoundedCodec()
    let pending = ThermalControlStatus(phase: .off, controlAvailable: false,
        nativeMayProceed: true, adapterRestored: true, safeToExit: false, message: "Native request reserved")
    let decoded = try codec.decode(ThermalControlStatus.self, from: codec.encode(pending))
    #expect(decoded.nativeMayProceed && !decoded.safeToExit)
    for phase in [ThermalControlPhase.watching, .paused, .restoring, .recoveryRequired, .qualifying] {
        #expect(throws: (any Error).self) {
            try codec.encode(ThermalControlStatus(phase: phase, controlAvailable: true,
                nativeMayProceed: true, safeToExit: false, message: "Conflicting phase"))
        }
    }
    #expect(throws: (any Error).self) {
        try codec.encode(ThermalControlStatus(phase: .off, controlAvailable: false,
            qualificationAvailable: true, nativeMayProceed: true, message: "Conflicting qualification"))
    }
}

@Test func automaticPauseAdmissionUsesAdvertisedLimitAndOlderStatusFailsClosed() throws {
    let codec = BoundedCodec()
    let ready = ThermalControlStatus(phase: .off, controlAvailable: true, message: "Qualified", maximumPauseSeconds: 120, minimumReservePercent: 50)
    let data = try codec.encode(ready)
    #expect(try codec.decode(ThermalControlStatus.self, from: data).admittedAutomaticPauseSeconds == 120)
    var old = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    old.removeValue(forKey: "maximumPauseSeconds")
    #expect(try codec.decode(ThermalControlStatus.self, from: JSONSerialization.data(withJSONObject: old)).admittedAutomaticPauseSeconds == nil)
    let trialOnly = ThermalControlStatus(phase: .unavailable, controlAvailable: false, qualificationAvailable: true, message: "Trial only", maximumPauseSeconds: 2)
    #expect(trialOnly.admittedAutomaticPauseSeconds == nil)
    for invalid in [0.0, 121.0, -1.0] {
        #expect(throws: (any Error).self) {
            try codec.encode(ThermalControlStatus(phase: .off, controlAvailable: true, message: "Invalid", maximumPauseSeconds: invalid))
        }
    }
}

@Test func automaticReserveAdmissionRequiresValidAdvertisedMinimum() throws {
    let codec = BoundedCodec()
    let ready = ThermalControlStatus(phase: .off, controlAvailable: true, message: "Qualified", maximumPauseSeconds: 120, minimumReservePercent: 50)
    let decoded = try codec.decode(ThermalControlStatus.self, from: codec.encode(ready))
    #expect(decoded.admittedMinimumReservePercent == 50 && decoded.admittedAutomaticPauseSeconds == 120)
    let missing = ThermalControlStatus(phase: .off, controlAvailable: true, message: "Old service", maximumPauseSeconds: 120)
    #expect(missing.admittedAutomaticPauseSeconds == nil && missing.admittedMinimumReservePercent == nil)
    for invalid in [19.0, 81.0, -1.0] {
        #expect(throws: (any Error).self) {
            try codec.encode(ThermalControlStatus(phase: .off, controlAvailable: true, message: "Invalid", maximumPauseSeconds: 120, minimumReservePercent: invalid))
        }
    }
}
