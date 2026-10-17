import Foundation
import Security
import Testing
@testable import StatBattControlProtocol

@Test func thermalStatusIsAlwaysNonActuatingAndVersioned() throws {
    let request = try BoundedCodec().encode(ThermalStatusRequest())
    let response = try BoundedCodec().decode(ThermalStatusResponse.self, from: ThermalStatusEndpoint.response(to: request))
    #expect(response.version == 1 && response.actuationDisabled)
}
@Test func thermalStatusRejectsMalformedAndOversizedPayloads() {
    for text in ["{}", "[]", "{\"version\":2}", "{\"version\":1,\"key\":\"CHIE\"}",
                 "{\"version\":true}", "{\"version\":{}}", "not JSON"] {
        #expect(throws: (any Error).self) { try ThermalStatusEndpoint.response(to: Data(text.utf8)) }
    }
    #expect(throws: (any Error).self) { try ThermalStatusEndpoint.response(to: Data(repeating: 32, count: 257)) }
    #expect(throws: (any Error).self) {
        try BoundedCodec().decode(ThermalStatusResponse.self, from: Data("{\"version\":1,\"actuationDisabled\":false}".utf8))
    }
}
@Test func thermalPeerRequirementPinsAppleTeamAndIdentifier() throws {
    let string = try ThermalServiceSigning.requirement(teamIdentifier: "ABCDE12345", identifier: "dev.statbatt.local")
    #expect(string == "anchor apple generic and certificate leaf[subject.OU] = \"ABCDE12345\" and identifier \"dev.statbatt.local\"")
    var requirement: SecRequirement?
    #expect(SecRequirementCreateWithString(string as CFString, SecCSFlags(), &requirement) == errSecSuccess)
    #expect(requirement != nil)
}
@Test func thermalPeerRequirementRejectsMissingIdentityAndInjection() {
    for team: String? in [nil, "", "ABCDE1234", "ABCDE123456", "ABCDE\\1234", "ABCDE\"1234", "éBCDE12345"] {
        #expect(throws: (any Error).self) { try ThermalServiceSigning.requirement(teamIdentifier: team, identifier: "dev.statbatt.local") }
    }
    for identifier: String? in [nil, "", "x\" or true", "x\\y", "x\ny", "应用", String(repeating: "a", count: 129)] {
        #expect(throws: (any Error).self) { try ThermalServiceSigning.requirement(teamIdentifier: "ABCDE12345", identifier: identifier) }
    }
}
