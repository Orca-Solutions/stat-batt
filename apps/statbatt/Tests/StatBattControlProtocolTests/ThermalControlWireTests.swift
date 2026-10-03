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
