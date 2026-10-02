import Foundation
import Testing
import StatBattDomain
@testable import StatBattControlProtocol

private let codec = BoundedCodec()
private func sampleContext() -> CommandContext { CommandContext(expected: StateVersion(), controlSessionID: UUID()) }

@Test func boundedCodecRoundTripAndCanonicalOrdering() throws {
    let request = SetPolicyRequest(context: sampleContext(), policy: RangePolicy())
    let data = try codec.encode(request)
    let decoded = try codec.decode(SetPolicyRequest.self, from: data)
    #expect(decoded.context == request.context)
    #expect(decoded.policy.resumeAtPercent == 70)
    #expect(try codec.encode(decoded) == data)
}

@Test func negotiationUsesIntersectionWithoutControlToken() throws {
    let request = NegotiationRequest(supportedVersions: [VersionRange(major: 2, minimumMinor: 0, maximumMinor: 3), VersionRange(major: 1, minimumMinor: 0, maximumMinor: 2)], appVersion: "0.1.0-dev")
    #expect(try request.chosenVersion() == ProtocolVersion.current)
    let incompatible = NegotiationRequest(supportedVersions: [VersionRange(major: 1, minimumMinor: 1, maximumMinor: 3)], appVersion: "0.1")
    #expect(throws: WireFailure(.protocolMismatch)) { try incompatible.chosenVersion() }
    #expect(throws: WireFailure(.protocolMismatch)) { try codec.encode(VersionedRequest(protocolVersion: ProtocolVersion(major: 2))) }
}

@Test func payloadSizeMalformedUTF8AndUnknownFieldsFailClosed() throws {
    #expect(throws: WireFailure(.payloadTooLarge)) { try codec.decode(VersionedRequest.self, from: Data(repeating: 32, count: 65_537)) }
    #expect(throws: WireFailure(.malformedRequest)) { try codec.decode(VersionedRequest.self, from: Data([0xFF])) }
    #expect(throws: WireFailure(.malformedRequest)) {
        try codec.decode(VersionedRequest.self, from: Data(#"{"protocolVersion":{"major":1,"minor":0},"command":"dangerous"}"#.utf8))
    }
    #expect(throws: WireFailure(.malformedRequest)) {
        try codec.decode(VersionedRequest.self, from: Data(#"{"protocolVersion":{"major":1,"minor":0,"key":"unknown"}}"#.utf8))
    }
}

@Test func rejectsNestedUnmodeledPathsAndCallerUID() throws {
    let data = try codec.encode(SetPolicyRequest(context: sampleContext(), policy: RangePolicy()))
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var context = try #require(object["context"] as? [String: Any])
    context["ownerUID"] = 0
    object["context"] = context
    #expect(throws: WireFailure(.malformedRequest)) { try codec.decode(SetPolicyRequest.self, from: JSONSerialization.data(withJSONObject: object)) }
    context.removeValue(forKey: "ownerUID")
    object["context"] = context
    var policy = try #require(object["policy"] as? [String: Any])
    policy["executablePath"] = "/arbitrary/path"
    object["policy"] = policy
    #expect(throws: WireFailure(.malformedRequest)) { try codec.decode(SetPolicyRequest.self, from: JSONSerialization.data(withJSONObject: object)) }
}

@Test func numericBoundsAndNonfiniteValuesNeverClamp() throws {
    var policy = RangePolicy(resumeAtPercent: 79, holdAtPercent: 80)
    #expect(throws: WireFailure(.invalidConfiguration, field: "holdAtPercent")) { try codec.encode(SetPolicyRequest(context: sampleContext(), policy: policy)) }
    policy = RangePolicy(resumeAtPercent: .nan)
    #expect(throws: WireFailure(.invalidConfiguration, field: "resumeAtPercent")) { try codec.encode(SetPolicyRequest(context: sampleContext(), policy: policy)) }
    let context = sampleContext()
    for invalidDuration in [0.0, -1.0, 86_401.0, Double.infinity] {
        #expect(throws: WireFailure(.invalidConfiguration, field: "expiresAfterSeconds")) {
            try codec.encode(StartOverrideRequest(context: context, request: OverrideRequest(goal: .holdCharging, expiresAfterSeconds: invalidDuration)))
        }
    }
    #expect(throws: WireFailure(.invalidConfiguration, field: "untilPercent")) {
        try codec.encode(StartOverrideRequest(context: context, request: OverrideRequest(goal: .discharge(untilPercent: 19))))
    }
}

@Test func thermalAndAdapterConsentValidation() throws {
    let context = sampleContext()
    #expect(throws: WireFailure(.invalidConfiguration, field: "resumeBatteryTemperatureCelsius")) {
        try codec.encode(SetPolicyRequest(context: context, policy: RangePolicy(temperatureGuardEnabled: true, maximumBatteryTemperatureCelsius: 40, resumeBatteryTemperatureCelsius: 40)))
    }
    #expect(throws: WireFailure(.invalidConfiguration, field: "adapterCyclingConsent")) {
        try codec.encode(SetPolicyRequest(context: context, policy: RangePolicy(backend: .adapterCycling)))
    }
}

@Test func adminFormLengthIsValidatedButNeverRepresentsRightApproval() throws {
    #expect(throws: WireFailure(.malformedRequest, field: "externalAuthorizationForm")) {
        try codec.encode(StopRequest(authority: .admin(AdminRecoveryContext(externalAuthorizationForm: Data(repeating: 0, count: 31))), reason: .recovery))
    }
    let request = EnrollOwnerRequest(context: AdminRecoveryContext(externalAuthorizationForm: Data(repeating: 0, count: 32)), expected: StateVersion(), intent: .enroll)
    let decoded = try codec.decode(EnrollOwnerRequest.self, from: codec.encode(request))
    #expect(decoded.context.externalAuthorizationForm.count == 32)
}

@Test func consentDatesUseUTCWithFractionalSeconds() throws {
    let policy = RangePolicy(backend: .adapterCycling, adapterCyclingConsent: ConsentRecord(recordedAtUTC: Date(timeIntervalSince1970: 1_700_000_000.125), disclosureVersion: "v1"))
    let data = try codec.encode(SetPolicyRequest(context: sampleContext(), policy: policy))
    #expect(String(decoding: data, as: UTF8.self).contains("2023-11-14T22:13:20.125Z"))
    let decoded = try codec.decode(SetPolicyRequest.self, from: data)
    #expect(decoded.policy.adapterCyclingConsent?.recordedAtUTC == policy.adapterCyclingConsent?.recordedAtUTC)
}
